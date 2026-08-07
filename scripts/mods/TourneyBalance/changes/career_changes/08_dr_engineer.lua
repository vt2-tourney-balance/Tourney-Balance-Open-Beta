local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Outcast Engineer
	$END_TB
]]


--[[

	NOT REFACTORED

]]
--[[ Removed due to new Balance Patch of the official Game (6.0.0)
mod_api.insert_talent_buff_template("dwarf_ranger", "bardin_engineer_ranged_crit_count", {
	buff_to_add = "bardin_engineer_ranged_crit_counter_buff",
	max_stacks = 1,
	stat_buff = "critical_strike_chance_ranged",
	buff_func = "add_buff_on_first_target_hit",
	event = "on_hit",
	client_side = true,
	valid_attack_types = {
		instant_projectile = true,
		heavy_instant_projectile = true,
		projectile = true
	}
})
mod_api.insert_talent_buff_template("dwarf_ranger", "bardin_engineer_ranged_crit_counter_buff", {
	reset_on_max_stacks = true,
	on_max_stacks_func = "add_remove_buffs",
    max_stacks = 4,     -- 5
	is_cooldown = true,
	icon = "bardin_engineer_ranged_crit_count",
	max_stack_data = {
		buffs_to_add = {
			"bardin_engineer_ranged_crit_count_buff"
		}
	}
})
mod_api.insert_talent_buff_template("dwarf_ranger", "bardin_engineer_ranged_crit_count_buff", {
    event = "on_critical_shot",
    max_stacks = 1,
    stat_buff = "critical_strike_chance_ranged",
    buff_func = "dummy_function",
    remove_on_proc = true,
    icon = "bardin_engineer_ranged_crit_count",
    priority_buff = true,
})
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_ranged_crit_count_buff", {
    bonus = 1
})
mod_api.update_talent("dr_engineer", 2,1, {
	icon = "bardin_engineer_ranged_crit_count",
	buffs = {
		"bardin_engineer_ranged_crit_count"
	}
})

mod_api.insert_text("bardin_engineer_improved_explosives_desc", "Every 4th Ranged Attack is a guaranteed Critical Hit.")
mod_api.insert_text("bardin_engineer_melee_power_ranged_power_desc", "Melee Power is increased by 10%%. Every 5 Melee Strikes makes Bardin's next Ranged Attack grant 15%% Ranged Power for 10 seconds.")
]]

