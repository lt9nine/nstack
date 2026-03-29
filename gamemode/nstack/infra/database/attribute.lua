local ORM = nstack.infra.database.orm

---@class Attribute
ORM.Attribute = Class()

---@param name string
---@param type AttributeType
function ORM.Attribute:_init( name , type )
    self:setName( name )
    self:setType( type )
    self:setIdentifier( false )
    self:setContainedType( nil )
    self:setMapping( nil )
end

---@param name string
function ORM.Attribute:setName( name ) self.name = name end

---@return string
function ORM.Attribute:getName() return self.name end

---@param type AttributeType
function ORM.Attribute:setType( type )
    assert( nstack.util.tableContains( ORM.AttributeType , type ) ,
        "Type " .. type .. " could not be assigned to attribute types" )
    self.type = type
end

---@return AttributeType
function ORM.Attribute:getType() return self.type end

---@param identifier boolean
function ORM.Attribute:setIdentifier( identifier )
    if type( identifier ) == "boolean" then
        self.identifier = identifier
    end
end

---@return boolean
function ORM.Attribute:getIdentifier() return self.identifier end

---@param containedType string|nil
function ORM.Attribute:setContainedType( containedType )
    self.containedType = containedType
end

---@return string
function ORM.Attribute:getContainedType() return self.containedType end

---@param mapping MapType|nil
function ORM.Attribute:setMapping( mapping )
    if mapping == nil then
        self.mapping = nil
    else
        assert( nstack.util.tableContains( ORM.MapType , mapping ) ,
            "Type " .. mapping .. " could not be assigned to mapping types" )
        self.mapping = mapping
    end
end

---@return MapType
function ORM.Attribute:getMapping() return self.mapping end

---@param name string
---@param value AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?}
---@return Attribute
function ORM.Attribute.fromDefinition( name , value )
    if type( value ) == "table" then
        local attribute = ORM.Attribute( name , value.type )
        for k , v in pairs( value ) do
            if k == "identifier" and type( v ) == "boolean" then
                attribute:setIdentifier( v )
            elseif k == "containedType" then
                attribute:setContainedType( v )
            elseif k == "mapping" then
                attribute:setMapping( v )
            end
        end
        return attribute
    elseif type( value ) == "number" then
        return ORM.Attribute( name , value )
    end
    error( "Type " .. type( value ) .. " cannot be converted into an attribute" )
end
