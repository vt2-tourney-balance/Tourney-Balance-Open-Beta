local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Foot Knight
		### Career Ability
		- Baseline ult damage/stagger cleave buffed to 4 (from 2). Exludes wide charge.
		- Baseline ult on_interrupt_blast.radius buffed to 4 (from 3). Excludes wide charge.
		
		### Passives
		**Protective Presence**
		- Aura radius increased to 20 (from 5).
		- Aura damage reduction reduced to 10% (from 15%).

		**CDR on Damage Taken**
		- Reduced ult cooldown gain on damage taken to 0.35 (from 0.5).

		### Talents
		**Staggering Force**
		- Stagger power decreased to 20% (from 35%).

		**Have At Thee!**
		- Now also procs when Mainstay marks an elite with a stagger count, even if the hit doesn't actually stagger it.

		**Crowd Clearer**
		- Duration increased to 5s (from 3s).

		**Rock of Reikland**
		- Global team passive
		- Increased block cost reduction to 30% (from 20%)
		- Added 30% stamina recovery

		**It's Hero Time**
		- Added a 30 second internal cooldown on the refund.
		- No longer refunds if the ultimate is already fully charged.
		
		**Inspiring Blow**
		- Increased cooldown reduction gained to 200% (from 100%) and duration to 1.5s (from 0.5s).
		- Now also procs when Mainstay marks an elite with a stagger count, even if the hit doesn't actually stagger it.

		**Numb to Pain**
		- Invulnerability duration on ult increased to 10s (from 3s).
	$END_TB
]]

--[[

	Ultimate

]]
-- cooldown increase
-- mod_api.update_career_ability_cooldown("es_2", 40)

-- reuse static tables instead of allocating new ones
local charge_cleave_distribution_buffed = {
	attack = 4, -- 2
	impact = 4, -- 2
}
local charge_cleave_distribution_default = {
	attack = 2,
	impact = 2,
}

-- baseline ult buff
-- TODO: needs looking, inconsistency between baseline and wide charge
-- TODO: wide charge description should be 2.5x instead of double width
mod:hook(CareerAbilityESKnight, "_run_ability", function (func, self, ...)
	func(self, ...)

	local owner_unit = self._owner_unit
	local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
	local status_extension = self._status_extension
	local has_battering_ram = talent_extension:has_talent("markus_knight_wide_charge", "empire_soldier", true)

	if has_battering_ram then
		-- battering ram replaces the baseline ult buff entirely
		PowerLevelTemplates.cleave_distribution_markus_knight_charge = charge_cleave_distribution_default
		status_extension.do_lunge.damage.on_interrupt_blast.radius = 3 -- 3, remove buff from baseline for battering ram specifically
		status_extension.do_lunge.damage.width = 5
		status_extension.do_lunge.damage.interrupt_on_max_hit_mass = false
	else
		-- increase radius of explosion and double cleave of explosion and normal charge
		PowerLevelTemplates.cleave_distribution_markus_knight_charge = charge_cleave_distribution_buffed
		status_extension.do_lunge.damage.on_interrupt_blast.radius = 4 -- 3
	end
end)

--[[

	Passives

]]
--[[
	Protective Presence
]]
-- Increase aura range - Repeat for all lvl 20 talents, because game creates snapshot of original values at load time
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_passive", {
	range = 20 -- 5
})
-- Nerf of aura damage reduction - Repeat for all lvl 20 talents, because game creates snapshot of original values at load time
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_passive_defence_aura", {
	multiplier = -0.1 -- -0.15
})
mod_api.insert_text("career_passive_desc_es_2a_2", "Aura that reduces damage taken by 10%")

