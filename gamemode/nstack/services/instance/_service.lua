local service = {
    name        = "instance" ,
    description = "" ,
    version     = "1.0.0" ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "instance.lua" , environment = "server" } ,
    }
}

return service
