local function command_switch_mode()

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
        djui_chat_message_create("You can only change modes during intermission. This is to prevent abuse of this command.")
    end

    return true

end

local function command_all_levels()

    gGlobalSyncTable.allLevels = not gGlobalSyncTable.allLevels
    if gGlobalSyncTable.allLevels then
        djui_chat_message_create("All Levels Enabled")
    else
        djui_chat_message_create("Switched to Standard Levels Only")
    end
    return true

end

local function command_player_list()

    gGlobalSyncTable.playerList = not gGlobalSyncTable.playerList
    if gGlobalSyncTable.playerList then
        djui_chat_message_create("Player List Enabled for Full-Game Mode")
    else
        djui_chat_message_create("Player List Disabled for Full-Game Mode")
    end
    return true

end

local function command_set_role(args)

    local parts = {}
    for part in string.gmatch(args, "%S+") do
        table.insert(parts, part)
    end
    
    if #parts < 2 then
        djui_chat_message_create("Usage: /set-role <username> <role>")
        return true
    end
    
    local username = parts[1]
    local role = string.lower(parts[2])
    
    if role ~= "seeker" and role ~= "hider" and role ~= "random" then
        djui_chat_message_create("Invalid role. Use: seeker, hider, or random")
        return true
    end
    
    local foundPlayer = false
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected then
            if string_without_hex(gNetworkPlayers[i].name) == username then
                gPlayerSyncTable[i].role = role
                djui_chat_message_create(username .. "'s role set to " .. role .. "!")
                foundPlayer = true
                break
            end
        end
    end
    
    if not foundPlayer then
        djui_chat_message_create("Player '" .. username .. "' not found.")
    end
    
    return true

end

local function command_settings()
    settingsMenuOpen = not settingsMenuOpen
    if settingsMenuOpen then
        djui_chat_message_create("Settings menu opened. Use D-Pad to navigate and edit, B to close.")
    else
        djui_chat_message_create("Settings menu closed.")
    end
    return true
end

local function command_add_round_time(secondsStr)
    if not secondsStr or secondsStr == "" then
        djui_chat_message_create("Usage: /add-time <seconds>")
        return true
    end

    local seconds = tonumber(secondsStr)
    if not seconds or seconds == 0 then
        djui_chat_message_create("Please provide a valid number of seconds.")
        return true
    end

    if gGlobalSyncTable.gameState ~= 3 then
        djui_chat_message_create("You can only add time during an active round.")
        return true
    end

    local framesToAdd = seconds * 30
    gGlobalSyncTable.timer = gGlobalSyncTable.timer + framesToAdd
    djui_chat_message_create("Added " .. seconds .. " seconds to the round timer!")
    return true
end

if network_is_server() then
    hook_chat_command("mode", "- Switch Gamemodes", command_switch_mode)
    hook_chat_command("levels", "- Toggle Blacklisted Levels", command_all_levels)
    hook_chat_command("playerlist", "- Toggle Player List for Full-Game Mode", command_player_list)
    hook_chat_command("set-role", "- Set a player's role (seeker/hider/random)", command_set_role)
    hook_chat_command("hideNseek", "- Open host settings menu", command_settings)
    hook_chat_command("add-time", "- Add x seconds to the active round timer", command_add_round_time)
end