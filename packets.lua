function packet_receive(data)
    
    if data.packet == "ON_TAG" then

        djui_chat_message_create("\\#FF8080\\[ " .. data.message .. " ]")
        play_sound(SOUND_GENERAL2_BOBOMB_EXPLOSION, gMarioStates[0].marioObj.header.gfx.cameraToObject)

        if network_is_server() and hiderCount > 1 then
            
            if gGlobalSyncTable.forceLevel then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer + math.floor(levels[gGlobalSyncTable.level][5]*30/(#players-1))
            else
                gGlobalSyncTable.timer = activeTimerFree
            end
            
        end

    end

    if data.packet == "SPLASH" then

        splashMessage = data.message
        splashTimer = 150

        if data.message == "Hide!" or data.message == "Begin!" then
            play_sound(SOUND_GENERAL_RACE_GUN_SHOT, gMarioStates[0].marioObj.header.gfx.cameraToObject)
            splashR, splashG, splashB = true, false, true
        end

        if data.message == "Forfeit..." then
            play_sound(SOUND_MENU_CAMERA_BUZZ, gMarioStates[0].marioObj.header.gfx.cameraToObject)
            play_music(0, 0, 0)
            splashR, splashG, splashB = false, false, true
        end

        if data.message == "Hiders Win!" then
            play_music(0, SEQ_EVENT_CUTSCENE_COLLECT_STAR, 0)
            splashR, splashG, splashB = false, false, true
        end

        if data.message == "Seekers Win!" then
            play_music(0, SEQ_EVENT_KOOPA_MESSAGE, 0)
            splashR, splashG, splashB = true, false, false
        end

        if data.message == "Single-Level Mode" then
            play_music(0, SEQ_EVENT_SOLVE_PUZZLE, 0)
            splashR, splashG, splashB = true, true, false
        end

        if data.message == "Full-Game Mode" then
            play_music(0, SEQ_EVENT_SOLVE_PUZZLE, 0)
            splashR, splashG, splashB = false, true, true
        end

    end

end

hook_event(HOOK_ON_PACKET_RECEIVE, packet_receive)