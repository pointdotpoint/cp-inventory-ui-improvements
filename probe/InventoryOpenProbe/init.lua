-- InventoryOpenProbe: measures where time goes when the hub/inventory menu opens.
-- Each open appends one report to probe.log in this folder (also printed to the CET console).

local WINDOW = 15.0     -- recording stops when the hub closes, or after this many seconds
local SKIP_SLOTS_ON_EVEN_OPENS = false -- A/B: every second open skips equipment slot population
local REMOVE_V_ON_EVEN_INITS = false -- A/B: every second inventory screen init detaches the 3D V widget
local RING = 120        -- frames kept from before the first script callback
local SLOW_FRAME = 0.025

local hooks = {
  { 'MenuHubGameController', 'OnInitialize' },
  { 'gameuiInventoryGameController', 'OnInitialize' },
  { 'gameuiInventoryGameController', 'OnSetUserData' },
  { 'gameuiInventoryGameController', 'RefreshUI' },
  { 'gameuiInventoryGameController', 'RefreshPlayerCyberware' },
  { 'gameuiInventoryGameController', 'OnEquipmentAreaCategoryCreated' },
  { 'gameuiInventoryGameController', 'PopulateArea' },
  { 'gameuiInventoryGameController', 'SetupPlayerStats' },
  { 'InventoryDataManagerV2', 'Initialize' },
  { 'InventoryItemDisplayController', 'InvalidateContent' },
  { 'InventoryItemModeLogicController', 'SetupData' },
  { 'inkInventoryPuppetPreviewGameController', 'OnInitialize' },
  { 'inkPuppetPreviewGameController', 'OnPreviewInitialized' },
  { 'inkInventoryPuppetPreviewGameController', 'OnUninitialize' },
  { 'BackpackMainGameController', 'OnInitialize' },
  { 'PhotoModePlayerEntityComponent', 'SetupInventory' },
  { 'PhotoModePlayerEntityComponent', 'PutOnFakeItem' },
  { 'PhotoModePlayerEntityComponent', 'OnItemAddedToSlot' },
  { 'PhotoModePlayerEntityComponent', 'OnItemVisualsAddedToSlot' },
  { 'PhotoModePlayerEntityComponent', 'ClearInventory' },
  { 'EquipmentEx.PaperdollHelper', 'AddPreview' },
  { 'EquipmentEx.PaperdollHelper', 'AddPuppet' },
  { 'inkInventoryPuppetPreviewGameController', 'OnSetCameraSetupEvent' },
  { 'BackpackMainGameController', 'OnSetUserData' },
  { 'CraftingMainGameController', 'OnInitialize' },
}

local ring, ringPos = {}, 0
local session = nil
local opens = 0
local invInits = 0

local function now() return os.clock() end

local function begin()
  opens = opens + 1
  session = { t0 = now(), elapsed = 0, frames = {}, calls = {}, order = {}, before = {}, notes = {},
              skipSlots = SKIP_SLOTS_ON_EVEN_OPENS and opens % 2 == 0 }
  -- Marker for the external sampler (probe/sampler.py).
  local m = io.open('marker.txt', 'w')
  if m then m:write(tostring(opens)); m:close() end
  for i = 1, RING do
    local dt = ring[((ringPos + i - 1) % RING) + 1]
    if dt then table.insert(session.before, dt) end
  end
end

