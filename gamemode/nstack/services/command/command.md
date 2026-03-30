# Service: command

Dispatches prefixed player chat messages to registered command handlers.
Integrates with the chat service via a priority-1 channel per prefix — messages
are consumed silently and never displayed as chat.

---

## Overview

The command service sits on top of the chat service. Each registered prefix gets
its own channel (priority `1`) that claims any message starting with that prefix,
parses the command name and arguments, and calls the matching handler. If no
handler is found for the command name the message is still suppressed and a debug
log entry is written.

Command handlers are registered at any time — before or after the chat service
is ready. The service resolves the timing automatically.

---

## Public API

Access via `nstack.services[ "command" ]`.

### `addCommand( prefix, name, fn )`

Registers a command handler. `prefix` is the trigger character(s), `name` is
the command word that follows. Command names are case-insensitive.

If this is the first command registered for a given prefix, a chat channel is
created automatically.

```lua
nstack.services[ "command" ].addCommand( "!" , "kick" , function( sender , args )
    -- args = { "PlayerName" , "reason" , "..." }
end )
```

### `removeCommand( prefix, name )`

Removes a command handler. If no commands remain for that prefix the associated
chat channel is also removed.

```lua
nstack.services[ "command" ].removeCommand( "!" , "kick" )
```

---

## Handler Function Contract

```lua
-- @param sender  Player   the player who typed the command
-- @param args    table    whitespace-split tokens after the command name
--                         e.g. "!kick PlayerName reason" → args = { "PlayerName", "reason" }
local function handler( sender , args )
    ...
end
```

Arguments are split on whitespace. Multiple consecutive spaces produce no empty
entries. The prefix and command name are already stripped — `args[1]` is the
first argument.

---

## Integration Pattern

Register commands from within `nstack.service.chat.ready` or any time after.
Modules should use `nstack.service.chat.ready` to stay decoupled:

```lua
hook.Add( "nstack.service.chat.ready" , "admin.module.registerCommands" , function()
    local commands = nstack.services[ "command" ]

    commands.addCommand( "!" , "kick" , function( sender , args )
        if ( not sender:IsAdmin() ) then return end
        -- find and kick player by args[1]
    end )

    commands.addCommand( "!" , "ban" , function( sender , args )
        if ( not sender:IsAdmin() ) then return end
        -- ban player by args[1] for args[2] minutes
    end )
end )
```

---

## Examples

### Admin commands via `!`

```lua
hook.Add( "nstack.service.chat.ready" , "admin.module.commands" , function()
    local commands = nstack.services[ "command" ]

    commands.addCommand( "!" , "kick" , function( sender , args )
        if ( not sender:IsAdmin() ) then return end

        local target = nstack.util.findPlayer( args[ 1 ] )
        if ( not IsValid( target ) ) then return end

        local reason = table.concat( args , " " , 2 )
        target:Kick( reason ~= "" and reason or "Kicked by an admin." )
    end )

    commands.addCommand( "!" , "tp" , function( sender , args )
        if ( not sender:IsAdmin() ) then return end
        sender:SetPos( sender:GetEyeTrace().HitPos )
    end )
end )
```

### A second prefix for a different module

```lua
hook.Add( "nstack.service.chat.ready" , "shop.module.commands" , function()
    local commands = nstack.services[ "command" ]

    commands.addCommand( "/" , "buy" , function( sender , args )
        local itemName = args[ 1 ]
        -- handle purchase
    end )

    commands.addCommand( "/" , "sell" , function( sender , args )
        -- handle sale
    end )
end )
```

### Sending feedback to the command caller

Commands can use `sendTo` on the chat service to reply privately:

```lua
commands.addCommand( "!" , "heal" , function( sender , args )
    if ( not sender:IsAdmin() ) then
        nstack.services[ "chat" ].sendTo( sender , "You do not have permission." , function( text , receiver )
            return { Color( 255 , 80 , 80 ) , "[!] " , color_white , text }
        end )
        return
    end

    sender:SetHealth( sender:GetMaxHealth() )
    nstack.services[ "chat" ].sendTo( sender , "Healed." , function( text , receiver )
        return { Color( 100 , 220 , 100 ) , "[!] " , color_white , text }
    end )
end )
```

---

## How It Differs from Chat Channels

| | `addCommand` | `addChannel` |
|---|---|---|
| Message displayed | Never | Yes, to receivers |
| Execution hook | `onClaim` | — |
| Typical prefix use | `!`, `/` | `@` (admin chat) |
| `canReceive` | Always `false` | Defined per channel |

Use `addCommand` when the prefix triggers an action with no visible message.
Use `addChannel` directly when the prefix routes a message to a specific audience.

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `nstack.service.chat.ready` | `nstack.service.command.registerWithChat` | Registers prefix channels with the chat service when it becomes available. Falls back to direct registration if chat is already running when the command service initialises. |
