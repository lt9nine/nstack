local service = {
    name        = "chat" ,
    description = "Text chat routing via composable channels and filters." ,
    version     = "1.0.0" ,
    environment = "shared" ,
    files = {
        [ 1 ] = { file = "chat.lua"    , environment = "server" } ,
        [ 2 ] = { file = "cl_chat.lua" , environment = "client" } ,
    }
}

return service
