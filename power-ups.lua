TEX_BOO = get_texture_info("powerup_boo")
TEX_BLOOPER = get_texture_info("powerup_blooper")
TEX_BULLET_BILL = get_texture_info("powerup_bullet_bill")
TEX_FREEZY = get_texture_info("powerup_freezy")

-- Called when a player collects a cap.
-- Used to start the power up roulette.
function on_cap_collected()

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
    local size = 256
    local x = djui_hud_get_screen_width() - gap - size
    local y = djui_hud_get_screen_height() - gap - size
    djui_hud_render_rect(x, y, size, size)

    if gPlayerSyncTable[0].powerUp ~= nil then
        local powerUp = gPlayerSyncTable[0].powerUp
        local texture = get_power_up_texture(powerUp)
        if texture ~= nil then
            djui_hud_render_texture(texture, x, y, size, size)
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


-- Bullet bill
-- Fires a homing bullet bill at the nearest player in the opposite team.
-- The bullet bill won't target anyone who has the "Boo" power-up active or if no player is close by.
-- the homing effect lasts for 10 seconds, after which the bullet bill will continue in a straight line.


-- Hider only power-ups

-- Freezy
-- Freezes the nearest seeker for 2 seconds.


-- Seeker only power-ups

-- Boo
-- Makes the user transparent for 20 seconds.