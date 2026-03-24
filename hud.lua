TEX_COMPASS = get_texture_info("compass_arrow")

splashMessage = "Hide!"
splashR, splashG, splashB = true, false, true
splashTimer = 0

local initMessageTimer = 300
local row = 0
local seekerVision = 128
local locations = {}
local timerMessages = {
    "Next Round in ",
    "Releasing Seekers in ",
    "Time: "
}

settingsMenuOpen = false
local settingsMenuRow = 1
local settingsMenuRows = 11  -- Mode, All Levels, Player List, Hide Timer, Round Timer, Compass Timer, Compass Height, Distance Indicator, Players, Power-Ups, Active Round Timer
local settingsMenuMode = "main"  -- "main", "players", or "powerups"
local connectedPlayers = {}
local selectedPlayerIdx = 1
local compassDirs = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
local compassArrowTex = nil
local triedCompassArrowTex = false
local powerUpMenuEntries = {
    {header = "All"},
    {key = "blooper", label = "Blooper"},
    {key = "bullet_bill", label = "Bullet Bill"},
    {key = "launch_star", label = "Launch Star"},
    {header = "Hiders Only"},
    {key = "boo", label = "Boo"},
    {key = "mini_mushroom", label = "Mini Mushroom"},
    {header = "Seekers Only"},
    {key = "freezie", label = "Freezie"},
    {key = "mega_mushroom", label = "Mega Mushroom"},
}
local powerUpMenuRows = #powerUpMenuEntries

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

local function toggle_mode_from_menu()
    if gGlobalSyncTable.gameState < 2 then
        gGlobalSyncTable.forceLevel = not gGlobalSyncTable.forceLevel
        gGlobalSyncTable.gameState = 1
        gGlobalSyncTable.timer = intermissionTimer

        if gGlobalSyncTable.forceLevel then
            packet_receive({packet = "SPLASH", message = "Single-Level Mode"})
            network_send(true, {packet = "SPLASH", message = "Single-Level Mode"})
        else
            packet_receive({packet = "SPLASH", message = "Full-Game Mode"})
            network_send(true, {packet = "SPLASH", message = "Full-Game Mode"})
        end
    else
        djui_chat_message_create("You can only change modes during intermission.")
    end
end

local function set_hide_timer_from_menu(seconds)
    if set_hide_timer_seconds then
        set_hide_timer_seconds(seconds)
    else
        seconds = math.floor(tonumber(seconds) or 0)
        gGlobalSyncTable.hideTimer = math.min(400, math.max(0, seconds))
    end
end

local function set_round_timer_from_menu(seconds)
    if set_round_timer_seconds then
        set_round_timer_seconds(seconds)
    else
        seconds = math.floor(tonumber(seconds) or 0)
        gGlobalSyncTable.roundTimer = math.min(400, math.max(0, seconds))
    end
end

local function set_compass_timer_from_menu(seconds)
    if set_compass_timer_seconds then
        set_compass_timer_seconds(seconds)
    else
        seconds = math.floor(tonumber(seconds) or 0)
        local maxSeconds = 0
        if get_round_timer_frames then
            maxSeconds = math.floor(get_round_timer_frames() / 30)
        end
        gGlobalSyncTable.compassTimer = math.min(maxSeconds, math.max(0, seconds))
    end
end

local function set_distance_indicator_from_menu(enabled)
    gGlobalSyncTable.showDistanceIndicator = enabled
end

local function get_hide_timer_text()
    if (gGlobalSyncTable.hideTimer or 0) > 0 then
        return tostring(gGlobalSyncTable.hideTimer) .. "s"
    end
    if get_hide_timer_frames then
        return "Default (" .. tostring(math.floor(get_hide_timer_frames() / 30)) .. "s)"
    end
    return "Default"
end

local function get_round_timer_text()
    if (gGlobalSyncTable.roundTimer or 0) > 0 then
        return tostring(gGlobalSyncTable.roundTimer) .. "s"
    end
    if get_round_timer_frames then
        return "Default (" .. tostring(math.floor(get_round_timer_frames() / 30)) .. "s)"
    end
    return "Default"
end

local function get_compass_timer_text()
    local value = gGlobalSyncTable.compassTimer or 0
    if value <= 0 then
        return "Off"
    end

    local maxSeconds = 0
    if get_round_timer_limit_seconds then
        maxSeconds = get_round_timer_limit_seconds()
    elseif get_round_timer_frames then
        maxSeconds = math.floor(get_round_timer_frames() / 30)
    end

    return tostring(math.min(value, maxSeconds)) .. "s"
