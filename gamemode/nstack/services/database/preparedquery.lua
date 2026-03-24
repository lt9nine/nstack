local ORM = nstack.services[ "database" ].orm

---@class PreparedQuery
ORM.PreparedQuery = Class()

---@param model Model
---@param queryType QueryType
---@param attributes nil|{[string]: any}
function ORM.PreparedQuery:_init( model , queryType , attributes )
    self.model = model
    self.type = queryType
    self.attributes = attributes
    self.whereConditions = {}
    self.sortOrder = {}
end

---@param whereConditions nil|{[string]: any}
---@return PreparedQuery
function ORM.PreparedQuery:where( whereConditions )
    self.whereConditions = whereConditions
    return self
end

---@param sortOrder nil|({[number|string]: (string|OrderType)})
---@return PreparedQuery
function ORM.PreparedQuery:sort( sortOrder )
    self.sortOrder = sortOrder
    return self
end

---@return table|nil
function ORM.PreparedQuery:run()
    return ORM.getHandler():runQuery( self )
end
