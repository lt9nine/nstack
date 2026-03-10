local ORM = nstack.services[ "orm" ]

local function checkReservedWords( input )
    for _, reserved in pairs (ORM.MysqlHandler.ReservedWords) do
        if string.lower(input) == string.lower(reserved) then
            return "`"..input.."`"
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
        local explo = string.Explode( ",", val )
        local r, g, b, a = tonumber( explo[1] ), tonumber( explo[2] ),
            tonumber( explo[3] ), tonumber( explo[4] )
        assert( r ~= nil and g ~= nil and b ~= nil and a ~= nil,
            "Die Werte der Color konnte nicht in Zahlen konvertiert werden" )
        return Color( r, g, b, a )
    elseif targetType == ORM.AttributeType.Number then
        return tonumber( val )
    elseif targetType == ORM.AttributeType.String then
        return val
    elseif targetType == ORM.AttributeType.Vector then
        local explo = string.Explode( ",", val )
        return Vector( tonumber( explo[1] ), tonumber( explo[2] ),
            tonumber( explo[3] ) )
    end

    return nil
end

---@class MysqlHandler
ORM.MysqlHandler = ORM.MysqlHandler or nstack.class.New()

ORM.MysqlHandler.ReservedWords = {
    "character"
}

---Konstruktor der Klasse
function ORM.MysqlHandler:_init()
    nstack.core.log.trace( "services :: orm" , "MysqlHandler initialized" )
end

---Baut aus den angegebenen Konditionen eine Mysql Where Query
---@param model Model
---@param whereConditions any
---@return string
local function buildWhere( model , whereConditions )
    local strConditions = {}

    for key, value in pairs( whereConditions ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil,
            "Das Attribut " ..
            key .. " konnte im Typ " .. model.name ..
            " nicht gefunden werden" )

        value = convertToString( value, attribute:getType() )

        table.insert( strConditions, key .. " = " .. value )
    end

    return "WHERE " .. table.concat( strConditions, " AND " )
end

---comment
---@param model Model
---@param sortOrder any
---@return string
local function buildSort(model , sortOrder )
    local strOrder = {}

    for key, value in pairs( sortOrder ) do
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
        assert( modelAttribute ~= nil,
            "Das Attribut " ..
            attribute .. " konnte im Typ " .. model.name ..
            " nicht gefunden werden" )



        table.insert( strOrder, attribute .. (order and " " .. order or "") )
    end

    return "ORDER BY " .. table.concat( strOrder , ", " )
end

---comment
---@param model Model
---@param attributes {[string]: any}
---@return string
local function buildUpdate( model , attributes )
    local strUpdates = {}

    for key, value in pairs( attributes ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil,
            "Das Attribut " ..
            key .. " konnte im Typ " .. model.name ..
            " nicht gefunden werden" )

        value = convertToString( value , attribute:getType() )

        table.insert( strUpdates , key .. " = " .. value )
    end

    local query = "UPDATE " ..
        checkReservedWords(model.name) .. " SET " .. table.concat( strUpdates , ", " )

    return query
end

---comment
---@param model Model
---@param attributes {[string]: any}
---@return string
local function buildAdd( model , attributes )
    local attributeNames = {}
    local attributeValues = {}

    for key, value in pairs( attributes ) do
        table.insert( attributeNames, key )
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil,
            "Das Attribut " ..
            key .. " konnte im Typ " .. model.name ..
            " nicht gefunden werden" )

        table.insert( attributeValues ,
            convertToString( value, attribute:getType() ) )
    end

    local query = "INSERT INTO " ..
    checkReservedWords(model.name) ..
        " (" ..
        table.concat( attributeNames, ", " ) ..
        ") VALUES (" .. table.concat( attributeValues, ", " ) .. ")"

    return query
end

---comment
---@param model Model
---@return unknown
-- FIXME: Complete function
local function buildDelete( model )
    local query = "DELETE FROM " .. checkReservedWords(model.name)
    return query
end