end

local function get_compass_height_text()
    if gGlobalSyncTable.compassHeightIndicator then
        return "ON"
    end
    return "OFF"
end

local function normalize_s16_angle(angle)
    angle = angle % 0x10000
    if angle > 0x7FFF then
        angle = angle - 0x10000
    end
    return angle
end

function is_same_stage(a, b)
    return a.currLevelNum == b.currLevelNum and a.currAreaIndex == b.currAreaIndex
end

function get_nearest_same_stage_hider_index(localIndex)
    local localPlayer = gNetworkPlayers[localIndex]
    local localMario = gMarioStates[localIndex]
    if not localPlayer or not localMario then
        return nil
    end

    local nearestIndex = nil
    local nearestDistSq = nil

    for i = 0, MAX_PLAYERS - 1 do
        if
            i ~= localIndex and
            gNetworkPlayers[i].connected and
            gNetworkPlayers[i].currAreaSyncValid and
            not gPlayerSyncTable[i].seeker and
            is_same_stage(gNetworkPlayers[i], localPlayer) and
            gMarioStates[i] and
            gMarioStates[i].marioObj
        then
            local dx = gMarioStates[i].pos.x - localMario.pos.x
            local dz = gMarioStates[i].pos.z - localMario.pos.z
            local distSq = dx * dx + dz * dz
            if nearestDistSq == nil or distSq < nearestDistSq then
                nearestDistSq = distSq
                nearestIndex = i
            end
        end
    end

    return nearestIndex
end

function get_nearest_hider()
    if gGlobalSyncTable.gameState ~= 3 then
        return false
    end

    if not gPlayerSyncTable[0].seeker then
        return false
    end

    local targetIndex = get_nearest_same_stage_hider_index(0)
    if not targetIndex then
        return false
    end

    local target = gMarioStates[targetIndex]
    if not target then
        return false
    end

    return target
end


local function render_distance_indicator()
    if not gGlobalSyncTable.showDistanceIndicator then
        return
    end

    local me = gMarioStates[0]
    local target = get_nearest_hider()
    if not me or not target then
        return
    end

    local dx = target.pos.x - me.pos.x
    local dy = target.pos.y - me.pos.y
    local dz = target.pos.z - me.pos.z
    local distance = math.round(math.sqrt(dx * dx + dy * dy + dz * dz) / 150) -- devide by 150 to convert from SM64 units to approximate meters, then round to nearest whole number
    local distanceText = tostring(distance) .. "m"
    fancy_text(distanceText, "middle", 0, djui_hud_get_screen_height() - 80, 2, 255, 255, 255, 255, true, false, false, false)
end

local function render_compass()
    local compassTimer = gGlobalSyncTable.compassTimer or 0
    if compassTimer <= 0 or gGlobalSyncTable.timer > (compassTimer * 30) then
        return
    end

    local me = gMarioStates[0]
    local target = get_nearest_hider()
    if not me or not target then
        return
    end

    local dx = target.pos.x - me.pos.x
    local dz = target.pos.z - me.pos.z
    local targetYaw = atan2s(dz, dx)
    local relativeYaw = normalize_s16_angle(targetYaw - me.area.camera.yaw)
    local dirIndex = math.floor((((relativeYaw + 0x1000) % 0x10000) / 0x2000)) + 1
    local dirText = compassDirs[dirIndex] or "N"

    local y = djui_hud_get_screen_height() - 80
    local x = 16

    djui_hud_set_color(255, 255, 255, 255)

    if TEX_COMPASS then
        local arrowX = x + 12
        local arrowY = y - 2
        local pivotX = arrowX + 32
        local pivotY = arrowY + 32
        djui_hud_set_rotation(relativeYaw, 0.5, 0.5)
        djui_hud_render_texture(TEX_COMPASS, arrowX, arrowY, 1, 1)
        djui_hud_set_rotation(0, 0, 0)
    else
        djui_hud_set_color(0, 0, 0, 176)
        djui_hud_render_rect(8, y - 8, 220, 40)
        djui_hud_print_text("Compass: " .. dirText, x, y, 1)
    end

    if gGlobalSyncTable.compassHeightIndicator then
        local dy = target.pos.y - me.pos.y
        local heightText = ""
        if dy > 150 then
            heightText = "above"
        elseif dy < -150 then
            heightText = "below"
        end

        if heightText ~= "" then
            djui_hud_print_text(heightText, x + 122, y, 1)
        end
    end
