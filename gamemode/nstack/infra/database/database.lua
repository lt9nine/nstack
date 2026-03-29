local db = nstack.infra.database

function db._init( credentials )
    nstack.core.log.trace( "infra :: database" , "triggered start" )

    if not mysqloo then
        nstack.core.log.fatal( "infra :: database" , "binary module 'mysqloo' not started or missing — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return false
    end

    if db.status == "running" then
        nstack.core.log.warn( "infra :: database" , "already running, skipping start..." )
        return false
    end

    if not credentials or not credentials.host or not credentials.port or not credentials.user or not credentials.pass or not credentials.name then
        nstack.core.log.fatal( "infra :: database" , "no credentials found in network.json global_settings — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
        return false
    end

    local databaseObject = mysqloo.connect( credentials.host , credentials.user , credentials.pass , credentials.name , credentials.port )

    local initBot = player.CreateNextBot( "nstack_db_init" )

    local function removeInitBot()
        if IsValid( initBot ) then initBot:Kick( "" ) end
    end

    function databaseObject.onConnected()
        removeInitBot()
        nstack.core.log.info( "infra :: database" , "connection established successfully!" )
        db.orm.setHandler( db.orm.MysqlHandler() )
        nstack.core.log.info( "infra :: database" , "ORM handler initialized!" )
        db.status = "running"
    end

    function databaseObject.onConnectionFailed( err )
        removeInitBot()
        nstack.core.log.fatal( "infra :: database" , "connection failed: " .. tostring( err ) .. " — shutting down" )
        -- game.ConsoleCommand( "quit\n" )
    end

    function db.query( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "infra :: database" , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "infra :: database" , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
    end

    function db.returnQuery( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "infra :: database" , "Query: " .. qtext )
        q.Finished = false
        q.onSuccess = function( query ) query.Finished = true end
        q.onError = function( q , e ) nstack.core.log.error( "infra :: database" , "Query failed: " .. e .. " on query: " .. qtext ) end
        q:start()
        return q
    end

    function db.returnQueryNoStart( qtext )
        local q = databaseObject:query( qtext )
        nstack.core.log.trace( "infra :: database" , "Query: " .. qtext )
        q.Finished = false
        q.onError = function( q , e ) nstack.core.log.error( "infra :: database" , "Query failed: " .. e .. " on query: " .. qtext ) end
        return q
    end

    databaseObject:connect()

    db.db = databaseObject
end
