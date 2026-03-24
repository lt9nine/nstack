local service = {
    name = "database" ,
    description = "Provides database connection, query functionality and object-relational mapping" ,
    version = "1.0.0" ,
    author = "https://github.com/lt9nine" ,
    settings = {} ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "credentials.lua" , environment = "server" } ,
        [ 2 ] = { file = "database.lua" , environment = "server" }
    }
}

return service