end

local function get_active_round_timer_text()
    if gGlobalSyncTable.gameState == 3 then
        return tostring(math.floor(gGlobalSyncTable.timer / 30)) .. "s remaining"
    end
    return "(Round not active)"
end

local function get_role_text(role)
    if role == "seeker" then
        return "Seeker"
    elseif role == "hider" then
        return "Hider"
    end
    return "Random"
end

local function on_settings_menu_update()
    if not network_is_server() then
        return
    end

    local m = gMarioStates[0]
    if not m or not m.controller then
        return
    end

    local pressed = m.controller.buttonPressed
    local held = m.controller.buttonDown

    -- Hotkey: L + D-pad up to toggle menu
    if (held & L_TRIG) ~= 0 and (pressed & U_JPAD) ~= 0 then
        settingsMenuOpen = not settingsMenuOpen
        settingsMenuMode = "main"
        settingsMenuRow = 1
        return
    end

    if not settingsMenuOpen then
        return
    end

    if settingsMenuMode == "main" then
        if (pressed & B_BUTTON) ~= 0 then
            settingsMenuOpen = false
            return
        end

        if (pressed & U_JPAD) ~= 0 then
            settingsMenuRow = settingsMenuRow - 1
            if settingsMenuRow < 1 then
                settingsMenuRow = settingsMenuRows
            end
        elseif (pressed & D_JPAD) ~= 0 then
            settingsMenuRow = settingsMenuRow + 1
            if settingsMenuRow > settingsMenuRows then
                settingsMenuRow = 1
            end
        end

        local left = (pressed & L_JPAD) ~= 0
        local right = (pressed & R_JPAD) ~= 0
        local select = (pressed & A_BUTTON) ~= 0

        if settingsMenuRow == 1 and (left or right or select) then
            toggle_mode_from_menu()
        elseif settingsMenuRow == 2 and (left or right or select) then
            gGlobalSyncTable.allLevels = not gGlobalSyncTable.allLevels
        elseif settingsMenuRow == 3 and (left or right or select) then
            gGlobalSyncTable.playerList = not gGlobalSyncTable.playerList
        elseif settingsMenuRow == 4 then
            local value = gGlobalSyncTable.hideTimer or 0
            if left then
                set_hide_timer_from_menu(value - 5)
            elseif right then
                set_hide_timer_from_menu(value + 5)
            elseif select then
                set_hide_timer_from_menu(0)
            end
        elseif settingsMenuRow == 5 then
            local value = gGlobalSyncTable.roundTimer or 0
            if left then
                set_round_timer_from_menu(value - 10)
            elseif right then
                set_round_timer_from_menu(value + 10)
            elseif select then
                set_round_timer_from_menu(0)
            end
        elseif settingsMenuRow == 6 then
            local value = gGlobalSyncTable.compassTimer or 0
            if left then
                set_compass_timer_from_menu(value - 10)
            elseif right then
                set_compass_timer_from_menu(value + 10)
            elseif select then
                set_compass_timer_from_menu(0)
            end
        elseif settingsMenuRow == 7 and (left or right or select) then
            set_compass_height_indicator(not gGlobalSyncTable.compassHeightIndicator)
        elseif settingsMenuRow == 8 then
            if left then
                set_distance_indicator_from_menu(false)
            elseif right then
                set_distance_indicator_from_menu(true)
            elseif select then
                set_distance_indicator_from_menu(not gGlobalSyncTable.showDistanceIndicator)
            end
        elseif settingsMenuRow == 9 and select then
            settingsMenuMode = "players"
            selectedPlayerIdx = 1
        elseif settingsMenuRow == 10 and select then
            settingsMenuMode = "powerups"
            settingsMenuRow = 1
        elseif settingsMenuRow == 11 and gGlobalSyncTable.gameState == 3 then
            if left then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer - 30
                if gGlobalSyncTable.timer < 0 then
                    gGlobalSyncTable.timer = 0
                end
            elseif right then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer + 30
            end
        end

    elseif settingsMenuMode == "players" then
        if (pressed & B_BUTTON) ~= 0 then
            settingsMenuMode = "main"
            return
        end

        if (pressed & U_JPAD) ~= 0 then
            selectedPlayerIdx = selectedPlayerIdx - 1
            if selectedPlayerIdx < 1 then
                selectedPlayerIdx = #connectedPlayers
            end
        elseif (pressed & D_JPAD) ~= 0 then
            selectedPlayerIdx = selectedPlayerIdx + 1
            if selectedPlayerIdx > #connectedPlayers then
                selectedPlayerIdx = 1
            end
        end

        local left = (pressed & L_JPAD) ~= 0
        local right = (pressed & R_JPAD) ~= 0

        if #connectedPlayers > 0 and selectedPlayerIdx >= 1 and selectedPlayerIdx <= #connectedPlayers then
            local playerIdx = connectedPlayers[selectedPlayerIdx]
            local currentRole = gPlayerSyncTable[playerIdx].role or "random"
            local newRole = currentRole
            
            if left or right then
                if currentRole == "seeker" then
                    newRole = "hider"
                elseif currentRole == "hider" then
                    newRole = "random"
                else
                    newRole = "seeker"
                end
                gPlayerSyncTable[playerIdx].role = newRole
            end
        end
    elseif settingsMenuMode == "powerups" then
        if (pressed & B_BUTTON) ~= 0 then
            settingsMenuMode = "main"
            settingsMenuRow = 10
            return
        end

        if (pressed & U_JPAD) ~= 0 then
            settingsMenuRow = settingsMenuRow - 1
            if settingsMenuRow < 1 then
                settingsMenuRow = powerUpMenuRows
            end
        elseif (pressed & D_JPAD) ~= 0 then
            settingsMenuRow = settingsMenuRow + 1
            if settingsMenuRow > powerUpMenuRows then
                settingsMenuRow = 1
            end
        end

        local left = (pressed & L_JPAD) ~= 0
        local right = (pressed & R_JPAD) ~= 0
        local select = (pressed & A_BUTTON) ~= 0
        local entry = powerUpMenuEntries[settingsMenuRow]

        if entry and entry.key and (left or right or select) then
            ensure_power_up_toggle_table()
            gGlobalSyncTable.powerUpsEnabled[entry.key] = not is_power_up_enabled(entry.key)
        end
    end
