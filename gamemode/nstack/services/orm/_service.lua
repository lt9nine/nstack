local service = {
    name = "orm" ,
    description = "Provides a object-relational mapping functionality" ,
    version = "1.0.0" ,
    author = "Nineware" ,
    dependencies = { "database" } ,
    settings = {} ,
    files = {
        [ 1 ] = { file = "orm.lua" , environment = "server" } ,
        [ 2 ] = { file = "enums.lua" , environment = "server" } ,
        [ 3 ] = { file = "preparedquery.lua" , environment = "server" } ,
        [ 4 ] = { file = "attribute.lua" , environment = "server" } ,
        [ 5 ] = { file = "model.lua" , environment = "server" } ,
        [ 6 ] = { file = "mysql.lua" , environment = "server" } ,
    }
}

return service