# Service: voice

Manages server-side voice chat routing via a composable rule system.
A single `PlayerCanHearPlayersVoice` hook delegates all hearing decisions
to a priority-sorted chain of rules registered by services and modules.

---

## Overview

By default — when no rules are registered — the service returns nothing and
GMod handles voice as normal (every player hears every other player, 2D).

Once any rule is registered the chain takes over. Each rule inspects a
receiver/sender pair and either returns a decision or abstains. The first
non-nil result wins. If all rules abstain the hook falls through to GMod default.

Rules are registered and removed at runtime. The instance service uses this
to block cross-instance voice. Modules can layer proximity, radio channels,
calls, or any other behaviour on top without touching each other.

---

## Public API

Access via `nstack.services[ "voice" ]`.

### `addRule( name, priority, fn )`

Registers a voice rule. Lower priority number = evaluated first.
If another rule already occupies the same priority a warning is logged
but both rules are kept; evaluation order between them is undefined.

```lua
nstack.services[ "voice" ].addRule( "proximity" , 100 , function( receiver , sender )
    if ( receiver:GetPos():Distance( sender:GetPos() ) > 800 ) then return false end
    return true , true
end )
```

### `removeRule( name )`

Removes a previously registered rule by name. No-ops silently if the name
is not found.

```lua
nstack.services[ "voice" ].removeRule( "proximity" )
```

---

## Rule Function Contract

```lua
-- @param receiver  Player  the player who would hear the voice
-- @param sender    Player  the player speaking
-- @return canHear  bool|nil  true = allow, false = block, nil = abstain
-- @return use3D    bool|nil  true = positional 3D audio, false = flat 2D (ignored if canHear is nil)
local function myRule( receiver , sender )
    ...
end
```

Returning `nil` passes the decision to the next rule in the chain. If no rule
decides, GMod default applies (heard, 2D).

---

## Priority Convention

There is no enforced mapping — pick a number that places your rule correctly
relative to others already registered. The following ranges are a guideline:

| Range | Typical use |
|---|---|
| `1 – 20` | Hard blocks: instance separation, admin mutes, bans |
| `50 – 80` | Channel-based routing: radio, calls, team voice |
| `100+` | Spatial fallbacks: proximity, default world voice |

---

## Integration Pattern

Services and modules must not reference `nstack.services[ "voice" ]` directly
during their own `_init`. Use the `nstack.service.voice.ready` hook instead —
it fires after the voice service is fully initialised and passes the service
table as its argument.

```lua
hook.Add( "nstack.service.voice.ready" , "my.module.registerVoiceRule" , function( voiceService )
    voiceService.addRule( "my-rule" , 50 , function( receiver , sender )
        ...
    end )
end )
```

If the voice service is not loaded the hook never fires — no error, no coupling.

---

## Hooks Listened

| Hook | Key | Description |
|---|---|---|
| `PlayerCanHearPlayersVoice` | `nstack.services.voice.playerCanHearPlayer` | Runs the rule chain for every receiver/sender pair |

## Hooks Fired

| Hook | Arguments | Description |
|---|---|---|
| `nstack.service.voice.ready` | `service` | Fired after the service is running; used by other services and modules to register rules |