local function finish()
  local s = session
  session = nil
  local out = {}
  local function add(fmt, ...) table.insert(out, string.format(fmt, ...)) end

  add('=== open #%d  %s  mode: %s  recorded %.1f s ===', opens, os.date('%Y-%m-%d %H:%M:%S'),
      s.skipSlots and 'SLOTS SKIPPED' or 'normal', s.elapsed)

  local worstBefore = 0
  for _, dt in ipairs(s.before) do if dt > worstBefore then worstBefore = dt end end
  local sumBefore = 0
  for _, dt in ipairs(s.before) do sumBefore = sumBefore + dt end
  add('gameplay before open: average frame %.1f ms, worst %.1f ms (%d frames)', sumBefore / math.max(#s.before, 1) * 1000, worstBefore * 1000, #s.before)

  local worst, slowSum, t = 0, 0, 0
  add('slow frames after open (> %.0f ms):', SLOW_FRAME * 1000)
  for i, dt in ipairs(s.frames) do
    t = t + dt
    if dt > worst then worst = dt end
    if dt > SLOW_FRAME then
      slowSum = slowSum + dt
      add('  frame %3d  at %6.0f ms  took %6.1f ms', i, t * 1000, dt * 1000)
    end
  end
  add('frames: %d   worst: %.1f ms   total in slow frames: %.1f ms', #s.frames, worst * 1000, slowSum * 1000)

  for _, note in ipairs(s.notes) do add(note) end
  add('script calls (inclusive time, nested calls counted in their parents too):')
  for _, name in ipairs(s.order) do
    local c = s.calls[name]
    add('  %-58s x%-3d %7.1f ms   at %s', name, c.n, c.total * 1000, table.concat(c.starts, ', '))
  end
  add('')

  local text = table.concat(out, '\n')
  print(text)
  local f = io.open('probe.log', 'a')
  if f then f:write(text, '\n'); f:close() end
end

local function findPreviewWidget(widget, depth)
  if not widget or depth > 12 then return nil end
  local okC, ctrl = pcall(function() return widget:GetController() end)
  if okC and ctrl and ctrl:IsA('inkInventoryPuppetPreviewGameController') then return widget end
  local okN, count = pcall(function() return widget:GetNumChildren() end)
  if not okN or not count then return nil end
  for i = 0, count - 1 do
    local found = findPreviewWidget(widget:GetWidgetByIndex(i), depth + 1)
    if found then return found end
  end
  return nil
end

local function hook(class, method)
  local name = class .. '.' .. method
  local okB = pcall(ObserveBefore, class, method, function()
    if class == 'MenuHubGameController' and not session then begin() end
    if not session then return end
    local c = session.calls[name]
    if not c then
      c = { n = 0, total = 0, starts = {}, stack = {} }
      session.calls[name] = c
      table.insert(session.order, name)
    end
    if #c.starts < 4 or (#c.starts < 40 and class ~= 'gameuiInventoryGameController') then
      table.insert(c.starts, string.format('%.0f ms (frame %d)', (now() - session.t0) * 1000, #session.frames + 1))
    end
    table.insert(c.stack, now())
  end)
  local okA = pcall(ObserveAfter, class, method, function()
    if not session then return end
    local c = session.calls[name]
    if not c or #c.stack == 0 then return end
    c.total = c.total + (now() - table.remove(c.stack))
    c.n = c.n + 1
  end)
  if not (okB and okA) then print('[InventoryOpenProbe] could not hook ' .. name) end
end

registerForEvent('onInit', function()
  for _, h in ipairs(hooks) do hook(h[1], h[2]) end
  ObserveAfter('MenuHubGameController', 'OnUninitialize', function()
    if session then finish() end
  end)
  Override('gameuiInventoryGameController', 'OnEquipmentAreaCategoryCreated', function(self, e, wrapped)
    if session and session.skipSlots then return false end
    return wrapped(e)
  end)
  ObserveBefore('gameuiInventoryGameController', 'OnSetUserData', function(self)
    invInits = invInits + 1
    local mode = 'normal'
    if REMOVE_V_ON_EVEN_INITS and invInits % 2 == 0 then
      local how = '?'
      local ok, err = pcall(function()
        local w
        for _, field in ipairs({ 'm_paperDollWidget', 'paperDollWidget' }) do
          local okF, res = pcall(function() return inkWidgetRef.Get(self[field]) end)
          if okF and res then w, how = res, 'field ' .. field; break end
        end
        if not w then w, how = findPreviewWidget(self:GetRootCompoundWidget(), 0), 'tree search' end
        if not w then error('preview widget not found') end
        how = how .. ', widget ' .. tostring(NameToString(w:GetName()))
        w.parentWidget:RemoveChild(w)
      end)
      mode = ok and ('V REMOVED via ' .. how) or ('V removal FAILED (' .. how .. '): ' .. tostring(err))
    end
    if session then
      table.insert(session.notes, string.format('inventory init #%d at %.0f ms (frame %d): %s',
        invInits, (now() - session.t0) * 1000, #session.frames + 1, mode))
    end
  end)
  print('[InventoryOpenProbe] ready')
end)

registerForEvent('onUpdate', function(dt)
  if session then
    table.insert(session.frames, dt)
    session.elapsed = session.elapsed + dt
    if session.elapsed >= WINDOW then finish() end
  else
    ringPos = (ringPos % RING) + 1
    ring[ringPos] = dt
  end
end)
