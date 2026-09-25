local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Shade
		### Career Ability
		- Lord and Boss boost_curve_multiplier_override incresed to 2 (from 1.8/1.5).
		- Reduced Infiltrate stealth duration to 3s (from 5s).

		### Passives
		**Assassin's Blade**
		- Added Gladerunner to the passive.
		- Increased movement speed by 10%.

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
		- Critical hits also restore 3 permanent health.

		**Elthrai's Mockery** (new, replaces Spring-Heeled Assassin)
		- Blur no longer grants invisibility. Instead grants 6 guaranteed backstabs and 1 guaranteed critical strike.
		- Melee attacks cause enemies to bleed (same bleed as Witch Hunter Captain's Flense).

		**Lingering Shadow** (new, replaces Gladerunner)
		- Increases Blur invisibility duration to 2 seconds (from 1.5s).
		- Attacking no longer ends Blur's invisibility.
		- Ranged attacks from stealth are guaranteed critical strikes.

		**Shimmer Strike**
		- Limited extending stealth to 4 times.
		- Increased duration granted from extending to 3s (from 1s).
		- Extending stealth reduces ultimate cooldown by 5%.

		**Hungry Wind**
		- After activating Infiltrate, the next 10 melee hits are considered backstabs.
		- Melee attacks are guaranteed critical strikes for the 10 seconds after leaving Infiltrate.
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
	duration = 3 -- 5
})
-- internal
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_short_blocker", {
	duration = 3 -- 5
})
--[[
	Hungry Wind
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_phasing", {
	duration = 3 -- 5
})
--[[
	Cloak of Pain
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_activated_ability_restealth", {
	duration = 3 -- 5
})
mod_api.insert_text("career_active_desc_we_1_2", "Kerillian becomes undetectable, can pass through enemies, and deals greatly increased melee damage. Lasts for 3 seconds or until she deals damage.")

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
	Gladerunner
]]
-- Move Gladerunner (flat movement speed) onto the base passive
mod_api.insert_career_passives("we_1", {
	"kerillian_shade_movement_speed",
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_movement_speed", {
	multiplier = 1.1 -- 1.1
})
mod_api.insert_text("career_passive_desc_we_1b_2", "Double damage when attacking enemies from behind with melee attacks. Kerillian moves 10.0% faster.")
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
	buff_func = "tb_ammo_fraction_gain_on_backstab",
	event = "on_backstab",
	ammo_bonus_fraction = 0.05,
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_backstabs_replenishes_ammunition_cooldown", {
	icon = "kerillian_shade_backstabs_replenishes_ammunition",
	duration = 2,
})
mod_api.insert_proc_function("tb_ammo_fraction_gain_on_backstab", function (owner_unit, buff, params)
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
-- Critical hits also restore 3 permanent health (once per attack, not per target cleaved)
mod_api.insert_proc_function("tb_shade_heal_on_critical_hit", function (owner_unit, buff, params)
	local target_number = params[4]

	if not Managers.state.network.is_server or not HEALTH_ALIVE[owner_unit] or target_number ~= 1 then
		return
	end

	DamageUtils.heal_network(owner_unit, owner_unit, buff.template.heal_amount, "career_passive")
end)
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_heal_on_critical_hit", {
	buff_func = "tb_shade_heal_on_critical_hit",
	event = "on_critical_hit",
	heal_amount = 3,
})
mod_api.update_talent("we_shade", 5, 1, {
	description = "kerillian_shade_damage_reduction_on_critical_hit_desc",
	description_values = {},
	buffs = {
		"kerillian_shade_damage_reduction_on_critical_hit",
		--"tb_kerillian_shade_heal_on_critical_hit",
	},
})
mod_api.insert_text("kerillian_shade_damage_reduction_on_critical_hit_desc", "Critical hits reduce damage taken by 20.0% for 5 seconds.")

