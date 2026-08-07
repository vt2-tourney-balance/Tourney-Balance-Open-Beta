local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local is_local = require("scripts/mods/TourneyBalance/_api/shared_utils").is_local

--[[
	$BEGIN_TB
		title	: 	Mercenary Changes
		ult		: 	-
		passives: 	Paced Strikes 		- Hitting 3 enemies in one swing grants 10% increased attack speed for 6 seconds to the Krubersreik 5, or 4.
		talent23: 	Helborg's Tutelage 	- Every 5 hits grant a guaranteed critical strike. Random Crits can still occur.
		talent42: 	Enhanced Training	- Paced Strikes now increases attack speed by 20%
		talent43: 	Strike Together 	- Paced Strikes activates on hitting 1 enemy.
	$END_TB
]]

--[[

	Passives

]]
--[[
	Paced Strikes
	Enhanced Trainig
	Strike Together
]]
-- Give Paced Strikes to team Passive
local function add_buff_to_team(owner_unit, buff_name)
	local buff_system = Managers.state.entity:system("buff_system")
	local side = Managers.state.side.side_by_unit[owner_unit]
	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

	for i = 1, #player_and_bot_units do
		local unit = player_and_bot_units[i]

		if HEALTH_ALIVE[unit] then
			buff_system:add_buff(unit, buff_name, owner_unit, false)
		end
	end
end
-- Refactored proc function
mod_api.insert_proc_function("gain_markus_mercenary_passive_proc", function (owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local attack_type = params[2]
	if not (ALIVE[owner_unit] and (attack_type == "light_attack" or attack_type == "heavy_attack")) then
		return
	end

	local buff_template = buff.template
	local target_number = params[4]
	local buff_to_add = buff_template.buff_to_add
	local buff_system = Managers.state.entity:system("buff_system")
	local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
	local passive_triggered = false

	if target_number and target_number >= 3 then
		-- Base Paced Strikes/Strike Together
		add_buff_to_team(owner_unit, buff_to_add)
		passive_triggered = true

		 -- Enhanced Training
		if talent_extension:has_talent("markus_mercenary_passive_improved") then
			buff_system:add_buff(owner_unit, "markus_mercenary_passive_improved", owner_unit, false)
		 -- Reikland Reaper
		elseif talent_extension:has_talent("markus_mercenary_passive_power_level_on_proc") then
			buff_system:add_buff(owner_unit, "markus_mercenary_passive_power_level", owner_unit, false)
		end

	-- Paced Strikes on hit
	elseif target_number and target_number >= 1 and talent_extension:has_talent("markus_mercenary_passive_group_proc") then
		add_buff_to_team(owner_unit, buff_to_add)
		passive_triggered = true
	end

	-- Blade Barrier correctly procs when Paced Strike is active
	if passive_triggered and talent_extension:has_talent("markus_mercenary_passive_defence_on_proc") then
		buff_system:add_buff(owner_unit, "markus_mercenary_passive_defence", owner_unit, false)
	end
end)
-- Enhanced Training adjustement, because Strike Together is passive
mod_api.update_talent_buff_template("empire_soldier", "markus_mercenary_passive_improved", {
    multiplier = 0.1 -- 0.2
})
mod_api.insert_text("career_passive_desc_es_3a", "Hitting 3 enemies in one swing grants 10% increased attack speed for 6 seconds to the Krubersreik 5, or 4.")
mod_api.insert_text("markus_mercenary_passive_improved_desc", "Paced Strikes now increases attack speed by 20.0%%")
mod_api.insert_text("markus_mercenary_passive_group_proc_desc", "Paced Strikes activates when hitting 1 enemy.")

--[[

	Talents

]]
--[[
	Helborg's Tutelage
]]
-- Added Random Crits: clears the vanilla "no_random_crits" talent perk
Talents.empire_soldier[52].perks = nil -- talent_settings_markus.lua:2503
-- on_hit only consumes the stack when an enemy is hit, but not if that hit was critical
mod_api.update_talent_buff_template("empire_soldier", "markus_mercenary_crit_count_buff", {
	event = "on_hit" -- "on_critical_action"
})
mod_api.insert_talent_text("markus_mercenary_crit_count", "Hellborg's Tutelage", "Every 5 hits grant a guaranteed critical strike. Random Crits can still occur.")
-- (FIX) Clients get 2 stack counts per hit
local add_buff_on_first_target_hit = ProcFunctions.add_buff_on_first_target_hit
mod_api.insert_proc_function("tb_add_buff_on_first_target_hit_helborg", function (owner_unit, buff, params)
	if is_local(owner_unit) then 
		add_buff_on_first_target_hit(owner_unit, buff, params)
	end
end)
mod_api.update_talent_buff_template("empire_soldier", "markus_mercenary_crit_count", {
	buff_func = "tb_add_buff_on_first_target_hit_helborg" --"add_buff_on_first_target_hit"
})


