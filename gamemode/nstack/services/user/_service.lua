local service = {
    name        = "user" ,
    description = "Tracks player identity and session data (steamid64, name, playtime, ...)" ,
    version     = "1.0.0" ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "user.lua" , environment = "server" } ,
    }
}

return service
