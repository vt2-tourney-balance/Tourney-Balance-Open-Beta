local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
    Deepwood Staff
]]
-- Overcharge slowdown
--mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_passive_healing_received_aura", { perks = {}, })

-- Lift duration
VortexTemplates.spirit_storm.time_of_life = { 5,5 }

-- Heat cost per lift
Weapons.staff_life.actions.action_one.cast_vortex.overcharge_amount = 12 -- 10

-- Overcharge explosion safety net
OverchargeData.we_thornsister.critical_overcharge_margin = math.huge

-- Overcharge explosion self-damage
--OverchargeData.we_thornsister.percent_health_lost = 0.8 --0.4

-- Heat decay start time
--OverchargeData.we_thornsister.time_until_overcharge_decreases = 0.5

-- Heat decay rate
--OverchargeData.we_thornsister.overcharge_value_decrease_rate = 1

-- Heat decay rate after explosion
--OverchargeData.we_thornsister.lockout_overcharge_decay_rate = 4


