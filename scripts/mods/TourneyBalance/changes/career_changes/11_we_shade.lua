local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local is_server = require("scripts/mods/TourneyBalance/_api/shared_utils").is_server

--[[
	$BEGIN_TB
		---
		## Shade
		### Career Ability
		- Lord and Boss boost_curve_multiplier_override incresed to 2 (from 1.8/1.5).
		- Reduced stealth duration to 3s (from 5).

		### Passives
		**Assassin's Blade**
		- Added Spring-Heeled Assassin and Gladerunner as one passive.
		- Increased movement speed by 10%. Critical hits and entering stealth further increase movement speed by 10% for 5s.

		**Blur**
		- Increased parry window to 0.75s (from 0.5s).


		### Talents
		**Cruelty**
		- Increased crit damage bonus to 80% (from 50%) and crit rate bonus to 5% (from 0%).

		**Exploit Weakness**
		- Poison, Bleed, and Burn each individually increase damage dealt by 20%. Stacks additive, up to 60% against a target suffering from all three.

		**Bloodfetcher**
		- Changed ammo refund to 5% (from 1 ammo).

		**Blood Drinker**
		- Also triggers when entering stealth.

		**Elthrai's Mockery** (new, replaces Spring-Heeled Assassin)
		- Hitting enemies taunts them for 5s. Deals 25% more damage to enemies Kerillian has taunted.

		**Lingering Shadow** (new, replaces Gladerunner)
		- Attacking from Blur's stealth no longer ends it.
		- Increases the duration of invisibility granted by Blur by 0.5 seconds.

		**Shimmer Strike**
		- Limited extending stealth duration to 4s (from uncapped).

		**Hungry Wind**
		- Additionally after leaving infiltrate all attacks are considered backstabs.
	$END_TB
]]

--[[

	Ultimate

]]
-- Raises the vanilla boss/elite cap on boost_damage_multiplier
-- The only source big enough to hit this cap is Shade's ult (shade_melee_boost grants 4)
-- Force-load Minotaur
if not Breeds.beastmen_minotaur then
	dofile("scripts/settings/breeds/breed_beastmen_minotaur")
end
local shade_boost_capped_breeds = {
	"chaos_exalted_sorcerer", -- 1.8
	"chaos_exalted_sorcerer_drachenfels", -- 1.8
	"chaos_spawn", -- 1.8
	"chaos_troll", -- 1.8
	"skaven_grey_seer", -- 1.8
	"skaven_rat_ogre", -- 1.8
	"skaven_storm_vermin_warlord", -- 1.8
	"skaven_stormfiend", -- 1.8
	"skaven_stormfiend_boss", -- 1.8
	"beastmen_minotaur", -- 1.5
	"chaos_exalted_champion_warcamp", -- 1.5
	"chaos_exalted_champion_norsca", -- 1.5
}
for _, breed_name in ipairs(shade_boost_capped_breeds) do
	Breeds[breed_name].boost_curve_multiplier_override = 2
end

--[[
	Infiltrate
	Shimmer Strike
	Hungry Wind
	Cloak of Pain
]]
-- Reduce ult stealth duration
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability", {
	duration = 2.5 -- 5
})
-- internal
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_short_blocker", {
	duration = 2.5 -- 5
})
--[[
	Hungry Wind
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_phasing", {
	duration = 2.5 -- 5
})
--[[
	Cloak of Pain
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_restealth", {
	duration = 2.5 -- 5
})
mod_api.insert_text("career_active_desc_we_1_2", "Kerillian becomes undetectable, can pass through enemies, and deals greatly increased melee damage. Lasts for 2.5 seconds or until she deals damage.")

--[[

	Passive
]]
--[[
	Blur
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_passive_stealth_parry", {
	event = "on_timed_block_long", -- "on_timed_block"
})
--[[
	Spring-Heeled Gladerunner
]]
-- Move Spring-Heeled Assassin (movement speed on crit) and Gladerunner (flat movement speed) onto the base passive
mod_api.insert_career_passives("we_1", {
	"kerillian_shade_movement_speed_on_critical_hit",
	"kerillian_shade_movement_speed",
})
-- Also triggers the crit movement speed burst when Blur activates, not just on critical hit
-- (re-inserted with the original on-crit entry kept by reference, since a 2nd entry can't be merged in via update_talent_buff_template)
local original_movement_speed_on_critical_hit_entry = TalentBuffTemplates.wood_elf.kerillian_shade_movement_speed_on_critical_hit.buffs[1]
mod_api.insert_talent_buff_template("wood_elf", "kerillian_shade_movement_speed_on_critical_hit", {
	original_movement_speed_on_critical_hit_entry,
	{
		buff_func = "add_buff",
		buff_to_add = "kerillian_shade_movement_speed_on_critical_hit_buff",
		event = "on_invisible",
	},
})
-- Reduced the proc's own movement speed bonus, since it now also fires whenever Kerillian enters any stealth (not just on crit)
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_movement_speed_on_critical_hit_buff", {
	multiplier = 1.1 -- 1.2
})
mod_api.insert_text("career_passive_desc_we_1b_2", "Double damage when attacking enemies from behind with melee attacks. Kerillian moves 10.0% faster. Critical hits or entering stealth increases movement speed by a further 10.0% for 5 seconds.")
mod_api.insert_career_perk_descriptions("we_1", "tb_we_1_gladerunner")