--[[
	Rock of Reikland - global passive
]]
mod_api.insert_talent_buff_template("empire_soldier", "tb_markus_knight_rock_of_reikland_buff", {
	{ 
		name = "tb_markus_knight_rock_of_reikland_buff", 
		max_stacks = 1, 
		stat_buff = "block_cost", 
		multiplier = -0.3 
	},
	{ 
		name = "tb_markus_knight_rock_of_reikland_buff", 
		max_stacks = 1, 
		stat_buff = "fatigue_regen", 
		multiplier = 0.3
	},
	{ 
		name = "tb_markus_knight_rock_of_reikland_buff", 
		max_stacks = 1, 
		stat_buff = "damage_taken", 
		multiplier = -0.1 
	},
})
-- Same loop as activate_buff_on_distance (buff_function_templates.lua), minus the distance check
mod_api.insert_buff_function("tb_activate_buff_on_team", function (owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local side = Managers.state.side.side_by_unit[owner_unit]

	if not side then
		return
	end

	local buff_to_add = buff.template.buff_to_add
	local buff_system = Managers.state.entity:system("buff_system")
	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

	for i = 1, #player_and_bot_units do
		local unit = player_and_bot_units[i]

		if Unit.alive(unit) then
			local buff_extension = ScriptUnit.extension(unit, "buff_system")

			if not buff_extension:has_buff_type(buff_to_add) then
				buff_system:add_buff(unit, buff_to_add, owner_unit, true)
			end
		end
	end
end)
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_passive_block_cost_aura", {
	buff_to_add = "tb_markus_knight_rock_of_reikland_buff",
	update_func = "tb_activate_buff_on_team",
})
mod_api.update_talent("es_knight", 4, 1, {
	buffs = { "markus_knight_passive_block_cost_aura" },
	description = "tb_markus_knight_rock_of_reikland_desc",
	description_values = {},
})
mod_api.insert_text("tb_markus_knight_rock_of_reikland_desc", "Protective Presence is always active and grants 30%% block cost reduction and 30%% stamina regeneration.")

--[[
	Comrades in Arms - Adjustment from Passive
]]
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_guard_defence", {
	buff_to_add = "markus_knight_guard_defence_buff",
	stat_buff = "damage_taken",
	update_func = "activate_buff_on_closest_distance",
	remove_buff_func = "remove_aura_buff",
	range = 20 -- 5
})
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_guard", {
	buff_to_add = "markus_knight_passive_power_increase_buff",
	stat_buff = "power_level",
	remove_buff_func = "remove_aura_buff",
	icon = "markus_knight_passive_power_increase",
	update_func = "activate_buff_on_closest_distance",
	range = 20 -- 5
})

--[[
	That's Bloody Teamwork - Adjustment from Passive
]]
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_damage_taken_ally_proximity", {
	buff_to_add = "markus_knight_damage_taken_ally_proximity_buff",
	range = 20, -- 5
	update_func = "activate_party_buff_stacks_on_ally_proximity", -- TODO: Check - Removed proc function, might break, replaced buff.range replaced w/ template.range
	chunk_size = 1,
	max_stacks = 3,
	remove_buff_func = "remove_party_buff_stacks"
})


--[[
	Unlisted: Ult CD on Taking Damage
]]
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_ability_cooldown_on_damage_taken", {
	bonus = 0.35 -- 0.5
})

--[[

	Talents

]]
--[[
	Staggering Force
]]
-- Stagger power decreased to 20% (from 35%)
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_power_level_impact", {
	multiplier = 0.2 --0.35
})
mod_api.update_talent("es_knight", 2, 1, {
	description_values = { -- update description
		{
			value_type = "percent",
			value = 0.2, -- buff_tweak_data.markus_knight_power_level_impact.multiplier
		}
	},
})
--[[
	Have At Thee! 
	Proc from Mainstay stagger count on an elite
	thp_stagger_damage_changes/01_damage_calc_changes.lua > mod:hook_origin(DamageUtils, "server_apply_hit", ...)
]]
mod_api.update_talent("es_knight", 2, 2, { -- update description
	description_values = {
	},
})
mod_api.insert_text("markus_knight_power_level_on_stagger_elite_desc", "Inflicting stagger counts on an elite enemy increases power by 15.0%% for 10 seconds.")

--[[
	Crowd Clearer
]]
-- Duration increased to 5s (from 3s)
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_attack_speed_on_push_buff", {
	duration = 5 -- 3
})
mod_api.update_talent("es_knight", 2, 3, { -- update description
	description_values = {
		{
			value_type = "percent",
			value = 0.15 -- buff_tweak_data.markus_knight_attack_speed_on_push_buff.multiplier
		},
		{
			value = 5 -- buff_tweak_data.markus_knight_attack_speed_on_push_buff.duration
		}
	},
})

