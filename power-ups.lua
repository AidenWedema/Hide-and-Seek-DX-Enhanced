TEX_BOO = get_texture_info("powerup_boo")
TEX_BLOOPER = get_texture_info("powerup_blooper")
TEX_BULLET_BILL = get_texture_info("powerup_bullet_bill")
TEX_FREEZIE = get_texture_info("powerup_freezie")
TEX_LAUNCH_STAR = get_texture_info("powerup_launch_star")
TEX_MEGA_MUSHROOM = get_texture_info("powerup_mega_mushroom")
TEX_MINI_MUSHROOM = get_texture_info("powerup_mini_mushroom")

local ALL_TEAM_POWER_UPS = {
    "blooper",
    "bullet_bill",
    "launch_star",
}

local HIDER_ONLY_POWER_UPS = {
    "boo",
    "mini_mushroom",
}

local SEEKER_ONLY_POWER_UPS = {
    "freezie",
    "mega_mushroom",
}

local rouletteActive = false
local rouletteCurrentPowerUp = nil
local rouletteFrames = 0
local rouletteDuration = 0
local rouletteSwapCooldown = 0

local BLOOPER_INK_DURATION = 6 * 30
local blooperInkTimer = 0

local BOO_DURATION = 15 * 30
local booVisualApplied = {}

local FREEZIE_DURATION = 2 * 30
local FREEZIE_MAX_RANGE = 5000

local BULLET_BILL_HOMING_DURATION = 20 * 30
local BULLET_BILL_HOMING_RANGE = 8000
local BULLET_BILL_SPEED = 40
local BULLET_BILL_TURN_SPEED = 1024
local BULLET_BILL_DAMAGE = 0x100
local BULLET_BILL_HIT_RADIUS = 60

local MEGA_MUSHROOM_DURATION = 12 * 30
local MEGA_MUSHROOM_SCALE = 3.0
local MEGA_MUSHROOM_SPEED_CAP = 70
local MEGA_MUSHROOM_JUMP_VEL_CAP = 95
local MEGA_MUSHROOM_GROW_CHECK_WINDOW = 45
local megaMushroomGrowCheck = {}
local megaMushroomLastVelY = {}

local MINI_MUSHROOM_SCALE = 0.5
local MINI_MUSHROOM_TERMINAL_VELOCITY = -20
local miniMushroomLastHealth = {}

local LAUNCH_STAR_VELOCITY = 120
local launchStarNoFallDamage = false


-- Utility functions

local function normalize_angle_s16(angle)
    angle = angle % 0x10000
    if angle >= 0x8000 then
        angle = angle - 0x10000
    end
    return angle
end

local function approach_angle_s16(current, target, maxStep)
    local delta = normalize_angle_s16(target - current)
    if delta > maxStep then
        delta = maxStep
    elseif delta < -maxStep then
        delta = -maxStep
    end
    return normalize_angle_s16(current + delta)
end

local function get_nearest_opposing_player()
    if gGlobalSyncTable.gameState ~= 3 then
        return nil
    end

    local localPlayer = gNetworkPlayers[0]
    local localMario = gMarioStates[0]
    local localSync = gPlayerSyncTable[0]
    if not localPlayer or not localMario or not localSync then
        return nil
    end

    local localIsSeeker = localSync.seeker and true or false
    local nearestPlayer = nil
    local nearestDistSq = nil

    for i = 0, MAX_PLAYERS - 1 do
        if
            i ~= 0 and
            gNetworkPlayers[i].connected and
            gNetworkPlayers[i].currAreaSyncValid and
            gPlayerSyncTable[i] ~= nil and
            gPlayerSyncTable[i].seeker ~= localIsSeeker and
            gNetworkPlayers[i].currLevelNum == localPlayer.currLevelNum and
            gNetworkPlayers[i].currAreaIndex == localPlayer.currAreaIndex and
            gMarioStates[i] and
            gMarioStates[i].marioObj
        then
            local dx = gMarioStates[i].pos.x - localMario.pos.x
            local dy = gMarioStates[i].pos.y - localMario.pos.y
            local dz = gMarioStates[i].pos.z - localMario.pos.z
            local distSq = dx * dx + dy * dy + dz * dz

            if nearestDistSq == nil or distSq < nearestDistSq then
                nearestDistSq = distSq
                nearestPlayer = gMarioStates[i]
            end
        end
    end

    return nearestPlayer