---comments
---@param model Model
---@param attributes string[]
---@return unknown
local function buildFind( model , attributes )
    local strAttributes = ""

    local directAttributes = {}
    if attributes ~= nil then
        for _, value in pairs( attributes ) do
            local attribute = model:getAttribute( value )
            assert( attribute ~= nil,
                "Das Attribut " ..
                value .. " konnte im Typ " .. model.name ..
                " nicht gefunden werden" )

            if attribute:getType() ~= ORM.AttributeType.Table and attribute:getMapping() == nil then
                table.insert( directAttributes, value )
            end
        end
    end

    if next( directAttributes ) ~= nil then
        strAttributes = table.concat( directAttributes, ", " )
    else
        strAttributes = "*"
    end


    local query = "SELECT " .. strAttributes .. " FROM " .. checkReservedWords(model.name)

    return query
end

local function convertRow( model , row )
    local result = {}
    for key, value in pairs( row ) do
        local attribute = model:getAttribute( key )
        assert( attribute ~= nil,
            "Das Attribut " ..
            key ..
            " konnte im Model " .. model.name .. " nicht gefunden werden" )

        result[key] = convertFromString( value , attribute:getType() )
    end
    return result
end

---comment
---@param query PreparedQuery
function ORM.MysqlHandler:runFind( query )
    local results = {}
    local findSql = buildFind( query.model , query.attributes )
    if next( query.whereConditions ) then
        local whereSql = buildWhere( query.model , query.whereConditions )
        findSql = findSql .. " " .. whereSql
    end

    if next( query.sortOrder ) then
        local sortSql = buildSort( query.model , query.sortOrder )
        findSql = findSql .. " " .. sortSql
    end
    local sqlQuery = nstack.services.database.returnQueryNoStart( findSql )
    sqlQuery:start()
    sqlQuery:wait()
    local data = sqlQuery:getData()

    -- Convert ResultData
    for _, row in pairs( data ) do
        table.insert( results, convertRow( query.model, row ) )
    end

    for _, row in pairs( results ) do
        -- Run Subqueries for Complex Types

        for _, value in pairs( query.model:getMappedAttributes() ) do
            -- Ensure the Mapped Model exists
            -- TODO: Check the Validity of the Models Attribute at Definition
            local subModel = ORM.getModel( value:getContainedType() )
            assert( subModel ~= nil,
                "Der Typ " ..
                value:getContainedType() .. " konnte im ORM nicht gefunden werden" )

            -- Create Queries based on the Mapping Type
            if value:getMapping() == ORM.MapType.OneToMany then
                -- assoicated Table has ForeignKey
                local sourceModelIdentifier = query.model:getIdentifier()

                local subQueryResults = query.model:find():where( {
                        ["fk_" .. query.model.name .. "_" .. sourceModelIdentifier:getName()] =
                            row[sourceModelIdentifier:getName()]
                    } )
                    :run()

                row[value:getName()] = subQueryResults
            elseif value.mapping == ORM.MapType.ManyToOne then
                -- Our Table holds foreign key
            elseif value.mapping == ORM.MapType.OneToOne then
                -- ?
            end
        end
    end

    return results
end

---comment
---@param query PreparedQuery
function ORM.MysqlHandler:runAdd( query )
    local addSql = buildAdd( query.model, query.attributes )

    -- TODO: insert Complex Objects
    local sqlQuery = nstack.services.database.returnQueryNoStart( addSql )
    sqlQuery:start()
    sqlQuery:wait()
end

function ORM.MysqlHandler:runUpdate( query )
    local updateSql = buildUpdate( query.model, query.attributes )
    if next( query.whereConditions ) then
        local whereSql = buildWhere( query.model, query.whereConditions )
        updateSql = updateSql .. " " .. whereSql
    end
    local sqlQuery = nstack.services.database.returnQueryNoStart( updateSql )
    sqlQuery:start()
    sqlQuery:wait()
end

function ORM.MysqlHandler:runDelete( query )
    local deleteSql = buildDelete( query.model )
    if next( query.whereConditions ) then
        local whereSql = buildWhere( query.model, query.whereConditions )
        deleteSql = deleteSql .. " " .. whereSql
    end

    local sqlQuery = nstack.services.database.returnQueryNoStart( deleteSql )
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