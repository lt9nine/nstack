local service = nstack.services[ "permissions" ]
local ORM     = nstack.infra.database.orm

local Permission

local function _parseAdditionals( json )
    if ( not json or json == "" or json == "null" ) then return {} end
    return util.JSONToTable( json ) or {}
end

local function _serializeAdditionals( additionals )
    if ( not additionals or #additionals == 0 ) then return "[]" end
    return util.TableToJSON( additionals )
end

function service._initDb()
    ORM.define( "permission" , {
        steamid64   = { type = ORM.AttributeType.String , identifier = true } ,
        usergroup   = ORM.AttributeType.String ,
        additionals = ORM.AttributeType.String ,
    } )

    Permission = ORM.getModel( "permission" )
end

function service._onJoin( player )
    local steamid64 = player:SteamID64()
    local results   = Permission:find():where( { steamid64 = steamid64 } ):run()

    if ( results[ 1 ] ) then
        service.cache[ steamid64 ] = {
            usergroup   = results[ 1 ].usergroup ,
            additionals = _parseAdditionals( results[ 1 ].additionals ) ,
        }
        nstack.core.log.trace( "services :: permissions" , "loaded " .. steamid64 .. " → " .. results[ 1 ].usergroup )
    else
        service.cache[ steamid64 ] = {
            usergroup   = service.defaultGroup ,
            additionals = {} ,
        }
        Permission:add( {
            steamid64   = steamid64 ,
            usergroup   = service.defaultGroup ,
            additionals = "[]" ,
        } ):run()
        nstack.core.log.trace( "services :: permissions" , "created record for " .. steamid64 .. " as " .. service.defaultGroup )
    end
end

function service._onLeave( player )
    service.cache[ player:SteamID64() ] = nil
end

-- Assigns a usergroup to a player and persists the change immediately.
function service.setGroup( steamid64 , groupName )
    local entry = service.cache[ steamid64 ]
    if ( entry ) then
        entry.usergroup = groupName
    end

    Permission:update( { usergroup = groupName } ):where( { steamid64 = steamid64 } ):run()
    nstack.core.log.debug( "services :: permissions" , "setGroup " .. steamid64 .. " → " .. groupName )
end

-- Adds a permission to a player's per-player additionals and persists it.
-- No-op if the permission is already present.
function service.addAdditional( steamid64 , permission )
    local entry = service.cache[ steamid64 ]
    if ( not entry ) then
        nstack.core.log.warn( "services :: permissions" , "addAdditional: no cache entry for " .. steamid64 )
        return
    end

    for _ , perm in ipairs( entry.additionals ) do
        if ( perm == permission ) then return end
    end

    entry.additionals[ #entry.additionals + 1 ] = permission
    Permission:update( { additionals = _serializeAdditionals( entry.additionals ) } ):where( { steamid64 = steamid64 } ):run()
    nstack.core.log.trace( "services :: permissions" , "addAdditional " .. steamid64 .. " + " .. permission )
end

-- Removes a permission from a player's per-player additionals and persists it.
-- No-op if the permission is not present.
function service.removeAdditional( steamid64 , permission )
    local entry = service.cache[ steamid64 ]
    if ( not entry ) then
        nstack.core.log.warn( "services :: permissions" , "removeAdditional: no cache entry for " .. steamid64 )
        return
    end

    for index , perm in ipairs( entry.additionals ) do
        if ( perm == permission ) then
            table.remove( entry.additionals , index )
            Permission:update( { additionals = _serializeAdditionals( entry.additionals ) } ):where( { steamid64 = steamid64 } ):run()
            nstack.core.log.trace( "services :: permissions" , "removeAdditional " .. steamid64 .. " - " .. permission )
            return
        end
    end
end
