local db  = nstack.infra.database
local ORM = nstack.infra.database.orm

local function checkReservedWords( input )
    for _ , reserved in pairs( ORM.MysqlHandler.ReservedWords ) do
        if string.lower( input ) == string.lower( reserved ) then
            return "`" .. input .. "`"
        end
    end
    return input
end

local function escape( input )
    --TODO: Sanitize
    return input
end

local function unescape( input )
    --TODO: Unsanitize
    return input
end

local function convertToString( val , sourceType )
    local result = nil
    if sourceType == ORM.AttributeType.Angle then
        result = val.pitch .. "," .. val.yaw .. "," .. val.roll
    elseif sourceType == ORM.AttributeType.Boolean then
        result = val and 1 or 0
    elseif sourceType == ORM.AttributeType.Color then
        result = val.r .. "," .. val.g .. "," .. val.b .. "," .. val.a
    elseif sourceType == ORM.AttributeType.Number then
        result = tonumber( val )
    elseif sourceType == ORM.AttributeType.String then
        result = tostring( val )
    elseif sourceType == ORM.AttributeType.Vector then
        result = val.x .. "," .. val.y .. "," .. val.z
    end

    if type( result ) == "string" then
        result = "'" .. escape( result ) .. "'"
    end

    return result
end

local function convertFromString( val , targetType )
    val = unescape( val )
    if targetType == ORM.AttributeType.Angle then
        local explo = string.Explode( "," , val )
        return Angle( tonumber( explo[1] ) , tonumber( explo[2] ) , tonumber( explo[3] ) )
    elseif targetType == ORM.AttributeType.Boolean then
        return val == "1" and true or false
    elseif targetType == ORM.AttributeType.Color then
        local explo = string.Explode( "," , val )
        local r , g , b , a = tonumber( explo[1] ) , tonumber( explo[2] ) ,
            tonumber( explo[3] ) , tonumber( explo[4] )
        assert( r ~= nil and g ~= nil and b ~= nil and a ~= nil ,
            "Color values could not be converted to numbers" )
        return Color( r , g , b , a )
    elseif targetType == ORM.AttributeType.Number then
        return tonumber( val )
    elseif targetType == ORM.AttributeType.String then
        return val
    elseif targetType == ORM.AttributeType.Vector then
        local explo = string.Explode( "," , val )
        return Vector( tonumber( explo[1] ) , tonumber( explo[2] ) , tonumber( explo[3] ) )
    end
    return nil
end

---@class MysqlHandler
ORM.MysqlHandler = Class()

ORM.MysqlHandler.ReservedWords = {
    "character"
}

function ORM.MysqlHandler:_init()
    self.database = db.db
end

local function buildWhere( model , whereConditions )
    local strConditions = {}
    for key , value in pairs( whereConditions ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil ,
            "Attribute " .. key .. " not found in type " .. model.name )
        value = convertToString( value , attribute:getType() )
        table.insert( strConditions , key .. " = " .. value )
    end
    return "WHERE " .. table.concat( strConditions , " AND " )
end

local function buildSort( model , sortOrder )
    local strOrder = {}
    for key , value in pairs( sortOrder ) do
        local attribute = nil
        local order = nil
        if type( key ) == "number" then
            attribute = value
        else
            attribute = key
            if value == ORM.OrderType.Ascending then
                order = "ASC"
            elseif value == ORM.OrderType.Descending then
                order = "DESC"
            end
        end
        local modelAttribute = model:getAttribute( attribute )
        assert( modelAttribute ~= nil ,
            "Attribute " .. attribute .. " not found in type " .. model.name )
        table.insert( strOrder , attribute .. ( order and " " .. order or "" ) )
    end
    return "ORDER BY " .. table.concat( strOrder , ", " )
end

local function buildUpdate( model , attributes )
    local strUpdates = {}
    for key , value in pairs( attributes ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil ,
            "Attribute " .. key .. " not found in type " .. model.name )
        value = convertToString( value , attribute:getType() )
        table.insert( strUpdates , key .. " = " .. value )
    end
    return "UPDATE " .. checkReservedWords( model.name ) .. " SET " .. table.concat( strUpdates , ", " )
end

local function buildAdd( model , attributes )
    local attributeNames = {}
    local attributeValues = {}
    for key , value in pairs( attributes ) do
        table.insert( attributeNames , key )
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil ,
            "Attribute " .. key .. " not found in type " .. model.name )
        table.insert( attributeValues , convertToString( value , attribute:getType() ) )
    end
    return "INSERT INTO " .. checkReservedWords( model.name ) ..
        " (" .. table.concat( attributeNames , ", " ) ..
        ") VALUES (" .. table.concat( attributeValues , ", " ) .. ")"
