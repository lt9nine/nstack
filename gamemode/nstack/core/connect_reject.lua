nstack.core.connect_reject = {}
nstack.core.connect_reject.starting = true

-- if own permission system: add bans, whitelists etc.

hook.Add( "CheckPassword" , "nstack.core.connect_reject" , function( steamid64 , ip , sv , cl , name )
    if nstack.core.connect_reject.starting then
        nstack.core.log.debug( "core" , "Player " .. name .. " tried to connect while server is starting, rejecting connection..." )
        return false , "[nstack]: Server is still starting, try again later..."
    end

    if nstack.core.global_settings.maintenance and nstack.core.global_settings.maintenance.active then
        if not table.HasValue( nstack.core.global_settings.maintenance.whitelist , tostring( steamid64 ) ) then
            nstack.core.log.warn( "core :: connect-reject" , "Player " .. name .. " tried to connect while server is in maintenance mode, rejecting connection..." )
            return false , "[nstack]: Server is in maintenance mode!"
        end
    end

    return true
end )

hook.Add( "nstack.initialized" , "nstack.core.connect_reject.initialized" , function()
    nstack.core.connect_reject.starting = false
end )