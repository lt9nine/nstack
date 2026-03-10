local ORM = nstack.services[ "orm" ]

---@class PreparedQuery
---@field public model Model Das Model auf dem die Query laufen soll
---@field public type QueryType Der Typ der Query
---@field public attributes nil|{[string]:any} Die Attribute die die Query beachten soll
---@field public whereConditions nil|{[string]:any} Konditionen um die Query einzuschränken
---@field public sortOrder nil|({[number|string]: (string|OrderType)}) Konditionen um die Sortierung der Query zu beeinflussen
ORM.PreparedQuery = ORM.PreparedQuery or nstack.class.New()

---Der Konstruktor der Klasse
---@param model Model Das Model der Klasse
---@param queryType QueryType Der Typ der Query
---@param attributes nil|{[string]: any} Wenn angegeben die Attribute für die Query
function ORM.PreparedQuery:_init( model , queryType , attributes )
    self.model = model
    self.type = queryType
    self.attributes = attributes
    self.whereConditions = {}
    self.sortOrder = {}    
end

---Fügt der Query Filter Konditionen hinzu
---@param whereConditions nil|{[string]: any} Die Konditionen mit denen gefiltert werden soll
---@return PreparedQuery
function ORM.PreparedQuery:where( whereConditions )
    self.whereConditions = whereConditions
    return self
end

---Fügt einer Find Query Sortierungen hinzu
---@param sortOrder nil|({[number|string]: (string|OrderType)}) Die Attribute nach denen sortiert  werden soll
---@return PreparedQuery
function ORM.PreparedQuery:sort( sortOrder )
    self.sortOrder = sortOrder
    return self
end

---Führt die Query mit dem Handler des ORM aus
---@return table|nil
function ORM.PreparedQuery:run()
    return ORM.getHandler():runQuery( self )
end