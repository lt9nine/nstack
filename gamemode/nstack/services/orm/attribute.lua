local ORM = nstack.services[ "orm" ]

---@class Attribute
---@field private name string Der Name des Attribut
---@field private type AttributeType Der Typ des Attribut
---@field private identifier boolean Legt fest ob das Attribut ein Identifier ist
---@field private containedType string|nil Bei komplexen Mappings der Zieltyp
---@field private mapping MapType|nil Die Art des Mapping
ORM.Attribute = ORM.Attribute or nstack.class.New()

---Konstruktor der Attributs Klasse
---@param name string
---@param type AttributeType
function ORM.Attribute:_init( name , type )
    self:setName( name )
    self:setType( type )
    self:setIdentifier( false )
    self:setContainedType( nil )
    self:setMapping( nil )
end

---Setzt den Namen des Attribut
---@param name string
function ORM.Attribute:setName( name ) self.name = name end

---Gibt den Namen des Attribut zurück
---@return string
function ORM.Attribute:getName() return self.name end

---Setzt den Typen des Attribut
---@param type AttributeType
function ORM.Attribute:setType( type )
    assert( nstack.util.tableContains( ORM.AttributeType , type ),
        "Der Typ " .. type .. " konnte nicht den Attributstypen zugeordnet werde" )
    self.type = type
end

---Gibt den Typen des Attribut zurück
---@return AttributeType
function ORM.Attribute:getType() return self.type end

---Legt fest ob das Attribut der Identifier des Model ist
---@param identifier boolean
function ORM.Attribute:setIdentifier( identifier )
    if type( identifier ) == "boolean" then
        self.identifier = identifier
    end
end

---Gibt zurück ob das Attribut der Identifier des Model ist
---@return boolean
function ORM.Attribute:getIdentifier() return self.identifier end

---Legt den Typen fest auf den das Attribut in einem komplexen Mapping verweist
---@param containedType string|nil
function ORM.Attribute:setContainedType( containedType )
    self.containedType = containedType
end

---Gibt den Identifier des komplexen Typen zurück
---@return string
function ORM.Attribute:getContainedType() return self.containedType end

---Legt den Typen des Mapping fest
---@param mapping MapType|nil
function ORM.Attribute:setMapping( mapping )
    if mapping == nil then
        self.mapping = nil
    else
        assert( nstack.util.tableContains( ORM.MapType , mapping ),
            "Der Typ " ..
            mapping .. " konnte nicht den Mappingtypen zugeordnet werde" )
        self.mapping = mapping
    end
end

---Gibt den Typen des Mapping zurück
---@return MapType
function ORM.Attribute:getMapping() return self.mapping end

---Erzeugt ein Attribut aus einer Liste an Schlüsselpaaren
---@param name string
---@param value AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?}
---@return unknown
function ORM.Attribute.fromDefinition( name , value )
    if type( value ) == "table" then
        local attribute = ORM.Attribute( name , value.type )
        for k, v in pairs( value ) do
            if k ~= "name" or k ~= "type" then
                if k == "identifier" and type( v ) == "boolean" then
                    attribute:setIdentifier( v )
                elseif k == "containedType" then
                    attribute:setContainedType( v )
                elseif k == "mapping" then
                    attribute:setMapping( v )
                end
            end
        end
        return attribute
    elseif type( value ) == "number" then
        return ORM.Attribute( name, value )
    end
    error( "Der angegebene Typ " ..
        type( value ) .. " kann nicht in ein Attribut konvertiert werden" )
end