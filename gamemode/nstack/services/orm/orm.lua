local service = nstack.services[ "orm" ]
local ORM = service

---@class ORM
---@field private models Model[] Die Models die im ORM registriert wurden
---@field private handler MysqlHandler Der Handler mit dem auf die Datenbank zugegriffen werden soll

---Eine Liste der Models die in dem ORM registriert sind
---@type Model[]
ORM.models = {}

---Der Handler den der ORM benutzt um auf die Datenbank zuzugreifen
---@type MysqlHandler
ORM.handler = nil

---Validiert ob der Handler alle benötigten Eigenschaften enthält
---@param handler MysqlHandler
---@return boolean
local function validateHandler( handler )
    return handler[ "runQuery" ] ~= nil
end

---Setzt den Handler der die Verbindung zur Datenbank herstellt
---@param handler MysqlHandler
function ORM.setHandler( handler )
    assert( validateHandler( handler ) , "Der Handler ist nicht valide" )
    ORM.handler = handler
end

---Gibt den festgelegten Handler zurück
---@return MysqlHandler
function ORM.getHandler()
    return ORM.handler
end

---Definiert ein neues Model in dem ORM
---@param name string Der Name des zu definierenden Model
---@param attributes (AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?})[] Die Liste der Attribute des Model
function ORM.define( name , attributes )
    ORM[ name ] = ORM.Model( name , attributes )
end

---Lädt das Model mit dem entsprechenden Namen aus dem ORM
---@param name string Der Name des Model
---@return Model|nil
function ORM.getModel( name )
    return ORM[ name ]
end

function service._init()
    nstack.core.log.trace( "services :: " .. service.name , "initialization triggered..." )

    local handler = ORM.MysqlHandler()
    ORM.setHandler( handler )

    nstack.core.log.info( "services :: " .. service.name , "ORM handler initialized" )
    nstack.core.lifecycle.reportServiceReady( service.name )

    return true
end

function service.start()
    nstack.core.log.trace( "services :: " .. service.name , "triggered start of service" )

    if nstack.services[ service.name ].status == "running" then
        nstack.core.log.warn( "services :: " .. service.name , "service already running, skipping start..." )
        return false
    end

    for _ , v in ipairs( service.dependencies ) do
        if nstack.services[ v ].status != "running" then
            nstack.core.log.warn( "services :: " .. service.name , "dependency '" .. v .. "' is not running, skipping service start..." )
            return false
        end
    end

    service._init()
end