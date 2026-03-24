local ORM = nstack.services[ "database" ].orm

---@enum AttributeType
ORM.AttributeType = {
    Angle = 1,
    Boolean = 2,
    Color = 3,
    Number = 4,
    String = 5,
    Vector = 6,
    Table = 7
}

---@enum QueryType
ORM.QueryType = {
    Add = 1,
    Update = 2,
    Delete = 3,
    Find = 4
}

---@enum OrderType
ORM.OrderType = {
    Descending = 1,
    Ascending = 2
}

---@enum MapType
ORM.MapType = {
    OneToMany = 1,
    ManyToOne = 2,
    ManyToMany = 3,
    OneToOne = 4
}
