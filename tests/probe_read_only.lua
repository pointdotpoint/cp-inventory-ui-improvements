-- Run from the repo root: lua tests/probe_read_only.lua
local events, before = {}, {}
function registerForEvent(name, callback) events[name] = callback end
function ObserveBefore(class, method, callback) before[class .. '.' .. method] = callback end
function ObserveAfter() end
function Override() end
Game = {
  GetQuestsSystem = function() error('A timing probe must not write quest state') end
}
io.open = function() return nil end
dofile('probe/InventoryOpenProbe/init.lua')
events.onInit()
before['MenuHubGameController.OnInitialize']()
events.onUpdate(16)
print('PASS: opening the timing probe does not change quest state')
