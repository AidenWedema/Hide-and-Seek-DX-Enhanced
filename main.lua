-- name: \\#FF80FF\\Hide & Seek DX v1.1 (Enhanced)
-- incompatible: gamemode
-- description: \\#FF80FF\\Hide and Seek DX\n\n\\#FFFFFF\\A full rewrite of the Hide and Seek mode that improves stability, design, and game flow.\n\nFEATURES:\n- Revamped HUD\n- Single-Level Mode\n- Full-Game Mode\n- ROM Hack Support\n- All Levels Unlocked\n  \\#FF8080\\(Save file will be overwritten!)\n\n\\#FFFFFF\\ENHANCED VERSION ADDITIONS:\n- Assign player roles\n- Powerups\n- Customizable round timers\n- Seeker compass and distance indicator\n\nCREDITS:\n- Written by Dan\n- Super Keeberghrh and djoslin0 (Original Hide and Seek)\n- Sunk (Star Cutscene Fix, Complete Save)\n- Sunk and Blocky (Automatic Doors)\n- EmeraldLockdown (Cannon Toggle)\n- EmilyEmmi (HMC Elevator Fix, DDD Submarine)\n- birdekek (HUD Name Processing)\n- LittleFox64 (Support)\n- KindAiden (Enhanced Version Development)
-- pausable: false

--GAME SETTINGS
intermissionTimer = 30 * 10
disperseTimer = 30 * 20
disperseTimerFree = 30 * 30
activeTimerFree = 30 * 180

--GLOBALS
gGlobalSyncTable.gameState = 0
gGlobalSyncTable.timer = intermissionTimer
gGlobalSyncTable.forceLevel = true
gGlobalSyncTable.level = 1
gGlobalSyncTable.allLevels = false
gGlobalSyncTable.playerList = false
gGlobalSyncTable.hideTimer = 0 -- seconds, 0 = default behavior
gGlobalSyncTable.roundTimer = 0 -- seconds, 0 = default behavior
gGlobalSyncTable.compassTimer = 0 -- seconds, 0 = off
gGlobalSyncTable.compassHeightIndicator = true
gGlobalSyncTable.showDistanceIndicator = false
gGlobalSyncTable.powerUpsEnabled = {
    blooper = true,
    bullet_bill = true,
    launch_star = true,
    boo = true,
    mini_mushroom = true,
    freezie = true,
    mega_mushroom = true,
}

seekerCount = 0
hiderCount = 0
players = {}