end

local function buildDelete( model )
    return "DELETE FROM " .. checkReservedWords( model.name )
end

local function buildFind( model , attributes )
    local directAttributes = {}
    if attributes ~= nil then
        for _ , value in pairs( attributes ) do
            local attribute = model:getAttribute( value )
            assert( attribute ~= nil ,
                "Attribute " .. value .. " not found in type " .. model.name )
            if attribute:getType() ~= ORM.AttributeType.Table and attribute:getMapping() == nil then
                table.insert( directAttributes , value )
            end
        end
    end
    local strAttributes = next( directAttributes ) ~= nil and table.concat( directAttributes , ", " ) or "*"
    return "SELECT " .. strAttributes .. " FROM " .. checkReservedWords( model.name )
end

local function convertRow( model , row )
    local result = {}
    for key , value in pairs( row ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil ,
            "Attribute " .. key .. " not found in model " .. model.name )
        result[ key ] = convertFromString( value , attribute:getType() )
    end
    return result
end

function ORM.MysqlHandler:runFind( query )
    local findSql = buildFind( query.model , query.attributes )
    if next( query.whereConditions ) then
        findSql = findSql .. " " .. buildWhere( query.model , query.whereConditions )
    end
    if next( query.sortOrder ) then
        findSql = findSql .. " " .. buildSort( query.model , query.sortOrder )
    end
    nstack.core.log.trace( "infra :: database :: orm" , findSql )

    local sqlQuery = self.database:query( findSql )
    sqlQuery.onError = function( _ , err )
        nstack.core.log.error( "infra :: database :: orm" , "Query failed: " .. err )
    end
    sqlQuery:start()
    sqlQuery:wait()

    local results = {}
    for _ , row in pairs( sqlQuery:getData() ) do
        local converted = convertRow( query.model , row )

        for _ , value in pairs( query.model:getMappedAttributes() ) do
            local subModel = ORM.getModel( value:getContainedType() )
            assert( subModel ~= nil ,
                "Type " .. value:getContainedType() .. " not found in ORM" )

            if value:getMapping() == ORM.MapType.OneToMany then
                local sourceIdentifier = query.model:getIdentifier()
                converted[ value:getName() ] = subModel:find():where( {
                    [ "fk_" .. query.model.name .. "_" .. sourceIdentifier:getName() ] =
                        converted[ sourceIdentifier:getName() ]
                } ):run()
            end
        end

        table.insert( results , converted )
    end

    return results
end

function ORM.MysqlHandler:runAdd( query )
    local addSql = buildAdd( query.model , query.attributes )
    nstack.core.log.trace( "infra :: database :: orm" , addSql )

    local sqlQuery = self.database:query( addSql )
    sqlQuery.onError = function( _ , err )
        nstack.core.log.error( "infra :: database :: orm" , "Query failed: " .. err )
    end
    sqlQuery:start()
    sqlQuery:wait()
end

function ORM.MysqlHandler:runUpdate( query )
    local updateSql = buildUpdate( query.model , query.attributes )
    if next( query.whereConditions ) then
        updateSql = updateSql .. " " .. buildWhere( query.model , query.whereConditions )
    end
    nstack.core.log.trace( "infra :: database :: orm" , updateSql )

    local sqlQuery = self.database:query( updateSql )
    sqlQuery.onError = function( _ , err )
        nstack.core.log.error( "infra :: database :: orm" , "Query failed: " .. err )
    end
    sqlQuery:start()
    sqlQuery:wait()
end

function ORM.MysqlHandler:runDelete( query )
    local deleteSql = buildDelete( query.model )
    if next( query.whereConditions ) then
        deleteSql = deleteSql .. " " .. buildWhere( query.model , query.whereConditions )
    end
    nstack.core.log.trace( "infra :: database :: orm" , deleteSql )

    local sqlQuery = self.database:query( deleteSql )
    sqlQuery.onError = function( _ , err )
        nstack.core.log.error( "infra :: database :: orm" , "Query failed: " .. err )
    end
    sqlQuery:start()
    sqlQuery:wait()
end

function ORM.MysqlHandler:runQuery( query )
    if query.type == ORM.QueryType.Add then
        return self:runAdd( query )
    elseif query.type == ORM.QueryType.Update then
        return self:runUpdate( query )
    elseif query.type == ORM.QueryType.Delete then
        return self:runDelete( query )
    elseif query.type == ORM.QueryType.Find then
        return self:runFind( query )
    end
    return nil
end
