local service = {
    name        = "command" ,
    description = "Chat command dispatcher. Routes prefixed player messages to registered handlers." ,
    version     = "1.0.0" ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "command.lua" , environment = "server" } ,
    }
}

return service
