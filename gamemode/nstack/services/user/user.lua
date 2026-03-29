local service = nstack.services[ "user" ]
local ORM     = nstack.infra.database.orm
local ws      = nstack.infra.websocket

local WS_CHANNEL = "nstack.service.user"

-- steamid64 -> { data = { ... } , server = string , joinTime = number|nil }
-- joinTime is only set for players local to this server (used for session duration calc)
-- server identifies which gameserver the player is currently on
service.cache = {}

local User

function service._init()
    nstack.core.log.info( "services :: user" , "starting..." )

    ORM.define( "user" , {
        steamid64     = { type = ORM.AttributeType.String , identifier = true } ,
        name          = ORM.AttributeType.String ,
        first_seen    = ORM.AttributeType.Number ,
        last_seen     = ORM.AttributeType.Number ,
        playtime      = ORM.AttributeType.Number ,
        session_count = ORM.AttributeType.Number ,
        last_ip       = ORM.AttributeType.String ,
    } )

    User = ORM.getModel( "user" )

    hook.Add( "PlayerInitialSpawn" , "nstack.services.user.onJoin"  , service.onJoin )
    hook.Add( "PlayerDisconnected" , "nstack.services.user.onLeave" , service.onLeave )

    hook.Add( "nstack.infra.websocket.connected"  , "nstack.services.user.wsConnected"  , service.onWsConnected )
    hook.Add( "nstack.infra.websocket.broadcast"  , "nstack.services.user.wsBroadcast"  , service.onWsBroadcast )

    -- websocket may already be connected if it came up before this service initialized
    if ws.status == "running" then
        service.onWsConnected()
    end

    nstack.core.log.info( "services :: user" , "started" )
end

function service.onWsConnected()
    ws.subscribe( WS_CHANNEL )
    nstack.core.log.debug( "services :: user" , "subscribed to " .. WS_CHANNEL )
end

function service.onWsBroadcast( msg )
    if msg.channel ~= WS_CHANNEL then return end

    local payload = msg.payload
    if not payload or not payload.event or not payload.steamid64 then return end

    if payload.event == "join" then
        service.cache[ payload.steamid64 ] = {
            data     = payload.data ,
            server   = payload.server ,
            joinTime = nil ,
        }
        nstack.core.log.debug( "services :: user" , "remote join: " .. payload.data.name .. " on " .. payload.server )

    elseif payload.event == "leave" then
        service.cache[ payload.steamid64 ] = nil
        nstack.core.log.debug( "services :: user" , "remote leave: " .. tostring( payload.steamid64 ) .. " from " .. payload.server )
    end
end

function service.onJoin( player )
    local steamid64 = player:SteamID64()
    local name      = player:Nick()
    local ip        = string.match( player:IPAddress() , "^([^:]+)" )
    local now       = os.time()
    local serverId  = nstack.core.identity.id

    local results = User:find():where( { steamid64 = steamid64 } ):run()

    local userData
    if results[ 1 ] then
        userData = results[ 1 ]

        User:update( {
            name          = name ,
            last_seen     = now ,
            last_ip       = ip ,
            session_count = userData.session_count + 1 ,
        } ):where( { steamid64 = steamid64 } ):run()

        userData.name          = name
        userData.last_seen     = now
        userData.last_ip       = ip
        userData.session_count = userData.session_count + 1
    else
        userData = {
            steamid64     = steamid64 ,
            name          = name ,
            first_seen    = now ,
            last_seen     = now ,
            playtime      = 0 ,
            session_count = 1 ,
            last_ip       = ip ,
        }

        User:add( userData ):run()
    end

    service.cache[ steamid64 ] = { data = userData , server = serverId , joinTime = now }

    nstack.core.log.debug( "services :: user" , "synced " .. name .. " (" .. steamid64 .. ")" )

    if ws.status == "running" then
        ws.broadcast( {
            event     = "join" ,
            steamid64 = steamid64 ,
            server    = serverId ,
            data      = userData ,
        } , WS_CHANNEL )
    end
end

function service.onLeave( player )
    local steamid64 = player:SteamID64()
    local entry     = service.cache[ steamid64 ]
    local serverId  = nstack.core.identity.id

    if not entry then
        nstack.core.log.warn( "services :: user" , "no cache entry for " .. tostring( player:Nick() ) .. " on disconnect" )
        return
    end

    local sessionDuration = os.time() - entry.joinTime
    local now             = os.time()

    User:update( {
        last_seen = now ,
        playtime  = entry.data.playtime + sessionDuration ,
    } ):where( { steamid64 = steamid64 } ):run()

    service.cache[ steamid64 ] = nil

    nstack.core.log.debug( "services :: user" , "saved session for " .. tostring( player:Nick() ) .. " (" .. steamid64 .. ")" )

    if ws.status == "running" then
        ws.broadcast( {
            event     = "leave" ,
            steamid64 = steamid64 ,
            server    = serverId ,
        } , WS_CHANNEL )
    end
end

-- Returns the cached user data table for a given steamid64, or nil if not online anywhere.
function service.getUser( steamid64 )
    local entry = service.cache[ steamid64 ]
    return entry and entry.data or nil
end

-- Returns the server id the player is currently on, or nil if not online anywhere.
function service.getServer( steamid64 )
    local entry = service.cache[ steamid64 ]
    return entry and entry.server or nil
end

-- Returns true if the player is currently online on this specific server.
function service.isLocal( steamid64 )
    local entry = service.cache[ steamid64 ]
    return entry ~= nil and entry.server == nstack.core.identity.id
end
