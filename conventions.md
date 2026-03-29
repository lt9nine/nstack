# nstack Style- and Ruleguide

This style and ruleguide defines the **mandatory coding conventions** for all nstack-related
projects, including core, services, modules, and extensions.

**Goals**
- High readability
- Long-term maintainability
- Collision-free namespaces
- Consistent framework-level architecture

---

## 1. General Formatting Rules

### 1.1 Whitespace in Brackets ( "Mandatory" )

Content inside brackets **must always be surrounded by spaces**.

Applies to:
- `()`
- `[]`
- `{}`

```lua
if ( condition ) then
value = table[ key ]
func( arg1 )
local t = { key = value }
```

❌ Invalid:
```lua
if(condition) then
table[key]
```

### 1.2 Comma Separation

Comma-separated arguments always need a whitespace in between.

```lua
func( arg1 , arg2 )
```

## 2. Naming Conventions
### 2.1 Classes
- PascalCase
- Placed under the relevant namespace, not a global
- Names describe a role or concept

```lua
ORM.Model = Class()
ORM.Attribute = Class()
ORM.MysqlHandler = Class()
```

### 2.2 Methods
- camelCase
- Must be verbs
```lua
function Logger:info( message )
function Module:load()
function Module:unload()
```

### 2.3 Properties / Fields
- camelCase
- Boolean fields must start with `is`, `has`, or `can`
```lua
self.isLoaded = true
self.hasPermission = false
self.canReload = true
```

### 2.4 Private / Internal Methods
- Prefix with `_`
```lua
function Module:_init()
function Module:_loadConfig()
```

