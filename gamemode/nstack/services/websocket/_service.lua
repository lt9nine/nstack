local service = {
    name = "websocket" ,
    description = "Provides websocket connection to nhub for multi-server communication" ,
    version = "1.0.0" ,
    author = "https://github.com/lt9nine" ,
    settings = {
        host = "136.243.175.175" ,
        port = 27011 ,
    } ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "websocket.lua" , environment = "server" } ,
    }
}

return service

-- You need to open the selected port on the machine. if websocket and game server are on same machine, you need to allow loopbacks!