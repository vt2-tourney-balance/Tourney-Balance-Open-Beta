local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
    Deepwood Staff
]]
-- Overcharge slowdown
--mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_passive_healing_received_aura", { perks = {}, })

-- Lift duration
VortexTemplates.spirit_storm.time_of_life = { 2,2 }

-- Heat cost per lift
Weapons.staff_life.actions.action_one.cast_vortex.overcharge_amount = 12

-- Overcharge explosion safety net
--OverchargeData.we_thornsister.critical_overcharge_margin = math.huge

-- Vent damage
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_thorn_sister_vent_damage", {
	stat_buff = "vent_damage",
	max_stacks = 1,
	multiplier = 1.5,
})
mod_api.insert_career_passives("we_thornsister", {
	"tb_kerillian_thorn_sister_vent_damage",
})

-- Overcharge explosion self-damage
--OverchargeData.we_thornsister.percent_health_lost = 0.8 --0.4

-- Heat decay start time
--OverchargeData.we_thornsister.time_until_overcharge_decreases = 0.5

-- Heat decay rate
--OverchargeData.we_thornsister.overcharge_value_decrease_rate = 1

-- Heat decay rate after explosion
--OverchargeData.we_thornsister.lockout_overcharge_decay_rate = 4