--[[

	Talents

]]
--[[
	Cruelty
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_increased_critical_strike_damage", {
	multiplier = 0.8 -- 0.5
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_increased_critical_strike_damage_chance", {
	stat_buff = "critical_strike_chance",
	bonus = 0.05 -- Added 5% crit
})
mod_api.update_talent("we_shade", 2, 1, {
	description = "kerillian_shade_increased_critical_strike_damage_desc",
	description_values = {},
	buffs = {
		"kerillian_shade_increased_critical_strike_damage",
		"tb_kerillian_shade_increased_critical_strike_damage_chance",
	},
})
mod_api.insert_text("kerillian_shade_increased_critical_strike_damage_desc", "Increases critical strike damage bonus by 80.0% and critical strike chance by 5.0%.")

--[[
	Exploit Weakness
]]
-- Marker perk so the shared damage hook (thp_stagger_damage_changes/02_damage_taken_changes.lua) can detect this talent and apply the split poison/bleed/burn bonus instead of the vanilla single poison-or-bleed bonus
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_increased_damage_on_poisoned_or_bleeding_enemy", {
	perks = {
		"kerillian_shade_increased_damage_on_poisoned_or_bleeding_enemy",
	},
})
mod_api.update_talent("we_shade", 2, 2, {
	description = "kerillian_shade_increased_damage_on_poisoned_or_bleeding_enemy_desc",
	description_values = {},
})
mod_api.insert_text("kerillian_shade_increased_damage_on_poisoned_or_bleeding_enemy_desc", "Increases damage by 20.0% for each negative status effect (poison, bleed, or burn) afflicting the enemy.")

--[[
	Bloodfletcher
]]
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_backstabs_replenishes_ammunition", {
	buff_func = "ammo_fraction_gain_on_backstab_tb",
	event = "on_backstab",
	ammo_bonus_fraction = 0.05,
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_backstabs_replenishes_ammunition_cooldown", {
	icon = "kerillian_shade_backstabs_replenishes_ammunition",
	duration = 2,
})
mod_api.insert_proc_function("ammo_fraction_gain_on_backstab", function (owner_unit, buff, params)
    local player = Managers.player:owner(owner_unit)

    if player and player.remote then
        return
    end

	local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

	if buff_extension and not buff_extension:has_buff_type("tb_kerillian_shade_backstabs_replenishes_ammunition_cooldown") then
		if ALIVE[owner_unit] then
			local buff_template = buff.template
			local weapon_slot = "slot_ranged"
			local inventory_extension = ScriptUnit.extension(owner_unit, "inventory_system")
			local slot_data = inventory_extension:get_slot_data(weapon_slot)
			local right_unit_1p = slot_data.right_unit_1p
			local left_unit_1p = slot_data.left_unit_1p
			local ammo_extension = GearUtils.get_ammo_extension(right_unit_1p, left_unit_1p)
			local ammo_bonus_fraction = buff_template.ammo_bonus_fraction

			-- Only refund 5% ammo
			if ammo_extension then
				local ammo_amount = math.max(math.round(ammo_extension:max_ammo() * ammo_bonus_fraction), 1)
				ammo_extension:add_ammo_to_reserve(ammo_amount)
			end
		end

		buff_extension:add_buff("tb_kerillian_shade_backstabs_replenishes_ammunition_cooldown")
	end
end)
mod_api.update_talent("we_shade", 4, 3, {
	description = "kerillian_shade_backstabs_replenishes_ammunition_desc",
	description_values = {},
	buffs = {
		"tb_kerillian_shade_backstabs_replenishes_ammunition",
	},
})
mod_api.insert_text("kerillian_shade_backstabs_replenishes_ammunition_desc", "Backstabs return 5% of maximum ammunition. 2 second cooldown.")

