local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Slayer
		### Talents
		**Dawi Drop**
		- Additionally grants max Trophy Hunter stacks (up to 5, with High Tally) while airborne.

		**A Thousand Cuts**
		- Attack speed increased to 15% (from 10%).

		**Impatience**
		- Additionally grants 5% dodge distance and 5% dodge speed per Trophy Hunter stack.

		**High Tally**
		- Increases Trophy Hunter's maximum stacks to 5 (from 4).

		**Adrenaline Surge**
		- Changed to 67% cooldown reduction per Trophy Hunter stack (300% only at max stacks).

		**Barge**
		- Push now staggers with medium_push strength and radius (no real damage), up from light_push.
		- Instead of taking damage, Bardin now bleeds out 90% of it over 10 seconds instea (ignores Barkskin).
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
mod_api.insert_text("bardin_slayer_passive_movement_speed_desc", "Each stack of Trophy Hunter increases movement speed by 10.0%% and dodge range by 5.0%%. Sets dodge count to 6.")

--[[
	High Tally
]]
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_slayer_passive_increased_max_stacks", {
	max_stacks = 5, -- 4
})
mod_api.insert_text("bardin_slayer_passive_increased_max_stacks_desc", "Increases Trophy Hunter's maximum stacks to 5 (from 4).")

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
-- Medium push
ExplosionTemplates.bardin_slayer_push_on_dodge.explosion.damage_profile = "medium_push" -- light_push
ExplosionTemplates.bardin_slayer_push_on_dodge.explosion.radius = 6 -- 1.5, Crunch's radius
ExplosionTemplates.bardin_slayer_push_on_dodge.explosion.max_damage_radius = 3 -- 1.5, Crunch's max_damage_radius
mod_api.update_talent("dr_slayer", 5, 3, {
	description = "bardin_slayer_push_on_dodge_desc",
	server = "both",
	buffs = {
		"bardin_slayer_push_on_dodge",
	}
})
mod_api.insert_text("bardin_slayer_push_on_dodge_desc", "Effective dodges push nearby enemies. Instead of taking damage, Bardin bleeds out 90% of it over 10 seconds instead.")

-- Barge bleed: pooled DoT buff like Warrior Priest Shield-of-Faith
-- new hits add to it and refresh duration
local TB_BARGE_BLEED_SOURCE = "life_tap"
local TB_BARGE_BLEED_TYPE = "knockdown_bleed"
local TB_BARGE_BLEED_DURATION = 10

local function tb_barge_has_talent(unit)
	local talent_extension = ScriptUnit.has_extension(unit, "talent_system")

	return not not (talent_extension and talent_extension:has_talent("bardin_slayer_push_on_dodge", "dwarf_ranger", true))
end

-- add_buff params don't reach reapply (the common case here), so smuggle the amount via upvalue instead
local tb_barge_pending_damage_amount = 0

mod_api.insert_buff_function("tb_barge_bleed_add_value", function (unit, buff, params)
	buff.value = (buff.value or 0) + tb_barge_pending_damage_amount
	buff.ticks_left = TB_BARGE_BLEED_DURATION
end)
mod_api.insert_buff_function("tb_barge_bleed_tick", function (unit, buff, params)
	if not Managers.state.network.is_server or not ALIVE[unit] then
		return
	end

	local ticks_left = buff.ticks_left or 0

	if ticks_left <= 0 or not buff.value or buff.value <= 0 then
		return
	end

	local damage_per_tick = buff.value / ticks_left

	buff.value = buff.value - damage_per_tick
	buff.ticks_left = ticks_left - 1

	DamageUtils.add_damage_network(unit, unit, damage_per_tick, "full", TB_BARGE_BLEED_TYPE, nil, Vector3(0, 0, 0), TB_BARGE_BLEED_SOURCE, nil, unit, nil, nil, nil, nil, nil, nil, nil, nil, 1)
end)
mod_api.insert_buff_template("tb_bardin_slayer_barge_bleed", {
	icon = "bardin_slayer_crit_chance", -- twich bleed icon
	debuff = true,
	max_stacks = 1,
	duration = TB_BARGE_BLEED_DURATION,
	update_frequency = 1,
	refresh_durations = true,
	apply_buff_func = "tb_barge_bleed_add_value",
	reapply_buff_func = "tb_barge_bleed_add_value",
	update_func = "tb_barge_bleed_tick",
})
mod_api.insert_text("tb_bardin_slayer_barge_bleed", "Bleeding")

-- Intercepts the instance before it reaches the health pool; banks it into the bleed pool
mod:hook(PlayerUnitHealthExtension, "add_damage", function (func, self, attacker_unit, damage_amount, hit_zone_name, damage_type, hit_position, damage_direction, damage_source_name, ...)
	local unit = self.unit

	if self.is_server and damage_amount and damage_amount > 0 and damage_source_name ~= TB_BARGE_BLEED_SOURCE and damage_source_name ~= "temporary_health_degen" and HEALTH_ALIVE[unit] and tb_barge_has_talent(unit) then
		local buff_extension = ScriptUnit.extension(unit, "buff_system")

		-- Hardcoded Barge Damage Reduction
		tb_barge_pending_damage_amount = damage_amount * 0.9
		buff_extension:add_buff("tb_bardin_slayer_barge_bleed")
		tb_barge_pending_damage_amount = 0

		return func(self, attacker_unit, 0, hit_zone_name, damage_type, hit_position, damage_direction, damage_source_name, ...)
	end

	return func(self, attacker_unit, damage_amount, hit_zone_name, damage_type, hit_position, damage_direction, damage_source_name, ...)
end)

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

		for _ = 1, 5 do -- covers max_stacks 3 (base/Impatience/Adrenaline Surge) and 5 (High Tally)
			proc_function(unit_3p, nil, nil)
		end
	end
end)