function set_hide_timer_seconds(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then
        seconds = 0
    end
    if seconds > 400 then
        seconds = 400
    end
    gGlobalSyncTable.hideTimer = seconds
end

function set_round_timer_seconds(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then
        seconds = 0
    end
    if seconds > 400 then
        seconds = 400
    end
    gGlobalSyncTable.roundTimer = seconds

    local maxCompass = math.floor(get_round_timer_frames() / 30)
    if (gGlobalSyncTable.compassTimer or 0) > maxCompass then
        gGlobalSyncTable.compassTimer = maxCompass
    end
end

function get_round_timer_limit_seconds()
    return math.floor(get_round_timer_frames() / 30)
end

function set_compass_timer_seconds(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then
        seconds = 0
    end

    local maxSeconds = get_round_timer_limit_seconds()
    if seconds > maxSeconds then
        seconds = maxSeconds
    end

    gGlobalSyncTable.compassTimer = seconds
end

function set_compass_height_indicator(enabled)
    gGlobalSyncTable.compassHeightIndicator = not not enabled
end

function get_hide_timer_frames()
    if (gGlobalSyncTable.hideTimer or 0) > 0 then
        return gGlobalSyncTable.hideTimer * 30
    end
    if gGlobalSyncTable.forceLevel then
        return disperseTimer
    end
    return disperseTimerFree
end

function get_round_timer_frames()
    if (gGlobalSyncTable.roundTimer or 0) > 0 then
        return gGlobalSyncTable.roundTimer * 30
    end
    if gGlobalSyncTable.forceLevel then
        return levels[gGlobalSyncTable.level][5] * 30
    end
    return activeTimerFree
end

local function update()

    seekerCount = 0
    hiderCount = 0
    players = {}

    for i=0,(MAX_PLAYERS-1) do
        if gNetworkPlayers[i].connected then
            if gPlayerSyncTable[i].seeker then
                seekerCount = seekerCount + 1
                network_player_set_description(gNetworkPlayers[i], "Seeker", 255, 128, 128, 255)
            else
                hiderCount = hiderCount + 1
                network_player_set_description(gNetworkPlayers[i], "Hider", 128, 128, 255, 255)
            end
            table.insert(players, gPlayerSyncTable[i])
        end
    end

    -- Reset Exits Out of Active Game
    if gGlobalSyncTable.gameState ~= 3 then
        canExit = true
    end

    -- Infinite Lives
    gMarioStates[0].numLives = 100

    -- Force several camera configs
    camera_config_enable_collisions(true)
    rom_hack_cam_set_collisions(1)
    camera_romhack_set_zoomed_in_dist(900)
    camera_romhack_set_zoomed_out_dist(1400)
    camera_romhack_set_zoomed_in_height(300)
    camera_romhack_set_zoomed_out_height(450)

    -- Toggle Player List Depending on Gamemode
    if gGlobalSyncTable.forceLevel or gGlobalSyncTable.playerList then
        gServerSettings.enablePlayerList = 1
    else
        gServerSettings.enablePlayerList = 0
    end

    -- Countdown Sound
    if gGlobalSyncTable.timer <= 150 and math.fmod(gGlobalSyncTable.timer, 30) == 0 then
        play_sound_with_freq_scale(SOUND_GENERAL_COIN_DROP, gMarioStates[0].marioObj.header.gfx.cameraToObject, 0.25)
    end

    -- TTC Stop Time
    set_ttc_speed_setting(TTC_SPEED_STOPPED)

    -- Force Players in Level
    if gGlobalSyncTable.forceLevel and gNetworkPlayers[0].currLevelNum ~= levels[gGlobalSyncTable.level][1] then
        warp_to_level(levels[gGlobalSyncTable.level][1], levels[gGlobalSyncTable.level][2], levels[gGlobalSyncTable.level][3])
        gMarioStates[0].health = 0x800
    elseif not gGlobalSyncTable.forceLevel and gGlobalSyncTable.gameState == 1 and gGlobalSyncTable.timer < 30 then
        warp_to_start_level()
    end

    -- Skip Level Intro Text Box
    if
        (gMarioStates[0].action == ACT_SPAWN_NO_SPIN_AIRBORNE or
        gMarioStates[0].action == ACT_SPAWN_NO_SPIN_LANDING or 
        gMarioStates[0].action == ACT_SPAWN_SPIN_AIRBORNE or
        gMarioStates[0].action == ACT_SPAWN_SPIN_LANDING) and
        gMarioStates[0].pos.y < gMarioStates[0].floorHeight + 10
    then
        set_mario_action(gMarioStates[0], ACT_FREEFALL, 0)
    end

    if network_is_server() then
        core_update()
    end

end

function core_update()

    if #players < 2 then
        gGlobalSyncTable.gameState = 0
    elseif gGlobalSyncTable.gameState == 0 then
        gGlobalSyncTable.gameState = 1
        gGlobalSyncTable.timer = intermissionTimer
    elseif gGlobalSyncTable.timer > 0 then
        -- Pause timer when settings menu is open (only during intermission)
        if not (settingsMenuOpen and gGlobalSyncTable.gameState == 1) then
            gGlobalSyncTable.timer = gGlobalSyncTable.timer - 1
        end
    end

    --Intermission
    if gGlobalSyncTable.gameState == 1 then

        if gGlobalSyncTable.timer > intermissionTimer then
            gGlobalSyncTable.timer = intermissionTimer
        --Start Disperse Phase
        elseif gGlobalSyncTable.timer < 1 then

            --Determine Seekers based on role
            for i=0,(MAX_PLAYERS-1) do
                if gNetworkPlayers[i].connected then
                    if gPlayerSyncTable[i].role == "seeker" then
                        gPlayerSyncTable[i].seeker = true
                    elseif gPlayerSyncTable[i].role == "hider" then
                        gPlayerSyncTable[i].seeker = false
                    else
                        gPlayerSyncTable[i].seeker = false
                    end
                end
            end

            --Determine Random Seekers
            local seekerCount = 0
            local randomIndices = {}

            for i=0,(MAX_PLAYERS-1) do
                if gNetworkPlayers[i].connected then
                    if gPlayerSyncTable[i].seeker then
                        seekerCount = seekerCount + 1
                    elseif not gPlayerSyncTable[i].role or gPlayerSyncTable[i].role == "random" then
                        table.insert(randomIndices, i)
                    end
                end
            end

            local seekersNeeded = 1
            if #players > 4 then
                seekersNeeded = 2
            end
            if #players > 10 then
                seekersNeeded = 3
            end

            while seekerCount < seekersNeeded and #randomIndices > 0 do
                local randomIdx = math.random(#randomIndices)
                local playerIdx = randomIndices[randomIdx]
                gPlayerSyncTable[playerIdx].seeker = true
                table.remove(randomIndices, randomIdx)
                seekerCount = seekerCount + 1
            end

            --Set Disperse Timer
            gGlobalSyncTable.timer = get_hide_timer_frames()
            
            --Change Level
            if gGlobalSyncTable.forceLevel then
                if gGlobalSyncTable.level >= #levels then
                    gGlobalSyncTable.level = 1
                else
                    gGlobalSyncTable.level = gGlobalSyncTable.level + 1
                end
                while not gGlobalSyncTable.allLevels and not levels[gGlobalSyncTable.level][6] do
                    if gGlobalSyncTable.level >= #levels then
                        gGlobalSyncTable.level = 1
                    else
                        gGlobalSyncTable.level = gGlobalSyncTable.level + 1
                    end
                end
            end
            

            packet_receive({packet = "SPLASH", message = "Hide!"})
            network_send(true, {packet = "SPLASH", message = "Hide!"})

            gGlobalSyncTable.gameState = 2

        end
        
    --Disperse Phase
    elseif gGlobalSyncTable.gameState == 2 then

        --Forfeit if Seeker(s) Disconnect or of all players are Seekers
        if seekerCount < 1 or seekerCount == #players then
            gGlobalSyncTable.timer = intermissionTimer
            gGlobalSyncTable.gameState = 1
            packet_receive({packet = "SPLASH", message = "Forfeit..."})
            network_send(true, {packet = "SPLASH", message = "Forfeit..."})
        end

        --Make Disconnected Indexes into Seekers
        for i=0,(MAX_PLAYERS-1) do
            if not gNetworkPlayers[i].connected then
                gPlayerSyncTable[i].seeker = true
            end
        end

        --Start Round
        local hideTimerFrames = get_hide_timer_frames()
        if gGlobalSyncTable.timer > hideTimerFrames then
            gGlobalSyncTable.timer = hideTimerFrames
        elseif gGlobalSyncTable.timer < 1 then
            gGlobalSyncTable.timer = get_round_timer_frames()
            gGlobalSyncTable.gameState = 3
            packet_receive({packet = "SPLASH", message = "Begin!"})
            network_send(true, {packet = "SPLASH", message = "Begin!"})
        end

    --Active
    elseif gGlobalSyncTable.gameState == 3 then

        --Make Disconnected Indexes into Seekers
        for i=0,(MAX_PLAYERS-1) do
            if not gNetworkPlayers[i].connected then
                gPlayerSyncTable[i].seeker = true
            end
        end

        if gGlobalSyncTable.timer > 12000 then
            gGlobalSyncTable.timer = 12000
        elseif gGlobalSyncTable.timer < 1 or hiderCount < 1 or seekerCount < 1 then
            
            --End Round
            gGlobalSyncTable.timer = intermissionTimer
            gGlobalSyncTable.gameState = 1
            
            if hiderCount < 1 then
                packet_receive({packet = "SPLASH", message = "Seekers Win!"})
                network_send(true, {packet = "SPLASH", message = "Seekers Win!"})
            elseif seekerCount < 1 then
                packet_receive({packet = "SPLASH", message = "Forfeit..."})
                network_send(true, {packet = "SPLASH", message = "Forfeit..."})
            else
                packet_receive({packet = "SPLASH", message = "Hiders Win!"})
                network_send(true, {packet = "SPLASH", message = "Hiders Win!"})
            end

        end

    end

end

hook_event(HOOK_UPDATE, update)