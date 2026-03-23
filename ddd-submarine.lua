---@param o Object
function custom_ddd_sub_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_ACTIVE_FROM_AFAR | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    o.oCollisionDistance = 20000
    o.collisionData = smlua_collision_util_get('ddd_seg7_collision_submarine')
end

---@param o Object
function custom_ddd_loop(o)
    load_object_collision_model()
end

hook_behavior(id_bhvBowsersSub, OBJ_LIST_SURFACE, true, custom_ddd_sub_init, custom_ddd_loop)