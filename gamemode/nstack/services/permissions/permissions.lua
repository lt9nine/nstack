local service = nstack.services[ "permissions" ]

service.groups       = {}
service.defaultGroup = "user"
service.cache        = {}

-- memoized full permission list per group, rebuilt in _buildGroupCache
local _groupPermCache = {}

-- Returns true if the granted permission node covers the requested permission.
-- Supports exact match, "*" (all), and "prefix.*" (wildcard subtree).
local function _matchPermission( granted , requested )
    if ( granted == "*" ) then return true end
    if ( granted == requested ) then return true end

    -- "admin.*" matches "admin.ban", "admin.ban.permanent", but not "adminx.ban"
    local prefix = string.match( granted , "^(.-)%.%*$" )
    if ( prefix ) then
        if ( string.sub( requested , 1 , #prefix + 1 ) == prefix .. "." ) then return true end
    end

    return false
end

-- Resolves the full inherited permission list for a group.
-- Follows inherits_from chains; guards against circular definitions.
-- Results are memoized in _groupPermCache after the first resolution.
local function _resolveGroupPermissions( groupName , visited )
    if ( not groupName ) then return {} end
    if ( _groupPermCache[ groupName ] ) then return _groupPermCache[ groupName ] end

    visited = visited or {}
    if ( visited[ groupName ] ) then return {} end
    visited[ groupName ] = true

    local group = service.groups[ groupName ]
    if ( not group ) then return {} end

    local permissions = {}

    if ( group.inherits_from ) then
        local inherited = _resolveGroupPermissions( group.inherits_from , visited )
        for _ , perm in ipairs( inherited ) do
            permissions[ #permissions + 1 ] = perm
        end
    end

    if ( group.permissions ) then
        for _ , perm in ipairs( group.permissions ) do
            permissions[ #permissions + 1 ] = perm
        end
    end

    _groupPermCache[ groupName ] = permissions
    return permissions
end

-- Rebuilds the memoized group permission chain cache.
-- Call after loading or modifying service.groups.
function service._buildGroupCache()
    _groupPermCache = {}
    for groupName , _ in pairs( service.groups ) do
        _resolveGroupPermissions( groupName )
    end
end

-- Returns true if the given steamid64 has the specified permission.
-- Checks additionals first, then the full inherited group permission chain.
function service.hasPermission( steamid64 , permission )
    local entry       = service.cache[ steamid64 ]
    local usergroup   = entry and entry.usergroup   or service.defaultGroup
    local additionals = entry and entry.additionals or {}

    for _ , granted in ipairs( additionals ) do
        if ( _matchPermission( granted , permission ) ) then return true end
    end

    local groupPerms = _resolveGroupPermissions( usergroup )
    for _ , granted in ipairs( groupPerms ) do
        if ( _matchPermission( granted , permission ) ) then return true end
    end

    return false
end

-- Returns the usergroup name for the given steamid64, or the default group if not cached.
function service.getGroup( steamid64 )
    local entry = service.cache[ steamid64 ]
    return entry and entry.usergroup or service.defaultGroup
end

-- Returns all additional (per-player) permissions for the given steamid64.
function service.getAdditionals( steamid64 )
    local entry = service.cache[ steamid64 ]
    return entry and entry.additionals or {}
end

-- Returns the full combined permission list for the given steamid64:
-- all inherited group permissions followed by per-player additionals, deduplicated.
function service.getPermissions( steamid64 )
    local entry       = service.cache[ steamid64 ]
    local usergroup   = entry and entry.usergroup   or service.defaultGroup
    local additionals = entry and entry.additionals or {}

    local seen        = {}
    local permissions = {}

    local function _add( perm )
        if ( not seen[ perm ] ) then
            seen[ perm ]                   = true
            permissions[ #permissions + 1 ] = perm
        end
    end

    for _ , perm in ipairs( _resolveGroupPermissions( usergroup ) ) do
        _add( perm )
    end

    for _ , perm in ipairs( additionals ) do
        _add( perm )
    end

    return permissions
end

function service._init()
    nstack.core.log.info( "services :: permissions" , "starting..." )

    local config = nstack.core.global_settings.permissions or {}
    service.groups       = config.usergroups    or {}
    service.defaultGroup = config.default_group or "user"

    service._buildGroupCache()
    service._initDb()

    hook.Add( "PlayerInitialSpawn" , "nstack.services.permissions.onJoin"  , service._onJoin )
    hook.Add( "PlayerDisconnected" , "nstack.services.permissions.onLeave" , service._onLeave )

    service.status = "running"
    nstack.core.log.info( "services :: permissions" , "started" )
end