--[[
	Blood Drinker
]]
-- Also triggers the damage reduction buff when Blur activates, not just on critical hit
-- (re-inserted with the original on-crit entry kept by reference, since a 2nd entry can't be merged in via update_talent_buff_template)
local original_damage_reduction_on_critical_hit_entry = TalentBuffTemplates.wood_elf.kerillian_shade_damage_reduction_on_critical_hit.buffs[1]
mod_api.insert_talent_buff_template("wood_elf", "kerillian_shade_damage_reduction_on_critical_hit", {
	original_damage_reduction_on_critical_hit_entry,
	{
		buff_func = "add_buff",
		buff_to_add = "kerillian_shade_damage_reduction_on_critical_hit_buff",
		event = "on_invisible",
	},
})
mod_api.update_talent("we_shade", 5, 1, {
	description = "kerillian_shade_damage_reduction_on_critical_hit_desc",
	description_values = {},
})
mod_api.insert_text("kerillian_shade_damage_reduction_on_critical_hit_desc", "Critical hits or entering stealth reduce damage taken by 20.0% for 5 seconds.")

--[[
	Elthrai's Mockery (new, replaces Spring-Heeled Assassin, which moved to the passive as part of Spring-Heeled Gladerunner)
]]
mod_api.insert_proc_function("tb_shade_taunt_on_hit", function (owner_unit, buff, params)
	if not is_server() then
		return
	end

	local hit_unit = params[1]

	if not hit_unit or not HEALTH_ALIVE[hit_unit] then
		return
	end

	local ai_extension = ScriptUnit.has_extension(hit_unit, "ai_system")

	if not ai_extension then
		return
	end

	local breed = ai_extension:breed()

	if breed.ignore_taunts then
		return
	end

	local blackboard = ai_extension:blackboard()
	local t = Managers.time:time("game")

	blackboard.taunt_unit = owner_unit
	blackboard.taunt_end_time = t + buff.template.taunt_duration
	blackboard.target_unit = owner_unit
	blackboard.target_unit_found_time = t
end)
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_taunt_on_hit", {
	buff_func = "tb_shade_taunt_on_hit",
	event = "on_hit",
	taunt_duration = 5,
	perks = {
		"tb_kerillian_shade_elthrais_mockery", -- marker perk read by the shared damage hook for the +20% taunted-enemy damage bonus
	},
})
mod_api.insert_talent("we_shade", 5, 2, "tb_kerillian_shade_elthrais_mockery", {
	buffer = "server",
	icon = "kerillian_shade_movement_speed_on_critical_hit", -- reuse Spring-Heeled Assassin's old icon, since this replaces it in this slot
	buffs = {
		"tb_kerillian_shade_taunt_on_hit",
	},
})
mod_api.insert_talent_text("tb_kerillian_shade_elthrais_mockery", "Elthrai's Mockery", "Hitting enemies taunts them for 5 seconds. Deals 20.0% more damage to enemies Kerillian has taunted.")

--[[
	Lingering Shadow (new, replaces Gladerunner, which moved to the passive as part of Spring-Heeled Gladerunner)
]]
mod_api.insert_proc_function("tb_shade_extend_blur_duration", function (owner_unit, buff, params)
	if not ALIVE[owner_unit] then
		return
	end

	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local blur_buff = buff_extension:get_non_stacking_buff("kerillian_shade_dash_stealth_active")

	-- end_time isn't always populated on initial apply (only on an explicit refresh), so derive it from
	-- start_time + duration instead of incrementing a field that may still be nil
	if blur_buff and blur_buff.duration and blur_buff.start_time then
		blur_buff.duration = blur_buff.duration + 0.5
		blur_buff.end_time = blur_buff.start_time + blur_buff.duration
	end
end)
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_lingering_shadow_duration", {
	buff_func = "tb_shade_extend_blur_duration",
	event = "on_invisible",
})
-- Overrides the vanilla proc so attacking from Blur's stealth no longer ends it, but only for players with this talent
mod_api.insert_proc_function("shade_short_stealth_on_hit", function (owner_unit, buff, params)
	if ALIVE[owner_unit] then
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")

		if talent_extension:has_talent("tb_kerillian_shade_lingering_shadow") then
			return
		end

		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

		buff_extension:remove_buff(buff.id)
	end
end)
mod_api.insert_talent("we_shade", 5, 3, "tb_kerillian_shade_lingering_shadow", {
	buffer = "both",
	icon = "kerillian_shade_movement_speed", -- reuse Gladerunner's old icon, since this replaces it in this slot
	buffs = {
		"tb_kerillian_shade_lingering_shadow_duration",
	},
})
mod_api.insert_talent_text("tb_kerillian_shade_lingering_shadow", "Lingering Shadow", "Increases the duration of invisibility granted by Blur by 0.5 seconds. Attacking while in Blur's stealth no longer ends it.")

