-- A/B Button Autofire for Gen1Recomp
--
-- Holding A and/or B re-presses it on a timer.  Three knobs, all in Options:
--
--   BUTTONS -- which buttons autofire applies to (A, B, both, or OFF).
--   DELAY   -- how long a button has to stay down before autofire starts.
--              A tap shorter than this is exactly one press, which is the
--              whole point: without it, one press reads as a burst.
--   RATE    -- how often it repeats once autofire is running.
--
-- Delay and rate are shared: both buttons run on the same timings.  Their
-- countdowns are tracked separately though, so holding A and then pressing B
-- gives B its own delay window instead of inheriting A's head start.
--
-- The timings are offered in milliseconds but stored as a whole number of
-- logic steps.  The game advances on a fixed 60Hz clock
-- (src/core/FixedStep.lua), so one step is 16.67ms and that is the finest an
-- input can be repeated -- the offered values are the ones that land on an
-- exact step count, rather than a free-typed number the engine would
-- silently round anyway.
--
-- The work happens in the "input.step" hook, which Game:step calls once per
-- logic step immediately BEFORE Input:step promotes queued presses to this
-- step's edges.  That is the seam the engine documents for exactly this
-- ("autoplay, accessibility drivers, input visualizers"), and it means an
-- injected press is visible to the same tick a physical one would be.
--
-- Injection is a push onto input.pressQueue.  Input:step turns every queued
-- name into a `pressed` edge; because a real key is still holding the
-- button, its source table is non-empty and the held state carries on
-- untouched.  We never write input.state ourselves, so the
-- A+B+SELECT+START soft reset (Input:softResetHeld) still counts only
-- genuinely held buttons -- including when autofire is driving both A and B.

local FACE_BUTTONS = { "a", "b" }
local DIRECTIONS = { "up", "down", "left", "right" }

-- which physical buttons each BUTTONS choice drives
local BUTTON_SETS = {
  off = {},
  a = { a = true },
  b = { b = true },
  ab = { a = true, b = true },
}

local BUTTON_CHOICES = {
  { "OFF", "off" },
  { "A ONLY", "a" },
  { "B ONLY", "b" },
  { "A AND B", "ab" },
}

-- { label, steps } -- steps * (1/60)s is the real interval
local DELAY_CHOICES = {
  { "150 MS", 9 },
  { "200 MS", 12 },
  { "250 MS", 15 },
  { "300 MS", 18 },
  { "400 MS", 24 },
  { "500 MS", 30 },
}

local RATE_CHOICES = {
  { "50 MS", 3 },
  { "100 MS", 6 },
  { "150 MS", 9 },
  { "200 MS", 12 },
  { "300 MS", 18 },
  { "400 MS", 24 },
  { "500 MS", 30 },
}

local DPAD_CHOICES = {
  { "OFF", false },
  { "ON", true },
}

local SCOPE_CHOICES = {
  { "EVERYWHERE", "all" },
  { "BATTLE ONLY", "battle" },
  { "WORLD ONLY", "world" },
}

-- Keys owned by this mod's option schema.  Kept in one list for the Gold
-- persistence compatibility bridge below so no unrelated mod option is ever
-- copied or written.
local OPTION_KEYS = { "buttons", "delay", "rate", "dpad", "scope" }
local GOLD_PERSIST_MARKER = "__a_autofire_gold_persist_v1"

