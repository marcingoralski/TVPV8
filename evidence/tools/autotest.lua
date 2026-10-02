-- Drives the client through a scripted scenario; "SHOT <name>" log lines are
-- picked up by an external watcher that screenshots the X display.
local ACCOUNT, PASSWORD, HOST = "111111", "tvp", "127.0.0.1:7171:772"

local function log(s) g_logger.info("[AUTOTEST] " .. g_clock.millis() .. " " .. s) end
local function shot(name) log("SHOT " .. name) end

local steps, idx = {}, 0
local function nextStep()
  idx = idx + 1
  local s = steps[idx]
  if not s then log("DONE") return end
  scheduleEvent(function()
    local ok, err = pcall(s[2])
    if not ok then log("STEP ERROR " .. tostring(err)) end
    nextStep()
  end, s[1])
end
local function run(list) steps = list; idx = 0; nextStep() end

local function login(char)
  g_settings.set('last-used-character', char)
  EnterGame.doLogin(ACCOUNT, PASSWORD, "", HOST)
end
local function enterChar() CharacterList.doLogin() end
local function say(t) g_game.talk(t) end
local function player() return g_game.getLocalPlayer() end
local function openBackpack()
  local bp = player():getInventoryItem(InventorySlotBack)
  if bp then g_game.open(bp) log("opened backpack id=" .. bp:getId()) else log("NO BACKPACK IN BACK SLOT") end
end
local function dumpInventory(tag)
  for slot = InventorySlotFirst, InventorySlotLast do
    local it = player():getInventoryItem(slot)
    if it then log(tag .. " slot " .. slot .. ": id=" .. it:getId() .. " count=" .. it:getCountOrSubType()) end
  end
  for _, c in pairs(g_game.getContainers()) do
    for i, it in ipairs(c:getItems()) do
      log(tag .. " container '" .. c:getName() .. "' #" .. i .. ": id=" .. it:getId() .. " count=" .. it:getCountOrSubType())
    end
  end
end
local function lookBackpackItems()
  for _, c in pairs(g_game.getContainers()) do
    for _, it in ipairs(c:getItems()) do g_game.look(it) end
  end
  for slot = InventorySlotFirst, InventorySlotLast do
    local it = player():getInventoryItem(slot)
    if it and slot ~= InventorySlotBack then g_game.look(it) end
  end
end


local function cleanUi()
  pcall(function() modules.game_outfit.destroy() end)
  pcall(function() modules.game_bot.botWindow:close() end)
end
local function frontPos()
  local pos = player():getPosition()
  local d = player():getDirection()
  if d == North then pos.y = pos.y - 1 elseif d == South then pos.y = pos.y + 1
  elseif d == East then pos.x = pos.x + 1 elseif d == West then pos.x = pos.x - 1 end
  return pos
end
local function findInvById(id)
  for slot = InventorySlotFirst, InventorySlotLast do
    local it = player():getInventoryItem(slot)
    if it and it:getId() == id then return it, slot end
  end
end
local RING = 3048 -- might ring (client id)
local function dropRingInFront()
  local it = findInvById(RING)
  if not it then log("ring not found") return end
  g_game.move(it, frontPos(), 1)
  local p = frontPos(); log("dropped ring at " .. p.x .. "," .. p.y .. "," .. p.z)
end
local function pickRingToFinger()
  local tile = g_map.getTile(frontPos())
  local thing = tile and tile:getTopMoveThing()
  if not thing then log("nothing in front") return end
  g_game.move(thing, {x=65535, y=InventorySlotFinger, z=0}, 1)
  log("picked id " .. thing:getId() .. " into finger slot")
end
local function lookRing()
  local it = player():getInventoryItem(InventorySlotFinger)
  if it then g_game.look(it) else log("no ring in finger slot") end
end

