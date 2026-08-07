local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Slayer
		### Talents
		**A Thousand Cuts**
		- Attack speed increased to 15% (from 10%).

		**Impatience**
		- Additionally grants 5% dodge distance and 5% dodge speed per Trophy Hunter stack.

		**Adrenaline Surge**
		- Changed to 67% cooldown reduction per Trophy Hunter stack (300% only at max stacks).

		**Barge**
		- Additionally grants 10% dodge distance and 10% dodge speed.
		- Additionally grants 15% damage reduction.
	$END_TB
]]

--[[

	Talents

]]
--[[
	A Thousand Cuts
]]
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_slayer_attack_speed_on_double_one_handed_weapons", {
	multiplier = 0.15 -- 0.1
})
mod_api.insert_text("bardin_slayer_attack_speed_on_double_one_handed_weapons_desc", "Gain 15.0%% attack speed if wielding 2 one-handed weapons.")

--[[
	Impatience
	Adrenaline Surge
]]
mod_api.insert_proc_function("add_bardin_slayer_passive_buff", function(owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local buff_system = Managers.state.entity:system("buff_system")

	if Unit.alive(owner_unit) then
		local buff_name = "bardin_slayer_passive_stacking_damage_buff"
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

		if talent_extension:has_talent("bardin_slayer_passive_increased_max_stacks", "dwarf_ranger", true) then
			buff_name = "bardin_slayer_passive_increased_max_stacks"
		end
		buff_system:add_buff(owner_unit, buff_name, owner_unit, false)

		if talent_extension:has_talent("bardin_slayer_passive_movement_speed", "dwarf_ranger", true) then
			buff_system:add_buff(owner_unit, "bardin_slayer_passive_movement_speed", owner_unit, false)
			buff_system:add_buff(owner_unit, "tb_bardin_slayer_passive_dodge_range", owner_unit, false) -- additional dodge range per stack
			buff_system:add_buff(owner_unit, "tb_bardin_slayer_passive_dodge_speed", owner_unit, false)	-- additional dodge speed per stack
		end

		if talent_extension:has_talent("bardin_slayer_passive_cooldown_reduction_on_max_stacks", "dwarf_ranger", true) then
			buff_system:add_buff(owner_unit, "bardin_slayer_passive_cooldown_reduction_on_max_stacks", owner_unit, false)
		end
	end
end)
--[[
	Impatience
]]
mod_api.insert_talent_buff_template("dwarf_ranger", "tb_bardin_slayer_passive_dodge_range", {
	max_stacks = 3,
	multiplier = 1.05,
	duration = 2,
	icon = "bardin_slayer_passive_stacking_damage_buff_grants_defence",
	remove_buff_func = "remove_movement_buff",
	apply_buff_func = "apply_movement_buff",
	refresh_durations = true,
	path_to_movement_setting_to_modify = {
		"dodging",
		"distance_modifier"
	}
})
mod_api.insert_talent_buff_template("dwarf_ranger", "tb_bardin_slayer_passive_dodge_speed", {
	max_stacks = 3,
	multiplier = 1.05,
	duration = 2,
	remove_buff_func = "remove_movement_buff",
	apply_buff_func = "apply_movement_buff",
	refresh_durations = true,
	path_to_movement_setting_to_modify = {
		"dodging",
		"speed_modifier"
	}
})
mod_api.insert_text("bardin_slayer_passive_movement_speed_desc", "Each stack of Trophy Hunter increases movement speed by 10.0%% and dodge range by 5.0%%.")
--[[
	Adrenaline Surge
]]
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_slayer_passive_cooldown_reduction_on_max_stacks", {
	duration = 2,
	multiplier = 0.67, -- Added
	max_stacks = 3, -- 1
})
mod_api.insert_text("bardin_slayer_passive_cooldown_reduction_on_max_stacks_desc", "Each stack of Trophy Hunter increases cooldown regeneration by 67%.")

--[[
	Barge
]]
mod_api.insert_talent_buff_template("dwarf_ranger", "tb_bardin_slayer_dodge_speed", {
	multiplier = 1.1,
	remove_buff_func = "remove_movement_buff",
	apply_buff_func = "apply_movement_buff",
	path_to_movement_setting_to_modify = {
		"dodging",
		"speed_modifier"
	}
})
mod_api.insert_talent_buff_template("dwarf_ranger", "tb_bardin_slayer_dodge_range", {
	multiplier = 1.1,
	remove_buff_func = "remove_movement_buff",
	apply_buff_func = "apply_movement_buff",
	path_to_movement_setting_to_modify = {
		"dodging",
		"distance_modifier"
	}
})
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_slayer_push_on_dodge", {
	stat_buff = "damage_taken", -- Added
	multiplier = -0.15 -- Added
})
mod_api.update_talent("dr_slayer", 5, 3, {
	description = "bardin_slayer_push_on_dodge_desc",
	server = "both",
	buffs = {
		"bardin_slayer_push_on_dodge",
		"tb_bardin_slayer_dodge_range",
		"tb_bardin_slayer_dodge_speed"
	}
})
mod_api.insert_text("bardin_slayer_push_on_dodge_desc", "Effective dodges pushes nearby small enemies out of the way. Increases dodge range by 10% and reduces damage taken by 15%.")


