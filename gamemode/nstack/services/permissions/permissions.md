# Service: permissions

Manages usergroup assignment and permission checking for all players.
Groups are defined in `network.json` and support linear inheritance chains.
Per-player extra permissions (additionals) are persisted in the database.

---

## Configuration

Configured via `network.json` → `global_settings.permissions`.

```json
"permissions": {
    "default_group": "user",
    "usergroups": {
        "user": {
            "inherits_from": null,
            "permissions": []
        },
        "vip": {
            "inherits_from": "user",
            "permissions": [ "chat.color" ]
        },
        "admin": {
            "inherits_from": "vip",
            "permissions": [ "admin.*" ]
        },
        "superadmin": {
            "inherits_from": "admin",
            "permissions": [ "*" ]
        }
    }
}
```

`default_group` is assigned to players who have no database record yet.
Each group may declare an `inherits_from` field pointing to another group —
the player receives every permission from that group and all groups below it
in the chain. Circular definitions are silently broken.

---

## Permission Syntax

Permissions are dot-separated identifiers namespaced by service or module.

| Pattern | Meaning |
|---|---|
| `chat.mute` | Exact permission |
| `admin.ban` | Exact permission |
| `admin.ban.permanent` | Sub-permission of `admin.ban` |
| `admin.*` | All permissions under `admin.*` at any depth |
| `*` | All permissions unconditionally |

A wildcard `prefix.*` matches any permission that begins with `prefix.` —
including deeply nested ones like `admin.ban.permanent` when `admin.*` is granted.
The wildcard does **not** match the prefix itself (`admin.*` does not grant `admin`).

---

## Database Table: `permission`

| Column | Type | Description |
|---|---|---|
| `steamid64` | STRING (PK) | Steam 64-bit ID |
| `usergroup` | STRING | Name of the assigned usergroup |
| `additionals` | STRING | JSON array of extra per-player permission strings |

```sql
CREATE TABLE `permission` (
    `steamid64`   VARCHAR(20)   NOT NULL COLLATE 'utf8mb4_general_ci',
    `usergroup`   VARCHAR(64)   NOT NULL COLLATE 'utf8mb4_general_ci',
    `additionals` TEXT          NOT NULL DEFAULT '[]' COLLATE 'utf8mb4_general_ci'
)
```

A record is created automatically on first join using `default_group` and an
empty additionals list. It is never deleted — reassigning a player to a different
group updates the existing row.

---

## Public API

Access via `nstack.services[ "permissions" ]`.

### `hasPermission( steamid64, permission )`
Returns `true` if the player has the given permission through any path —
additionals, their assigned group, or any group in the inheritance chain.

```lua
if nstack.services[ "permissions" ].hasPermission( player:SteamID64() , "admin.ban" ) then
    -- allow
end
```

### `getGroup( steamid64 )`
Returns the usergroup name for the given steamid64. Falls back to
`service.defaultGroup` if the player is not in the cache.

```lua
local group = nstack.services[ "permissions" ].getGroup( player:SteamID64() )
-- "admin", "user", ...
```

### `getAdditionals( steamid64 )`
Returns the sequential table of per-player additional permissions.
Returns an empty table if the player is not in the cache.

```lua
local extras = nstack.services[ "permissions" ].getAdditionals( player:SteamID64() )
for _ , perm in ipairs( extras ) do
    print( perm )
end
```

### `getPermissions( steamid64 )`
Returns a sequential table of all permissions the player holds — the full
inherited group chain followed by their per-player additionals.
Falls back to `defaultGroup` if the player is not in the cache.

```lua
local perms = nstack.services[ "permissions" ].getPermissions( player:SteamID64() )
for _ , perm in ipairs( perms ) do
    print( perm )
end
```

### `setGroup( steamid64, groupName )`
Assigns a new usergroup to the player and persists it to the database immediately.
Also updates the in-memory cache if the player is currently online.

```lua
nstack.services[ "permissions" ].setGroup( player:SteamID64() , "admin" )
```

### `addAdditional( steamid64, permission )`
Adds a permission to the player's per-player additionals and persists it.
No-op if the permission is already present. The player must be online (cached).

```lua
nstack.services[ "permissions" ].addAdditional( player:SteamID64() , "chat.mute" )
```

### `removeAdditional( steamid64, permission )`
Removes a permission from the player's per-player additionals and persists it.
No-op if the permission is not present. The player must be online (cached).

```lua
nstack.services[ "permissions" ].removeAdditional( player:SteamID64() , "chat.mute" )
```

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `PlayerInitialSpawn` | `nstack.services.permissions.onJoin` | Loads or creates the player's DB record, populates cache |
| `PlayerDisconnected` | `nstack.services.permissions.onLeave` | Evicts the player from the cache |

---

## Cache Structure

`service.cache` is a table keyed by steamid64, populated on join and evicted on disconnect:

```lua
service.cache[ steamid64 ] = {
    usergroup   = "admin" ,              -- assigned group name
    additionals = { "chat.mute" , ... } , -- parsed from DB JSON
}
```

Group permissions are **not** stored in the cache entry. They are resolved on
demand from `service.groups` via the memoized `_groupPermCache`.

---

## Group Resolution

`service.groups` is loaded from `network.json` once in `_init` and never
mutated at runtime. The inherited permission chain for each group is resolved
once and stored in the module-local `_groupPermCache` table.

`service._buildGroupCache()` clears and rebuilds this memo. It is called
automatically during `_init` and can be called manually if `service.groups`
is modified at runtime.

Resolution order for `hasPermission`:

1. Player's `additionals` (checked first — most specific)
2. Player's assigned group permissions
3. Inherited group permissions, walked up the chain

The first match short-circuits and returns `true`.