return function(mod)
  mod.options:define({
    { key = "buttons", label = "AUTOFIRE BUTTONS", type = "choice",
      default = "ab", choices = BUTTON_CHOICES },
    { key = "delay", label = "HOLD BEFORE REPEAT", type = "choice",
      default = 15, choices = DELAY_CHOICES },
    { key = "rate", label = "REPEAT EVERY", type = "choice",
      default = 12, choices = RATE_CHOICES },
    -- Walking is unaffected either way: OverworldState:dirHeld reads
    -- input:isDown, so a held direction already repeats on its own and an
    -- injected edge changes nothing out there.  What this actually buys is
    -- cursor repeat in menus, which read wasPressed -- the Pokedex, the bag,
    -- the naming grid, the PC.
    { key = "dpad", label = "DIRECTIONAL KEYS", type = "choice",
      default = false, choices = DPAD_CHOICES },
    -- BATTLE ONLY is the escape hatch for the overworld's hazards: holding A
    -- re-triggers whatever you are facing, a yes/no prompt that appears
    -- mid-hold answers itself, and held B repeats cancel, which walks back
    -- out of menus.  WORLD ONLY is the mirror, for players who want autofire
    -- for overworld text and menus but keep battles fully manual so a held
    -- button cannot pick a move or burn a turn on its own.
    { key = "scope", label = "AUTOFIRE IN", type = "choice",
      default = "all", choices = SCOPE_CHOICES },
  })

  -- cached rather than read per step: options:get walks the schema on a
  -- miss, and this runs 60 times a second for every tracked button
  local active, delaySteps, rateSteps, scope
  local liveGame = nil

  local function readOptions()
    local faces = BUTTON_SETS[mod.options:get("buttons")] or BUTTON_SETS.off
    active = {}
    for button in pairs(faces) do active[button] = true end
    if mod.options:get("dpad") then
      for _, dir in ipairs(DIRECTIONS) do active[dir] = true end
    end
    delaySteps = tonumber(mod.options:get("delay")) or 15
    rateSteps = math.max(1, tonumber(mod.options:get("rate")) or 12)
    scope = mod.options:get("scope") or "all"
  end

  -- Gen1Recomp v0.1.75 currently has two option persistence shapes:
  -- Loader.modOptions is loaded from the shared root options.modOptions, while
  -- Game2/save.options points at the Gold-specific options.gold block.  The
  -- generic MODS manager updates both live tables, but its persistence helper
  -- calls game:writeOptions(); Game2 exposes persistOptions() instead.  The
  -- result is a Gold-only failure mode where settings work for the session and
  -- come back as defaults on the next boot.
  --
  -- Keep this bridge capability-based rather than version-gated.  On a Gold
  -- build where the manager still has that split, save the Gold block after
  -- our option changes and restore only OUR five keys into the loader on the
  -- next game.ready.  On Gen 1 (and on a future engine that supplies the normal
  -- writeOptions path) this collapses to the ordinary persistence route.
  local function gameOptions(game)
    if not game then return nil end
    if type(game.options) == "table" then return game.options end
    local save = game.save
    return save and type(save.options) == "table" and save.options or nil
  end

  local function persistChangedOptions(game)
    if not game then return end
    local hasWriteOptions = type(game.writeOptions) == "function"
    local hasGoldWriter = type(game.persistOptions) == "function"

    -- Gen 1 already has the normal writeOptions path.  Only the Gold-style
    -- capability split needs a compatibility marker/bucket of its own.
    if not hasWriteOptions and hasGoldWriter then
      local options = gameOptions(game)
      if options then
        options.modOptions = options.modOptions or {}
        local bucket = options.modOptions[mod.id]
        if type(bucket) ~= "table" then
          bucket = {}
          options.modOptions[mod.id] = bucket
        end
        -- The manager has already written the changed value into this bucket
        -- before it emits mod.options_changed.  The marker distinguishes a
        -- Gold block intentionally persisted by this compatibility shim from a
        -- coincidental/stale table, so launcher/root options remain authoritative
        -- until the player actually changes Autofire in-game on Gold.
        bucket[GOLD_PERSIST_MARKER] = true
      end
    end

    if hasWriteOptions then
      pcall(game.writeOptions, game)
    elseif hasGoldWriter then
      pcall(game.persistOptions, game)
    end
  end

  local function restoreGoldOptions(game)
    local options = gameOptions(game)
    local all = options and options.modOptions
    local saved = all and all[mod.id]
    if type(saved) ~= "table" or not saved[GOLD_PERSIST_MARKER] then
      return false
    end

    -- mod.options:get is backed by loader.modOptions.  Game2 intentionally
    -- keeps its Gold options block separate, so mirror only this mod's known
    -- keys back into that live backing table once the loader exists.
    local loader = game and game.mods
    if not loader then return false end
    loader.modOptions = loader.modOptions or {}
    local target = loader.modOptions[mod.id]
    if type(target) ~= "table" then
      target = {}
      loader.modOptions[mod.id] = target
    end
    for _, key in ipairs(OPTION_KEYS) do
      if saved[key] ~= nil then target[key] = saved[key] end
    end
    return true
  end

  readOptions()
  mod.events:on("game.ready", function(payload)
    liveGame = (payload and payload.game) or mod.game
    if restoreGoldOptions(liveGame) then readOptions() end
  end)
  mod.events:on("mod.options_changed", function(payload)
    if payload and payload.mod == mod.id then
      readOptions()
      persistChangedOptions(liveGame or mod.game)
    end
  end)

  -- battle.started / battle.ended bracket every battle, so scope can be
  -- answered without reaching into the state stack
  local inBattle = false
  mod.events:on("battle.started", function() inBattle = true end)
  mod.events:on("battle.ended", function() inBattle = false end)

  -- per button: consecutive steps held, and steps since the last injection.
  -- Separate entries because A and B are held independently.
  local TRACKED = {}
  for _, btn in ipairs(FACE_BUTTONS) do TRACKED[#TRACKED + 1] = btn end
  for _, dir in ipairs(DIRECTIONS) do TRACKED[#TRACKED + 1] = dir end

  local track = {}
  for _, btn in ipairs(TRACKED) do
    track[btn] = { held = 0, since = 0 }
  end

  -- ListMenu has its own opt-in hold-to-scroll (keyRepeat, via the
  -- ui.list_menu hook), and several shipped mods turn it on -- pokedex_plus
  -- does so on five of its lists.  Those screens already advance the cursor
  -- on held frames, so an injected edge on top of that scrolls twice per
  -- tick.  Where a state repeats for itself, leave its directions alone;
  -- A and B are unaffected, since keyRepeat only drives the d-pad.
  local function stateRepeatsDirections(game)
    local stack = game and game.stack
    local top = stack and stack.top and stack:top()
    return top ~= nil and top.keyRepeat and true or false
  end

  local function scopeAllows()
    if scope == "battle" then return inBattle end
    if scope == "world" then return not inBattle end
    return true
  end

  -- true when this button is already queued this step -- a real press
  -- landed, or another tool mod injected one.  Never stack a second edge.
  local function alreadyQueued(input, button)
    for _, queued in ipairs(input.pressQueue or {}) do
      if queued == button then return true end
    end
    return false
  end

  local DIRECTION = {}
  for _, dir in ipairs(DIRECTIONS) do DIRECTION[dir] = true end

  local function stepButton(input, button, skipDirections)
    local t = track[button]

    if not input:isDown(button) then
      -- released (or never held, or cleared by Input:reset on focus loss)
      t.held = 0
      t.since = 0
      return
    end

    -- A real press edge is queued this step.  Usually that is the first
    -- step of a hold and the counters are already zero, but it also covers
    -- a release+press that both landed inside one logic step: the held
    -- state never dipped, so without this the delay would not re-arm and a
    -- fast double tap would resume autofire mid-burst.  A second source
    -- claiming the button mid-hold re-arms for the same reason.
    local fresh = alreadyQueued(input, button)
    if fresh then
      t.held = 0
      t.since = 0
    end

    t.held = t.held + 1

    -- the counters keep running even when this button is not autofiring, so
    -- switching options mid-hold cannot release a backlog of repeats
    if not active[button] or not scopeAllows()
        or (skipDirections and DIRECTION[button]) then
      t.since = 0
      return
    end

    if t.held <= delaySteps then
      -- still inside the initial hold window: one tap stays one press
      t.since = 0
      return
    end

    t.since = t.since + 1
    if t.since >= rateSteps and not fresh then
      t.since = 0
      input.pressQueue[#input.pressQueue + 1] = button
    end
  end

  mod.hooks:wrap("input.step", function(next, game)
    local input = game and game.input
    if not input or not input.isDown then
      return next()
    end

    local skipDirections = stateRepeatsDirections(game)
    for _, button in ipairs(TRACKED) do
      stepButton(input, button, skipDirections)
    end

    return next()
  end)

  -- published so a test (or another mod) can inspect the timing without a
  -- live Game
  mod.exports.stateForTest = function()
    return { track = track, delaySteps = delaySteps,
             rateSteps = rateSteps, active = active }
  end

  local names = {}
  for _, btn in ipairs(TRACKED) do
    if active[btn] then names[#names + 1] = btn:upper() end
  end
  mod.log:info("autofire ready for [%s]: %d-step delay, repeat every %d steps",
               #names > 0 and table.concat(names, "+") or "NONE",
               delaySteps, rateSteps)
end
