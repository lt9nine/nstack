local service = nstack.services[ "database" ]
local dependencies = service.dependencies

function service._init() -- internal function
    require( "mysqloo" )

    local settings = service.settings

    if not settings or not settings.host or not settings.user or not settings.pass or not settings.name or not settings.port then
        nstack.core.log.error( "services :: " .. service.name , "missing required settings, aborting init..." )
        return false
    end

    nstack.services[ "database" ].status = "starting"
    nstack.core.log.trace( "services :: " .. service.name , "initialization triggered..." )

    nstack.core.log.trace( "services :: " .. service.name , "trying to connect to database..." )
    local databaseObject = mysqloo.connect( settings.host , settings.user , settings.pass , settings.name , settings.port )

    function databaseObject.onConnected()
        nstack.core.log.info( "services :: " .. service.name , "database connection established successfully!" )
        nstack.core.lifecycle.reportServiceReady( service.name )
    end

    function databaseObject.onConnectionFailed( error )
        nstack.core.log.error( "services :: " .. service.name , "database connection failed!" )
        nstack.services[ "database" ].status = "stopped"
    end

    function service.query( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.info( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
    end

    function service.returnQuery( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.info( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
        return q
    end

    function service.returnQueryNoStart( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.info( "services :: " .. service.name , "Query: " .. qtext )
        q.Finished = false
        q.onError = function( q , e ) nstack.core.log.error( "services :: " .. service.name , "Query failed: " .. e .. " on query: " .. qtext ) end
        return q
    end

    databaseObject:connect()

    nstack.services[ "database" ].db = databaseObject

    return true
end

function service.start() -- declaring as global and serverside function
    nstack.core.log.trace( "services :: " .. service.name , "triggered start of service" )

    if nstack.services[ "database" ].status == "running" then
        nstack.core.log.warn( "services :: " .. service.name , "service already running, skipping start..." )
        return false
    end

    for _ , v in ipairs( dependencies ) do
        if nstack.services[ v ].status != "running" then
            nstack.core.log.warn( "services :: " .. service.name , "dependency '" .. v .. "' is not running, skipping service start..." )
            return false
        end
    end

    service._init()
end