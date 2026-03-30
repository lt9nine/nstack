local service = nstack.services[ "instance" ]

local _entMeta = FindMetaTable( "Entity" )
local _plyMeta = FindMetaTable( "Player" )

local _defaultInstance = "default"

local _classBlacklist = {
    "func_" ,
    "info_" ,
    "env_" ,
    "worldspawn" ,
    "soundent" ,
    "player_manager" ,
    "gmod_gamerules" ,
    "scene_manager" ,
    "trigger_teleport" ,
    "logic_" ,
    "hint" ,
    "filter_activator_name" ,
}

service.instanceTable = {}

local function _isBlacklisted( ent )
    local class = ent:GetClass()
    for _ , pattern in ipairs( _classBlacklist ) do
        if ( string.find( class , pattern , 1 , true ) ) then return true end
    end
    return false
end

local function _recursiveSetPreventTransmit( ent , ply , block )
    if ( ent == ply ) then return end
    if ( not IsValid( ent ) ) then return end
    if ( not IsValid( ply ) ) then return end

    ent:SetPreventTransmit( ply , block )
    for _ , child in ipairs( ent:GetChildren() ) do
        _recursiveSetPreventTransmit( child , ply , block )
    end
end

local function _recursiveSetInstance( ent , instance )
    if ( not IsValid( ent ) ) then return end
    ent:_setEntityInstance( instance )
    for _ , child in ipairs( ent:GetChildren() ) do
        _recursiveSetInstance( child , instance )
    end
end

-- Internal: stores the instance and updates transmit visibility for all players.
function _entMeta:_setEntityInstance( instance )
    service.instanceTable[ self ] = instance
    for _ , ply in ipairs( player.GetAll() ) do
        _recursiveSetPreventTransmit( self , ply , instance ~= ply:getEntityInstance() )
    end
end

-- Player override: also re-filters all non-map entities for this player's new instance.
function _plyMeta:_setEntityInstance( instance )
    service.instanceTable[ self ] = instance
    for _ , ply in ipairs( player.GetAll() ) do
        _recursiveSetPreventTransmit( self , ply , instance ~= ply:getEntityInstance() )
    end
    for _ , ent in ipairs( ents.GetAll() ) do
        if ( ent:CreatedByMap() or _isBlacklisted( ent ) ) then continue end
        _recursiveSetPreventTransmit( ent , self , instance ~= ent:getEntityInstance() )
    end
end

-- Sets the instance for this entity (or player) and notifies the client if it is a player.
function _entMeta:setInstance( instance )
    _recursiveSetInstance( self , instance )
    if ( not self:IsPlayer() ) then return end

    local hidden = {}
    for _ , ent in ipairs( ents.GetAll() ) do
        if ( ent:getEntityInstance() ~= instance ) then
            hidden[ #hidden + 1 ] = ent
        end
    end

    net.Start( "nstack:service:instance:change" )
        net.WriteString( instance )
        net.WriteTable( hidden )
    net.Send( self )
end

-- Returns the instance this entity currently belongs to.
function _entMeta:getEntityInstance()
    return service.instanceTable[ self ] or _defaultInstance
end

-- Sets the instance for the given entity.
function service.setInstance( ent , instance )
    if ( not IsValid( ent ) ) then return end
    ent:setInstance( instance )
end

-- Returns the instance the given entity currently belongs to.
function service.getInstanceOf( ent )
    if ( not IsValid( ent ) ) then return _defaultInstance end
    return ent:getEntityInstance()
end

-- Returns the default instance number.
function service.getDefaultInstance()
    return _defaultInstance
end

function service._init()
    nstack.core.log.info( "services :: instance" , "starting..." )

    util.AddNetworkString( "nstack:service:instance:change" )

    hook.Add( "InitPostEntity" , "nstack.service.instance.initCollision" , function()
        timer.Simple( 0 , function()
            for _ , ent in ipairs( ents.GetAll() ) do
                ent:SetCustomCollisionCheck( true )
            end
        end )
    end )

    hook.Add( "OnEntityCreated" , "nstack.service.instance.entityCreated" , function( ent )
        ent:SetCustomCollisionCheck( true )
    end )

    hook.Add( "PlayerInitialSpawn" , "nstack.service.instance.playerSpawn" , function( ply )
        ply:setInstance( _defaultInstance )
    end )

    local _spawnedWithModelHooks = {
        "PlayerSpawnedEffect" ,
        "PlayerSpawnedProp" ,
        "PlayerSpawnedRagdoll" ,
    }
    for _ , hookName in ipairs( _spawnedWithModelHooks ) do
        hook.Add( hookName , "nstack.service.instance.inheritInstance" , function( ply , _ , ent )
            ent:setInstance( ply:getEntityInstance() )
        end )
    end

    local _spawnedHooks = {
        "PlayerSpawnedNPC" ,
        "PlayerSpawnedSENT" ,
        "PlayerSpawnedSWEP" ,
        "PlayerSpawnedVehicle" ,
    }
    for _ , hookName in ipairs( _spawnedHooks ) do
        hook.Add( hookName , "nstack.service.instance.inheritInstance" , function( ply , ent )
            ent:setInstance( ply:getEntityInstance() )
        end )
    end

    local _pickupHooks = {
        "PhysgunPickup" ,
        "AllowPlayerPickup" ,
        "GravGunPickupAllowed" ,
        "PlayerCanPickupWeapon" ,
        "PlayerCanPickupItem" ,
        "CanPlayerUnfreeze" ,
    }
    for _ , hookName in ipairs( _pickupHooks ) do
        hook.Add( hookName , "nstack.service.instance.noInteraction" , function( ply , ent )
            if ( ply:getEntityInstance() ~= ent:getEntityInstance() ) then return false end
        end )
    end

    hook.Add( "nstack.service.voice.ready" , "nstack.service.instance.registerVoiceRule" , function( voiceService )
        voiceService.addRule( "instance" , 10 , function( receiver , sender )
            if ( receiver:getEntityInstance() ~= sender:getEntityInstance() ) then return false end
            return nil
        end )
    end )

    hook.Add( "PlayerCanSeePlayersChat" , "nstack.service.instance.noChat" , function( _ , _ , receiver , sender )
        if ( receiver:getEntityInstance() ~= sender:getEntityInstance() ) then return false end
    end )

    hook.Add( "CanTool" , "nstack.service.instance.noTool" , function( ply , trace )
        if ( trace.Entity:IsWorld() ) then return end
        if ( ply:getEntityInstance() ~= trace.Entity:getEntityInstance() ) then return false end
    end )

    hook.Add( "ShouldCollide" , "nstack.service.instance.noCollide" , function( ent1 , ent2 )
        if ( ent1:IsWorld() or ent2:IsWorld() ) then return end
        if ( ent1:getEntityInstance() ~= ent2:getEntityInstance() ) then return false end
    end )

    service.status = "running"
    nstack.core.log.info( "services :: instance" , "started" )
end