--[[
	Elthrai's Mockery
	Hungry Wind
]]
-- Consumes the oldest stack of buff_to_remove on hit. Stacks granted this same frame are skipped, so a stack
-- granted mid-hit can't be eaten by the hit that produced it (procs added mid-hit still run in the same
-- trigger_procs pass)
-- melee_only: only melee hits consume a stack (guaranteed_backstab does nothing for ranged hits)
mod_api.insert_proc_function("tb_shade_consume_stack_on_hit", function (owner_unit, buff, params)
	if not ALIVE[owner_unit] then
		return
	end

	local template = buff.template
	local attack_type = params[2]

	if template.melee_only and attack_type ~= "light_attack" and attack_type ~= "heavy_attack" then
		return
	end

	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local stacks = buff_extension:get_stacking_buff(template.buff_to_remove)
	local oldest_stack = stacks and stacks[1]

	if oldest_stack and oldest_stack.start_time < Managers.time:time("game") then
		buff_extension:remove_buff(oldest_stack.id)
	end
end)
-- Shared guaranteed-backstab stack granted by both Elthrai's Mockery and Hungry Wind, so their stacks pool together
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_backstab_stack", {
	max_stacks = 20,
	icon = "kerillian_shade_movement_speed_on_critical_hit", -- Spring-Heeled Assassin's icon marks backstab stacks
	perks = {
		"guaranteed_backstab",
	},
})
-- Shared consumer; max_stacks = 1 keeps it to a single instance when both talents are taken, so a hit only spends one stack
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_backstab_consumer", {
	buff_func = "tb_shade_consume_stack_on_hit",
	buff_to_remove = "tb_kerillian_shade_backstab_stack",
	event = "on_hit",
	melee_only = true,
	max_stacks = 1,
})

--[[
	Elthrai's Mockery (new, replaces Spring-Heeled Assassin)
]]
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_crit_stack", {
	max_stacks = 6,
	icon = "kerillian_shade_movement_speed",
	stat_buff = "critical_strike_chance",
	bonus = 1,
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_crit_consumer", {
	buff_func = "tb_shade_consume_stack_on_hit",
	buff_to_remove = "tb_kerillian_shade_crit_stack",
	event = "on_hit",
	max_stacks = 1,
})
-- 6 backstabs, 1 crit
mod_api.insert_proc_function("tb_shade_blur_on_dodge", function (owner_unit, buff, params)
	if not ALIVE[owner_unit] then
		return
	end

	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if talent_extension and talent_extension:has_talent("tb_kerillian_shade_elthrais_mockery") then
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

		for i = 1, 6 do
			buff_extension:add_buff("tb_kerillian_shade_backstab_stack")
		end

		buff_extension:add_buff("tb_kerillian_shade_crit_stack")

		buff_extension:remove_buff(buff.id)

		return
	end

	return ProcFunctions.kerillian_thorn_sister_add_buff_remove(owner_unit, buff, params)
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_dash_stealth", {
	buff_func = "tb_shade_blur_on_dodge", -- "kerillian_thorn_sister_add_buff_remove"
})
-- Flense's bleed: every melee hit applies weapon_bleed_dot_whc (despite the perk's name, the damage calc in
-- thp_stagger_damage_changes/01_damage_calc_changes.lua doesn't check for crits). That check runs on the server,
-- so the talent must be buffered "both" (vanilla Flense is "server"); the stack consumers are harmless there,
-- since the stacks themselves are only ever added on the owning client
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_bleed_on_critical_hit", {
	perks = {
		"victor_witchhunter_bleed_on_critical_hit",
	},
})
mod_api.insert_talent("we_shade", 5, 2, "tb_kerillian_shade_elthrais_mockery", {
	buffer = "both",
	icon = "kerillian_shade_movement_speed_on_critical_hit", -- reuse Spring-Heeled Assassin's icon, since this replaces it in this slot
	buffs = {
		"tb_kerillian_shade_backstab_consumer",
		"tb_kerillian_shade_crit_consumer",
		"tb_kerillian_shade_bleed_on_critical_hit",
	},
})
mod_api.insert_talent_text("tb_kerillian_shade_elthrais_mockery", "Elthrai's Mockery","Blur no longer grants invisibility and instead grants 6 guaranteed backstabs and 1 guaranteed critical strike. Melee attacks cause enemies to bleed.")

