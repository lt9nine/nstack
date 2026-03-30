local service = nstack.services[ "command" ]

function service._init()
    nstack.core.log.info( "services :: command" , "starting..." )

    service._prefixes     = {}  -- prefix → { commands = { name → fn }, channelRegistered = bool }
    service._chatService  = nil

    local chatService = nstack.services[ "chat" ]
    if ( chatService and chatService.status == "running" ) then
        service._registerWithChat( chatService )
    else
        hook.Add( "nstack.service.chat.ready" , "nstack.service.command.registerWithChat" , service._registerWithChat )
    end

    service.status = "running"
    nstack.core.log.info( "services :: command" , "started" )
end

-- Registers a command handler for a given prefix.
-- fn( sender, args ) — args is a table of whitespace-split tokens after the command name.
function service.addCommand( prefix , name , fn )
    if ( not service._prefixes[ prefix ] ) then
        service._prefixes[ prefix ] = { commands = {} , channelRegistered = false }
    end

    service._prefixes[ prefix ].commands[ string.lower( name ) ] = fn
    service._ensurePrefixChannel( prefix )

    nstack.core.log.debug( "services :: command" , "registered command '" .. name .. "' for prefix '" .. prefix .. "'" )
end

-- Removes a command handler. Unregisters the prefix channel if no commands remain.
function service.removeCommand( prefix , name )
    local prefixData = service._prefixes[ prefix ]
    if ( not prefixData ) then return end

    prefixData.commands[ string.lower( name ) ] = nil

    if ( table.Count( prefixData.commands ) == 0 ) then
        if ( service._chatService ) then
            service._chatService.removeChannel( "command:" .. prefix )
        end
        service._prefixes[ prefix ] = nil
        nstack.core.log.debug( "services :: command" , "unregistered prefix '" .. prefix .. "' — no commands remaining" )
    end
end

function service._registerWithChat( chatService )
    service._chatService = chatService

    for prefix , _ in pairs( service._prefixes ) do
        service._ensurePrefixChannel( prefix )
    end
end

function service._ensurePrefixChannel( prefix )
    if ( not service._chatService ) then return end

    local prefixData = service._prefixes[ prefix ]
    if ( not prefixData or prefixData.channelRegistered ) then return end

    local prefixLength = #prefix

    service._chatService.addChannel( "command:" .. prefix , 1 , {
        claim = function( sender , text , teamOnly )
            return string.sub( text , 1 , prefixLength ) == prefix
        end ,
        onClaim = function( sender , text )
            local parts = {}
            for token in string.gmatch( string.sub( text , prefixLength + 1 ) , "%S+" ) do
                parts[ #parts + 1 ] = token
            end

            local name = string.lower( table.remove( parts , 1 ) or "" )
            local handler = prefixData.commands[ name ]

            if ( handler ) then
                handler( sender , parts )
            else
                nstack.core.log.debug( "services :: command" , "unknown command '" .. name .. "' for prefix '" .. prefix .. "'" )
            end
        end ,
        canReceive = function( receiver , sender , text ) return false end ,
    } )

    prefixData.channelRegistered = true
    nstack.core.log.debug( "services :: command" , "registered channel for prefix '" .. prefix .. "'" )
end