end

local function ensure_power_up_toggle_table()
    if gGlobalSyncTable.powerUpsEnabled == nil then
        gGlobalSyncTable.powerUpsEnabled = {}
    end

    local defaults = {
        blooper = true,
        bullet_bill = true,
        launch_star = true,
        boo = true,
        mini_mushroom = true,
        freezie = true,
        mega_mushroom = true,
    }

    for key, value in pairs(defaults) do
        if gGlobalSyncTable.powerUpsEnabled[key] == nil then
            gGlobalSyncTable.powerUpsEnabled[key] = value
        end
    end
end

local function is_power_up_enabled(powerUp)
    ensure_power_up_toggle_table()
    return gGlobalSyncTable.powerUpsEnabled[powerUp] ~= false
end

local function get_available_power_ups_for_local_player()
    local pool = {}

    for _, value in ipairs(ALL_TEAM_POWER_UPS) do
        if is_power_up_enabled(value) then
            table.insert(pool, value)
        end
    end

    if gPlayerSyncTable[0].seeker then
        for _, value in ipairs(SEEKER_ONLY_POWER_UPS) do
            if is_power_up_enabled(value) then
                table.insert(pool, value)
            end
        end
    else
        for _, value in ipairs(HIDER_ONLY_POWER_UPS) do
            if is_power_up_enabled(value) then
                table.insert(pool, value)
            end
        end
    end

    return pool
end