--[[
	It's Hero Time
]]
-- 30s ICD nerf
mod_api.insert_buff_template("tb_markus_knight_hero_time_ready_buff", {
	icon = "markus_knight_movement_speed_on_incapacitated_allies",
})
mod_api.insert_buff_template("tb_markus_knight_hero_time_cooldown_buff", {
	icon = "markus_knight_movement_speed_on_incapacitated_allies",
	is_cooldown = true,
	duration = 30,
	duration_end_func = "add_buff_local",
	buff_to_add = "tb_markus_knight_hero_time_ready_buff",
})
mod_api.insert_buff_function("markus_hero_time_reset", function (unit, buff, params)
	local player_unit = unit

	if not Unit.alive(player_unit) then
		return
	end

	local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")

	if not buff_extension or buff_extension:has_buff_type("tb_markus_knight_hero_time_cooldown_buff") then
		return
	end

	local career_extension = ScriptUnit.has_extension(player_unit, "career_system")

	if not career_extension or career_extension:current_ability_cooldown(1) == 0 then
		return
	end

	career_extension:reduce_activated_ability_cooldown_percent(1) -- 0.7

	local ready_buff = buff_extension:get_buff_type("tb_markus_knight_hero_time_ready_buff")

	if ready_buff then
		buff_extension:remove_buff(ready_buff.id)
	end

	buff_extension:add_buff("tb_markus_knight_hero_time_cooldown_buff")
end)
mod_api.insert_text("markus_knight_charge_reset_on_incapacitated_allies_desc", "Refunds 100% of cooldown upon allied incapacitation, unless the ultimate is already fully charged. 30 second internal cooldown.")

-- Fix Hero Time not proccing if ally already disabled
mod_api.insert_buff_function("markus_knight_movespeed_on_incapacitated_ally", function (owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local side = Managers.state.side.side_by_unit[owner_unit]
	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
	local num_units = #player_and_bot_units
	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local buff_system = Managers.state.entity:system("buff_system")
	local template = buff.template
	local buff_to_add = template.buff_to_add
	local disabled_allies = 0

	for i = 1, num_units do
		local unit = player_and_bot_units[i]
		local status_extension = ScriptUnit.extension(unit, "status_system")
		local is_disabled = status_extension:is_disabled()

		if is_disabled then
			disabled_allies = disabled_allies + 1
		end
	end

	if not buff.disabled_allies then
		buff.disabled_allies = 0
	end

	if buff_extension:has_buff_type(buff_to_add) then
		if disabled_allies <= buff.disabled_allies then
			local buff_id = buff.buff_id

			if buff_id then
				buff_system:remove_server_controlled_buff(owner_unit, buff_id)

				buff.buff_id = nil
			end
		end
	elseif disabled_allies > 0 and disabled_allies > buff.disabled_allies then
		buff.buff_id = buff_system:add_buff(owner_unit, buff_to_add, owner_unit, true)
	end

	buff.disabled_allies = disabled_allies

	-- It's Hero Time: show the "ready" icon
	if not buff_extension:has_buff_type("tb_markus_knight_hero_time_ready_buff") and not buff_extension:has_buff_type("tb_markus_knight_hero_time_cooldown_buff") then
		buff_system:add_buff(owner_unit, "tb_markus_knight_hero_time_ready_buff", owner_unit, true)
	end
end)

--[[
	Inspiring Blow
	Proc from Mainstay stagger count on an elite
	thp_stagger_damage_changes/01_damage_calc_changes.lua > mod:hook_origin(DamageUtils, "server_apply_hit", ...)
]]
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_cooldown_on_stagger_elite", {
	buff_func = "buff_on_stagger_enemy"
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_cooldown_buff", {
	duration = 0.5,
	multiplier = 1,
	icon = "markus_knight_improved_passive_defence_aura" -- added icon
})
mod_api.insert_text("markus_knight_cooldown_on_stagger_elite_desc", "Inflicting stagger counts on an elite enemy accelerates the cooldown of nearby allies by 100%% for 0.5 seconds.")

--[[
	Numb to Pain
]]
-- Invulnerability on ult duration increased to 10s
mod_api.update_talent_buff_template("empire_soldier", "markus_knight_ability_invulnerability_buff", {
	duration = 5 -- 3
})
mod_api.update_talent("es_knight", 6, 1, {
	description_values = {
		{
			value = 5 -- 3
		}
	},
})



