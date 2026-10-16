-- Read-only timing and visibility checks. Install as InventoryOpenProbe for sampler.py.
local session, opens = nil, 0
local zoomState, inputZoom
local function log(message)
  print('[InventoryTiming] ' .. message)
  local file = io.open('probe.log', 'a')
  if file then file:write(message, '\n'); file:close() end
end

local function finish()
  if not session then return end
  log(string.format('open #%d: worst frame %.1f ms, captured %.1f s',
    opens, session.worst * 1000, session.elapsed))
  for name, call in pairs(session.calls) do
    log(string.format('%s: %d calls, %.1f ms total, %.1f ms max (inclusive CPU time)',
      name, call.count, call.total, call.max))
  end
  session = nil
end

local function hook(class, method)
  local started = {}
  ObserveBefore(class, method, function()
    if session then table.insert(started, os.clock()) end
  end)
  ObserveAfter(class, method, function()
    if #started == 0 then return end
    local elapsed = (os.clock() - table.remove(started)) * 1000
    if session then
      local name = class .. '.' .. method
      local call = session.calls[name] or { count = 0, total = 0, max = 0 }
      call.count, call.total, call.max = call.count + 1, call.total + elapsed, math.max(call.max, elapsed)
      session.calls[name] = call
    end
  end)
end

local function checkVisibility(controller, opening)
  local state = Game.GetScriptableSystemsContainer():Get(CName.new('FastInventoryState'))
  assert(state, 'FastInventoryState missing: restart with the updated scripts')
  local button = controller:GetChildWidgetByPath(CName.new('fastInventoryToggle'))
  if not button then return end -- Button is reparented while Wardrobe is active.
  local text = button:GetText()
  local expected = state.previewVisible and (opening and 'LOADING V...' or 'HIDE V') or 'SHOW V'
  if not opening and text == 'LOADING V...' then expected = state.previewVisible and text or 'SHOW V' end
  assert(text == expected, 'visibility preference disagrees with button: ' .. tostring(text))
  log('visibility check passed: saved shown=' .. tostring(state.previewVisible) .. ', button=' .. text)
end

registerForEvent('onInit', function()
  ObserveBefore('MenuHubGameController', 'OnInitialize', function()
    finish()
    opens = opens + 1
    session = { elapsed = 0, worst = 0, calls = {} }
    local marker = io.open('marker.txt', 'w')
    if marker then marker:write(tostring(opens)); marker:close() end
    log('begin open #' .. opens)
  end)
  for _, entry in ipairs({
    {'MenuHubGameController', 'OnInitialize'},
    {'gameuiInventoryGameController', 'OnSetUserData'},
    {'gameuiInventoryGameController', 'RefreshUI'},
    {'gameuiInventoryGameController', 'OnEquipmentAreaCategoryCreated'},
    {'gameuiInventoryGameController', 'OnRedesignInventoryReady'},
    {'gameuiInventoryGameController', 'OnFastInventorySpawn'},
    {'inkPuppetPreviewGameController', 'OnPreviewInitialized'},
    {'PreviewPosesState', 'BuildSelector'},
    {'PreviewPosesState', 'PoseName'},
    {'PreviewPosesState', 'BuildBrowser'},
    {'PreviewPosesState', 'ApplyFilter'},
  }) do
    local ok, err = pcall(hook, entry[1], entry[2])
    if not ok then log('hook unavailable: ' .. entry[1] .. '.' .. entry[2] .. ': ' .. tostring(err)) end
  end
  ObserveAfter('gameuiInventoryGameController', 'OnSetUserData', function(controller)
    local ok, err = pcall(checkVisibility, controller, true)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('gameuiInventoryGameController', 'OnFastInventoryToggle', function(controller)
    local ok, err = pcall(checkVisibility, controller, false)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('gameuiInventoryGameController', 'PreviewViewSaveZoom', function(controller)
    local ok, err = pcall(function()
      local state = Game.GetScriptableSystemsContainer():Get(CName.new('PreviewPosesState'))
      assert(state.invZoomValid and state.invZoom == controller.bvzZoomLevel, 'zoom input was not saved immediately')
      zoomState, inputZoom = state, controller.bvzZoomLevel
      log('zoom input saved: ' .. tostring(inputZoom))
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('gameuiInventoryGameController', 'PreviewViewRestoreZoom', function(controller)
    if not controller:PreviewViewInDefaultMode() then return end
    local ok, err = pcall(function()
      local state = Game.GetScriptableSystemsContainer():Get(CName.new('PreviewPosesState'))
      if not state.invZoomValid and not state.invViewValid then return end
      if state == zoomState then
        assert(state.invZoom == inputZoom, 'automatic reset overwrote the last zoom input')
      end
      assert(controller.bvzZoomLevel == state.invZoom, 'inventory did not restore saved zoom')
      log('inventory zoom restore check passed: ' .. tostring(state.invZoom))
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('PreviewPosesState', 'BuildSelector', function(state, parent, target)
    local ok, err = pcall(function()
      assert(state.owner == target, 'pose selector belongs to a different screen')
      assert(state.button and state.button:GetParentWidget() == parent, 'pose button is on the wrong screen')
      assert(not state.listPanel and not state.search, 'previous screen retained its pose browser')
      log('pose selector ownership check passed')
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('PreviewPosesState', 'BuildBrowser', function(state, parent, target)
    local ok, err = pcall(function()
      assert(state.owner == target, 'pose browser callbacks target a different screen')
      assert(state.listPanel and state.listPanel:GetParentWidget() == parent, 'pose browser is on the wrong screen')
      log('pose browser ownership check passed')
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('gameuiInventoryGameController', 'HideWardrobeScreen', function(controller)
    if controller.wardrobeReady then return end
    local ok, err = pcall(function()
      local state = Game.GetScriptableSystemsContainer():Get(CName.new('PreviewPosesState'))
      assert(state.owner == controller, 'inventory did not regain the pose selector')
      assert(state.preview == state.inventoryPreview, 'inventory did not regain its pose preview')
      log('wardrobe return ownership check passed')
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('inkPuppetPreviewGameController', 'OnPreviewViewRestore', function(controller, evt)
    if evt.pass < 3 or evt.generation ~= controller.pvRestoreGeneration
      or not controller:IsA('EquipmentEx.WardrobeScreenController') then return end
    local ok, err = pcall(function()
      local state = Game.GetScriptableSystemsContainer():Get(CName.new('PreviewPosesState'))
      local inventory = state.inventory
      if not inventory then return end
      assert(controller.bvzWardrobeZoomLevel == inventory.bvzZoomLevel, 'Wardrobe changed Inventory zoom')
      local surface = inventory:PreviewViewSurface()
      if surface and controller.bvzWardrobePreviewWidget then
        local expected, actual = surface:GetScale(), controller.bvzWardrobePreviewWidget:GetScale()
        assert(expected.X == actual.X and expected.Y == actual.Y, 'Wardrobe changed preview scale')
      end
      log('wardrobe zoom/scale check passed: zoom=' .. tostring(inventory.bvzZoomLevel))
    end)
    if not ok then log('CHECK FAILED: ' .. tostring(err)) end
  end)
  ObserveAfter('MenuHubGameController', 'OnUninitialize', finish)
  log('ready; timings measure CPU work, frame durations also capture waiting')
end)

registerForEvent('onUpdate', function(dt)
  if session then
    session.worst = math.max(session.worst, dt)
    session.elapsed = session.elapsed + dt
    if session.elapsed >= 15 then finish() end
  end
end)
