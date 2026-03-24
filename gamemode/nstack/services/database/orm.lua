local service = nstack.services[ "database" ]

service.orm = {}

local ORM = service.orm

---@type Model[]
ORM.models = {}

---@type MysqlHandler
ORM.handler = nil

---@param handler MysqlHandler
function ORM.setHandler( handler )
    assert( handler[ "runQuery" ] ~= nil , "Handler is not valid" )
    ORM.handler = handler
end

---@return MysqlHandler
function ORM.getHandler()
    return ORM.handler
end

---@param name string
---@param attributes (AttributeType|{name: string?, type: AttributeType, identifier: boolean?, containedType: string?, mapping: MapType?})[]
function ORM.define( name , attributes )
    ORM[ name ] = ORM.Model( name , attributes )
end

---@param name string
---@return Model|nil
function ORM.getModel( name )
    return ORM[ name ]
end
