-- {LEVEL, AREA, ACT, CANNONS, STARTING_TIME, WHITELIST_LEVEL}

levels = {
    
    
    {LEVEL_CASTLE_GROUNDS, 1, 0, true, 120, false},
    {LEVEL_BOB, 1, 2, true, 120, true},    
    {LEVEL_WF, 1, 2, true, 90, true},
    {LEVEL_JRB, 1, 2, true, 120, false},
    {LEVEL_CCM, 1, 1, true, 150, true},
    {LEVEL_BBH, 1, 2, false, 150, true},

    {LEVEL_PSS, 1, 1, false, 90, false},
    {LEVEL_TOTWC, 1, 1, false, 90, false},
    {LEVEL_BITDW, 1, 1, false, 90, false},
    {LEVEL_BOWSER_1, 1, 1, false, 40, false},
    
    {LEVEL_CASTLE, 1, 0, false, 120, true},
    {LEVEL_HMC, 1, 1, false, 150, true},
    {LEVEL_LLL, 1, 1, false, 120, false},
    {LEVEL_SSL, 1, 1, true, 150, true},
    {LEVEL_DDD, 1, 2, false, 120, false},

    {LEVEL_VCUTM, 1, 1, false, 90, false},
    {LEVEL_COTMC, 1, 1, false, 40, false},
    {LEVEL_BITFS, 1, 1, false, 150, false},
    {LEVEL_BOWSER_2, 1, 1, false, 40, false},

    {LEVEL_CASTLE_COURTYARD, 1, 0, false, 40, false},
    {LEVEL_SL, 1, 1, false, 120, true},
    {LEVEL_WDW, 1, 1, true, 150, true},
    {LEVEL_TTM, 1, 2, true, 150, true},
    {LEVEL_THI, 1, 3, true, 180, true},
    {LEVEL_TTC, 1, 1, false, 120, false},
    {LEVEL_RR, 1, 1, true, 150, false},

    {LEVEL_WMOTR, 1, 1, true, 90, false},
    {LEVEL_BITS, 1, 1, false, 150, false},
    {LEVEL_BOWSER_3, 1, 1, false, 40, false}

}