local function get_random_power_up(previousPowerUp)
    local pool = get_available_power_ups_for_local_player()
    if #pool == 0 then
        return nil
    end

    local selectedPowerUp = pool[math.random(#pool)]
    if #pool > 1 and previousPowerUp ~= nil then
        local tries = 0
        while selectedPowerUp == previousPowerUp and tries < 8 do
            selectedPowerUp = pool[math.random(#pool)]
            tries = tries + 1
        end
    end

    return selectedPowerUp
end

local function start_power_up_roulette()
    local initialPowerUp = get_random_power_up(nil)
    if initialPowerUp == nil then
        return
    end

    rouletteActive = true
    rouletteFrames = 0
    rouletteDuration = 180
    rouletteSwapCooldown = 0
    rouletteCurrentPowerUp = initialPowerUp
end

local function stop_power_up_roulette(clearPowerUp)
    rouletteActive = false
    rouletteFrames = 0
    rouletteDuration = 0
    rouletteSwapCooldown = 0
    rouletteCurrentPowerUp = nil
    if clearPowerUp then
        gPlayerSyncTable[0].powerUp = nil
    else
        play_sound(SOUND_GENERAL_PAINTING_EJECT, gGlobalSoundSource)
    end
end

local function update_power_up_roulette()
    if not rouletteActive then
        return
    end

    rouletteFrames = rouletteFrames + 1
    local progress = rouletteFrames / rouletteDuration
    if progress > 1 then
        progress = 1
    end

    local swapInterval = 1 + math.floor((progress * progress) * 10)
    if rouletteSwapCooldown <= 0 then
        rouletteCurrentPowerUp = get_random_power_up(rouletteCurrentPowerUp)
        rouletteSwapCooldown = swapInterval
    else
        rouletteSwapCooldown = rouletteSwapCooldown - 1
    end

    if rouletteFrames >= rouletteDuration then
        if rouletteCurrentPowerUp ~= nil and is_power_up_enabled(rouletteCurrentPowerUp) then
            gPlayerSyncTable[0].powerUp = rouletteCurrentPowerUp
        else
            gPlayerSyncTable[0].powerUp = nil
        end
        stop_power_up_roulette(false)
    end
end

local function on_power_up_update()
    local m = gMarioStates[0]

    if gGlobalSyncTable.gameState ~= 3 then
        stop_power_up_roulette(true)
        blooperInkTimer = 0
        gPlayerSyncTable[0].booTimer = 0
        gPlayerSyncTable[0].megaMushTimer = 0
        gPlayerSyncTable[0].miniMushroomActive = false
        megaMushroomGrowCheck[0] = nil
        megaMushroomLastVelY[0] = nil
        miniMushroomLastHealth[0] = nil
        launchStarNoFallDamage = false
        return
    end

    update_power_up_roulette()

    if blooperInkTimer > 0 then
        blooperInkTimer = blooperInkTimer - 1
    end

    if gPlayerSyncTable[0].booTimer ~= nil and gPlayerSyncTable[0].booTimer > 0 then
        gPlayerSyncTable[0].booTimer = gPlayerSyncTable[0].booTimer - 1
    end

    if gPlayerSyncTable[0].megaMushTimer ~= nil and gPlayerSyncTable[0].megaMushTimer > 0 then
        gPlayerSyncTable[0].megaMushTimer = gPlayerSyncTable[0].megaMushTimer - 1
    end

    if m and launchStarNoFallDamage then
        if m.pos.y > m.floorHeight + 10 or m.vel.y > 0 then
            m.peakHeight = m.pos.y
        else
            launchStarNoFallDamage = false
        end
    end

    if not m or not m.controller then
        return
    end

    if gPlayerSyncTable[0].powerUp ~= nil and not is_power_up_enabled(gPlayerSyncTable[0].powerUp) then
        gPlayerSyncTable[0].powerUp = nil
    end

    local pressed = m.controller.buttonPressed
    if (pressed & Y_BUTTON) ~= 0 then
        if gPlayerSyncTable[0].powerUp ~= nil then
            activate_power_up(gPlayerSyncTable[0].powerUp)
            gPlayerSyncTable[0].powerUp = nil
        end
    end
end

-- Called when a player collects a cap or star.
-- Used to start the power up roulette.
function on_item_collected()
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    if rouletteActive then
        return
    end

    if gPlayerSyncTable[0].powerUp ~= nil then
        return
    end

    local numPowerUps = #get_available_power_ups_for_local_player()
    if numPowerUps == 0 then
        return
    end

    start_power_up_roulette()

    -- if there's only 1 power-up available, skip the roulette and just give it to the player immediately
    if numPowerUps == 1 then
        update_power_up_roulette()
        stop_power_up_roulette(false)
    end
end

function get_power_up_texture(powerUp)
    if powerUp == "blooper" then
        return TEX_BLOOPER
    elseif powerUp == "bullet_bill" then
        return TEX_BULLET_BILL
    elseif powerUp == "freezie" then
        return TEX_FREEZIE
    elseif powerUp == "boo" then
        return TEX_BOO
    elseif powerUp == "launch_star" then
        return TEX_LAUNCH_STAR
    elseif powerUp == "mega_mushroom" then
        return TEX_MEGA_MUSHROOM
    elseif powerUp == "mini_mushroom" then
        return TEX_MINI_MUSHROOM
    else
        return nil
    end
end

function render_item_box()
    local gap = 10
    local size = 128
    local x = djui_hud_get_screen_width() - gap - size
    local y = djui_hud_get_screen_height() - gap - size

    djui_hud_set_color(0, 0, 0, 192)
    djui_hud_render_rect(x, y, size, size)
    djui_hud_set_color(255, 255, 255, 255)
    
    local powerUp = rouletteCurrentPowerUp
    if powerUp == nil then
        powerUp = gPlayerSyncTable[0].powerUp
    end
    
    if powerUp ~= nil then
        local texture = get_power_up_texture(powerUp)
        if texture ~= nil then
            djui_hud_render_texture(texture, x, y, 0.5, 0.5)
        end
    end
end

-- All team power-ups

function activate_power_up(powerUp)
    if not is_power_up_enabled(powerUp) then
        return
    end

    if powerUp == "blooper" then
        activate_blooper()
    elseif powerUp == "bullet_bill" then
        activate_bullet_bill()
    elseif powerUp == "freezie" then
        activate_freezie()
    elseif powerUp == "boo" then
        activate_boo()
    elseif powerUp == "launch_star" then
        activate_launch_star()
    elseif powerUp == "mega_mushroom" then
        activate_mega_mushroom()
    elseif powerUp == "mini_mushroom" then
        activate_mini_mushroom()
    end
end

-- Blooper
-- Puts ink on the screen of all players in the opposite team which goes away after 6 seconds.

local function apply_blooper_to_local_player(senderSeeker)
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    if gPlayerSyncTable[0].seeker == senderSeeker then
        return
    end

    blooperInkTimer = BLOOPER_INK_DURATION
end

local function render_blooper_overlay()
    if blooperInkTimer <= 0 then
        return
    end

    local sw = djui_hud_get_screen_width()
    local sh = djui_hud_get_screen_height()

    local alpha = 170
    if blooperInkTimer < 30 then
        alpha = math.floor((blooperInkTimer / 30) * 170)
    end

    djui_hud_set_color(0, 0, 0, alpha)
    djui_hud_render_rect(0, 0, sw, math.floor(sh * 0.22))
    djui_hud_render_rect(0, math.floor(sh * 0.78), sw, math.floor(sh * 0.22))
    djui_hud_render_rect(0, 0, math.floor(sw * 0.18), sh)
    djui_hud_render_rect(math.floor(sw * 0.82), 0, math.floor(sw * 0.18), sh)
    djui_hud_render_rect(math.floor(sw * 0.35), math.floor(sh * 0.3), math.floor(sw * 0.3), math.floor(sh * 0.4))
end

local function on_power_up_packet(data)
    if data.packet == "BLOOPER" then
        apply_blooper_to_local_player(data.senderSeeker)
    end
end

function activate_blooper()
    local senderSeeker = gPlayerSyncTable[0].seeker and true or false
    local data = {
        packet = "BLOOPER",
        senderSeeker = senderSeeker,
    }

    network_send(true, data)
    on_power_up_packet(data)
end

-- Bullet bill
-- Fires a homing bullet bill at the nearest player in the opposite team.
-- The bullet bill won't target anyone who has the "Boo" power-up active or if no player is close by.
-- the homing effect lasts for 10 seconds, after which the bullet bill will continue in a straight line.

local function explode_bullet_bill(o)
    spawn_non_sync_object(id_bhvExplosion, E_MODEL_EXPLOSION, o.oPosX, o.oPosY, o.oPosZ, function () end)
    spawn_mist_particles()
    obj_mark_for_deletion(o)
end

local function bullet_bill_try_hit_local_player(o)
    local m = gMarioStates[0]
    if not m then
        return false
    end

    if not gNetworkPlayers[0].currAreaSyncValid then
        return false
    end

    if boo_is_active_for_player(0) then
        return false
    end

    local dx = m.pos.x - o.oPosX
    local dy = (m.pos.y + 80) - o.oPosY
    local dz = m.pos.z - o.oPosZ
    local distance = math.sqrt(dx^2 + dy^2 + dz^2)
    if distance > BULLET_BILL_HIT_RADIUS then
        return false
    end

    m.health = math.max(0xFF, m.health - BULLET_BILL_DAMAGE)
    return true
end

function bhv_bullet_bill_powerup_init(o)
    o.oGravity = 0
    o.oFriction = 0
    o.oBuoyancy = 0
    o.oDragStrength = 0
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.oTimer = 0
    o.oAction = 0           -- 0 = searching for target, 1 = homing in, 2 = flying straight
    o.oSubAction = 0        -- target player index when homing

    -- set to .25 of normal scale
    o.header.gfx.scale.x = 0.25
    o.header.gfx.scale.y = 0.25
    o.header.gfx.scale.z = 0.25

    -- point straight upward
    o.oMoveAnglePitch = degrees_to_sm64(-90)
    o.oMoveAngleYaw = 0
    o.oMoveAngleRoll = degrees_to_sm64(-90)

    o.oFaceAnglePitch = o.oMoveAnglePitch
    o.oFaceAngleYaw = o.oMoveAngleYaw
    o.oFaceAngleRoll = o.oMoveAngleRoll

    -- Set the hitbox
    o.hitboxRadius = 50
    o.hitboxHeight = 50

    obj_set_model_extended(o, E_MODEL_BULLET_BILL)

    network_init_object(o, true, nil)
end

function bhv_bullet_bill_powerup_loop(o)
    if bullet_bill_try_hit_local_player(o) then
        explode_bullet_bill(o)
        return
    end

    if o.oTimer >= BULLET_BILL_HOMING_DURATION then
        o.oAction = 2
    end

    if o.oAction == 0 then
        local target = get_nearest_opposing_player()
        if target and not boo_is_active_for_player(target.playerIndex) then
            local dx = target.pos.x - o.oPosX
            local dy = target.pos.y - o.oPosY
            local dz = target.pos.z - o.oPosZ
            local distance = math.sqrt(dx^2 + dy^2 + dz^2)
            if distance < BULLET_BILL_HOMING_RANGE then
                o.oAction = 1
                o.oSubAction = target.playerIndex
            end
        end
    elseif o.oAction == 1 then
        local targetPlayerIndex = o.oSubAction
        local target = gMarioStates[targetPlayerIndex]
        if target then
            local angle = obj_angle_to_object(o, target.marioObj)
            local pitch = obj_pitch_to_object(o, target.marioObj)
            o.oMoveAngleYaw = approach_angle_s16(o.oMoveAngleYaw, angle, BULLET_BILL_TURN_SPEED)
            o.oMoveAnglePitch = approach_angle_s16(o.oMoveAnglePitch, pitch, BULLET_BILL_TURN_SPEED)

            -- if the target gets out of range or gets the boo power-up, stop homing
            local dx = target.pos.x - o.oPosX
            local dy = target.pos.y - o.oPosY
            local dz = target.pos.z - o.oPosZ
            local distance = math.sqrt(dx^2 + dy^2 + dz^2)
            if distance > BULLET_BILL_HOMING_RANGE or boo_is_active_for_player(targetPlayerIndex) then
                o.oAction = 2
            end
        else
            o.oAction = 2
        end
    end

    o.oFaceAnglePitch = o.oMoveAnglePitch
    o.oFaceAngleYaw = o.oMoveAngleYaw
    o.oFaceAngleRoll = o.oMoveAngleRoll

    -- turn facing angles into xyz velocity
    local velX = BULLET_BILL_SPEED * coss(o.oMoveAnglePitch) * sins(o.oMoveAngleYaw)
    local velY = -BULLET_BILL_SPEED * sins(o.oMoveAnglePitch)
    local velZ = BULLET_BILL_SPEED * coss(o.oMoveAnglePitch) * coss(o.oMoveAngleYaw)
    o.oVelX = velX
    o.oVelY = velY
    o.oVelZ = velZ

    cur_obj_move_using_vel()

    if bullet_bill_try_hit_local_player(o) then
        explode_bullet_bill(o)
        return
    end
end


id_bhvBulletBillPowerup = hook_behavior(nil, OBJ_LIST_GENACTOR, true, bhv_bullet_bill_powerup_init, bhv_bullet_bill_powerup_loop)

function activate_bullet_bill()
    local m = gMarioStates[0]
    if not m then
        return
    end

    local spawnY = m.pos.y + 200 * m.marioObj.header.gfx.scale.y
    spawn_sync_object(id_bhvBulletBillPowerup, E_MODEL_BULLET_BILL, m.pos.x, spawnY, m.pos.z, nil)
end

-- Launch Star
-- Launches the user high into the air.
function activate_launch_star()
    local m = gMarioStates[0]
    if not m then
        return
    end

    set_mario_action(m, ACT_TRIPLE_JUMP, 0)
    m.vel.y = LAUNCH_STAR_VELOCITY
    launchStarNoFallDamage = true
end

-- Seeker only power-ups

-- freezie
-- Freezes the nearest seeker for 2 seconds.

function freezie_mario_update(m)
    if not m then
        return
    end

    local playerIndex = m.playerIndex
    local playerSync = gPlayerSyncTable[playerIndex]
    local isFreezieActive = playerSync ~= nil and playerSync.freezieTimer ~= nil and playerSync.freezieTimer > 0

    if isFreezieActive then
        gPlayerSyncTable[playerIndex].freezieTimer = gPlayerSyncTable[playerIndex].freezieTimer - 1
        m.vel.x = 0
        m.vel.y = 0
        m.vel.z = 0
        m.forwardVel = 0
    end
end

function activate_freezie()
    -- Find nearset player from opposite team
    local m = gMarioStates[0]
    if not m then
        return
    end

    local target = get_nearest_hider()
    if not target then
        return
    end

    local dx = target.pos.x - m.pos.x
    local dy = target.pos.y - m.pos.y
    local dz = target.pos.z - m.pos.z
    local distance = math.sqrt(dx^2 + dy^2 + dz^2)

    if distance < FREEZIE_MAX_RANGE then
        if target.playerIndex ~= 0 then
            gPlayerSyncTable[target.playerIndex].freezieTimer = FREEZIE_DURATION
        end
    end
end

-- Mega Mushroom
-- Makes the user 3x as big for 10 seconds with scaled speed and jump height.
-- Includes a check to put it back in the item box if the player gets stuck while growing.

local function set_mega_mushroom_visual_state(m, active)
    if not m or not m.marioBodyState then
        return
    end

    if active then
        m.marioObj.header.gfx.scale.x = MEGA_MUSHROOM_SCALE
        m.marioObj.header.gfx.scale.y = MEGA_MUSHROOM_SCALE
        m.marioObj.header.gfx.scale.z = MEGA_MUSHROOM_SCALE
    else
        m.marioObj.header.gfx.scale.x = 1.0
        m.marioObj.header.gfx.scale.y = 1.0
        m.marioObj.header.gfx.scale.z = 1.0
    end
end

local function set_mega_mushroom_gameplay_state(m, active)
    if not m then
        return
    end

    if active then
        m.flags = m.flags | MARIO_METAL_CAP
    else
        if (m.flags & MARIO_METAL_CAP) ~= 0 then
            m.flags = m.flags & ~MARIO_METAL_CAP
            stop_cap_music()
        end
    end
end

local function cancel_mega_mushroom(m, returnToItemBox)
    local playerIndex = m.playerIndex
    gPlayerSyncTable[playerIndex].megaMushTimer = 0
    if playerIndex == 0 then
        set_mega_mushroom_gameplay_state(m, false)
    end
    set_mega_mushroom_visual_state(m, false)
    megaMushroomGrowCheck[playerIndex] = nil

    if returnToItemBox and playerIndex == 0 then
        gPlayerSyncTable[0].powerUp = "mega_mushroom"
    end
end

local function mega_mushroom_mario_update(m)
    if not m then
        return
    end

    local playerIndex = m.playerIndex
    local playerSync = gPlayerSyncTable[playerIndex]
    local isMegaMushActive = playerSync ~= nil and playerSync.megaMushTimer ~= nil and playerSync.megaMushTimer > 0
    local lastVelY = megaMushroomLastVelY[playerIndex]
    if lastVelY == nil then
        lastVelY = m.vel.y
    end

    if isMegaMushActive then
        set_mega_mushroom_visual_state(m, isMegaMushActive)
    end

    if playerIndex == 0 then
        set_mega_mushroom_gameplay_state(m, isMegaMushActive)
    end

    if isMegaMushActive then
        -- Scale movement physics for local player while mega is active.
        if playerIndex == 0 then
            if m.controller ~= nil and m.controller.stickMag ~= nil and m.controller.stickMag > 6 then
                local speedDirection = m.forwardVel < 0 and -1 or 1
                local boostedForwardVel = math.abs(m.forwardVel) + 1.5
                if boostedForwardVel > MEGA_MUSHROOM_SPEED_CAP then
                    boostedForwardVel = MEGA_MUSHROOM_SPEED_CAP
                end
                m.forwardVel = boostedForwardVel * speedDirection
            end

            if m.vel.y > 0 and lastVelY <= 0 then
                local boostedJumpVel = m.vel.y * 1.35
                if boostedJumpVel > MEGA_MUSHROOM_JUMP_VEL_CAP then
                    boostedJumpVel = MEGA_MUSHROOM_JUMP_VEL_CAP
                end
                m.vel.y = boostedJumpVel
            end
        end

        -- Check for "stuck while growing" only during the initial grow window
        -- and only when player is trying to move.
        local growCheck = megaMushroomGrowCheck[playerIndex]
        if growCheck ~= nil then
            growCheck.framesLeft = growCheck.framesLeft - 1
            growCheck.sampleTimer = growCheck.sampleTimer - 1

            if growCheck.sampleTimer <= 0 then
                local tryingToMove = m.controller ~= nil and m.controller.stickMag ~= nil and m.controller.stickMag > 20
                if tryingToMove then
                    local distMoved = math.sqrt(
                        (m.pos.x - growCheck.x) ^ 2 +
                        (m.pos.z - growCheck.z) ^ 2
                    )

                    if distMoved < 2.0 then
                        cancel_mega_mushroom(m, true)
                        return
                    end
                end

                growCheck.x = m.pos.x
                growCheck.z = m.pos.z
                growCheck.sampleTimer = 10
            end

            if growCheck.framesLeft <= 0 then
                megaMushroomGrowCheck[playerIndex] = nil
            end
        end
    else
        megaMushroomGrowCheck[playerIndex] = nil
        megaMushroomLastVelY[playerIndex] = nil
        if playerIndex == 0 then
            set_mega_mushroom_gameplay_state(m, false)
        end
        set_mega_mushroom_visual_state(m, false)
        return
    end

    megaMushroomLastVelY[playerIndex] = m.vel.y
end

function activate_mega_mushroom()
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    gPlayerSyncTable[0].megaMushTimer = MEGA_MUSHROOM_DURATION
    megaMushroomGrowCheck[0] = {
        x = gMarioStates[0].pos.x,
        z = gMarioStates[0].pos.z,
        sampleTimer = 10,
        framesLeft = MEGA_MUSHROOM_GROW_CHECK_WINDOW,
    }
    set_mega_mushroom_gameplay_state(gMarioStates[0], true)
    set_mega_mushroom_visual_state(gMarioStates[0], true)
end

-- Hider only power-ups

-- Mini Mushroom
-- Makes the user 0.5x normal size permanently.
-- Taking damage while mini means instant death.
-- Fall slower and never get fall damage.

local function set_mini_mushroom_visual_state(m, active)
    if not m or not m.marioBodyState then
        return
    end

    if active then
        m.marioObj.header.gfx.scale.x = MINI_MUSHROOM_SCALE
        m.marioObj.header.gfx.scale.y = MINI_MUSHROOM_SCALE
        m.marioObj.header.gfx.scale.z = MINI_MUSHROOM_SCALE
    else
        m.marioObj.header.gfx.scale.x = 1.0
        m.marioObj.header.gfx.scale.y = 1.0
        m.marioObj.header.gfx.scale.z = 1.0
    end
end

local function mini_mushroom_mario_update(m)
    if not m then
        return
    end

    local playerIndex = m.playerIndex
    local playerSync = gPlayerSyncTable[playerIndex]
    local isMiniActive = playerSync ~= nil and playerSync.miniMushroomActive

    -- Mini effect should not persist through death.
    if isMiniActive and m.health <= 0xFF then
        playerSync.miniMushroomActive = false
        isMiniActive = false
    end

    if isMiniActive then
        set_mini_mushroom_visual_state(m, isMiniActive)
    end

    if isMiniActive then
        -- Reduce fall speed
        if m.vel.y < MINI_MUSHROOM_TERMINAL_VELOCITY then
            m.vel.y = MINI_MUSHROOM_TERMINAL_VELOCITY
        end

        -- Prevent fall damage
        m.peakHeight = m.pos.y

        -- Instant death when taking any damage while mini.
        local lastHealth = miniMushroomLastHealth[playerIndex]
        if lastHealth ~= nil and m.health < lastHealth then
            m.health = 0xFF
            playerSync.miniMushroomActive = false
            set_mini_mushroom_visual_state(m, false)
            miniMushroomLastHealth[playerIndex] = nil
            return
        end

        miniMushroomLastHealth[playerIndex] = m.health
    else
        miniMushroomLastHealth[playerIndex] = nil
    end
end

function activate_mini_mushroom()
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    gPlayerSyncTable[0].miniMushroomActive = true
    miniMushroomLastHealth[0] = gMarioStates[0].health
    set_mini_mushroom_visual_state(gMarioStates[0], true)
end

-- Boo
-- Makes the user transparent for 20 seconds.

function boo_is_active_for_player(playerIndex)
    local playerSync = gPlayerSyncTable[playerIndex]
    return playerSync ~= nil and playerSync.booTimer ~= nil and playerSync.booTimer > 0
end

local function set_boo_visual_state(m, active)
    if not m or not m.marioBodyState then
        return
    end

    local playerIndex = m.playerIndex
    if active then
        m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_NOISE_ALPHA
        booVisualApplied[playerIndex] = true
    elseif booVisualApplied[playerIndex] then
        m.marioBodyState.modelState = m.marioBodyState.modelState & ~MODEL_STATE_NOISE_ALPHA
        booVisualApplied[playerIndex] = false
    end
end

local function boo_mario_update(m)
    set_boo_visual_state(m, boo_is_active_for_player(m.playerIndex))
end

function activate_boo()
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    gPlayerSyncTable[0].booTimer = BOO_DURATION
    set_boo_visual_state(gMarioStates[0], true)
end


hook_event(HOOK_UPDATE, on_power_up_update)
hook_event(HOOK_ON_PACKET_RECEIVE, on_power_up_packet)
hook_event(HOOK_ON_HUD_RENDER, render_blooper_overlay)
hook_event(HOOK_MARIO_UPDATE, boo_mario_update)
hook_event(HOOK_MARIO_UPDATE, freezie_mario_update)
hook_event(HOOK_MARIO_UPDATE, mega_mushroom_mario_update)
hook_event(HOOK_MARIO_UPDATE, mini_mushroom_mario_update)

-- Trigger power-up roulette when a star is collected
local function on_star_collect(m, _, intee)
    if m.playerIndex == 0 and intee == INTERACT_STAR_OR_KEY then
        on_item_collected()
    end
end

hook_event(HOOK_ON_INTERACT, on_star_collect)