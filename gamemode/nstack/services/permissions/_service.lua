local service = {
    name        = "permissions" ,
    description = "Usergroup and per-player permission management" ,
    version     = "1.0.0" ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "permissions.lua" , environment = "server" } ,
        [ 2 ] = { file = "db.lua"          , environment = "server" } ,
    }
}

return service
