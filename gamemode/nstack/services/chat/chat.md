# Service: chat

Routes all server-side text chat through a composable channel and filter system.
A single `PlayerSay` hook intercepts every player message, suppresses native chat,
and delivers formatted messages to the correct receivers via a net message.

---

## Overview

When no channels are registered the service returns nothing from `PlayerSay` and
GMod handles chat normally. Once any channel is registered, the service takes over
routing entirely. Channels claim messages, decide receivers, and control formatting.
Filters run after a channel has decided delivery and can veto individual receivers.

**`sendTo`** bypasses the channel and filter system entirely — it is always delivered
directly, regardless of instance or any other filter.

---

## Public API

Access via `nstack.services[ "chat" ]`.

### `addChannel( name, priority, channel )`

Registers a channel. Lower priority number = evaluated first.
If another channel already occupies the same priority a warning is logged
but both are kept; evaluation order between them is undefined.

```lua
nstack.services[ "chat" ].addChannel( "global" , 100 , {
    claim      = function( sender , text , teamOnly ) return true end ,
    canReceive = function( receiver , sender , text ) return true end ,
    format     = function( sender , text , receiver )
        return { Color( 255 , 255 , 255 ) , sender:Nick() .. ": " .. text }
    end ,
} )
```

### `removeChannel( name )`

Removes a channel by name. No-ops silently if not found.

```lua
nstack.services[ "chat" ].removeChannel( "global" )
```

### `addFilter( name, fn )`

Registers a global filter. Filters run after a channel has allowed a receiver and
can veto delivery. They receive the claiming channel as the fourth argument,
which allows filters to opt out for specific channel types (e.g. `isDirect`).

```lua
nstack.services[ "chat" ].addFilter( "mute" , function( receiver , sender , text , channel )
    if ( mutedPlayers[ sender ] ) then return false end
end )
```

### `removeFilter( name )`

Removes a filter by name.

```lua
nstack.services[ "chat" ].removeFilter( "mute" )
```

### `send( sender, text, options )`

Sends a message programmatically, bypassing claim logic.
`sender` can be a `Player` or `nil` for server messages.

| Option | Type | Description |
|---|---|---|
| `channel` | string\|nil | Channel name — uses its `canReceive` and `format`. If omitted, delivers to all players. |
| `format` | function\|nil | Overrides the channel's format function for this message. |
| `broadcast` | bool\|nil | Overrides the channel's broadcast setting. |

```lua
local chat = nstack.services[ "chat" ]

-- Server announcement to all players
chat.send( nil , "The match begins in 30 seconds." , {
    format = function( sender , text , receiver )
        return { Color( 255 , 200 , 0 ) , "[Server] " , color_white , text }
    end ,
} )

-- Send through a specific channel's receiver list
chat.send( ply , "Hello admins." , { channel = "admin" } )
```

### `sendTo( target, text, formatFn )`

Delivers directly to a specific target. Bypasses all channels and filters.
`target` can be a `Player`, a SteamID64 string, or a table of either.
If a SteamID64 target is not found on this server, the message is forwarded
via websocket to other servers (not yet implemented).

`formatFn` receives `( text, receiver )` — there is no sender context.

```lua
local chat = nstack.services[ "chat" ]

-- Direct message to a local player
chat.sendTo( ply , "Only you can see this." , function( text , receiver )
    return { Color( 100 , 200 , 255 ) , "[DM] " , color_white , text }
end )

-- Direct message to a player by SteamID64 (cross-server capable)
chat.sendTo( "76561198000000000" , "You have a new notification." , function( text , receiver )
    return { Color( 100 , 200 , 255 ) , "[Notification] " , color_white , text }
end )

-- Multiple targets at once
chat.sendTo( { ply1 , ply2 , "76561198000000000" } , "Meeting in five minutes." , function( text , receiver )
    return { color_white , text }
end )
```

---

## Channel Table

```lua
{
    -- Required
    claim      = function( sender, text, teamOnly ) → bool ,
    canReceive = function( receiver, sender, text ) → bool ,
    format     = function( sender, text, receiver ) → table ,

    -- Optional
    broadcast  = false ,   -- send via websocket to other servers after local delivery
    isDirect   = false ,   -- opt out of filters that respect this flag (e.g. instance filter)
}
```

### `claim( sender, text, teamOnly )`

Called once per message to determine if this channel owns it.
The first channel (by priority) that returns `true` claims the message.
All other channels are skipped.

### `onClaim( sender, text )` *(optional)*

Called immediately after a channel claims a message, before delivery runs.
Use this to execute logic (commands, logging, side effects) without interfering
with the delivery pipeline. If `canReceive` always returns `false`, the message
is fully consumed with no visible output — this is the command channel pattern.

```lua
onClaim = function( sender , text )
    -- parse and dispatch command
end ,
```

### `canReceive( receiver, sender, text )`

Called per player to determine if they receive the message.
Only called for the claiming channel.

### `format( sender, text, receiver )`

Returns a sequence table of alternating `Color` and `string` values, passed
directly to `chat.AddText` on the client. Called once per receiver, so the
format can be personalised (e.g. "You said:" vs "PlayerName said:").

