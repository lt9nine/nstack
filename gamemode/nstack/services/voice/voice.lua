local service = nstack.services[ "voice" ]

function service._init()
    nstack.core.log.info( "services :: voice" , "starting..." )

    service._rules = {}
    service._sortedRules = {}

    hook.Add( "PlayerCanHearPlayersVoice" , "nstack.services.voice.playerCanHearPlayer" , service.playerCanHearPlayer )

    service.status = "running"
    nstack.core.log.info( "services :: voice" , "started" )

    hook.Run( "nstack.service.voice.ready" , service )
end

function service.addRule( name , priority , fn )
    for _ , rule in ipairs( service._sortedRules ) do
        if ( rule.priority == priority and rule.name ~= name ) then
            nstack.core.log.warn( "services :: voice" , "rule '" .. name .. "' shares priority " .. priority .. " with rule '" .. rule.name .. "' — order between them is undefined" )
            break
        end
    end

    service._rules[ name ] = { name = name , priority = priority , fn = fn }
    service._rebuildSortedRules()
end

function service.removeRule( name )
    if ( not service._rules[ name ] ) then return end

    service._rules[ name ] = nil
    service._rebuildSortedRules()
end

function service._rebuildSortedRules()
    local sorted = {}

    for _ , rule in pairs( service._rules ) do
        sorted[ #sorted + 1 ] = rule
    end

    table.sort( sorted , function( a , b )
        return a.priority < b.priority
    end )

    service._sortedRules = sorted
end

function service.playerCanHearPlayer( receiver , sender )
    if ( #service._sortedRules == 0 ) then return end

    for _ , rule in ipairs( service._sortedRules ) do
        local canHear , use3D = rule.fn( receiver , sender )
        if ( canHear ~= nil ) then
            return canHear , use3D
        end
    end
end
