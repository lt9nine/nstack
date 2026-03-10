local ORM = nstack.services[ "orm" ]

---@class Model
ORM.Model = ORM.Model or nstack.class.New()

---Konstruktor des Model
---@param name string Der Name des Model
---@param attributes {[string]:(AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?})} Ein Table dessen Schlüsselpaare in Attribute konvertiert werden
function ORM.Model:_init( name , attributes )
    self.name = name
    self.attributes = {}
    
    for key, value in pairs( attributes ) do
        table.insert( self.attributes , ORM.Attribute.fromDefinition( key , value ) )
    end    
end

---Startet einen Versuch ein Objekt in der Datenbank zu finden
---@param  attributes {[string]: any}|nil Eine Liste an Schlüsselpaaren anhand welcher versucht werden soll ein Objekt zu finden
---@return PreparedQuery
function ORM.Model:find( attributes )
    return ORM.PreparedQuery( self , ORM.QueryType.Find , attributes )
end

---Startet einen Versuch ein Objekt in die Datenbank einzufügen
---@param keyValuePairs {[string]: any} Eine Liste an Schlüsselpaaren mit den Werten die einngefügt werden soll
---@return PreparedQuery
function ORM.Model:add( keyValuePairs )
    return ORM.PreparedQuery( self , ORM.QueryType.Add , keyValuePairs )
end

---Startet einen Versuch ein Objekt in der Datenbank zu aktualisieren
---@param keyValuePairs {[string]: any} Eine Liste an Schlüsselpaaren mit den aktualisierten Werten
---@return PreparedQuery
function ORM.Model:update( keyValuePairs )
    return ORM.PreparedQuery( self , ORM.QueryType.Update , keyValuePairs )
end

---Startet  einen Versuch ein Objekt aus der Datenbank zu entfernen
---@return PreparedQuery
function ORM.Model:remove()
    return ORM.PreparedQuery( self , ORM.QueryType.Delete , nil )
end

---Holt sich das Attribut mit dem entsprechenden Namen aus dem Model
---@param attribute string
---@return Attribute|nil
function ORM.Model:getAttribute( attribute )
    for _, value in pairs( self.attributes ) do
        if value.name == attribute then
            return value
        end
    end

    return nil
end

---Gibt alle Attribute des Model zurück
---@return Attribute[]
function ORM.Model:getAttributes()
    return self.attributes
end

---Gibt das identifizierende Attribut des Models zurück
---@return Attribute|nil
function ORM.Model:getIdentifier()
    for _, value in pairs( self:getAttributes() ) do
        if type( value ) == "table" and value:getIdentifier() then
            return value
        end
    end

    return nil
end

---Gibt eine Liste der gemappten Attribute zurück
---@return Attribute[]
function ORM.Model:getMappedAttributes()
    local resultSet = {}
    for _, value in pairs( self:getAttributes() ) do
        if value:getType() == ORM.AttributeType.Table and value:getMapping() ~= nil then
            table.insert( resultSet , value )
        end
    end

    return resultSet
end