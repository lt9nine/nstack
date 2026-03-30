local service = {
    name        = "voice" ,
    description = "" ,
    version     = "1.0.0" ,
    environment = "server" ,
    settings    = {
        
    } ,
    files = {
        [ 1 ] = { file = "voice.lua" , environment = "server" } ,
    }
}

return service
