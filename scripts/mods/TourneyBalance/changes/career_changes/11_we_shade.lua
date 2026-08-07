local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		title	: 	Shade Changes
		ult		: 	Lord and Boss boost_curve_multiplier_override incresed to 2 (from 1.8/1.5).
					Reduced stealth duration to 2.5s (from 5)
		passives:  	Blur - Increased parry window to 0.75s (from 0.5s).
		talent21:   Cruelty - Increased crit damage bonus to 80% (from 50%) and crit rate bonus to 5% (from 0%).
		talent43:  	Bloodfetcher - Changed ammo refund to 5% (from 1 ammo).
		talent61:	Shimmer Strike - Limited extending stealth duration to 4s (from uncapped).
	$END_TB	
]]

--[[

	Ultimate

]]
-- Raises the vanilla boss/elite cap on boost_damage_multiplier 
-- The only source big enough to hit this cap is Shade's ult (shade_melee_boost grants 4)
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
	"beastmen_minotaur", -- 1.5 (NEW)
	"chaos_exalted_champion", -- 1.5 (NEW)
}
for _, breed_name in ipairs(shade_boost_capped_breeds) do
	Breeds[breed_name].boost_curve_multiplier_override = 2
end

--[[
	Infiltrate
	Shimmer Strike
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
	buffs = {
		"kerillian_shade_increased_critical_strike_damage",
		"tb_kerillian_shade_increased_critical_strike_damage_chance",
	},
})
mod_api.insert_text("kerillian_shade_increased_critical_strike_damage_desc", "Increases critical strike damage bonus by 80.0% and critical strike chance by 5.0%.")

--[[
	Bloodfletcher
]]
mod_api.insert_talent_buff_template("wood_elf", "kerillian_shade_backstabs_replenishes_ammunition", {
	ammo_bonus_fraction = 0.05, -- Added 5% ammo on backstab
})
mod_api.insert_proc_function("ammo_fraction_gain_on_backstab", function (owner_unit, buff, params)
	local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

	if buff_extension and not buff_extension:has_buff_type("kerillian_shade_backstabs_replenishes_ammunition_cooldown") then
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

		buff_extension:add_buff("kerillian_shade_backstabs_replenishes_ammunition_cooldown")
	end
end)
mod_api.insert_text("kerillian_shade_backstabs_replenishes_ammunition_desc", "Backstabs return 5% of maximum ammunition. 2 second cooldown.")

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
	buffs = {
		"tb_shimmer_activator", -- adds necessary buffs to shimmer talent to handle having capped uses
		"tb_shimmer_handler"
	}
})
mod_api.insert_text("kerillian_shade_activated_stealth_combo_desc", "Leaving Infiltrate grants stealth for 3 seconds. Killing an Elite or Special extends this duration by 1 second up to a maximum of 4 times.")


