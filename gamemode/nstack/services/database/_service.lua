local service = {
    name = "database" ,
    description = "Provides a database connection and query functionality" ,
    version = "1.0.0" ,
    author = "Nineware" ,
    dependencies = {} ,
    settings = {} ,
    files = {
        [ 1 ] = { file = "credentials.lua" , environment = "server" } ,
        [ 2 ] = { file = "database.lua" , environment = "server" } ,
    }
}

return service