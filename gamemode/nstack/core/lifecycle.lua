nstack.core.lifecycle = {}
nstack.core.lifecycle.state = 0
nstack.core.lifecycle.states = {
    [ 0 ] = "load" ,
    [ 1 ] = "init" ,
    [ 2 ] = "start" ,
    [ 3 ] = "live" ,
}

function nstack.core.lifecycle.start()
    hook.Run( "NStack.Core.Lifecycle.Changed" , -1 , 0 )
    nstack.core.log.info( "lifecycle" , "Started lifecycle with state 0" )
end

function nstack.core.lifecycle.onChange( oldState , newState )
    nstack.core.log.info( "lifecycle" , "State changed from " .. oldState .. " to " .. newState )

    hook.Run( "NStack.Core.Lifecycle.Changed" , oldState , newState )
end

function nstack.core.lifecycle.set( state )
    if nstack.core.lifecycle.state == state then return end

    if not nstack.core.lifecycle.states[ state ] then
        nstack.core.log.fatal( "lifecycle" , "State " .. state .. " does not exist" )
        return
    end
    
    local currentState = nstack.core.lifecycle.state
    
    -- Check if lifecycle went a step back
    if currentState ~= nil and state < currentState then
        nstack.core.log.warn( "lifecycle" , string.format( "Lifecycle went backwards from state %d (%s) to state %d (%s)" , 
            currentState , nstack.core.lifecycle.states[ currentState ] , 
            state , nstack.core.lifecycle.states[ state ] 
        ) )
    end

    -- Check if a state was skipped
    if currentState ~= nil and state > currentState + 1 then
        local skippedStates = {}
        for i = currentState + 1 , state - 1 do
            table.insert( skippedStates , string.format( "%d (%s)" , i , nstack.core.lifecycle.states[ i ] ) )
        end
        nstack.core.log.warn( "lifecycle" , string.format( "State skipped: jumped from state %d (%s) to state %d (%s), skipped: %s" , 
            currentState , nstack.core.lifecycle.states[ currentState ] , 
            state , nstack.core.lifecycle.states[ state ] , 
            table.concat( skippedStates , ", " ) 
        ) )
    end
    
    nstack.core.lifecycle.state = state
    nstack.core.log.debug( "lifecycle" , "Sent lifecycle sync" )
    nstack.core.lifecycle.onChange( currentState , state )
end

function nstack.core.lifecycle.get()
    return nstack.core.lifecycle.state
end

-- Tracks which services must be running before the framework advances to "live"
nstack.core.lifecycle.pendingServices = {}

function nstack.core.lifecycle.registerService( name )
    nstack.core.lifecycle.pendingServices[ name ] = false
    nstack.core.log.debug( "lifecycle" , "Registered service '" .. name .. "' as pending" )
end

function nstack.core.lifecycle.checkReady()
    if nstack.core.lifecycle.state == 3 then return end

    for _ , ready in pairs( nstack.core.lifecycle.pendingServices ) do
        if not ready then return end
    end

    nstack.core.lifecycle.set( 3 )
    hook.Run( "NStack.Core.Ready" )
end

function nstack.core.lifecycle.reportServiceReady( name )
    if nstack.core.lifecycle.pendingServices[ name ] == nil then
        nstack.core.log.warn( "lifecycle" , "Service '" .. name .. "' reported ready but was never registered" )
        return
    end

    nstack.services[ name ].status = "running"
    nstack.core.lifecycle.pendingServices[ name ] = true
    nstack.core.log.debug( "lifecycle" , "Service '" .. name .. "' is ready" )

    -- Retry any services that skipped start because a dependency was not yet ready
    if nstack.core.lifecycle.loadOrder then
        for _ , serviceName in ipairs( nstack.core.lifecycle.loadOrder ) do
            local s = nstack.services[ serviceName ]
            if istable( s ) and s.status == "stopped" and s.start then
                s.start()
            end
        end
    end

    nstack.core.lifecycle.checkReady()
end