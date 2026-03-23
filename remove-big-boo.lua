local function update()
    omm_world_behavior_set_dormant(id_bhvBalconyBigBoo, true)
end

function for_each_object_with_behavior(behavior, func_f)
    local obj = obj_get_first_with_behavior_id(behavior)
    local objCoin = 0
    if behavior == id_bhvBoo then
        objCoin = obj_get_first_with_behavior_id(id_bhvCoinInsideBoo)
    end
    while obj ~= nil do
        func_f(obj)
        obj = obj_get_next_with_same_behavior_id(obj)
        if behavior == id_bhvBoo then
            func_f(objCoin)
            objCoin = obj_get_next_with_same_behavior_id(objCoin)
        end
    end
end

function omm_world_behavior_set_dormant(bhvId, set)
    for_each_object_with_behavior(bhvId, function(obj)
        obj_set_dormant(obj, set)
    end)
end

function obj_set_dormant(o, set)
    if set then
        o.activeFlags = o.activeFlags | ACTIVE_FLAG_DORMANT
        o.header.gfx.node.flags = o.header.gfx.node.flags & ~GRAPH_RENDER_ACTIVE
        o.oInteractStatus = INT_STATUS_INTERACTED
        o.oIntangibleTimer = -1
    elseif (o.activeFlags & ACTIVE_FLAG_DORMANT) ~= 0 then
        o.activeFlags = o.activeFlags & ~ACTIVE_FLAG_DORMANT
        o.header.gfx.node.flags = o.header.gfx.node.flags | GRAPH_RENDER_ACTIVE
        o.oInteractStatus = 0
        o.oIntangibleTimer = 0
    end
end

hook_event(HOOK_UPDATE, update)