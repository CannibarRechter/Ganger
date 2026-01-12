-------------------------------------------------------------------------
-- Ganger wave sets (weighted compositions by biome); bookkeeping and
-- calcs done in ganger_wave. Persistence performed by ganger_dom.
-------------------------------------------------------------------------
local wave_sets = { -- do not modify at runtime, results will be discarded
-- on restore from save; this is why persistence is in dom.
-- use base ratios of 100:10:5:1 for base/alpha/ultra/boss ratios
-------------------------------------------------------------------------
-- ACID
-------------------------------------------------------------------------
["acid"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 1.25,  "units/ground/arachnoid_sentinel", },
        { 0.13,  "units/ground/arachnoid_sentinel_alpha", },
        { 0.07,  "units/ground/arachnoid_sentinel_ultra", },
        { 0.013,"units/ground/arachnoid_sentinel_boss_random", },

        { 2.00,  "units/ground/granan", },
        { 0.20,  "units/ground/granan_alpha", },
        { 0.10,  "units/ground/granan_ultra", },
        { 0.02,  "units/ground/granan_boss", },

        { 1.00,  "units/ground/nerilian", },
        { 0.10,  "units/ground/nerilian_alpha", },
        { 0.05,  "units/ground/nerilian_ultra", },
        { 0.01,  "units/ground/nerilian_boss_random", },

        { 0.75,  "units/ground/nurglax", },
        { 0.075, "units/ground/nurglax_alpha", },
        { 0.038, "units/ground/nurglax_ultra", },
        { 0.007, "units/ground/nurglax_boss_random", },

        { 0.50,  "units/ground/phirian", },
        { 0.05,  "units/ground/phirian_alpha", },
        { 0.025, "units/ground/phirian_ultra", },
        { 0.005, "units/ground/phirian_boss_random", },

        { 0.50,  "units/ground/baxmoth", },
        { 0.05,  "units/ground/baxmoth_alpha", },
        { 0.025, "units/ground/baxmoth_ultra", },
        { 0.005, "units/ground/baxmoth_boss_random", },
    }
},
-------------------------------------------------------------------------
-- CAVERNS
-------------------------------------------------------------------------
["caverns"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 2.00,  "units/ground/crawlog", },
        { 0.20,  "units/ground/crawlog_alpha", },
        { 0.10,  "units/ground/crawlog_ultra", },
        { 0.02,  "units/ground/crawlog_boss", },

        { 0.25,  "units/ground/gnerot_caverns", },
        { 0.025, "units/ground/gnerot_alpha", },
        { 0.013, "units/ground/gnerot_ultra", },
        { 0.002, "units/ground/gnerot_boss_random", },

        { 1.00,  "units/ground/gulgor", },
        { 0.10,  "units/ground/gulgor_alpha", },
        { 0.05,  "units/ground/gulgor_ultra", },
        { 0.01,  "units/ground/gulgor_boss", },

        { 0.75,  "units/ground/necrodon", },
        { 0.075, "units/ground/necrodon_alpha", },
        { 0.038, "units/ground/necrodon_ultra", },
        { 0.007, "units/ground/necrodon_boss_random", },

        { 1.00,  "units/ground/stregaros_crystal", },
        { 0.10,  "units/ground/stregaros_crystal_alpha", },
        { 0.05,  "units/ground/stregaros_crystal_ultra", },
        { 0.01,  "units/ground/stregaros_boss_crystal", }
    }
},
-------------------------------------------------------------------------
-- DESERT
-------------------------------------------------------------------------
["desert"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 0.35,  "units/ground/gnerot", },
        { 0.03,  "units/ground/gnerot_alpha", },
        { 0.015, "units/ground/gnerot_ultra", },
        { 0.003, "units/ground/gnerot_boss_random", },

        { 0.50,  "units/ground/kermon", },
        { 0.05,  "units/ground/kermon_alpha", },
        { 0.025, "units/ground/kermon_ultra", },

        { 0.75,  "units/ground/lesigian", },
        { 0.075, "units/ground/lesigian_alpha", },
        { 0.038, "units/ground/lesigian_ultra", },
        { 0.007, "units/ground/lesigian_boss", },

        { 3.00,  "units/ground/mushbit", },
        { 0.30,  "units/ground/mushbit_alpha", },
        { 0.15,  "units/ground/mushbit_ultra", },

        { 2.00,  "units/ground/stregaros", },
        { 0.20,  "units/ground/stregaros_alpha", },
        { 0.10,  "units/ground/stregaros_ultra", },
        { 0.02,  "units/ground/stregaros_boss_random", },

        { 1.50,  "units/ground/zorant", },
        { 0.15,  "units/ground/zorant_alpha", },
        { 0.08,  "units/ground/zorant_ultra", },
    }
},
-------------------------------------------------------------------------
-- JUNGLE
-------------------------------------------------------------------------
["jungle"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 1.25,  "units/ground/arachnoid_sentinel", },
        { 0.13,  "units/ground/arachnoid_sentinel_alpha", },
        { 0.07,  "units/ground/arachnoid_sentinel_ultra", },
        { 0.013, "units/ground/arachnoid_sentinel_boss_random", },

        { 0.20,  "units/ground/baxmoth", },
        { 0.02,  "units/ground/baxmoth_alpha", },
        { 0.01,  "units/ground/baxmoth_ultra", },
        { 0.002, "units/ground/baxmoth_boss_random", },

        { 0.50,  "units/ground/bomogan", },
        { 0.05,  "units/ground/bomogan_alpha", },
        { 0.025, "units/ground/bomogan_ultra", },

        { 2.00,  "units/ground/canoptrix", },
        { 0.20,  "units/ground/canoptrix_alpha", },
        { 0.10,  "units/ground/canoptrix_ultra", },
        { 0.02,  "units/ground/canoptrix_boss", },

        { 1.00,  "units/ground/kafferroceros", },
        { 0.10,  "units/ground/kafferroceros_alpha", },
        { 0.05,  "units/ground/kafferroceros_ultra", },
        { 0.01,  "units/ground/kafferroceros_boss_random", },

        { 0.50,  "units/ground/kermon", },
        { 0.05,  "units/ground/kermon_alpha", },
        { 0.025, "units/ground/kermon_ultra", },

        { 0.25,  "units/ground/phirian", },
        { 0.025, "units/ground/phirian_alpha", },
        { 0.013, "units/ground/phirian_ultra", },
        { 0.003, "units/ground/phirian_boss_random", },
    }
},
-------------------------------------------------------------------------
-- MAGMA
-------------------------------------------------------------------------
["magma"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 0.5,  "units/ground/bomogan_alpha", },
        { 0.1,  "units/ground/bomogan_ultra", },

        { 0.5,  "units/ground/krocoon_alpha", },
        { 0.25, "units/ground/krocoon_ultra", },
        { 0.05, "units/ground/krocoon_boss_fire", },

        { 1.00,  "units/ground/magmoth", },
        { 0.10,  "units/ground/magmoth_alpha", },
        { 0.05,  "units/ground/magmoth_ultra", },
        { 0.01,  "units/ground/magmoth_boss", },

        { 0.35,  "units/ground/morirot", },
        { 0.03,  "units/ground/morirot_alpha", },
        { 0.015, "units/ground/morirot_ultra", },

        { 2.00,  "units/ground/nerilian", },
        { 0.020, "units/ground/nerilian_alpha", },
        { 0.010, "units/ground/nerilian_ultra", },
        { 0.005, "units/ground/nerilian_boss_random", },

        { 0.035, "units/ground/phirian_alpha", },
        { 0.017, "units/ground/phirian_ultra", },
        { 0.003, "units/ground/phirian_boss_random", },
    }
},
-------------------------------------------------------------------------
-- METALLIC
-------------------------------------------------------------------------
["metallic"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 0.35,  "units/ground/bradron", },
        { 0.03,  "units/ground/bradron_alpha", },
        { 0.015, "units/ground/bradron_ultra", },

        { 0.50,  "units/ground/kermon_metallic", },
        { 0.05,  "units/ground/kermon_alpha", },
        { 0.025, "units/ground/kermon_ultra", },

        { 0.75,  "units/ground/flurian", },
        { 0.075, "units/ground/flurian_alpha", },
        { 0.038, "units/ground/flurian_ultra", },
        { 0.007, "units/ground/flurian_boss_random", },

        { 0.75,  "units/ground/lesigian", },
        { 0.075, "units/ground/lesigian_alpha", },
        { 0.038, "units/ground/lesigian_ultra", },
        { 0.007, "units/ground/lesigian_boss", },

        { 0.75,  "units/ground/octabit", },
        { 0.075, "units/ground/octabit_alpha", },
        { 0.038, "units/ground/octabit_ultra", },

        { 2.00,  "units/ground/wingmite", },
        { 0.20,  "units/ground/wingmite_alpha", },
        { 0.10,  "units/ground/wingmite_ultra", },
        { 0.02,  "units/ground/wingmite_boss", },
    }
},
-------------------------------------------------------------------------
-- SWAMP
-------------------------------------------------------------------------
["swamp"] = {
    ["total"] = 0,
    ["blueprints"] = {
        -- v1:   v2:
        { 0.50,  "units/ground/baxmoth", },
        { 0.05,  "units/ground/baxmoth_alpha", },
        { 0.025, "units/ground/baxmoth_ultra", },
        { 0.005, "units/ground/baxmoth_boss_random", },

        { 0.2,   "units/ground/canceroth", },

        { 0.75,  "units/ground/fungor", },
        { 0.075, "units/ground/fungor_alpha", },
        { 0.038, "units/ground/fungor_ultra", },
        { 0.007, "units/ground/fungor_boss_random", },

        { 0.35,  "units/ground/stickrid", },
        { 0.03,  "units/ground/stickrid_alpha", },
        { 0.015, "units/ground/stickrid_ultra", },

        { 0.75,  "units/ground/nurglax", },
        { 0.075, "units/ground/nurglax_alpha", },
        { 0.038, "units/ground/nurglax_ultra", },
        { 0.007, "units/ground/nurglax_boss_random", },

        { 0.50,  "units/ground/phirian", },
        { 0.05,  "units/ground/phirian_alpha", },
        { 0.025, "units/ground/phirian_ultra", },
        { 0.005, "units/ground/phirian_boss_random", },

        { 0.50,  "units/ground/plutrodon", },
        { 0.05,  "units/ground/plutrodon_alpha", },
        { 0.025, "units/ground/plutrodon_ultra", },
    }
},
-------------------------------------------------------------------------
}
return wave_sets