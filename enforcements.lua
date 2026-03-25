djui_set_popup_disabled_override(true)
gServerSettings.playerInteractions = 0
gServerSettings.pvpType = 1
gServerSettings.bubbleDeath = 0
gServerSettings.bouncyLevelBounds = 0
gServerSettings.stayInLevelAfterStar = 2
gServerSettings.playerKnockbackStrength = 10
gServerSettings.nametags = 0
gServerSettings.pauseAnywhere = 1
gServerSettings.skipIntro = 1
gLevelValues.disableActs = true

cannonTimer = 0
canExit = true

-- Become Seeker on Death
local function screen_transition(trans)
    local s = gPlayerSyncTable[0]
    local m = gMarioStates[0]
    if not s.seeker and gGlobalSyncTable.gameState == 3 then
        if trans == WARP_TRANSITION_FADE_INTO_BOWSER or (m.floor.type == SURFACE_DEATH_PLANE and m.pos.y <= m.floorHeight + 2048) then
            if canExit then
              canExit = false
            else
              s.seeker = true
              network_send(true, {packet = "ON_TAG", message = string_without_hex(gNetworkPlayers[0].name) .. " has died!"})
              packet_receive({packet = "ON_TAG", message = string_without_hex(gNetworkPlayers[0].name) .. " has died!"})
            end
        end
    end
end

--Always Have Cap
---@param m MarioState
local function before_mario_update(m)
    if m.playerIndex ~= 0 then return end
    m.flags = m.flags | MARIO_CAP_ON_HEAD
end

-- Disable Koopa Shell
local function allow_interact(_, _, intee)
    if intee == INTERACT_KOOPA_SHELL then
        return false
    end
end

--- @param m MarioState
local function mario_update(m)

  -- Seekers are Locked During Dispersion
  if gGlobalSyncTable.gameState == 2 and gPlayerSyncTable[0].seeker then
    if gMarioStates[0].action & ACT_FLAG_AIR ~= 0 then
      if (gMarioStates[0].flags & MARIO_WING_CAP) ~= 0 then
        gMarioStates[0].action = ACT_FLYING
      else
        gMarioStates[0].action = ACT_SPAWN_NO_SPIN_AIRBORNE
      end
    elseif gMarioStates[0].action & ACT_FLAG_SWIMMING == 0 then
      gMarioStates[0].pos.y = gMarioStates[0].pos.y + 20
    end
    gMarioStates[0].vel.x = 0
    gMarioStates[0].vel.y = 0
    gMarioStates[0].vel.z = 0
    gMarioStates[0].forwardVel = 0
  end
  
  -- Disable all cap abilities and call on_item_collected
  if (m.flags & MARIO_VANISH_CAP) ~= 0 then
      m.flags = m.flags & ~MARIO_VANISH_CAP 
      stop_cap_music()
      on_item_collected()
  end
  if (m.flags & MARIO_METAL_CAP) ~= 0 then
      local playerSync = gPlayerSyncTable[m.playerIndex]
      local megaActive = playerSync ~= nil and playerSync.megaMushTimer ~= nil and playerSync.megaMushTimer > 0
      if not megaActive then
        m.flags = m.flags & ~MARIO_METAL_CAP
        stop_cap_music()
        on_item_collected()
      end
  end
  if (m.flags & MARIO_WING_CAP) ~= 0 then
      m.flags = m.flags & ~MARIO_WING_CAP
      stop_cap_music()
      on_item_collected()
  end

  -- Stop BLJ
  if m.forwardVel <= -55 then
      m.forwardVel = -55
  end

  -- Never Sleep
  if m.action == ACT_START_SLEEPING or m.action == ACT_SHIVERING then
      m.action = ACT_IDLE
  end

  -- Cannon Timer
  local s = gPlayerSyncTable[m.playerIndex]
  if m.playerIndex == 0 and m.action == ACT_IN_CANNON and m.actionState == 2 then
      cannonTimer = cannonTimer + 1
      if cannonTimer >= 90 then -- 90 is 3 seconds
          m.forwardVel = 100 * coss(m.faceAngle.x)

          m.vel.y = 100 * sins(m.faceAngle.x)

          m.pos.x = m.pos.x + 120 * coss(m.faceAngle.x) * sins(m.faceAngle.y)
          m.pos.y = m.pos.y + 120 * sins(m.faceAngle.x)
          m.pos.z = m.pos.z + 120 * coss(m.faceAngle.x) * coss(m.faceAngle.y)

          play_sound(SOUND_ACTION_FLYING_FAST, m.marioObj.header.gfx.cameraToObject)
          play_sound(SOUND_OBJ_POUNDING_CANNON, m.marioObj.header.gfx.cameraToObject)

          m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags | GRAPH_RENDER_ACTIVE
          set_camera_mode(m.area.camera, m.area.camera.defMode, 1)

          set_mario_action(m, ACT_SHOT_FROM_CANNON, 0)
          queue_rumble_data_mario(m, 60, 70)
          m.usedObj.oAction = 2
          cannonTimer = 0
      end
  end
  if m.playerIndex == 0 and m.action == ACT_SHOT_FROM_CANNON then
      cannonTimer = 0
  end

  -- Give Seekers Metal Skin
  if s.seeker and gNetworkPlayers[m.playerIndex].connected then
    m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_METAL
  end
  
end

-- Disable Messages
---@param m MarioState
---@param action integer
local function before_set_mario_action(m, action)
    if m.playerIndex == 0 then
        if
            action == ACT_WAITING_FOR_DIALOG or
            action == ACT_READING_SIGN or
            action == ACT_READING_NPC_DIALOG or
            action == ACT_JUMBO_STAR_CUTSCENE or
            (action == ACT_READING_AUTOMATIC_DIALOG and get_id_from_behavior(m.interactObj.behavior) ~= id_bhvDoor and get_id_from_behavior(m.interactObj.behavior) ~= id_bhvStarDoor)
        then
            return 1
        elseif action == ACT_EXIT_LAND_SAVE_DIALOG then
            set_camera_mode(m.area.camera, m.area.camera.defMode, 1)
            return ACT_IDLE
        end
    end
end

--Enforce Exit Limit
local function on_pause_exit()
  
  if gGlobalSyncTable.gameState == 3 then
    if not gPlayerSyncTable[0].seeker and not canExit then
      return false
    end
    canExit = false
  end  
  return true

end

hook_event(HOOK_ON_SCREEN_TRANSITION, screen_transition)
hook_event(HOOK_ALLOW_INTERACT, allow_interact)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)
hook_event(HOOK_ON_PAUSE_EXIT, on_pause_exit)