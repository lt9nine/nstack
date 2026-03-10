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

### 1.2 Comma Seperation

Comma-Seperated arguments always need a whitespace inbetween

```lua
func( arg1 , arg2 )
```

## 2. Naming Conventions
### 2.1 Classes
- PascalCase
- no `nstack` prefix
- Names describe a role or concept

```lua
local Logger = nstack.class.new()
local Module = nstack.class.new()
local InventoryService = nstack.class.new()
```

Namespace usage:
```
nstack.class.Logger
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
- lobal exposure: optional, avoid polluting _G
```
nstack = {
    core = {},
    class = {},
    modules = {},
    services = {},
    util = {}
}
```
```lua
nstack.core.init()
nstack.modules.inventory:load()
nstack.services.log:info( "nstack booted" )
```

### 3.2 `nstack.core`
**Purpose**
- Provides framework-level foundation
- Handles bootstrap, lifecycle, module management
- Core utilities used by modules & services

**Responsibilities**
- Initialize framework (init)
- Track modules & services
- Provide system hooks
- Provide config systems

### 3.3 `nstack.class`
**Purpose**
- Provides OOP support
- Central location for all class definitions
- Avoids polluting global namespace

`nstack.class` is just a namespace. The class support gets added inside the `nstack.core`.

**Example**
```lua
nstack.class.Logger = Class()

function nstack.class.Logger:_init( name )
    self.name = name
end

function nstack.class.Logger:info( msg )
    print( "[INFO][" .. self.name .. "] " .. msg )
end
```
```lua
local logger = nstack.class.Logger( "core" )
logger:info( "nstack booted" )
```

### 3.4 `nstack.modules`
**Purpose**
- Encapsulates optional feature packages
- Usually gameplay-related or server extensions
- Modules can depend on services but not tightly coupled to each other

### 3.5 `nstack.services`
**Purpose**
- Provides system-wide functionality
- Singleton-style, always available
- Independent of modules

**Rules**
- No game-specific logic
- Always active, long-lived
- Can be consumed by modules

```lua
nstack.services.log:info( "Cluster connected" )
nstack.services.db:query( "SELECT * FROM users" )
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
- `shared` utils can never use `server`- or `client`-specific utils

```lua
nstack.util.string.split( "a,b,c" , "," )
nstack.util.table.deepCopy( myTable )
```

## 4. Object-Oriented Programming (OOP)
A simple oop-module is used:
```lua
local function new( class , ... )
    local instance = setmetatable( {} , class )

    instance:_init( ... )

    return instance
end

local function Classify( parent )
    tbl = {}
    tbl.__index = tbl
    tbl._Class = true

    local meta = {}

    if ( parent ) then
        meta.__index = parent
    end

    meta.__call = new

    return setmetatable(tbl, meta)
end

local function isClass( obj )
    return obj and istable( obj ) and obj._Class
end

_G.TableToClass = Classify
_G.Class = Classify
_G.isclass = isClass
```

### 4.1 Class Declaration
```lua
local Logger = Class()
```

### 4.2 Constructor
- Always named `_init`
```lua
function Logger:_init( name )
    self.name = name
end
```

### 4.3 Instantiation
```lua
local logger = Logger( "core" )
```

## 5. Network Strings
### 5.1 Format
```
nstack:<layer>:<module>:<action>
```

### 5.2 Examples
```lua
util.AddNetworkString( "nstack:core:ready" )
util.AddNetworkString( "nstack:module:inventory:sync" )
```
`<module>` can be skipped, depending on the layer

## 6. Hooks
### 6.1 Identifiers
```
NStack.<Layer>.<Module>.<Hook>.<Event>
```
```lua
hook.Add( "Initialize" , "NStack.Core.Initialize.Init" , function()
    nstack.core.init()
end )
```

### 6.2 Custom Hooks
```lua
hook.Run( "NStack.Core.Ready" )
hook.Run( "NStack.Module.Loaded" , moduleName )
```

## 7. Control Flow Style
### 7.1 If / Else
```lua
if ( condition ) then
    ...
else
    ...
end
```

### 7.2 Prefer Early Returns
```lua
if ( not isValid ) then
    return
end
```

## 8. Comments
### 8.1 Single-Line Comments
```lua
-- Initialize logging service
```

### 8.2 Block Comments
```lua
--[[
    Inventory module bootstrap
    Handles item syncing and persistence
]]
```

## 9. Modules
...

## 10. Global Rules
- Whitespace is part of the style
- Namespace over name prefixes
- Readability over cleverness
- The framework defines rules; modules must follow
- One style, everywhere, without exception

___

***nstack is a foundation.<br>
Consistency is non-negotiable.***