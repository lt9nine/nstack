local ORM = nstack.services[ "database" ].orm

---@class Model
ORM.Model = Class()

---@param name string
---@param attributes {[string]:(AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?})}
function ORM.Model:_init( name , attributes )
    self.name = name
    self.attributes = {}

    for key , value in pairs( attributes ) do
        table.insert( self.attributes , ORM.Attribute.fromDefinition( key , value ) )
    end
end

---@param attributes {[string]: any}|nil
---@return PreparedQuery
function ORM.Model:find( attributes )
    return ORM.PreparedQuery( self , ORM.QueryType.Find , attributes )
end

---@param keyValuePairs {[string]: any}
---@return PreparedQuery
function ORM.Model:add( keyValuePairs )
    return ORM.PreparedQuery( self , ORM.QueryType.Add , keyValuePairs )
end

---@param keyValuePairs {[string]: any}
---@return PreparedQuery
function ORM.Model:update( keyValuePairs )
    return ORM.PreparedQuery( self , ORM.QueryType.Update , keyValuePairs )
end

---@return PreparedQuery
function ORM.Model:remove()
    return ORM.PreparedQuery( self , ORM.QueryType.Delete , nil )
end

---@param attribute string
---@return Attribute|nil
function ORM.Model:getAttribute( attribute )
    for _ , value in pairs( self.attributes ) do
        if value.name == attribute then
            return value
        end
    end
    return nil
end

---@return Attribute[]
function ORM.Model:getAttributes()
    return self.attributes
end

---@return Attribute|nil
function ORM.Model:getIdentifier()
    for _ , value in pairs( self:getAttributes() ) do
        if type( value ) == "table" and value:getIdentifier() then
            return value
        end
    end
    return nil
end

---@return Attribute[]
function ORM.Model:getMappedAttributes()
    local resultSet = {}
    for _ , value in pairs( self:getAttributes() ) do
        if value:getType() == ORM.AttributeType.Table and value:getMapping() ~= nil then
            table.insert( resultSet , value )
        end
    end
    return resultSet
end