--[[
	Shimmer Strike
]]
-- protects from proccing multiple times per swing
mod_api.insert_talent_buff_template("wood_elf", "tb_shimmer_abuser", {
	duration = 0.1,
	max_stacks = 1
})
-- removes a shimmer charge when you kill an elite/special
mod_api.insert_talent_buff_template("wood_elf", "tb_shimmer_handler", {
	buff_func = "tb_shimmer_control",
	buff_to_remove = "tb_shimmer_charges",
	event = "on_kill_elite_special",
	max_stacks = 1
})
mod_api.insert_talent_buff_template("wood_elf", "tb_shimmer_activator", {
	buff_func = "add_buff_reff_buff_stack",
	buff_to_add = "tb_shimmer_charges",
	event = "on_ability_activated",
	max_stacks = 1,
	amount_to_add = 4, -- gives 4 shimmer uses when you ult
	reference_buff = "tb_shimmer_handler"
})
-- controls how many shimmer uses you have left
mod_api.insert_talent_buff_template("wood_elf", "tb_shimmer_charges", {
	buff_func = "shade_activated_ability_on_hit",
	max_stacks = 4, -- maximum shimmer uses at once
	icon = "kerillian_shade_passive_stealth_on_backstab_kill"
})
mod_api.insert_talent_buff_template("wood_elf", "kerillian_shade_ult_invis_combo_window", {
	buff_func = "shade_combo_stealth_extend_on_kill",
	duration = 0.3,
	refresh_durations = true,
	event = "on_kill_elite_special",
	extend_time = 1,                                           
	max_stacks = 1,
	icon = "kerillian_shade_passive_stealth_on_backstab_kill",
	remove_buff_func = "kerillian_shade_missed_combo_window"
})
mod_api.insert_proc_function("shade_combo_stealth_on_hit", function (owner_unit, buff, params)
	if ALIVE[owner_unit] then
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
		
		if not buff_extension:has_buff_type("kerillian_shade_ult_invis_combo_blocker") then
			if buff_extension:num_buff_stacks("tb_shimmer_charges") > 0 then -- only gives shimmer buff if you have charges
				buff_extension:add_buff("kerillian_shade_ult_invis_combo_window")
			end
			if buff_extension:num_buff_stacks("tb_shimmer_charges") <= 0 then -- always removes invis if you have no charges and hit an enemy
				buff_extension:remove_buff(buff.id)
			end
		end
	end
end)
mod_api.insert_proc_function("tb_shimmer_control", function (owner_unit, buff, params)
	if ALIVE[owner_unit] then
		local buff_template = buff.template
		local buff_name = buff_template.buff_to_remove
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
		local buffs = buff_extension:get_stacking_buff(buff_name)
		
		if buffs then
			local num_stacks = #buffs
			
			if not buff_extension:has_buff_type("tb_shimmer_abuser") then
				if num_stacks > 0 then
					local buff_id = buffs[num_stacks].id

					buff_extension:remove_buff(buff_id)
					buff_extension:add_buff("tb_shimmer_abuser")
				end
			end
		end
	end
end)
mod_api.update_talent("we_shade", 6, 1, {
	description = "kerillian_shade_activated_stealth_combo_desc",
	description_values = {},
	buffs = {
		"tb_shimmer_activator", -- adds necessary buffs to shimmer talent to handle having capped uses
		"tb_shimmer_handler"
	}
})
mod_api.insert_text("kerillian_shade_activated_stealth_combo_desc", "Leaving Infiltrate grants stealth for 3 seconds. Killing an Elite or Special extends this duration by 1 second up to a maximum of 4 times.")

--[[
	Hungry Wind
]]
-- All attacks count as backstabs for that same 10s window
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_power_buff", {
	perks = {
		"guaranteed_backstab",
	},
})
mod_api.update_talent("we_shade", 6, 2, {
	description = "kerillian_shade_activated_ability_phasing_desc",
	description_values = {},
})
mod_api.insert_text("kerillian_shade_activated_ability_phasing_desc", "Leaving Infiltrate grants Kerillian 10% movement speed and 15% Power with the ability to pass through enemies for 10 seconds. All attacks are considered backstabs for the duration. Infiltrate no longer grants bonus damage.")


