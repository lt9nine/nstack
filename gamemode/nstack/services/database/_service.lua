local service = {
    name = "database" ,
    description = "Provides database connection, query functionality and object-relational mapping" ,
    version = "1.0.0" ,
    author = "https://github.com/lt9nine" ,
    settings = {} ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "credentials.lua"   , environment = "server" } ,
        [ 2 ] = { file = "orm.lua"           , environment = "server" } ,
        [ 3 ] = { file = "enums.lua"         , environment = "server" } ,
        [ 4 ] = { file = "preparedquery.lua" , environment = "server" } ,
        [ 5 ] = { file = "attribute.lua"     , environment = "server" } ,
        [ 6 ] = { file = "model.lua"         , environment = "server" } ,
        [ 7 ] = { file = "mysql.lua"         , environment = "server" } ,
        [ 8 ] = { file = "database.lua"      , environment = "server" } ,
    }
}

return service