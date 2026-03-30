local service = nstack.services[ "chat" ]

function service._init()
    nstack.core.log.info( "services :: chat" , "starting..." )

    service._channels      = {}
    service._sortedChannels = {}
    service._filters       = {}

    util.AddNetworkString( "nstack:service:chat:message" )

    hook.Add( "PlayerSay" , "nstack.services.chat.playerSay" , service._onPlayerSay )

    service.status = "running"
    nstack.core.log.info( "services :: chat" , "started" )

    hook.Run( "nstack.service.chat.ready" , service )
end

-- Registers a channel. Lower priority = evaluated first.
-- Warns if another channel already occupies the same priority.
function service.addChannel( name , priority , channel )
    for _ , existing in ipairs( service._sortedChannels ) do
        if ( existing.priority == priority and existing.name ~= name ) then
            nstack.core.log.warn( "services :: chat" , "channel '" .. name .. "' shares priority " .. priority .. " with channel '" .. existing.name .. "' — order between them is undefined" )
            break
        end
    end

    service._channels[ name ] = {
        name       = name ,
        priority   = priority ,
        claim      = channel.claim ,
        canReceive = channel.canReceive ,
        format     = channel.format ,
        broadcast  = channel.broadcast or false ,
    }

    service._rebuildSortedChannels()
end

-- Removes a channel by name. No-ops if not found.
function service.removeChannel( name )
    if ( not service._channels[ name ] ) then return end
    service._channels[ name ] = nil
    service._rebuildSortedChannels()
end

-- Registers a global filter. Filters veto delivery regardless of channel.
-- fn( receiver, sender, text ) → false to block, nil to allow.
function service.addFilter( name , fn )
    service._filters[ name ] = fn
end

-- Removes a filter by name.
function service.removeFilter( name )
    service._filters[ name ] = nil
end

-- Sends a message programmatically, bypassing claim logic.
-- options: { channel = name, format = fn, broadcast = bool }
-- If no channel is given, delivers to all players.
function service.send( sender , text , options )
    options = options or {}
    local channel = options.channel and service._channels[ options.channel ] or nil
    service._deliver( sender , text , channel , options.format , options.broadcast )
end

-- Delivers directly to a target without routing through channels.
-- target: Player, SteamID64 string, or a table of either.
-- formatFn: function( text, receiver ) → format table
function service.sendTo( target , text , formatFn )
    local targets = ( type( target ) == "table" and not target.IsValid ) and target or { target }

    for _ , t in ipairs( targets ) do
        if ( IsValid( t ) and t:IsPlayer() ) then
            local formatted = formatFn( text , t )
            service._deliverToPlayer( t , service._serializeFormat( formatted ) )
        elseif ( type( t ) == "string" ) then
            local localPlayer = nil
            for _ , ply in ipairs( player.GetAll() ) do
                if ( ply:SteamID64() == t ) then
                    localPlayer = ply
                    break
                end
            end

            if ( localPlayer ) then
                local formatted = formatFn( text , localPlayer )
                service._deliverToPlayer( localPlayer , service._serializeFormat( formatted ) )
            else
                -- Player is not on this server — forward via websocket.
                -- nstack.infra.websocket.broadcast( { type = "chat:direct" , target = t , text = text } , "global" )
                nstack.core.log.debug( "services :: chat" , "player " .. t .. " not on this server, websocket forward not yet implemented" )
            end
        end
    end
end

function service._rebuildSortedChannels()
    local sorted = {}
    for _ , channel in pairs( service._channels ) do
        sorted[ #sorted + 1 ] = channel
    end
    table.sort( sorted , function( a , b )
        return a.priority < b.priority
    end )
    service._sortedChannels = sorted
end

function service._passesFilters( receiver , sender , text , channel )
    for _ , filter in pairs( service._filters ) do
        if ( filter( receiver , sender , text , channel ) == false ) then return false end
    end
    return true
end

-- Converts a format table ( { Color(...), "string", ... } ) into a net-safe table.
function service._serializeFormat( formatTable )
    local serialized = {}
    for _ , entry in ipairs( formatTable ) do
        if ( type( entry ) == "table" and entry.r ~= nil ) then
            serialized[ #serialized + 1 ] = { isColor = true , r = entry.r , g = entry.g , b = entry.b }
        else
            serialized[ #serialized + 1 ] = { isColor = false , value = tostring( entry ) }
        end
    end
    return serialized
end

function service._deliverToPlayer( receiver , serialized )
    net.Start( "nstack:service:chat:message" )
        net.WriteTable( serialized )
    net.Send( receiver )
end

function service._deliver( sender , text , channel , formatOverride , broadcastOverride )
    local formatFn = formatOverride or ( channel and channel.format ) or function( s , t , r )
        local name = ( IsValid( s ) and s:Nick() ) or "[Server]"
        return { color_white , name .. ": " .. t }
    end

    local shouldBroadcast = broadcastOverride
    if ( shouldBroadcast == nil ) then
        shouldBroadcast = channel and channel.broadcast or false
    end

    for _ , receiver in ipairs( player.GetAll() ) do
        local canReceive = ( not channel ) or channel.canReceive( receiver , sender , text )
        if ( canReceive and service._passesFilters( receiver , sender , text , channel ) ) then
            local formatted = formatFn( sender , text , receiver )
            service._deliverToPlayer( receiver , service._serializeFormat( formatted ) )
        end
    end

    if ( shouldBroadcast ) then
        -- nstack.infra.websocket.broadcast( { type = "chat" , sender = IsValid( sender ) and sender:SteamID64() or nil , text = text } , "global" )
        nstack.core.log.debug( "services :: chat" , "websocket broadcast not yet implemented" )
    end
end

function service._onPlayerSay( sender , text , teamOnly )
    if ( #service._sortedChannels == 0 ) then return end

    local claimedChannel = nil
    for _ , channel in ipairs( service._sortedChannels ) do
        if ( channel.claim( sender , text , teamOnly ) ) then
            claimedChannel = channel
            break
        end
    end

    if ( not claimedChannel ) then return end

    if ( claimedChannel.onClaim ) then
        claimedChannel.onClaim( sender , text )
    end

    service._deliver( sender , text , claimedChannel , nil , nil )

    return false
end
