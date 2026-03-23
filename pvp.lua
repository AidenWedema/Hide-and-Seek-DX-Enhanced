-- Direct PVP is Disabled
local function allow_pvp_attack(a, v)
    return false
end

-- Touch PVP Handler
local function on_interact(m, obj, intee)
    if
        gGlobalSyncTable.gameState == 3 and 
        intee == INTERACT_PLAYER and
        m ~= gMarioStates[0]
    then
        for i=0,(MAX_PLAYERS-1) do
            if
                gNetworkPlayers[i].connected and
                gNetworkPlayers[i].currAreaSyncValid and
                obj == gMarioStates[i].marioObj and
                
                gPlayerSyncTable[m.playerIndex].seeker and
                not gPlayerSyncTable[i].seeker and
                --Exceptions for Tagging
                gMarioStates[i].action ~= ACT_TELEPORT_FADE_IN and
                gMarioStates[i].action ~= ACT_TELEPORT_FADE_OUT and
                gMarioStates[i].action ~= ACT_IN_CANNON and
                gMarioStates[i].action ~= ACT_DISAPPEARED and

                (
                    -- Seeker Must be Attacking
                    m.action & ACT_FLAG_ATTACKING ~= 0
                    -- Exceptions for Touch-to-Tag
                    or gMarioStates[i].action == ACT_VERTICAL_WIND
                    or gMarioStates[i].action == ACT_TWIRLING
                    or (gMarioStates[i].action & ACT_FLAG_SWIMMING ~= 0 and m.action & ACT_FLAG_SWIMMING ~= 0)
                    or (gMarioStates[i].action & ACT_FLAG_ON_POLE ~= 0 and m.action & ACT_FLAG_ON_POLE ~= 0)
                )
            then
                gPlayerSyncTable[i].seeker = true
                network_send(true, {packet = "ON_TAG", message = string_without_hex(gNetworkPlayers[m.playerIndex].name) .. " tagged " .. string_without_hex(gNetworkPlayers[i].name) .. "!"})
                packet_receive({packet = "ON_TAG", message = string_without_hex(gNetworkPlayers[m.playerIndex].name) .. " tagged " .. string_without_hex(gNetworkPlayers[i].name) .. "!"})
            end
        end
    end
end

hook_event(HOOK_ALLOW_PVP_ATTACK, allow_pvp_attack)
hook_event(HOOK_ON_INTERACT, on_interact)