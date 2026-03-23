TEX_BOO = get_texture_info("powerup_boo")
TEX_BLOOPER = get_texture_info("powerup_blooper")
TEX_BULLET_BILL = get_texture_info("powerup_bullet_bill")
TEX_FREEZIE = get_texture_info("powerup_freezie")
TEX_LAUNCH_STAR = get_texture_info("powerup_launch_star")
TEX_MEGA_MUSHROOM = get_texture_info("powerup_mega_mushroom")
TEX_MINI_MUSHROOM = get_texture_info("powerup_mini_mushroom")

local ALL_TEAM_POWER_UPS = {
    -- "blooper",
    -- "bullet_bill",
    -- "launch_star",
}

local HIDER_ONLY_POWER_UPS = {
    -- "boo",
    "mini_mushroom",
}

local SEEKER_ONLY_POWER_UPS = {
    -- "freezie",
    "mega_mushroom",
}

local rouletteActive = false
local rouletteCurrentPowerUp = nil
local rouletteFrames = 0
local rouletteDuration = 0
local rouletteSwapCooldown = 0

local BLOOPER_INK_DURATION = 6 * 30
local blooperInkTimer = 0

local BOO_DURATION = 10 * 30
local booVisualApplied = {}

local MEGA_MUSHROOM_DURATION = 1000 * 30
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

local function get_available_power_ups_for_local_player()
    local pool = {}

    for _, value in ipairs(ALL_TEAM_POWER_UPS) do
        table.insert(pool, value)
    end

    if gPlayerSyncTable[0].seeker then
        for _, value in ipairs(SEEKER_ONLY_POWER_UPS) do
            table.insert(pool, value)
        end
    else
        for _, value in ipairs(HIDER_ONLY_POWER_UPS) do
            table.insert(pool, value)
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
    rouletteActive = true
    rouletteFrames = 0
    rouletteDuration = 180
    rouletteSwapCooldown = 0
    rouletteCurrentPowerUp = get_random_power_up(nil)
end

local function stop_power_up_roulette(clearPowerUp)
    rouletteActive = false
    rouletteFrames = 0
    rouletteDuration = 0
    rouletteSwapCooldown = 0
    rouletteCurrentPowerUp = nil
    if clearPowerUp then
        gPlayerSyncTable[0].powerUp = nil
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
        gPlayerSyncTable[0].powerUp = rouletteCurrentPowerUp
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

    local pressed = m.controller.buttonPressed
    if (pressed & Y_BUTTON) ~= 0 then
        if gPlayerSyncTable[0].powerUp ~= nil then
            activate_power_up(gPlayerSyncTable[0].powerUp)
            gPlayerSyncTable[0].powerUp = nil
        end
    end
end

-- Called when a player collects a cap.
-- Used to start the power up roulette.
function on_cap_collected()
    if gGlobalSyncTable.gameState ~= 3 then
        return
    end

    if rouletteActive then
        return
    end

    if gPlayerSyncTable[0].powerUp ~= nil then
        return
    end

    start_power_up_roulette()
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
        djui_hud_print_text("Power-Up: " .. powerUp, x, y, 1)
        if texture ~= nil then
            djui_hud_render_texture(texture, x, y, 0.5, 0.5)
        end
    end
end

-- All team power-ups

function activate_power_up(powerUp)
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

function activate_bullet_bill()
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

-- freezie
-- Freezes the nearest seeker for 2 seconds.

function activate_freezie()
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


-- Seeker only power-ups

-- Boo
-- Makes the user transparent for 20 seconds.

local function boo_is_active_for_player(playerIndex)
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
hook_event(HOOK_MARIO_UPDATE, mega_mushroom_mario_update)
hook_event(HOOK_MARIO_UPDATE, mini_mushroom_mario_update)