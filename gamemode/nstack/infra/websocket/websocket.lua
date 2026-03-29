local ws = nstack.infra.websocket

function ws._init( settings )
    nstack.core.log.trace( "infra :: websocket" , "triggered start" )

    if not GWSockets then
        nstack.core.log.fatal( "infra :: websocket" , "binary module 'gwsockets' not started or missing — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return false
    end

    if ws.status == "running" then
        nstack.core.log.warn( "infra :: websocket" , "already running, skipping start..." )
        return false
    end

    local server_id = nstack.core.identity.id
    local key       = nstack.core.identity.settings.websocket_key

    if not server_id or not key or key == "" then
        nstack.core.log.fatal( "infra :: websocket" , "no websocket_key found in network.json for this server — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return false
    end

    local url = "ws://" .. settings.host .. ":" .. tostring( settings.port )

    nstack.core.log.debug( "infra :: websocket" , "connecting to " .. url )

    local socket = GWSockets.createWebSocket( url )
    local connected = false

    local initBot = player.CreateNextBot( "nstack_ws_init" )

    local function removeInitBot()
        if IsValid( initBot ) then initBot:Kick( "" ) end
    end

    function socket.onConnected()
        removeInitBot()
        nstack.core.log.info( "infra :: websocket" , "connection established, authenticating..." )

        socket:write( util.TableToJSON( {
            type      = "auth" ,
            server_id = server_id ,
            key       = key ,
        } ) )

        connected = true
        ws.status = "running"
        hook.Run( "nstack.infra.websocket.connected" )
        nstack.core.log.info( "infra :: websocket" , "authenticated as '" .. server_id .. "'" )
    end

    function socket.onMessage( data )
        local msg = util.JSONToTable( data )

        if not msg then
            nstack.core.log.warn( "infra :: websocket" , "received invalid JSON: " .. tostring( data ) )
            return
        end

        nstack.core.log.trace( "infra :: websocket" , "message received, type: " .. tostring( msg.type ) )

        hook.Run( "nstack.infra.websocket.Message" , msg )

        if msg.type == "broadcast" then
            hook.Run( "nstack.infra.websocket.broadcast" , msg )
        elseif msg.type == "direct" then
            hook.Run( "nstack.infra.websocket.direct" , msg )
        elseif msg.type == "rpc" then
            hook.Run( "nstack.infra.websocket.rpc" , msg )
        elseif msg.type == "rpc_response" then
            hook.Run( "nstack.infra.websocket.rpc_response" , msg )
        end
    end

    function socket.onDisconnected()
        nstack.core.log.warn( "infra :: websocket" , "disconnected" )
        ws.status = "stopped"
        hook.Run( "nstack.infra.websocket.disconnected" )
    end

    function socket.onError( socketOrMsg , msg )
        removeInitBot()
        local errMsg = type( socketOrMsg ) == "string" and socketOrMsg or tostring( msg )
        if not connected then
            nstack.core.log.fatal( "infra :: websocket" , "connection failed: " .. errMsg .. " — shutting down" )
            -- game.ConsoleCommand( "quit\n" )
        else
            nstack.core.log.error( "infra :: websocket" , "error: " .. errMsg )
        end
        hook.Run( "nstack.infra.websocket.error" , errMsg )
    end

    nstack.core.log.debug( "infra :: websocket" , "opening connection..." )
    socket:open()

    ws.socket = socket

    function ws.broadcast( payload , channel )
        local msg = { type = "broadcast" , payload = payload }
        if channel then msg.channel = channel end
        socket:write( util.TableToJSON( msg ) )
    end

    function ws.direct( to , payload )
        socket:write( util.TableToJSON( { type = "direct" , to = to , payload = payload } ) )
    end

    function ws.rpc( to , id , payload )
        socket:write( util.TableToJSON( { type = "rpc" , id = id , to = to , payload = payload } ) )
    end

    function ws.respond( id , payload )
        socket:write( util.TableToJSON( { type = "rpc_response" , id = id , payload = payload } ) )
    end

    function ws.subscribe( channel )
        socket:write( util.TableToJSON( { type = "subscribe" , channel = channel } ) )
    end

    function ws.unsubscribe( channel )
        socket:write( util.TableToJSON( { type = "unsubscribe" , channel = channel } ) )
    end
end
