nstack.core.identifier = {}
nstack.core.identity = {}

local function identifyMe( ip )
    local json = file.Read( "gamemodes/" .. GAMEMODE.FolderName .. "/gamemode/network.json" , "GAME" )
    if not json then
        nstack.core.log.fatal( "identifier" , "network.json not found — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return
    end

    local network = util.JSONToTable( json )
    if not network or not network.servers then
        nstack.core.log.fatal( "identifier" , "network.json is malformed — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return
    end

    nstack.core.global_settings = network.global_settings or {}

    local host , port = string.match( ip , "^(.+):(%d+)$" )
    port = tonumber( port )

    for id , server in pairs( network.servers ) do
        if server.host == host and server.port == port then
            nstack.core.identity = {
                id       = id ,
                name     = server.name ,
                host     = server.host ,
                port     = server.port ,
                settings = server.settings or {} ,
            }
            nstack.core.log.info( "identifier" , "this server identified as: " .. id .. " (" .. server.name .. ")" )
            nstack.core.initialize()
            return
        end
    end

    nstack.core.log.fatal( "identifier" , "no matching server found for " .. ip .. " — shutting down" )
    -- game.ConsoleCommand( "quit\n" )
end

hook.Add( "GetGameDescription" , "nstack.core.identifier" , function()
    local ip = game.GetIPAddress()
    if not string.StartWith( ip , "0.0.0.0" ) then
        hook.Remove( "GetGameDescription" , "nstack.core.identifier" )
        identifyMe( ip )
    end
    return "nstack"
end )