local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Slayer
		### Talents
		**Dawi Drop**
		- Additionally grants max Trophy Hunter stacks while airborne.

		**A Thousand Cuts**
		- Attack speed increased to 15% (from 10%).

		**Impatience**
		- Additionally grants 5% dodge distance and 5% dodge speed per Trophy Hunter stack.
		- Sets dodge count to 6, regardless of the wielded weapon.

		**Adrenaline Surge**
		- Changed to 67% cooldown reduction per Trophy Hunter stack (300% only at max stacks).

		**Barge**
		- Now requires more than 3 effective dodges remaining (i.e. banked dodge budget, boosted by Impatience) to proc the push.
		- Push now uses Crunch's (upgraded) ultimate landing stagger explosion.
	$END_TB
]]

--[[

	Talents

]]
--[[
	Dawi Drop
]]
-- With Dawi Drop selected, max Trophy Hunter
mod:hook_safe(CareerAbilityDRSlayer, "_do_leap", function (self)
	local do_leap = self._status_extension.do_leap

	if not do_leap then
		return
	end

	local leap_events = do_leap.leap_events
	local original_start = leap_events.start

	leap_events.start = function (this)
		if original_start then
			original_start(this)
		end

		local unit_3p = this.unit
		local talent_extension = ScriptUnit.has_extension(unit_3p, "talent_system")

		if not talent_extension or not talent_extension:has_talent("bardin_slayer_activated_ability_leap_damage") then -- Dawi Drop only
			return
		end

		local proc_function = ProcFunctions.add_bardin_slayer_passive_buff

		for _ = 1, 4 do -- covers max_stacks 3 (base/Impatience/Adrenaline Surge) and 4 (increased_max_stacks talent)
			proc_function(unit_3p, nil, nil)
		end
	end
end)

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
mod_api.insert_text("bardin_slayer_passive_movement_speed_desc", "Each stack of Trophy Hunter increases movement speed by 10.0%% and dodge range by 5.0%%. Sets dodge count to 6, regardless of the wielded weapon.")
-- Flat dodge count of 6 regardless of weapon, same pattern as No Dawdling in 05_dr_ranger.lua
mod:hook(GenericStatusExtension, "get_dodge_item_data", function (func, self, ...)
	func(self, ...)

	local talent_extension = ScriptUnit.has_extension(self.unit, "talent_system")

	if talent_extension and talent_extension:has_talent("bardin_slayer_passive_movement_speed") then
		self.dodge_count = 6
	end
end)
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
	--stat_buff = "damage_taken", -- Added
	--multiplier = -0.15, -- Added
	explosion_template = "bardin_slayer_activated_ability_landing_stagger_impact", -- Crunch's ult landing stagger (was bardin_slayer_push_on_dodge)
})
-- 3 effective dodges required
mod_api.insert_proc_function("bardin_slayer_push_on_dodge", function (owner_unit, buff, params)
	if Unit.alive(owner_unit) then
		local status_extension = ScriptUnit.has_extension(owner_unit, "status_system")
		local effective_dodges_left = status_extension.dodge_count - status_extension.dodge_cooldown

		if effective_dodges_left > 3 then

			local first_person_extension = ScriptUnit.has_extension(owner_unit, "first_person_system")
			local career_extension = ScriptUnit.has_extension(owner_unit, "career_system")
			local dodge_direction_box = params[1]
			local dodge_direction = dodge_direction_box:unbox()
			local template = buff.template
			local explosion_template = template.explosion_template
			local owner_position = POSITION_LOOKUP[owner_unit]
			local unit_rotation = first_person_extension:current_rotation()
			local career_power_level = career_extension:get_career_power_level()
			local offset_distance = 2
			local flat_unit_rotation = Quaternion.look(Vector3.flat(Quaternion.forward(unit_rotation)), Vector3.up())
			local move_direction = Quaternion.rotate(flat_unit_rotation, dodge_direction)
			local offset_position = owner_position + Vector3.normalize(move_direction) * offset_distance
			local area_damage_system = Managers.state.entity:system("area_damage_system")

			area_damage_system:create_explosion(owner_unit, offset_position, unit_rotation, explosion_template, 1, "career_ability", career_power_level, false)
		end
	end
end)
mod_api.update_talent("dr_slayer", 5, 3, {
	description = "bardin_slayer_push_on_dodge_desc",
	server = "both",
	buffs = {
		"bardin_slayer_push_on_dodge",
		--"tb_bardin_slayer_dodge_range",
		--"tb_bardin_slayer_dodge_speed"
	}
})
mod_api.insert_text("bardin_slayer_push_on_dodge_desc", "Dodging while more than 3 effective dodges remain pushes and staggers nearby enemies.")