--ROM HACKS
for mod in pairs(gActiveMods) do
    if gActiveMods[mod].incompatible ~= nil and gActiveMods[mod].incompatible:find("romhack") then
        
        --STAR ROAD
        if gActiveMods[mod].relativePath == "star-road" then
            levels = {
        
                {LEVEL_CASTLE_GROUNDS, 1, 0, true, 120, false},
                {LEVEL_BOB, 1, 2, true, 180, true},    
                {LEVEL_WF, 1, 2, true, 180, true},
                {LEVEL_JRB, 1, 2, true, 180, true},
                {LEVEL_CCM, 1, 1, true, 180, true},
                {LEVEL_BBH, 1, 2, true, 180, true},

                {LEVEL_PSS, 1, 1, true, 150, true},
                {LEVEL_COTMC, 1, 1, true, 90, false},
                {LEVEL_VCUTM, 1, 1, true, 60, false},
                {LEVEL_BITDW, 1, 1, true, 180, false},
                {LEVEL_BOWSER_1, 1, 1, true, 120, false},
                
                {LEVEL_CASTLE_COURTYARD, 1, 0, true, 180, false},
                {LEVEL_HMC, 1, 1, true, 180, false},
                {LEVEL_LLL, 1, 1, true, 180, true},
                {LEVEL_SSL, 1, 1, true, 180, true},
                {LEVEL_DDD, 1, 2, true, 180, false},
                {LEVEL_SL, 1, 1, true, 180, true},
                
                {LEVEL_SA, 1, 1, true, 120, true},
                {LEVEL_BITFS, 1, 1, true, 150, false},
                {LEVEL_BOWSER_2, 1, 1, true, 90, false},

                {LEVEL_CASTLE, 1, 0, true, 90, false},
                {LEVEL_WDW, 1, 1, true, 180, true},
                {LEVEL_TTM, 1, 2, true, 180, true},
                {LEVEL_THI, 1, 3, true, 180, true},
                {LEVEL_TTC, 1, 1, true, 180, true},
                {LEVEL_RR, 1, 1, true, 180, false},

                {LEVEL_TOTWC, 1, 1, true, 180, true},
                {LEVEL_BITS, 1, 1, true, 180, false},
                {LEVEL_BOWSER_3, 1, 1, true, 40, false},
                {LEVEL_WMOTR, 1, 1, true, 180, false},
                {50, 1, 0, true, 60, false},
                
            }
        end

        --SM74
        if gActiveMods[mod].relativePath == "sm74" then
            levels = {
        
                {LEVEL_CASTLE_COURTYARD, 1, 0, true, 180, true},

                {LEVEL_BOB, 1, 2, true, 180, true},    
                {LEVEL_WF, 1, 2, true, 150, true},
                {LEVEL_JRB, 1, 2, true, 180, false},

                {LEVEL_COTMC, 1, 1, true, 60, false},
                {LEVEL_BITDW, 1, 1, true, 150, true},

                {LEVEL_WMOTR, 1, 1, true, 180, true},

                {LEVEL_CCM, 1, 1, true, 180, true},
                {LEVEL_BBH, 1, 2, true, 180, true},
                {LEVEL_HMC, 1, 1, true, 180, true},
                {LEVEL_LLL, 1, 1, true, 180, true},
                {LEVEL_SSL, 1, 1, true, 180, true},
                {LEVEL_DDD, 1, 2, true, 180, true},
            
                {LEVEL_PSS, 1, 1, true, 150, false},
                {LEVEL_TOTWC, 1, 1, true, 150, false},
                {LEVEL_VCUTM, 1, 1, true, 150, false},
                {LEVEL_BITFS, 1, 1, true, 180, true},

                {LEVEL_CASTLE, 1, 0, true, 150, false},
                
                {LEVEL_SL, 1, 1, true, 180, true},
                {LEVEL_WDW, 1, 1, true, 180, true},
                {LEVEL_TTM, 1, 2, true, 180, false},
                {LEVEL_THI, 1, 3, true, 180, false},
                {LEVEL_TTC, 1, 1, true, 180, false},
                {LEVEL_RR, 1, 1, true, 180, false},
                
                {LEVEL_SA, 1, 1, true, 150, false},
                {LEVEL_BITS, 1, 1, true, 180, false},
                {LEVEL_BOWSER_3, 1, 1, true, 40, false}
            
            }
        end


        --SM64 SAPPHIRE
        if gActiveMods[mod].relativePath == "sapphire" then
            levels = {
        
                {LEVEL_CASTLE, 1, 0, false, 30, false},
                {LEVEL_BOB, 1, 2, false, 120, true},    
                {LEVEL_WF, 1, 2, false, 120, true},
                {LEVEL_JRB, 1, 2, false, 120, true},
                {LEVEL_CCM, 1, 1, false, 120, true},
                {LEVEL_PSS, 1, 1, false, 60, false},
                {LEVEL_BITS, 1, 1, false, 120, false},
                {LEVEL_BOWSER_3, 1, 1, false, 40, false}
            
            }
        end

        --SM64 RAINBOW ROAD
        if gActiveMods[mod].relativePath == "rainbow-road" then
            levels = {
        
                {LEVEL_CASTLE_GROUNDS, 1, 0, false, 0, false},
                
                {LEVEL_BOB, 1, 2, false, 150, true},    
                {LEVEL_WF, 1, 2, false, 150, true},
                {LEVEL_JRB, 1, 2, false, 150, true},
                {LEVEL_CCM, 1, 1, false, 150, true},
                {LEVEL_BBH, 1, 2, false, 150, true},
            
                {LEVEL_TOTWC, 1, 1, false, 120, false},
                {LEVEL_VCUTM, 1, 1, false, 150, true},
                {LEVEL_COTMC, 1, 1, false, 120, false},
                {LEVEL_BITDW, 1, 1, false, 120, false},
            
                {LEVEL_CASTLE_COURTYARD, 1, 0, false, 60, false},

                {LEVEL_HMC, 1, 1, false, 150, true},
                {LEVEL_LLL, 1, 1, false, 150, true},

                {LEVEL_BITS, 1, 1, false, 120, false},
                {LEVEL_PSS, 1, 1, false, 60, false},
                {LEVEL_SA, 1, 1, false, 60, false},
                
            }
        end

    end
end