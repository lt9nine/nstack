# Service: user

Tracks player identity and session data across all servers in the network.
Persists records to the database and keeps an in-memory cache synchronized
via the websocket infra.

---

## Configuration

No configuration required. The service uses the shared database and websocket
infra which are configured in `network.json` → `global_settings`.

---

## Database Table: `User`

| Column | Type | Description |
|---|---|---|
| `steamid64` | STRING (PK) | Steam 64-bit ID |
| `name` | STRING | Last known Steam display name |
| `first_seen` | NUMBER | Unix timestamp of first join |
| `last_seen` | NUMBER | Unix timestamp of most recent join |
| `playtime` | NUMBER | Cumulative playtime in seconds |
| `session_count` | NUMBER | Total number of sessions |
| `last_ip` | STRING | IP address from most recent join (port stripped) |

```sql
CREATE TABLE `user` (
    `steamid64`     VARCHAR(20)  NOT NULL COLLATE 'utf8mb4_general_ci',
    `name`          VARCHAR(64)  NOT NULL COLLATE 'utf8mb4_general_ci',
    `first_seen`    INT UNSIGNED NOT NULL,
    `last_seen`     INT UNSIGNED NOT NULL,
    `playtime`      INT UNSIGNED NOT NULL DEFAULT '0',
    `session_count` INT UNSIGNED NOT NULL DEFAULT '0',
    `last_ip`       VARCHAR(50)  NOT NULL DEFAULT '' COLLATE 'utf8mb4_general_ci'
)
```

---

## Public API

Access via `nstack.services[ "user" ]`.

### `getUser( steamid64 )`
Returns the user data table for the given steamid64, or `nil` if the player
is not currently online on any server.

```lua
local user = nstack.services[ "user" ].getUser( player:SteamID64() )
-- user.name, user.playtime, user.steamid64, ...
```

### `getServer( steamid64 )`
Returns the server id string the player is currently on, or `nil` if offline.

```lua
local server = nstack.services[ "user" ].getServer( player:SteamID64() )
```

### `isLocal( steamid64 )`
Returns `true` if the player is online on **this** server specifically.

```lua
if nstack.services[ "user" ].isLocal( player:SteamID64() ) then ... end
```

### `getPlayerCount( server_id )`
Returns the number of players currently online on the given server.

```lua
local count = nstack.services[ "user" ].getPlayerCount( "main" )
```

### `getGlobalPlayerCount()`
Returns the total number of players online across the entire network.

```lua
local total = nstack.services[ "user" ].getGlobalPlayerCount()
```

### `getPlayerList( server_id )`
Returns a sequential table of user data objects for all players on the given server.

```lua
local players = nstack.services[ "user" ].getPlayerList( "main" )
for _ , user in ipairs( players ) do
    print( user.name )
end
```

### `getGlobalPlayerList()`
Returns a sequential table of user data objects for all players online on the network.

```lua
local players = nstack.services[ "user" ].getGlobalPlayerList()
for _ , user in ipairs( players ) do
    print( user.name , user.steamid64 )
end
```

---

## Timers

| Name | Interval | Description |
|---|---|---|
| `nstack.services.user.playtimeFlush` | 600 s | Writes accumulated playtime for all local players to the DB |

### Playtime flush

Every 10 minutes `flushPlaytime()` iterates the local cache and, for each
player whose `joinTime` is set (i.e. connected to **this** server), computes
the elapsed time since the last checkpoint, adds it to `entry.data.playtime`,
persists the new value to the database, then resets `joinTime` to `now`.

This means `onLeave` and subsequent flush ticks always operate on the time
since the last checkpoint only — no double-counting occurs.

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `PlayerInitialSpawn` | `nstack.services.user.onJoin` | DB upsert, cache populate, broadcast join |
| `PlayerDisconnected` | `nstack.services.user.onLeave` | DB session write, cache evict, broadcast leave |
| `nstack.infra.websocket.connected` | `nstack.services.user.wsConnected` | Subscribes to the websocket channel |
| `nstack.infra.websocket.broadcast` | `nstack.services.user.wsBroadcast` | Receives join/leave events from other servers |

---

## WebSocket

**Channel:** `nstack.service.user`

The service subscribes to this channel on websocket connect and broadcasts
two event types:

**`join`** — emitted when a player connects to this server.
```json
{
  "event": "join",
  "steamid64": "76561198...",
  "server": "server-id",
  "data": { "name": "...", "playtime": 0, ... }
}
```

**`leave`** — emitted when a player disconnects from this server.
```json
{
  "event": "leave",
  "steamid64": "76561198...",
  "server": "server-id"
}
```

Other servers receiving these messages update their local `service.cache`
accordingly, so `getUser` / `getServer` / `isLocal` reflect the network-wide
online state.

---

## Cache Structure

`service.cache` is a table keyed by steamid64:

```lua
service.cache[ steamid64 ] = {
    data     = { ... } ,  -- user fields (mirrors DB row)
    server   = "id" ,     -- server the player is currently on
    joinTime = number ,   -- unix timestamp of local join; nil for remote players
}
```

`joinTime` is local-only and used to calculate session duration on disconnect.
It is never broadcast.
