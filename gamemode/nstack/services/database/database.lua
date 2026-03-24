local service = nstack.services[ "database" ]

function service._init()
    nstack.core.log.trace( "services :: " .. service.name , "triggered start of service" )

    if not mysqloo then
        nstack.core.log.warn( "services :: " .. service.name , "binary module 'mysqloo' not started or missing, skipping start..." )
        return false
    end

    if nstack.services[ "database" ].status == "running" then
        nstack.core.log.warn( "services :: " .. service.name , "service already running, skipping start..." )
        return false
    end

    if not service.credentials or not service.credentials.host or not service.credentials.port or not service.credentials.user or not service.credentials.pass or not service.credentials.name then
        nstack.core.log.warn( "services :: " .. service.name , "No credentials found for database, skipping start..." )
        return false
    end

    local databaseObject = mysqloo.connect( service.credentials.host , service.credentials.user , service.credentials.pass , service.credentials.name , service.credentials.port )

    local initBot = player.CreateNextBot( "nstack_db_init" )

    local function removeInitBot()
        if IsValid( initBot ) then initBot:Kick( "" ) end -- Create "Player" to kickstart the Think Hook! Outsource in the future?
    end

    function databaseObject.onConnected()
        removeInitBot()
        nstack.core.log.info( "services :: " .. service.name , "database connection established successfully!" )
    end

    function databaseObject.onConnectionFailed( err )
        removeInitBot()
        nstack.core.log.error( "services :: " .. service.name , "database connection failed!" )
        nstack.services[ "database" ].status = "stopped"
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
end