```lua
format = function( sender , text , receiver )
    if ( receiver == sender ) then
        return { Color( 180 , 180 , 180 ) , "You: " , color_white , text }
    end
    return { Color( 255 , 255 , 255 ) , sender:Nick() .. ": " , color_white , text }
end
```

---

## Filter Function Contract

```lua
-- @param receiver  Player   the player who would receive the message
-- @param sender    Player   the player who sent the message (may be invalid for server messages)
-- @param text      string   the message content
-- @param channel   table    the claiming channel table (may be nil for service.send without a channel)
-- @return          false to block, nil to allow
```

Returning anything other than `false` (including nothing) allows delivery.
Filters have no priority — all registered filters run for every delivery attempt,
and any single `false` blocks it.

---

## Filter and `isDirect`

Filters receive the claiming channel as a fourth argument. Channels that set
`isDirect = true` can be excluded from hard-block filters (such as instance
separation) so that intentional targeted messages are never intercepted.

```lua
service.addChannel( "dm" , 50 , {
    isDirect   = true ,
    claim      = function( sender , text , teamOnly )
        return string.sub( text , 1 , 4 ) == "/dm "
    end ,
    canReceive = function( receiver , sender , text )
        -- resolve target from text and return receiver == target
    end ,
    format = function( sender , text , receiver )
        return { Color( 100 , 180 , 255 ) , "[DM] " , color_white , text }
    end ,
} )

-- A filter that respects isDirect
service.addFilter( "instance" , function( receiver , sender , text , channel )
    if ( channel and channel.isDirect ) then return nil end
    if ( not IsValid( sender ) ) then return nil end
    if ( receiver:getEntityInstance() ~= sender:getEntityInstance() ) then return false end
end )
```

---

## Priority Convention

There is no enforced mapping — pick a number that places your channel correctly
relative to others. The following ranges are a guideline:

| Range | Typical use |
|---|---|
| `1 – 20` | High-intercept: command channels (`/dm`, `/admin`), prefix-triggered |
| `50 – 80` | Scoped channels: team chat, faction chat |
| `100+` | Catch-all fallback: global chat |

---

## Integration Pattern

Services and modules must not reference `nstack.services[ "chat" ]` during
their own `_init`. Use the `nstack.service.chat.ready` hook — it fires after
the chat service is fully initialised and passes the service table as argument.

```lua
hook.Add( "nstack.service.chat.ready" , "my.module.registerChatChannels" , function( chatService )
    chatService.addChannel( "global" , 100 , { ... } )
    chatService.addFilter( "mute" , function( ... ) ... end )
end )
```

If the chat service is not loaded the hook never fires — no error, no coupling.

---

## Examples

### Admin chat via prefix

```lua
hook.Add( "nstack.service.chat.ready" , "admin.module.adminChat" , function( chatService )
    chatService.addChannel( "admin" , 10 , {
        claim = function( sender , text , teamOnly )
            return sender:IsAdmin() and string.sub( text , 1 , 1 ) == "@"
        end ,
        canReceive = function( receiver , sender , text )
            return receiver:IsAdmin()
        end ,
        format = function( sender , text , receiver )
            local message = string.sub( text , 2 )  -- strip leading @
            return { Color( 255 , 100 , 100 ) , "[ADMIN] " , color_white , sender:Nick() .. ": " , Color( 220 , 220 , 220 ) , message }
        end ,
    } )
end )
```

### Team chat via the teamOnly flag

```lua
hook.Add( "nstack.service.chat.ready" , "teams.module.teamChat" , function( chatService )
    chatService.addChannel( "team" , 50 , {
        claim = function( sender , text , teamOnly )
            return teamOnly == true
        end ,
        canReceive = function( receiver , sender , text )
            return receiver:Team() == sender:Team()
        end ,
        format = function( sender , text , receiver )
            return { Color( 100 , 200 , 100 ) , "[TEAM] " , color_white , sender:Nick() .. ": " , text }
        end ,
    } )
end )
```

### Global fallback

```lua
hook.Add( "nstack.service.chat.ready" , "chat.module.globalChat" , function( chatService )
    chatService.addChannel( "global" , 100 , {
        claim = function( sender , text , teamOnly )
            return true
        end ,
        canReceive = function( receiver , sender , text )
            return true
        end ,
        format = function( sender , text , receiver )
            return { color_white , sender:Nick() .. ": " , text }
        end ,
    } )
end )
```

### Server announcement

```lua
nstack.services[ "chat" ].send( nil , "Server restarting in 5 minutes." , {
    format = function( sender , text , receiver )
        return { Color( 255 , 80 , 80 ) , "[!] " , Color( 255 , 200 , 0 ) , text }
    end ,
} )
```

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `PlayerSay` | `nstack.services.chat.playerSay` | Intercepts player messages, routes through the channel system, suppresses native chat |

## Hooks Fired

| Hook | Arguments | Description |
|---|---|---|
| `nstack.service.chat.ready` | `service` | Fired after the service is running; used by other services and modules to register channels and filters |

---

## Network Strings

| String | Direction | Description |
|---|---|---|
| `nstack:service:chat:message` | Server → Client | Carries a serialized format table rendered via `chat.AddText` |
