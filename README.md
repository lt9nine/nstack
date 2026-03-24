# nstack

**nstack** is an open-source Garry's Mod gamemode framework. It provides a structured foundation — a service and module system, ORM, utilities, and conventions — so you can focus on building features instead of boilerplate.

> ⚠️ This project is in early development (`dev-0.1`). APIs may change.

---

## What it is

nstack is a **standalone gamemode** (derived from sandbox internally) that you build on top of directly. It is not a base class to derive other gamemodes from. Instead of writing spaghetti gamemode code, you add **services** and **modules** that slot into the framework.

```
nstack/
├── core/        — logging, server identity
├── services/    — auto-loaded subsystems (database, ORM, ...)
├── modules/     — gameplay features (not yet implemented)
└── util/        — shared/server/client helper functions
```

---

## Features

- **Service system** — auto-discovers and loads services from `services/<name>/`, with environment-aware file loading (`server`, `client`, `shared`)
- **ORM** — define models and run type-safe queries against MySQL without writing raw SQL
- **Utility layer** — stateless helpers auto-loaded per realm
- **Structured logging** — leveled log output (`trace` → `fatal`) with category support
- **Server identity** — identifies the current server from a `network.json` config at startup

---

## Services

A service is a folder under `nstack/services/` with a `_service.lua` descriptor and any number of Lua files.

```lua
-- services/example/_service.lua
return {
    name        = "example" ,
    environment = "server" ,
    files = {
        [ 1 ] = { file = "example.lua" , environment = "server" } ,
    }
}
```

```lua
-- services/example/example.lua
local service = nstack.services[ "example" ]

function service._init()
    nstack.core.log.info( "example" , "service started" )
end
```

Services are initialized automatically. The service table is its own public interface — no separate globals.

---

## ORM

Define a model and query the database without raw SQL:

```lua
local orm = nstack.services[ "database" ].orm

orm.define( "Player" , {
    steamId = { type = orm.AttributeType.String , identifier = true } ,
    score   = orm.AttributeType.Number ,
} )

orm.getModel( "Player" ):find():where( { score = 100 } ):run()
```

---

## WebSocket

The websocket service connects to [nhub](https://github.com/lt9nine/nhub) for multi-server communication. It requires the [GWSockets](https://github.com/FredyH/GWSockets) binary module.

**Setup:** add `websocket_key` to your server's entry in `network.json` and set the nhub `host`/`port` in `services/websocket/_service.lua` settings.

**Sending messages:**

```lua
local ws = nstack.services[ "websocket" ]

-- broadcast to all servers (optional channel)
ws.broadcast( { message = "hello" } )
ws.broadcast( { message = "hello" } , "mychannel" )

-- send directly to a specific server
ws.direct( "es-2" , { message = "hello from es-1" } )

-- RPC call: send a request and handle the response by matching the id
local rpcId = "req-" .. util.CRC( tostring( SysTime() ) )

ws.rpc( "es-2" , rpcId , { method = "getPlayerCount" } )

hook.Add( "NStack:WebSocket:RPCResponse" , rpcId , function( msg )
    if msg.id ~= rpcId then return end
    hook.Remove( "NStack:WebSocket:RPCResponse" , rpcId )
    print( "player count on es-2: " , msg.payload.result )
end )

-- respond to an incoming RPC from another server
hook.Add( "NStack:WebSocket:RPC" , "myhandler" , function( msg )
    if msg.payload.method == "getPlayerCount" then
        ws.respond( msg.id , { result = #player.GetAll() } )
    end
end )

-- subscribe / unsubscribe from a channel
ws.subscribe( "mychannel" )
ws.unsubscribe( "mychannel" )
```

**Receiving messages:**

```lua
-- all incoming messages
hook.Add( "NStack:WebSocket:Message" , "myhandler" , function( msg )
    print( msg.from , msg.type )
end )

-- typed hooks
hook.Add( "NStack:WebSocket:Broadcast"    , "myhandler" , function( msg ) end )
hook.Add( "NStack:WebSocket:Direct"       , "myhandler" , function( msg ) end )
hook.Add( "NStack:WebSocket:RPC"          , "myhandler" , function( msg ) end )
hook.Add( "NStack:WebSocket:RPCResponse"  , "myhandler" , function( msg ) end )
hook.Add( "NStack:WebSocket:Disconnected" , "myhandler" , function() end )
hook.Add( "NStack:WebSocket:Error"        , "myhandler" , function( err ) end )
```

`msg` is the decoded JSON envelope from nhub — it always contains `type` and `from`, and optionally `payload`, `channel`, `id`, and `ts`.

---

## Contributing

Contributions are welcome. Before opening a PR, read the [conventions guide](conventions.md) — it defines mandatory style and architecture rules that all code must follow.

---

## License

nstack is free to use and modify. **Commercial redistribution of nstack itself is not permitted.** Building and selling modules or services on top of nstack is explicitly allowed.

---

## Links

- [Conventions & Style Guide](conventions.md)
- [GitHub](https://github.com/lt9nine/nstack)
- [nhub](https://github.com/lt9nine/nhub)
- Documentation — coming via GitHub Pages
