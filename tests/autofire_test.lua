-- Drives the mod against the engine's real src/core/Input.lua and a
-- stand-in for Game:step that calls the hook in the same order Game does.
--
-- Run from the game root:  lua tests/autofire_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

-- GamepadMap pulls in love; stub the three functions Input uses
package.loaded["src.core.GamepadMap"] = {
  gamepadBindings = function() return {} end,
  rawBindings = function() return {} end,
  ignoreRawForJoystick = function() return false end,
}

local Input = require("src.core.Input")
local Hooks = require("src.mods.Hooks")

local modPath = os.getenv("AUTOFIRE_MAIN") or "mods/a_autofire/main.lua"

local hooks = Hooks.new()
local options = { buttons = "ab", delay = 15, rate = 3, scope = "all",
                  dpad = false }
local listeners = {}

local mod = {
  options = {
    define = function() end,
    get = function(_, k) return options[k] end,
  },
  events = { on = function(_, name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
  end },
  hooks = { wrap = function(_, name, cb)
    return hooks:wrap(name, cb, 0, "a_autofire")
  end },
  exports = {},
  log = { info = function() end, warn = function() end },
}

local chunk = assert(loadfile(modPath), "cannot load " .. modPath)
chunk()(mod)

local function emit(name, payload)
  for _, fn in ipairs(listeners[name] or {}) do fn(payload) end
end

local function setOption(key, value)
  options[key] = value
  emit("mod.options_changed", { mod = "a_autofire", key = key, value = value })
end

local input = setmetatable({}, { __index = Input })
input:init()
local stack = { states = {} }
function stack:top() return self.states[#self.states] end
local game = { input = input, stack = stack }

-- Z presses A, X presses B (src/core/Input.lua DEFAULT_BINDINGS)
local KEY = { a = "z", b = "x", up = "up", down = "down",
              left = "left", right = "right" }

-- mirrors Game:step's ordering exactly
local function step()
  hooks:call("input.step", function() end, game, 1 / 60)
  input:step()
  return input:wasPressed("a"), input:wasPressed("b"), input:wasPressed("down")
end

-- run `steps` logic steps and count the press edges each button produced
local function run(steps)
  local pa, pb, pd = 0, 0, 0
  for _ = 1, steps do
    local a, b, d = step()
    if a then pa = pa + 1 end
    if b then pb = pb + 1 end
    if d then pd = pd + 1 end
  end
  return pa, pb, pd
end

-- a clean slate that the mod actually observes: reset, then one idle step
local function clear()
  input:reset()
  step()
end

local failures = 0
local function check(label, got, want)
  local ok = got == want
  if not ok then failures = failures + 1 end
  print(("%-56s %s  (got %s, want %s)")
    :format(label, ok and "PASS" or "FAIL", tostring(got), tostring(want)))
end

-- ---------------------------------------------------------------- A only

setOption("buttons", "a")

clear()
input:keypressed(KEY.a)
local pa = run(10)                     -- 167ms, inside the 250ms delay
input:keyreleased(KEY.a)
pa = pa + run(5)
check("A: tap held 167ms is exactly one press", pa, 1)

clear()
input:keypressed(KEY.a)
pa = run(15 + 30)                      -- delay, then a press every 3rd step
input:keyreleased(KEY.a)
check("A: held 45 steps gives 1 + 30/3", pa, 1 + 10)

clear()
input:keypressed(KEY.a)
run(15 + 9)
input:keyreleased(KEY.a)
pa = run(20)
check("A: silent after release", pa, 0)

clear()
input:keypressed(KEY.a)
run(30)
check("A: soft reset not armed by autofire", input:softResetHeld(), false)
input:keyreleased(KEY.a)

-- B must stay untouched while the mode is A ONLY
clear()
input:keypressed(KEY.b)
local _, pb = run(15 + 30)
input:keyreleased(KEY.b)
check("A ONLY: B held 45 steps gives one press", pb, 1)

-- ---------------------------------------------------------------- B only

setOption("buttons", "b")

clear()
input:keypressed(KEY.b)
_, pb = run(15 + 30)
input:keyreleased(KEY.b)
check("B ONLY: B held 45 steps gives 1 + 30/3", pb, 1 + 10)

clear()
input:keypressed(KEY.a)
pa = run(15 + 30)
input:keyreleased(KEY.a)
check("B ONLY: A held 45 steps gives one press", pa, 1)

-- ---------------------------------------------------------------- A and B

setOption("buttons", "ab")

clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("A AND B: both repeat together (A)", pa, 1 + 10)
check("A AND B: both repeat together (B)", pb, 1 + 10)

-- B pressed 20 steps into an A hold must get its own delay window, not
-- inherit A's head start
clear()
input:keypressed(KEY.a)
run(20)                                -- A is already autofiring
input:keypressed(KEY.b)
_, pb = run(10)                        -- 10 steps: still inside B's delay
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("A AND B: B gets its own delay window", pb, 1)

-- both held plus SELECT and START is still a genuine soft reset chord
clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
input:keypressed("tab")                -- select
input:keypressed("escape")             -- start
run(30)
check("A AND B: real four-button chord still resets", input:softResetHeld(), true)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
input:keyreleased("tab")
input:keyreleased("escape")

-- ---------------------------------------------------------------- off

setOption("buttons", "off")

clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(60)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("OFF: one second hold gives one press (A)", pa, 1)
check("OFF: one second hold gives one press (B)", pb, 1)

-- ---------------------------------------------------------- shared timings

setOption("buttons", "ab")
setOption("rate", 6)                   -- 100ms
setOption("delay", 30)                 -- 500ms

clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(30 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("shared rate/delay applies to A", pa, 1 + 5)
check("shared rate/delay applies to B", pb, 1 + 5)

setOption("rate", 3)
setOption("delay", 15)

-- ---------------------------------------------------------------- scope

setOption("scope", "battle")

clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("scope=battle, outside battle: A quiet", pa, 1)
check("scope=battle, outside battle: B quiet", pb, 1)

clear()
emit("battle.started", {})
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
emit("battle.ended", {})
check("scope=battle, in battle: A repeats", pa, 1 + 10)
check("scope=battle, in battle: B repeats", pb, 1 + 10)

setOption("scope", "world")

clear()
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
check("scope=world, outside battle: A repeats", pa, 1 + 10)
check("scope=world, outside battle: B repeats", pb, 1 + 10)

clear()
emit("battle.started", {})
input:keypressed(KEY.a)
input:keypressed(KEY.b)
pa, pb = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.b)
emit("battle.ended", {})
check("scope=world, in battle: A quiet", pa, 1)
check("scope=world, in battle: B quiet", pb, 1)

-- a battle that starts mid-hold must cut autofire off, not let the
-- already-elapsed delay carry into it
setOption("scope", "world")
clear()
input:keypressed(KEY.a)
pa = run(15 + 9)                       -- autofiring in the overworld
emit("battle.started", {})
pa = pa + run(30)                      -- battle begins under the same hold
input:keyreleased(KEY.a)
emit("battle.ended", {})
check("scope=world: battle starting mid-hold stops it", pa, 1 + 3)

-- ------------------------------------------------------ directional keys

setOption("scope", "all")
setOption("dpad", false)

clear()
input:keypressed(KEY.down)
local _, _, pd = run(15 + 30)
input:keyreleased(KEY.down)
check("dpad OFF: DOWN held 45 steps gives one press", pd, 1)

setOption("dpad", true)

clear()
input:keypressed(KEY.down)
_, _, pd = run(15 + 30)
input:keyreleased(KEY.down)
check("dpad ON: DOWN held 45 steps gives 1 + 30/3", pd, 1 + 10)

clear()
input:keypressed(KEY.down)
pd = select(3, run(10))
input:keyreleased(KEY.down)
check("dpad ON: short tap on DOWN is one press", pd, 1)

-- directions and face buttons run on the same shared timings
clear()
input:keypressed(KEY.a)
input:keypressed(KEY.down)
pa, _, pd = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.down)
check("dpad ON: A and DOWN repeat alike (A)", pa, 1 + 10)
check("dpad ON: A and DOWN repeat alike (DOWN)", pd, 1 + 10)

-- a screen with its own hold-to-scroll must not get doubled up
stack.states[1] = { keyRepeat = true }
clear()
input:keypressed(KEY.a)
input:keypressed(KEY.down)
pa, _, pd = run(15 + 30)
input:keyreleased(KEY.a)
input:keyreleased(KEY.down)
check("state with keyRepeat: DOWN left alone", pd, 1)
check("state with keyRepeat: A still repeats", pa, 1 + 10)
stack.states[1] = nil

-- scope applies to directions too
setOption("scope", "battle")
clear()
input:keypressed(KEY.down)
_, _, pd = run(15 + 30)
input:keyreleased(KEY.down)
check("dpad ON, scope=battle, outside battle: quiet", pd, 1)

clear()
emit("battle.started", {})
input:keypressed(KEY.down)
_, _, pd = run(15 + 30)
input:keyreleased(KEY.down)
emit("battle.ended", {})
check("dpad ON, scope=battle, in battle: repeats", pd, 1 + 10)

print(failures == 0 and "\nall checks passed"
                    or ("\n" .. failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
