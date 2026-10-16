-- PreviewPoseTest: can the workspot system play an arbitrary animation on the inventory /
-- wardrobe preview puppet? Uses AMM's workspot entity and one of AMM's player animations.
-- Every step is logged to pose_test.log in this folder.

local DELAY = 2.0
local WORKSPOT_ENT = 'base\\amm_workspots\\entity\\workspot_anim.ent'
local WORKSPOT_COMP = 'amm_workspot_base'
local TEST_ANIM = 'stand__2h_front__dance__01'

local pending = nil   -- { controller, wait, stage, deviceID, tries }
local active = nil    -- { puppet, device }
local checks = nil

local function log(fmt, ...)
  local line = string.format('[%s] ' .. fmt, os.date('%H:%M:%S'), ...)
  print('[PreviewPoseTest] ' .. line)
  local f = io.open('pose_test.log', 'a')
  if f then f:write(line, '\n'); f:close() end
end

local function try(label, fn)
  local ok, res = pcall(fn)
  if ok then
    log('%s -> ok %s', label, tostring(res))
  else
    log('%s -> ERROR %s', label, tostring(res))
  end
  return ok, res
end

local function cleanup()
  if not active then return end
  if active.puppet then pcall(function() Game.GetWorkspotSystem():StopInDevice(active.puppet) end) end
  if active.device then pcall(function() exEntitySpawner.Despawn(active.device) end) end
  active = nil
end

local function run(controller)
  log('=== test start, controller %s', NameToString(controller:GetClassName()))
  local _, puppet = try('GetGamePuppet', function() return controller:GetGamePuppet() end)
  if not puppet then return end
  try('puppet class', function() return NameToString(puppet:GetClassName()) end)
  local _, id = try('puppet entity id', function() return tostring(puppet:GetEntityID().hash) end)
  try('FindEntityByID finds puppet in game world', function()
    return Game.FindEntityByID(puppet:GetEntityID()) ~= nil
  end)
  local _, pos = try('puppet position', function()
    local p = puppet:GetWorldPosition(); return string.format('%.1f %.1f %.1f', p.x, p.y, p.z)
  end)
  try('player position', function()
    local p = Game.GetPlayer():GetWorldPosition(); return string.format('%.1f %.1f %.1f', p.x, p.y, p.z)
  end)
  try('puppet attached', function() return puppet:IsAttached() end)

  local _, deviceID = try('spawn workspot device at puppet', function()
    local t = puppet:GetWorldTransform()
    return exEntitySpawner.Spawn(WORKSPOT_ENT, t, '')
  end)
  if not deviceID then return end
  pending = { stage = 'wait_device', puppet = puppet, deviceID = deviceID, tries = 0, wait = 0.1 }
end

local function playOnDevice(device, puppet)
  active = { puppet = puppet, device = device }
  try('PlayInDeviceSimple', function()
    Game.GetWorkspotSystem():PlayInDeviceSimple(device, puppet, false, WORKSPOT_COMP, CName.new('AMM_WORKSPOT'), nil, 0, 1, nil)
    return true
  end)
  try('SendJumpToAnimEnt ' .. TEST_ANIM, function()
    Game.GetWorkspotSystem():SendJumpToAnimEnt(puppet, TEST_ANIM, true)
    return true
  end)
  try('IsActorInWorkspot', function() return Game.GetWorkspotSystem():IsActorInWorkspot(puppet) end)
  -- The workspot may attach asynchronously; re-check over a few seconds.
  checks = { puppet = puppet, device = device, times = { 0.5, 1.5, 3.0, 5.0 }, t = 0, retried = false }
end

registerForEvent('onInit', function()
  ObserveAfter('inkPuppetPreviewGameController', 'OnPreviewInitialized', function(self)
    cleanup()
    pending = { stage = 'delay', controller = self, wait = DELAY }
  end)
  ObserveBefore('inkPreviewGameController', 'OnUninitialize', function()
    pending = nil
    checks = nil
    cleanup()
  end)
  log('ready')
end)

local function runChecks(dt)
  checks.t = checks.t + dt
  if #checks.times == 0 or checks.t < checks.times[1] then return end
  table.remove(checks.times, 1)
  local ws = Game.GetWorkspotSystem()
  try(string.format('t=%.1fs IsActorInWorkspot', checks.t), function() return ws:IsActorInWorkspot(checks.puppet) end)
  try(string.format('t=%.1fs device user', checks.t), function()
    local user = ws:GetDeviceUser(checks.device:GetEntityID())
    return user and NameToString(user:GetClassName()) or 'none'
  end)
  try(string.format('t=%.1fs puppet anim time dilation', checks.t), function() return checks.puppet:GetTimeDilation() end)
  -- Second attempt halfway through, in case the first request was dropped.
  if not checks.retried and checks.t >= 1.5 then
    checks.retried = true
    try('retry PlayInDevice (non-simple)', function()
      ws:PlayInDevice(checks.device, checks.puppet)
      return true
    end)
    try('retry SendJumpToAnimEnt', function()
      ws:SendJumpToAnimEnt(checks.puppet, TEST_ANIM, true)
      return true
    end)
  end
  if #checks.times == 0 then
    log('=== checks done')
    checks = nil
  end
end

registerForEvent('onUpdate', function(dt)
  if checks then
    local ok, err = pcall(runChecks, dt)
    if not ok then log('checks failed: %s', tostring(err)); checks = nil end
  end
  if not pending then return end
  pending.wait = pending.wait - dt
  if pending.wait > 0 then return end

  if pending.stage == 'delay' then
    local controller = pending.controller
    pending = nil
    local ok, err = pcall(run, controller)
    if not ok then log('run failed: %s', tostring(err)) end
  elseif pending.stage == 'wait_device' then
    pending.tries = pending.tries + 1
    local device = Game.FindEntityByID(pending.deviceID)
    if device then
      log('device found after %d polls', pending.tries)
      local puppet = pending.puppet
      pending = nil
      playOnDevice(device, puppet)
    elseif pending.tries >= 30 then
      log('device never appeared after %d polls (spawning may be paused while the menu is open)', pending.tries)
      pending = nil
    else
      pending.wait = 0.1
    end
  end
end)