**Methods starting with a double underscore (`__`) are `gLua` [Meta-Methods](https://wiki.facepunch.com/gmod/Metamethods) for table operations!**

### 2.5 Variables
```lua
local moduleName = "inventory"
local maxRetries = 3
```

Global variables should always be declared with a leading `_G`
```lua
_G.nstack = {}
```

❌ Avoid abbreviations:
- tmp
- cnt
- mgr

## 3. nstack Namespacing
### 3.1 Root Namespace `nstack`
- Purpose: Central entry point for all framework functionality
- Contains: sub-namespaces, singleton objects, bootstrapping
- Global exposure: via `_G.nstack`

```lua
_G.nstack = {
    core     = {} ,
    infra    = {} ,
    modules  = {} ,
    services = {} ,
    util     = {} ,
}
```

### 3.2 `nstack.core`
**Purpose**
- Provides framework-level foundation
- Handles bootstrap, module management
- Core utilities used by modules & services

**Responsibilities**
- Initialize framework
- Track modules & services
- Provide system hooks
- Provide logging

### 3.3 `nstack.infra`
**Purpose**
- Provides low-level I/O drivers required by the framework itself
- Loaded statically by core before services, server-side only
- Not a dynamic registry — infra components are always present

**Responsibilities**
- Database connection and ORM (`nstack.infra.database`)
- WebSocket connection to nhub (`nstack.infra.websocket`)
- Configuration read from `network.json` → `global_settings`

**Rules**
- Core and services may both consume infra
- Infra components are initialized via `_init( config )` called from `nstack.core.initialize()`
- Config comes from `network.json` `global_settings`, never hardcoded

```lua
nstack.infra.database.orm.define( "User" , attributes )
nstack.infra.database.db:query( "SELECT 1" )
nstack.infra.websocket.broadcast( payload , "global" )
```

### 3.4 `nstack.modules`
**Purpose**
- Encapsulates optional feature packages
- Usually gameplay-related or server extensions
- Modules can depend on services but not tightly coupled to each other

### 3.5 `nstack.services`
**Purpose**
- Provides domain-level functionality (e.g. chat, admin, players)
- Singleton-style, always available once initialized
- Independent of modules

**Rules**
- No raw I/O — use `nstack.infra` for database/websocket
- Always active, long-lived
- Can be consumed by modules

```lua
nstack.services[ "chat" ].send( player , message )
```

### 3.6 `nstack.util`
**Purpose**
- Pure helper functions
- Stateless, no lifecycle
- Available everywhere

**Rules**
- No state
- No hooks or network registration
- Only functions
- `shared` utils can never use `server`- or `client`-specific APIs

```lua
nstack.util.tableContains( myTable , value )
```

Utils are organized into subdirectories and auto-loaded:
- `util/shared/` — available on both realms
- `util/server/` — server-only
- `util/client/` — client-only

## 4. Object-Oriented Programming (OOP)
A simple OOP module is used, loaded globally from `gamemode/includes/modules/class.lua`:

```lua
_G.Class = Classify  -- factory function
```

### 4.1 Class Declaration
Classes are declared under their relevant namespace, not as globals.

```lua
ORM.Model = Class()
ORM.Attribute = Class()
```

### 4.2 Constructor
- Always named `_init`
```lua
function ORM.Model:_init( name , attributes )
    self.name = name
end
```

### 4.3 Instantiation
```lua
local model = ORM.Model( "User" , attributes )
```

## 5. Services

Services are self-contained subsystems registered with the framework automatically.

### 5.1 File Structure
Each service lives in its own folder under `nstack/services/<name>/`:

```
services/
  chat/
    _service.lua     ← descriptor, loaded first
    chat.lua
    ...
```

### 5.2 Descriptor (`_service.lua`)
Returns a plain table. Must include `name`, `environment`, and `files`.
The `environment` of the service and all its files must match.

```lua
local service = {
    name        = "chat" ,
    description = "..." ,
    version     = "1.0.0" ,
    author      = "..." ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "chat.lua" , environment = "server" } ,
    }
}

return service
```

**File environment values:** `"server"`, `"client"`, `"shared"`

### 5.3 Service Initialization
Define `service._init()` in the main service file.
The service table IS the public interface — no separate global.

```lua
local service = nstack.services[ "chat" ]

function service._init()
    nstack.core.log.trace( "services :: " .. service.name , "starting..." )
    -- setup
end
```

## 6. Logging

All logging goes through `nstack.core.log`.

### 6.1 Levels (lowest → highest severity)
`trace` → `debug` → `info` → `warn` → `error` → `fatal`

### 6.2 Usage
```lua
nstack.core.log.trace( category , message )
nstack.core.log.debug( category , message )
nstack.core.log.info( category , message )
nstack.core.log.warn( category , message )
nstack.core.log.error( category , message )
nstack.core.log.fatal( category , message )
```

### 6.3 When to Use Each Level

| Level   | When to use |
|---------|-------------|
| `trace` | High-frequency internals: individual SQL queries, individual websocket messages, internal function entry points. Never useful in production. |
| `debug` | Step-by-step flow within an operation: "connecting to...", "opening connection", config values being applied. Useful during development, off in production. |
| `info`  | Significant lifecycle milestones an operator always wants to see: service started, connection established, server identified. Low frequency, always meaningful. |
| `warn`  | The system handled it gracefully but something was off: optional component missing (skipping), already running (skipping), unexpected disconnect. No action required. |
| `error` | An operation failed and the system cannot complete it. The framework continues running. Query failed, malformed data received, runtime websocket error. |
| `fatal` | The framework cannot function. **Always followed by a server shutdown.** Reserved for unrecoverable startup failures — missing `network.json`, failed database connection, failed websocket connection. |

**`fatal` must always be paired with a shutdown:**
```lua
nstack.core.log.fatal( "infra :: database" , "connection failed — shutting down" )
game.ConsoleCommand( "quit\n" )
```

### 6.4 Category Format
Use `::` to separate layers within the category string.
```lua
nstack.core.log.info( "infra :: database" , "connected" )
nstack.core.log.trace( "infra :: database :: orm" , sql )
nstack.core.log.info( "infra :: websocket" , "authenticated" )
nstack.core.log.trace( "services :: chat" , "message sent" )
```

## 7. Network Strings
### 7.1 Format
All lowercase, colon-separated segments.
```
nstack:<layer>:<subsystem>:<action>
```

`<subsystem>` can be omitted when the layer alone is sufficient context.

### 7.2 Examples
```lua
util.AddNetworkString( "nstack:core:ready" )
util.AddNetworkString( "nstack:infra:websocket:connected" )
util.AddNetworkString( "nstack:service:chat:message" )
```

## 8. Hooks
### 8.1 Hook Registration Keys
Use lowercase dot-separated identifiers.
```
nstack.<layer>.<module>.<event>
```
```lua
hook.Add( "Initialize" , "nstack.core.initialize" , function()
    nstack.core.initialize()
end )
```

### 8.2 Custom Hooks (fired by nstack)
All hook names fired by nstack use lowercase dot-separated identifiers — the same convention as hook registration keys.
```lua
hook.Run( "nstack.initialized" )
hook.Run( "nstack.infra.websocket.connected" )
hook.Run( "nstack.service.chat.message" , data )
```

## 9. Control Flow Style
### 9.1 If / Else
```lua
if ( condition ) then
    ...
else
    ...
end
```

### 9.2 Prefer Early Returns
```lua
if ( not isValid ) then
    return
end
```

## 10. Comments
### 10.1 Single-Line Comments
```lua
-- Initialize logging service
```

### 10.2 Block Comments
```lua
--[[
    Inventory module bootstrap
    Handles item syncing and persistence
]]
```

## 11. Modules
...

## 12. Global Rules
- Whitespace is part of the style
- Namespace over name prefixes
- Readability over cleverness
- The framework defines rules; modules must follow
- One style, everywhere, without exception

___

***nstack is a foundation.<br>
Consistency is non-negotiable.***