--[[
	Lingering Shadow (new, replaces Gladerunner, which moved to the passive)
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
-- Attacking no longer ends Blur's stealth. Blur gets its own proc instead of overriding the shared vanilla
-- shade_short_stealth_on_hit, which kerillian_shade_activated_ability_short also uses
mod_api.insert_proc_function("tb_shade_blur_stealth_on_hit", function (owner_unit, buff, params)
	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if talent_extension and talent_extension:has_talent("tb_kerillian_shade_lingering_shadow") then
		return
	end

	return ProcFunctions.shade_short_stealth_on_hit(owner_unit, buff, params)
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_dash_stealth_active", {
	buff_func = "tb_shade_blur_stealth_on_hit", -- "shade_short_stealth_on_hit"
})
-- Ranged attacks are guaranteed crits while stealthed (mirrors the passive's melee stealth crits:
-- kerillian_shade_stealth_crits / kerillian_shade_stealth_crits_remover)
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_lingering_shadow_ranged_stealth_crits", {
	buff_func = "add_buff_local",
	buff_to_add = "tb_kerillian_shade_lingering_shadow_ranged_stealth_crits_buff",
	event = "on_invisible",
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_lingering_shadow_ranged_stealth_crits_remover", {
	buff_func = "remove_buff_stack",
	event = "on_visible",
	remove_buff_stack_data = {
		{
			buff_to_remove = "tb_kerillian_shade_lingering_shadow_ranged_stealth_crits_buff",
			num_stacks = 1,
			server_controlled = false,
		},
	},
})
mod_api.insert_talent_buff_template("wood_elf", "tb_kerillian_shade_lingering_shadow_ranged_stealth_crits_buff", {
	max_stacks = 1,
	stat_buff = "critical_strike_chance_ranged",
	bonus = 1,
})
mod_api.insert_talent("we_shade", 5, 3, "tb_kerillian_shade_lingering_shadow", {
	buffer = "both",
	icon = "kerillian_shade_movement_speed", -- reuse Gladerunner's old icon, since this replaces it in this slot
	buffs = {
		"tb_kerillian_shade_lingering_shadow_duration",
		"tb_kerillian_shade_lingering_shadow_ranged_stealth_crits",
		"tb_kerillian_shade_lingering_shadow_ranged_stealth_crits_remover",
	},
})
-- Blur baseline lasts 1.5 seconds
mod_api.insert_talent_text("tb_kerillian_shade_lingering_shadow", "Lingering Shadow", "Blur invisibility lasts 2 seconds and no longer breaks when attacking. Ranged attacks from stealth are guaranteed critical strikes.")

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
})
-- controls how many shimmer uses you have left
mod_api.insert_talent_buff_template("wood_elf", "tb_shimmer_charges", {
	max_stacks = 4, -- maximum shimmer uses at once
	icon = "kerillian_shade_passive_stealth_on_backstab_kill"
})
mod_api.insert_talent_buff_template("wood_elf", "kerillian_shade_ult_invis_combo_window", {
	buff_func = "shade_combo_stealth_extend_on_kill",
	duration = 0.3,
	refresh_durations = true,
	event = "on_kill_elite_special",
	extend_time = 3, -- 1
	max_stacks = 1,
	icon = "kerillian_shade_passive_stealth_on_backstab_kill",
	remove_buff_func = "kerillian_shade_missed_combo_window"
})
-- Fix: clear leftover shimmer charges once the stealth extension ends, so they can't be
-- silently spent on an unrelated kill outside of Infiltrate
local tb_shimmer_vanilla_on_shade_activated_ability_remove = BuffFunctionTemplates.functions.on_shade_activated_ability_remove
mod_api.insert_buff_function("tb_shade_ult_invis_remove", function (unit, buff, params, world)
	tb_shimmer_vanilla_on_shade_activated_ability_remove(unit, buff, params, world)

	if ALIVE[unit] then
		local buff_extension = ScriptUnit.extension(unit, "buff_system")
		local shimmer_charges = buff_extension:get_stacking_buff("tb_shimmer_charges")

		if shimmer_charges then
			for i = #shimmer_charges, 1, -1 do
				buff_extension:remove_buff(shimmer_charges[i].id)
			end
		end
	end
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_ult_invis", {
	remove_buff_func = "tb_shade_ult_invis_remove",
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

					-- Refund 5% of the ultimate's cooldown for each shimmer consumed
					local career_extension = ScriptUnit.extension(owner_unit, "career_system")

					career_extension:reduce_activated_ability_cooldown_percent(0.05)
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
mod_api.insert_text("kerillian_shade_activated_stealth_combo_desc", "Leaving Infiltrate grants stealth for 3 seconds. Killing an Elite or Special extends this duration by 3 seconds and refunds 5.0% of the ultimate's cooldown, up to a maximum of 4 times.")

--[[
	Hungry Wind
]]
-- Reduce the post-Infiltrate movement speed/Power/pass-through window
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_phasing_buff", {
	duration = 10,
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_movespeed_buff", {
	duration = 10,
})
mod_api.update_talent_buff_template("wood_elf", "kerillian_shade_power_buff", {
	duration = 10,
	apply_buff_func = "tb_hungry_wind_add_crit_buff",
	reapply_buff_func = "tb_hungry_wind_add_crit_buff", -- re-ulting while the window is active refreshes the power buff
})
-- Guaranteed melee crits for the Hungry Wind window (same approach as WHC's Fervency:
-- victor_witchhunter_activated_ability_guaranteed_crit_self_buff). Only Hungry Wind adds kerillian_shade_power_buff,
-- from vanilla on_shade_activated_ability_remove, which only runs on the owning peer
mod_api.insert_talent_buff_template("wood_elf", "tb_hungry_wind_crit_buff", {
	duration = 10, -- keep in sync with kerillian_shade_power_buff
	max_stacks = 1,
	refresh_durations = true,
	stat_buff = "critical_strike_chance_melee",
	bonus = 1,
})
mod_api.insert_buff_function("tb_hungry_wind_add_crit_buff", function (unit, buff, params, world)
	if ALIVE[unit] then
		ScriptUnit.extension(unit, "buff_system"):add_buff("tb_hungry_wind_crit_buff")
	end
end)
-- Backstabs-on-hit is now a limited resource (shared backstab stacks consumed by melee hits) instead of
-- unlimited for the whole power-buff window
mod_api.insert_talent_buff_template("wood_elf", "tb_hungry_wind_backstab_activator", {
	buff_func = "add_buff_reff_buff_stack",
	buff_to_add = "tb_kerillian_shade_backstab_stack",
	event = "on_ability_activated",
	amount_to_add = 12,
	max_stacks = 1,
})
mod_api.update_talent("we_shade", 6, 2, {
	description = "kerillian_shade_activated_ability_phasing_desc",
	description_values = {},
	buffs = {
		"tb_hungry_wind_backstab_activator", -- adds necessary buffs to handle having capped backstab hits
		"tb_kerillian_shade_backstab_consumer",
	},
})
mod_api.insert_text("kerillian_shade_activated_ability_phasing_desc", "Leaving Infiltrate grants Kerillian 10% movement speed, 15% Power, guaranteed melee critical strikes and the ability to pass through enemies for 10 seconds. Infiltrate no longer grants bonus damage, instead grants 10 guaranteed backstabs.")


