local service = nstack.services[ "websocket" ]

function service._init()
    nstack.core.log.trace( "services :: " .. service.name , "triggered start of service" )

    if not GWSockets then
        nstack.core.log.warn( "services :: " .. service.name , "binary module 'gwsockets' not started or missing, skipping start..." )
        return false
    end

    if nstack.services[ "websocket" ].status == "running" then
        nstack.core.log.warn( "services :: " .. service.name , "service already running, skipping start..." )
        return false
    end

    local server_id = nstack.core.identity.id
    local key       = nstack.core.identity.settings.websocket_key

    if not server_id or not key or key == "" then
        nstack.core.log.warn( "services :: " .. service.name , "no websocket_key found in network.json for this server, skipping start..." )
        return false
    end

    local url = "ws://" .. service.settings.host .. ":" .. tostring( service.settings.port )

    nstack.core.log.debug( "services :: " .. service.name , "connecting to " .. url )

    local ws = GWSockets.createWebSocket( url )

    local initBot = player.CreateNextBot( "nstack_ws_init" )

    local function removeInitBot()
        if IsValid( initBot ) then initBot:Kick( "" ) end
    end

    function ws.onConnected()
        removeInitBot()
        nstack.core.log.info( "services :: " .. service.name , "connection established, authenticating..." )

        ws:write( util.TableToJSON( {
            type      = "auth" ,
            server_id = server_id ,
            key       = key ,
        } ) )

        nstack.core.log.info( "services :: " .. service.name , "authenticated as '" .. server_id .. "'" )
    end

    function ws.onMessage( data )
        local msg = util.JSONToTable( data )

        if not msg then
            nstack.core.log.warn( "services :: " .. service.name , "received invalid JSON: " .. tostring( data ) )
            return
        end

        nstack.core.log.trace( "services :: " .. service.name , "message received, type: " .. tostring( msg.type ) )

        hook.Run( "NStack:WebSocket:Message" , msg )

        if msg.type == "broadcast" then
            hook.Run( "NStack:WebSocket:Broadcast" , msg )
        elseif msg.type == "direct" then
            hook.Run( "NStack:WebSocket:Direct" , msg )
        elseif msg.type == "rpc" then
            hook.Run( "NStack:WebSocket:RPC" , msg )
        elseif msg.type == "rpc_response" then
            hook.Run( "NStack:WebSocket:RPCResponse" , msg )
        end
    end

    function ws.onDisconnected()
        nstack.core.log.warn( "services :: " .. service.name , "disconnected" )
        nstack.services[ "websocket" ].status = "stopped"
        hook.Run( "NStack:WebSocket:Disconnected" )
    end

    function ws.onError( socketOrMsg , msg )
        removeInitBot()
        local errMsg = type( socketOrMsg ) == "string" and socketOrMsg or tostring( msg )
        nstack.core.log.error( "services :: " .. service.name , "error: " .. errMsg )
        hook.Run( "NStack:WebSocket:Error" , errMsg )
    end

    nstack.core.log.debug( "services :: " .. service.name , "opening connection..." )
    ws:open()

    service.ws = ws

    function service.broadcast( payload , channel )
        local msg = { type = "broadcast" , payload = payload }
        if channel then msg.channel = channel end
        ws:write( util.TableToJSON( msg ) )
    end

    function service.direct( to , payload )
        ws:write( util.TableToJSON( { type = "direct" , to = to , payload = payload } ) )
    end

    function service.rpc( to , id , payload )
        ws:write( util.TableToJSON( { type = "rpc" , id = id , to = to , payload = payload } ) )
    end

    function service.respond( id , payload )
        ws:write( util.TableToJSON( { type = "rpc_response" , id = id , payload = payload } ) )
    end

    function service.subscribe( channel )
        ws:write( util.TableToJSON( { type = "subscribe" , channel = channel } ) )
    end

    function service.unsubscribe( channel )
        ws:write( util.TableToJSON( { type = "unsubscribe" , channel = channel } ) )
    end
end
