local service = nstack.services[ "database" ]

function service._init()
    require( "mysqloo" )

    nstack.core.log.trace( "services :: " .. service.name , "triggered start of service" )

    if nstack.services[ "database" ].status == "running" then
        nstack.core.log.warn( "services :: " .. service.name , "service already running, skipping start..." )
        return false
    end

    if not service.settings or not service.settings.host or not service.settings.port or not service.settings.user or not service.settings.pass or not service.settings.name then
        nstack.core.log.warn( "services :: " .. service.name , "No credentials found for database, skipping start..." )
        return false
    end

    local databaseObject = mysqloo.connect( settings.host , settings.user , settings.pass , settings.name , settings.port )

    function databaseObject.onConnected()
        nstack.core.log.info( "services :: " .. service.name , "database connection established successfully!" )
        nstack.core.lifecycle.reportServiceReady( service.name )
    end

    function databaseObject.onConnectionFailed( error )
        nstack.core.log.error( "services :: " .. service.name , "database connection failed!" )
        nstack.services[ "database" ].status = "stopped"
        return false
    end

    function service.query( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
    end

    function service.returnQuery( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
        return q
    end

    function service.returnQueryNoStart( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        return q
    end

    databaseObject:connect()

    nstack.services[ "database" ].db = databaseObject

    return true
end