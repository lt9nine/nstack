# Service: instance

Manages instance separation between players and entities on the server.
Each entity and player belongs to a numbered instance; entities in different
instances cannot see, interact with, or collide with each other.

---

## Overview

Instances are string identifiers (default: `"default"`). Every entity is implicitly in
instance `"default"` until assigned otherwise. When a player's instance changes, the
service recalculates `SetPreventTransmit` for all relevant entities so the
client only receives networked updates for things in the same instance.

Collision separation is enforced via `ShouldCollide`. Pickup, tool, and voice
interactions are blocked across instance boundaries by the relevant hooks.
Map-created entities and a set of engine-class entities are intentionally
excluded from transmit filtering so the world remains functional.

---

## Public API

Access via `nstack.services[ "instance" ]`.

### `setInstance( ent, instance )`

Sets the instance for the given entity or player. Recursively applies to all
child entities. If `ent` is a player, sends a `nstack:service:instance:change`
net message to that client so it can update its local state.

```lua
nstack.services[ "instance" ].setInstance( ply , "arena-1" )
nstack.services[ "instance" ].setInstance( prop , "lobby" )
```

### `getInstanceOf( ent )`

Returns the instance string the given entity currently belongs to.
Returns the default instance (`"default"`) if the entity is invalid or unassigned.

```lua
local instance = nstack.services[ "instance" ].getInstanceOf( ply )
-- "default", "arena-1", "lobby", ...
```

### `getDefaultInstance()`

Returns the default instance string (`"default"`).

```lua
local default = nstack.services[ "instance" ].getDefaultInstance()
```

---

## Entity / Player Metamethods

The service extends the `Entity` and `Player` metatables with convenience
methods. These are the same operations as the service API functions above.

### `ent:setInstance( instance )`

Equivalent to `service.setInstance( ent , instance )`.

```lua
ply:setInstance( "arena-1" )
prop:setInstance( ply:getEntityInstance() )
```

### `ent:getEntityInstance()`

Equivalent to `service.getInstanceOf( ent )`.

```lua
if ( ply:getEntityInstance() ~= prop:getEntityInstance() ) then
    -- different instance
end
```

---

## Instance State

`service.instanceTable` is a table keyed by entity reference. It is never
persisted — all instances reset to `1` on server restart.

```lua
service.instanceTable[ ent ] = 2   -- set internally
service.instanceTable[ ent ]       -- returns 2
```

Entries for disconnected players or removed entities are not automatically
evicted. Entity references in Lua become invalid but the table entry remains
until the next map cleanup. This has no practical effect since `IsValid` guards
all reads.

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `InitPostEntity` | `nstack.service.instance.initCollision` | Enables custom collision checks on all existing entities (deferred one tick) |
| `OnEntityCreated` | `nstack.service.instance.entityCreated` | Enables custom collision check on newly created entities |
| `PlayerInitialSpawn` | `nstack.service.instance.playerSpawn` | Assigns the player to the default instance |
| `PlayerSpawnedEffect`, `PlayerSpawnedProp`, `PlayerSpawnedRagdoll` | `nstack.service.instance.inheritInstance` | Assigns the spawned entity to the spawning player's instance |
| `PlayerSpawnedNPC`, `PlayerSpawnedSENT`, `PlayerSpawnedSWEP`, `PlayerSpawnedVehicle` | `nstack.service.instance.inheritInstance` | Assigns the spawned entity to the spawning player's instance |
| `PhysgunPickup`, `AllowPlayerPickup`, `GravGunPickupAllowed`, `PlayerCanPickupWeapon`, `PlayerCanPickupItem`, `CanPlayerUnfreeze` | `nstack.service.instance.noInteraction` | Blocks pickup and interaction across instances |
| `PlayerCanHearPlayersVoice` | `nstack.service.instance.noVoice` | Blocks voice between players in different instances |
| `PlayerCanSeePlayersChat` | `nstack.service.instance.noChat` | Blocks chat visibility between players in different instances |
| `CanTool` | `nstack.service.instance.noTool` | Blocks tool use on entities in a different instance |
| `ShouldCollide` | `nstack.service.instance.noCollide` | Prevents physics collision between entities in different instances |

---

## Network Strings

| String | Direction | Description |
|---|---|---|
| `nstack:service:instance:change` | Server → Client | Sent when a player's instance changes; carries the new instance string and a table of entities that should now be hidden |

---

## Blacklisted Classes

The following entity class prefixes are excluded from transmit filtering when
a player changes instance. These are engine-required or map-structural entities
that must remain networked regardless of instance:

`func_`, `info_`, `env_`, `worldspawn`, `soundent`, `player_manager`,
`gmod_gamerules`, `scene_manager`, `trigger_teleport`, `logic_`, `hint`,
`filter_activator_name`

Map-created entities (`ent:CreatedByMap()`) are also unconditionally excluded.
