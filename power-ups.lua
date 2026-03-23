TEX_BOO = get_texture_info("powerup_boo")
TEX_BLOOPER = get_texture_info("powerup_blooper")
TEX_BULLET_BILL = get_texture_info("powerup_bullet_bill")
TEX_FREEZY = get_texture_info("powerup_freezy")

local ALL_TEAM_POWER_UPS = {
    "blooper",
    "bullet_bill",
}

local HIDER_ONLY_POWER_UPS = {
    "freezy",
}

local SEEKER_ONLY_POWER_UPS = {
    "boo",
}

local rouletteActive = false
local rouletteCurrentPowerUp = nil
local rouletteFrames = 0
local rouletteDuration = 0
local rouletteSwapCooldown = 0
local blooperInkTimer = 0
local BLOOPER_INK_DURATION = 30 * 6

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
    if gGlobalSyncTable.gameState ~= 3 then
        stop_power_up_roulette(true)
        blooperInkTimer = 0
        return
    end

    update_power_up_roulette()

    if blooperInkTimer > 0 then
        blooperInkTimer = blooperInkTimer - 1
    end

    local m = gMarioStates[0]
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
    elseif powerUp == "freezy" then
        return TEX_FREEZY
    elseif powerUp == "boo" then
        return TEX_BOO
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

function activate_power_up(powerUp)
    if powerUp == "blooper" then
        activate_blooper()
    elseif powerUp == "bullet_bill" then
        activate_bullet_bill()
    elseif powerUp == "freezy" then
        activate_freezy()
    elseif powerUp == "boo" then
        activate_boo()
    end
end


-- All team power-ups

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


-- Hider only power-ups

-- Freezy
-- Freezes the nearest seeker for 2 seconds.

function activate_freezy()
end


-- Seeker only power-ups

-- Boo
-- Makes the user transparent for 20 seconds.

function activate_boo()
end


hook_event(HOOK_UPDATE, on_power_up_update)
hook_event(HOOK_ON_PACKET_RECEIVE, on_power_up_packet)
hook_event(HOOK_ON_HUD_RENDER, render_blooper_overlay)