end

local function on_hud_render()

    --HIDE NORMAL HUD
    hud_hide()

    --RENDER HEALTH METER
    djui_hud_set_color(255, 255, 255, 255)
    hud_render_power_meter(gMarioStates[0].health, djui_hud_get_screen_width() - 256, 0, 256, 256)
    
    -- Startup Message
    if initMessageTimer > 0 and network_is_server() then
        djui_hud_set_color(0, 0, 0, 192)
        djui_hud_render_rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height())
        fancy_text("Hide and Seek DX", "middle", 0, djui_hud_get_screen_height()/2-120, 3, 255, 128, 255, 255, false, false, false, false)
        fancy_text("Use /mode, /levels, and /playerlist to customize your game.", "middle", 0, djui_hud_get_screen_height()/2-30, 2, 255, 255, 255, 255, false, false, false, false)        
        fancy_text("You can also use /hideNseek (or press L + D-pad Up) to open the Settings menu.", "middle", 0, djui_hud_get_screen_height()/2 + 30, 1.5, 255, 255, 255, 255, false, false, false, false)
        fancy_text("This message will disappear in " .. math.floor(initMessageTimer / 30) + 1, "middle", 0, djui_hud_get_screen_height()/2 + 90, 1, 255, 255, 255, 255, false, false, false, false)
        initMessageTimer = initMessageTimer - 1
    end

    --STARTING SEEKER
    if gGlobalSyncTable.gameState == 2 and gPlayerSyncTable[0].seeker then
            
        djui_hud_set_color(0, 0, 0, seekerVision)
        djui_hud_render_rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height())
        djui_hud_set_color(255, 255, 255, 255)
        fancy_text("You are a Starting Seeker.", "middle", 0, djui_hud_get_screen_height()/2 - 136, 3, 255, 255, 255, 255)
        fancy_text("Please wait to be released.", "middle", 0, djui_hud_get_screen_height()/2 - 8, 3, 255, 255, 255, 255)
        
        if seekerVision < 255 then
            seekerVision = seekerVision + 1
        end

    else
        seekerVision = 128
    end

    -- Player List
    row = 0
    djui_hud_set_color(0, 0, 0, 192)

    rectWidth = 120
    for i=0, MAX_PLAYERS-1 do
        if gNetworkPlayers[i].connected and djui_hud_measure_text(shorten_name(string_without_hex(gNetworkPlayers[i].name))) > rectWidth then
            rectWidth = djui_hud_measure_text(shorten_name(string_without_hex(gNetworkPlayers[i].name)))
        end
    end
    djui_hud_render_rect(0, 0, rectWidth+16, #players*30 + 150)

    fancy_text("Players: " .. #players, "left", 4, row, 1, 255, 255, 255, 255, false, false, false, false)
    row = row + 60

    fancy_text("Hiders: " .. hiderCount, "left", 4, row, 1, 255, 255, 255, 255, false, false, false, false)
    row = row + 30
    for i=0, MAX_PLAYERS-1 do
        if gNetworkPlayers[i].connected and not gPlayerSyncTable[i].seeker then
            local r, g, b = hex_to_rgb(network_get_player_text_color_string(i))
            fancy_text(shorten_name(string_without_hex(gNetworkPlayers[i].name)), "left", 4, row, 1, r, g, b, 255, false, false, false, false)
            row = row + 30
        end
    end
    row = row + 30

    fancy_text("Seekers: " .. seekerCount, "left", 4, row, 1, 255, 255, 255, 255)
    row = row + 30
    for i=0, MAX_PLAYERS-1 do
        if gNetworkPlayers[i].connected and gPlayerSyncTable[i].seeker then
            local r, g, b = hex_to_rgb(network_get_player_text_color_string(i))
            fancy_text(shorten_name(string_without_hex(gNetworkPlayers[i].name)), "left", 4, row, 1, r, g, b, 255, false, false, false, false)
            row = row + 30
        end
    end
    row = row + 30

    -- Full-Game Course List
    if not gGlobalSyncTable.forceLevel and gPlayerSyncTable[0].seeker then

        locations = {}
        rect2Width = 0
        
        for i=0, MAX_PLAYERS-1 do
            if gNetworkPlayers[i].connected and not gPlayerSyncTable[i].seeker then
                local iLevel = tostring(get_level_name(gNetworkPlayers[i].currCourseNum, gNetworkPlayers[i].currLevelNum, gNetworkPlayers[i].currAreaIndex))
                local dup = false
                for j=0, #locations do
                    if locations[j] == iLevel then
                        dup = true
                    end
                end
                if not dup then
                    table.insert(locations, iLevel)
                    if djui_hud_measure_text(iLevel) > rect2Width then
                        rect2Width = djui_hud_measure_text(iLevel)
                    end
                end
            end
        end

        table.sort(locations)
        local inLocation = ""

        for i=1, #locations do
            if locations[i] == tostring(get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)) then
                inLocation = tostring(get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex))
            end
        end

        if inLocation == "" then
            djui_hud_set_color(64 + 64 * math.sin(gGlobalSyncTable.timer/2), 0, 0, 192)
        else
            djui_hud_set_color(0, 0, 0, 192)
        end
        
        djui_hud_render_rect(rectWidth+16, 0, rect2Width+8, #locations*30)

        for i=1, #locations do
            if locations[i] == inLocation then
                fancy_text(locations[i], "left", rectWidth+20, (i-1)*30, 1, 128, 255, 128, 255, false, false, true, false)
            else
                fancy_text(locations[i], "left", rectWidth+20, (i-1)*30, 1, 255, 255, 255, 255, false, true, false, false)
            end
        end

    end

    -- Mode and Timer
    if gGlobalSyncTable.timer < 900 and gGlobalSyncTable.gameState == 3 then
        fancy_text(timerMessages[gGlobalSyncTable.gameState] .. math.floor(gGlobalSyncTable.timer / 30) + 1, "middle", 0, 30, 2, 255, 255, 255, 255, true, true, false, false)
    elseif gGlobalSyncTable.gameState ~= 0 then
        fancy_text(timerMessages[gGlobalSyncTable.gameState] .. math.floor(gGlobalSyncTable.timer / 30) + 1, "middle", 0, 30, 2, 255, 255, 255, 255, true, false, false, false)
    else
        fancy_text("Waiting for More Players...", "middle", 0, 30, 2, 255, 255, 255, 255, true, false, false, false)
    end

    if gGlobalSyncTable.forceLevel then
        if gGlobalSyncTable.allLevels then
            djui_hud_set_color(0, 0, 0, 128)
            fancy_text("Single-Level Mode (All Levels)", "middle", 0, 0, 1, 255, 255, 0, 255, true, false, false, false)
        else
            djui_hud_set_color(0, 0, 0, 128)
            fancy_text("Single-Level Mode (Standard)", "middle", 0, 0, 1, 255, 255, 0, 255, true, false, false, false)
        end
    else
        djui_hud_set_color(0, 0, 0, 128)
        fancy_text("Full-Game Mode", "middle", 0, 0, 1, 0, 255, 255, 255, true, false, false, false)
    end

    -- Splash Text
    if splashTimer > 0 and not (gPlayerSyncTable[0].seeker and splashMessage == "Hide!") then
        fancy_text(splashMessage, "middle", 0, 188, 4, 255, 255, 255, 255, true, splashR, splashG, splashB)
        splashTimer = splashTimer - 1
    end

    -- Cannon Text
    if gMarioStates[0].action == ACT_IN_CANNON and gMarioStates[0].actionState == 2 then
        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text("Shooting in " .. math.floor((90-cannonTimer) / 30) + 1, center_text("Shooting in " .. math.floor((90-cannonTimer) / 30) + 1, 3), djui_hud_get_screen_height()-120, 3) 
    end

    -- WIP
    -- djui_hud_set_color(0, 0, 0, 192)
    -- fancy_text("Player List is now a host option! Update releases tomorrow!", "right", 0, djui_hud_get_screen_height()-30, 1, 255, 255, 255, 255, true, false, false, false)

    -- Exit
    if not gPlayerSyncTable[0].seeker and not canExit then
        fancy_text("You've used your exit for this round!", "right", 0, djui_hud_get_screen_height()-60, 1, 255, 255, 255, 255, true, true, false, false)
        fancy_text("You cannot exit again. If you die, you become a seeker!", "right", 0, djui_hud_get_screen_height()-30, 1, 255, 255, 255, 255, true, true, false, false)
    end

    -- Build connected players list
    connectedPlayers = {}
    for i=0, MAX_PLAYERS-1 do
        if gNetworkPlayers[i].connected then
            table.insert(connectedPlayers, i)
        end
    end

    -- Host Settings Menu
    if settingsMenuOpen and network_is_server() then
        local sw = djui_hud_get_screen_width()
        local sh = djui_hud_get_screen_height()
        local x = sw / 2 - 350
        local y = sh / 2 - 190
        local menuWidth = 500

        djui_hud_set_color(0, 0, 0, 150)
        djui_hud_render_rect(0, 0, sw, sh)

        djui_hud_set_color(0, 0, 0, 228)
        djui_hud_render_rect(x, y, menuWidth, 480)

        if settingsMenuMode == "main" then
            fancy_text("Host Settings", "left", x + 16, y + 14, 1.5, 255, 255, 255, 255, false, false, false, false)
            fancy_text("D-Pad: Navigate/Edit  A: Select  B: Close", "left", x + 16, y + 52, 1, 200, 200, 200, 255, false, false, false, false)

            local rowY = y + 96
            local line = 44

            local modeText = "Mode: " .. (gGlobalSyncTable.forceLevel and "Single-Level" or "Full-Game")
            local allLevelsText = "All Levels: " .. (gGlobalSyncTable.allLevels and "ON" or "OFF")
            local playerListText = "Player List: " .. (gGlobalSyncTable.playerList and "ON" or "OFF")
            local hideTimerText = "Hide Timer: " .. get_hide_timer_text()
            local roundTimerText = "Round Timer: " .. get_round_timer_text()
            local compassTimerText = "Compass Timer: " .. get_compass_timer_text()
            local compassHeightText = "Compass Height: " .. get_compass_height_text()
            local distanceIndicatorText = "Distance Indicator: " .. (gGlobalSyncTable.showDistanceIndicator and "ON" or "OFF")
            local playersText = "Manage Player Roles"
            local powerUpsText = "Power-Ups"
            local activeRoundText = "Active Round: " .. get_active_round_timer_text()

            fancy_text((settingsMenuRow == 1 and "> " or "  ") .. modeText, "left", x + 20, rowY, 1.2, settingsMenuRow == 1 and 255 or 215, settingsMenuRow == 1 and 255 or 215, settingsMenuRow == 1 and 128 or 215, 255, settingsMenuRow == 1, true, true, false)
            fancy_text((settingsMenuRow == 2 and "> " or "  ") .. allLevelsText, "left", x + 20, rowY + line, 1.2, settingsMenuRow == 2 and 255 or 215, settingsMenuRow == 2 and 255 or 215, settingsMenuRow == 2 and 128 or 215, 255, settingsMenuRow == 2, true, true, false)
            fancy_text((settingsMenuRow == 3 and "> " or "  ") .. playerListText, "left", x + 20, rowY + line * 2, 1.2, settingsMenuRow == 3 and 255 or 215, settingsMenuRow == 3 and 255 or 215, settingsMenuRow == 3 and 128 or 215, 255, settingsMenuRow == 3, true, true, false)
            fancy_text((settingsMenuRow == 4 and "> " or "  ") .. hideTimerText, "left", x + 20, rowY + line * 3, 1.2, settingsMenuRow == 4 and 255 or 215, settingsMenuRow == 4 and 255 or 215, settingsMenuRow == 4 and 128 or 215, 255, settingsMenuRow == 4, true, true, false)
            fancy_text((settingsMenuRow == 5 and "> " or "  ") .. roundTimerText, "left", x + 20, rowY + line * 4, 1.2, settingsMenuRow == 5 and 255 or 215, settingsMenuRow == 5 and 255 or 215, settingsMenuRow == 5 and 128 or 215, 255, settingsMenuRow == 5, true, true, false)
            fancy_text((settingsMenuRow == 6 and "> " or "  ") .. compassTimerText, "left", x + 20, rowY + line * 5, 1.2, settingsMenuRow == 6 and 255 or 215, settingsMenuRow == 6 and 255 or 215, settingsMenuRow == 6 and 128 or 215, 255, settingsMenuRow == 6, true, true, false)
            fancy_text((settingsMenuRow == 7 and "> " or "  ") .. compassHeightText, "left", x + 20, rowY + line * 6, 1.2, settingsMenuRow == 7 and 255 or 215, settingsMenuRow == 7 and 255 or 215, settingsMenuRow == 7 and 128 or 215, 255, settingsMenuRow == 7, true, true, false)
            fancy_text((settingsMenuRow == 8 and "> " or "  ") .. distanceIndicatorText, "left", x + 20, rowY + line * 7, 1.2, settingsMenuRow == 8 and 255 or 215, settingsMenuRow == 8 and 255 or 215, settingsMenuRow == 8 and 128 or 215, 255, settingsMenuRow == 8, true, true, false)
            fancy_text((settingsMenuRow == 9 and "> " or "  ") .. playersText, "left", x + 20, rowY + line * 8, 1.2, settingsMenuRow == 9 and 255 or 215, settingsMenuRow == 9 and 255 or 215, settingsMenuRow == 9 and 128 or 215, 255, settingsMenuRow == 9, true, true, false)
            fancy_text((settingsMenuRow == 10 and "> " or "  ") .. powerUpsText, "left", x + 20, rowY + line * 9, 1.2, settingsMenuRow == 10 and 255 or 215, settingsMenuRow == 10 and 255 or 215, settingsMenuRow == 10 and 128 or 215, 255, settingsMenuRow == 10, true, true, false)
            local activeRoundColor = gGlobalSyncTable.gameState == 3 and 255 or 150
            fancy_text((settingsMenuRow == 11 and "> " or "  ") .. activeRoundText, "left", x + 20, rowY + line * 10, 1.2, settingsMenuRow == 11 and activeRoundColor or 150, settingsMenuRow == 11 and activeRoundColor or 150, settingsMenuRow == 11 and 128 or 100, 255, settingsMenuRow == 11 and gGlobalSyncTable.gameState == 3, true, true, false)

        elseif settingsMenuMode == "players" then
            fancy_text("Manage Player Roles", "left", x + 16, y + 14, 1.5, 255, 255, 255, 255, false, false, false, false)
            fancy_text("D-Pad: Navigate  Left/Right: Change Role  B: Back", "left", x + 16, y + 52, 1, 200, 200, 200, 255, false, false, false, false)

            if #connectedPlayers == 0 then
                fancy_text("No connected players", "left", x + 20, y + 110, 1, 200, 200, 200, 255, false, false, false, false)
            else
                local playerY = y + 96
                for i=1, #connectedPlayers do
                    local playerIdx = connectedPlayers[i]
                    local name = shorten_name(string_without_hex(gNetworkPlayers[playerIdx].name))
                    local role = gPlayerSyncTable[playerIdx].role or "random"
                    local roleText = get_role_text(role)
                    local roleR, roleG, roleB = 255, 255, 255
                    if roleText == "Seeker" then
                        roleR, roleG, roleB = 255, 128, 128
                    elseif roleText == "Hider" then
                        roleR, roleG, roleB = 128, 192, 255
                    else
                        roleR, roleG, roleB = 220, 220, 220
                    end

                    fancy_text((selectedPlayerIdx == i and "> " or "  ") .. name, "left", x + 20, playerY, 1.2, selectedPlayerIdx == i and 220 or 200, selectedPlayerIdx == i and 220 or 200, selectedPlayerIdx == i and 220 or 200, 255, selectedPlayerIdx == i, true, true, false)
                    fancy_text(roleText, "left", x + 380, playerY, 1.2, roleR, roleG, roleB, 255, false, false, false, false)
                    playerY = playerY + 36
                end
            end
        elseif settingsMenuMode == "powerups" then
            fancy_text("Power-Up Toggles", "left", x + 16, y + 14, 1.5, 255, 255, 255, 255, false, false, false, false)
            fancy_text("D-Pad: Navigate  A/Left/Right: Toggle  B: Back", "left", x + 16, y + 52, 1, 200, 200, 200, 255, false, false, false, false)

            ensure_power_up_toggle_table()
            local itemY = y + 96
            local line = 34

            for i = 1, powerUpMenuRows do
                local entry = powerUpMenuEntries[i]
                local selected = (settingsMenuRow == i)

                if entry.header then
                    fancy_text(entry.header, "left", x + 20, itemY, 1.1, 180, 180, 180, 255, false, false, false, false)
                else
                    local enabled = is_power_up_enabled(entry.key)
                    local statusText = enabled and "ON" or "OFF"
                    local statusR = enabled and 128 or 255
                    local statusG = enabled and 255 or 128
                    local statusB = enabled and 128 or 128

                    fancy_text((selected and "> " or "  ") .. entry.label, "left", x + 20, itemY, 1.1, selected and 220 or 200, selected and 220 or 200, selected and 220 or 200, 255, selected, true, true, false)
                    fancy_text(statusText, "left", x + 380, itemY, 1.1, statusR, statusG, statusB, 255, false, false, false, false)
                end

                itemY = itemY + line
            end
        end
    end

    render_compass()
    render_distance_indicator()
    render_item_box()
end

function fancy_text(message, margin, xpos, ypos, size, r, g, b, a, rect, rectR, rectG, rectB)
    
    if margin == "middle" then
        xpos = center_text(message, size)
    elseif margin == "right" then
        xpos = right_text(message, size)
    end

    if rect then
        djui_hud_set_color(sine_color(rectR), sine_color(rectG), sine_color(rectB), 192)
        djui_hud_render_rect(xpos-4*size, ypos, (djui_hud_measure_text(message)+8)*size, 30*size)
    end

    djui_hud_set_color(0, 0, 0, 255)
    djui_hud_print_text(message, xpos+size*2, ypos+size*2, size)
    djui_hud_set_color(r, g, b, a)
    djui_hud_print_text(message, xpos, ypos, size)
    
end

function center_text(message, size)
    return djui_hud_get_screen_width()/2 - (djui_hud_measure_text(message) * size)/2
end

function right_text(message, size)
    return djui_hud_get_screen_width() - (djui_hud_measure_text(message) * size)
end

function sine_color(colorBool)
    if colorBool then
        return 128 + 127 * math.sin(gGlobalSyncTable.timer/2)
    end
    return 0
end

function shorten_name(name)
    if string.len(name) > 12 then
        return string.sub(name, 0, 12) .. "..."
    end
    return name
end

function string_without_hex(name)
    local s = ''
    local inSlash = false
    for i = 1, #name do
        local c = name:sub(i,i)
        if c == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            s = s .. c
        end
    end
    return s
end

function hex_to_rgb(hex)
	-- remove the # and the \\ from the hex so that we can convert it properly
	hex = hex:gsub('#','')
	hex = hex:gsub('\\','')

    -- sanity check
	if string.len(hex) == 6 then
		return tonumber('0x'..hex:sub(1,2)), tonumber('0x'..hex:sub(3,4)), tonumber('0x'..hex:sub(5,6))
	else
		return 0, 0, 0
	end
end

hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
hook_event(HOOK_UPDATE, on_settings_menu_update)
