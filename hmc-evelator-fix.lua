local function hook_behavior_custom(id, override, init, loop)
    return hook_behavior(id,
        get_object_list_from_behavior(get_behavior_from_id(id)), -- Automatically get the correct object list
        override, init, loop,
        "bhvMhCustom" ..
        get_behavior_name_from_id(id):sub(4) -- Give the behavior a consistent behavior name (for example, bhvTreasureChestsJrb will become bhvMhCustomTreasureChestsJrb)
    )
end
local function custom_elevator_loop(o)
    -- check if there are any nearby players waiting at the bottom. If so, SEND THE ELEVATOR!
    -- note that oElevatorUnkF4 is the elevator's bottom y position. oElevatorUnkFC is... I think the middle point?
    local nearestM = nearest_mario_state_to_object(o)
    if nearestM and nearestM.playerIndex == 0 and (o.oAction == 0 or (o.oAction == 3 and o.oTimer > 60)) and o.oElevatorUnk100 ~= 2 and o.oPosY > o.oElevatorUnkF4 then
        if o.oAction == 3 then
            log_to_console(tostring(o.oTimer))
        end
        for i=0,MAX_PLAYERS-1 do
            local m = gMarioStates[i]
            if is_player_active(m) ~= 0 and m.pos.y < o.oElevatorUnkFC and dist_between_object_and_point(m.marioObj, o.oPosX, o.oElevatorUnkF4, o.oPosZ) < 1000 then
                o.oAction = 2
                network_send_object(o, false)
                break
            end
        end
    end
    bhv_elevator_loop()
end
hook_behavior_custom(id_bhvHmcElevatorPlatform, false, nil, custom_elevator_loop)
hook_behavior_custom(id_bhvMeshElevator, false, nil, custom_elevator_loop)