local function stashHandsIntoBackpack()
  local bp
  for _, c in pairs(g_game.getContainers()) do bp = c end
  if not bp then log("no open container") return end
  for _, slot in ipairs({InventorySlotLeft, InventorySlotRight, InventorySlotAmmo}) do
    local it = player():getInventoryItem(slot)
    if it then g_game.move(it, {x=65535, y=0x40 + bp:getId(), z=0}, it:getCount()) log("moved slot " .. slot .. " into backpack") end
  end
end

local scenarios = {}

-- Fresh install: schema.sql only, no migration applied.
scenarios.fresh = function()
  run({
    {3000, function() login("Gm Tester") end},
    {3000, function() shot("01_charlist") end},
    {1500, enterChar},
    {4000, function() shot("02_fresh_schema_login") end},
  })
end

-- Migration applied: give items, relog, compare.
scenarios.relog = function()
  run({
    {3000, function() login("Gm Tester") end},
    {3000, enterChar},
    {4000, function() say("/i 1988") end},
    {800, function() say("/i 2164") end},
    {800, function() say("/i 2273, 5") end},
    {800, function() say("/i 2304, 4") end},
    {800, function() say("/i 2148, 57") end},
    {800, function() say("/i 2160, 3") end},
    {800, function() say("/i 2120") end},
    {1500, openBackpack},
    {1500, lookBackpackItems},
    {2000, function() dumpInventory("BEFORE") end},
    {500, function() shot("03_before_logout") end},
    {1500, function() say("/save") end},
    {1500, function() g_game.safeLogout() end},
    {4000, function() shot("04_logged_out") end},
    {1500, enterChar},
    {4000, openBackpack},
    {1500, lookBackpackItems},
    {2000, function() dumpInventory("AFTER") end},
    {500, function() shot("05_after_relog") end},
  })
end


-- Run 1: give items + set attributes, look, then log out cleanly.
scenarios.give = function()
  run({
    {3000, function() login("Gm Tester") end},
    {3000, enterChar},
    {4000, cleanUi},
    {500, function() say("/i 1988") end},
    {800, function() say("/i 2164") end},
    {800, function() say("/i 2148, 57") end},
    {800, function() say("/i 2160, 3") end},
    {800, function() say("/i 2120") end},
    {1500, dropRingInFront},
    {1500, function() say("/attr charges, 7") end},
    {1200, function() say("/attr description, Engraved for PR 18 test.") end},
    {1500, pickRingToFinger},
    {1500, openBackpack},
    {1500, stashHandsIntoBackpack},
    {2000, function() dumpInventory("BEFORE") end},
    {500, lookRing},
    {1200, function() shot("03_before_logout") end},
    {1000, function() g_game.safeLogout() end},
    {3000, function() shot("04_logged_out") end},
  })
end

-- Run 2 (fresh client process, player reloaded from DB): inspect the same items.
scenarios.check = function()
  run({
    {3000, function() login("Gm Tester") end},
    {3000, enterChar},
    {4000, cleanUi},
    {500, openBackpack},
    {1500, function() dumpInventory("AFTER") end},
    {500, lookRing},
    {1200, function() shot("05_after_relog") end},
    {1000, function() g_game.safeLogout() end},
    {3000, function() end},
  })
end

function init()
  g_settings.set('autoReconnect', false)
  connect(g_game, {
    onGameStart = function() log("EVENT onGameStart") end,
    onGameEnd = function() log("EVENT onGameEnd") end,
    onLoginError = function(e) log("EVENT onLoginError " .. tostring(e)) end,
    onConnectionError = function(m, c) log("EVENT onConnectionError " .. tostring(m) .. " " .. tostring(c)) end,
    onLogout = function() log("EVENT onLogout") end,
  })
  pcall(function() g_window.move({x=0,y=0}) g_window.resize({width=1280,height=800}) end)
  local plan = g_resources.fileExists("/mods/autotest/scenario.txt") and g_resources.readFileContents("/mods/autotest/scenario.txt") or ""
  plan = plan:gsub("%s+", "")
  log("scenario=" .. plan)
  if scenarios[plan] then scenarios[plan]() end
end
