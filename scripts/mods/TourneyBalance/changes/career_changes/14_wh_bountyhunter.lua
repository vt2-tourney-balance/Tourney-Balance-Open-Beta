local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local is_local = require("scripts/mods/TourneyBalance/_api/shared_utils").is_local

--[[
	$BEGIN_TB
		# Bounty Hunter Changes
		## Passives
		### Blessed Kill (NEW)
		- Melee Kills reset the cooldown of Blessed Shots.

		## Talents
		### Blessed Combat
		- Added ranged hits also grant 15% more attack speed for the next 6 attacks.
		### Salvaged Ammunition
		- Added effect to also trigger on special kills.
		### Job Well Done
		- Decreased max damage reductions stacks to 20 (from 30).
		### Just Reward
		- Decreased trigger time window to 4s (from 10s)
		### Double Shotted
		- Increased cooldown reduction to 80% (from 60%).
		### Indiscriminate Blast
		- Increased cooldown reduction to 60% (from 25%).
	$END_TB
]]

--[[

	Passives

]]
mod_api.insert_career_passives("wh_2", { "victor_bountyhunter_activate_passive_on_melee_kill" })
mod_api.insert_perk_text("tb_wh_2d", "Blessed Kill", "Melee kills reset the cooldown of Blessed Shots.")
mod_api.insert_career_perk_descriptions("wh_2", "tb_wh_2d")

--[[

	Talents

]]

-- Blessed Combat
mod_api.update_talent_buff_template("witch_hunter", "victor_bountyhunter_activate_passive_on_melee_kill", {
	activation_buff = "victor_bountyhunter_blessed_melee_damage_buff",
	buff_to_add = "victor_bountyhunter_blessed_melee_attack_speed_buff",
	update_func = "activate_buff_on_other_buff",
})
mod_api.insert_talent_buff_template("witch_hunter", "victor_bountyhunter_blessed_melee_attack_speed_buff", {
	stat_buff = "attack_speed",
	multiplier = 0.15,
	max_stacks = 1,
})
mod_api.insert_text("victor_bountyhunter_weapon_swap_buff_desc", "Melee strikes make up to the next 6 ranged shots deal 15%% more damage. Ranged hits make up to the next 6 melee strikes deal 15%% more damage and grants 15%% attack speed for the next 6 strikes.")

--[[
	Salvaged Ammunition
]]
-- also procs on Specials
mod_api.insert_proc_function("victor_bounty_hunter_ammo_fraction_gain_out_of_ammo", function (owner_unit, buff, params)
	if not is_local(owner_unit) then
		return
	end

	if ALIVE[owner_unit] then
		local killed_unit_breed_data = params[2]

		if killed_unit_breed_data.special or killed_unit_breed_data.elite then
			local buff_template = buff.template
			local weapon_slot = "slot_ranged"
			local inventory_extension = ScriptUnit.extension(owner_unit, "inventory_system")
			local slot_data = inventory_extension:get_slot_data(weapon_slot)
			local right_unit_1p = slot_data.right_unit_1p
			local left_unit_1p = slot_data.left_unit_1p
			local right_hand_ammo_extension = ScriptUnit.has_extension(right_unit_1p, "ammo_system")
			local left_hand_ammo_extension = ScriptUnit.has_extension(left_unit_1p, "ammo_system")
			local ammo_extension = right_hand_ammo_extension or left_hand_ammo_extension
			local current_ammo = ammo_extension:remaining_ammo()
			local clip_ammo = ammo_extension:ammo_count()

			if current_ammo < 1 and clip_ammo < 1 then
				local ammo_bonus_fraction = buff_template.ammo_bonus_fraction
				local ammo_amount = math.max(math.round(ammo_extension:max_ammo() * ammo_bonus_fraction), 1)

				if ammo_extension then
					ammo_extension:add_ammo_to_reserve(ammo_amount)
				end
			end
		end
	end
end)
mod_api.insert_text("victor_bountyhunter_reload_on_kill_desc", "Killing an elite or special while out of ammunition restores 20.0%% of max ammo. Melee kills reload 1 ammo into Victor's ranged weapon.")

--[[
	Job Well Done
]]
mod_api.update_talent_buff_template("witch_hunter", "victor_bountyhunter_stacking_damage_reduction_on_elite_or_special_kill_buff", {
	max_stacks = 20 -- 30
})
mod_api.update_talent("wh_bountyhunter", 5, 3, {
    description_values = {
		{
			value_type = "percent",
			value = -0.01
		},
		{
			value = 20 -- 30
		}
	},
})

--[[
	Just Reward
]]
mod_api.update_talent_buff_template("witch_hunter", "victor_bountyhunter_activated_ability_passive_cooldown_reduction", {
    cooldown = 4, -- 10
    multiplier = 0.2,
})
mod_api.insert_text("victor_bountyhunter_activated_ability_reset_cooldown_on_stacks_desc", "Ranged critical hits reduces the cooldown of Locked and Loaded by 20%. Can only trigger once every 4 seconds.")

--[[
	Double-Shotted
]]
mod_api.update_talent_buff_template("witch_hunter", "victor_bountyhunter_activated_ability_railgun_delayed_add", {
    max_stacks = 1,
    multiplier = 0.8, -- 0.6
})
mod_api.insert_text("victor_bountyhunter_activated_ability_railgun_desc_2", "Modifies Victor's sidearm to fire two powerful bullets in a straight line. Scoring a headshot with this attack will reduce the cooldown of Locked and Loaded by 80%%. This can only happen once")


--[[
	Indisctiminate blast cdr upped to 60%
]]
mod_api.update_talent_buff_template("witch_hunter", "victor_bountyhunter_activated_ability_blast_shotgun", {
    multiplier = -0.6, -- -0.25
})
mod_api.update_talent("wh_bountyhunter", 6, 3, {
	description_values = {
		{
			value_type = "percent",
			value = 0.6, -- 0.25
		},
		{
			value = 20,
		},
	},
})

