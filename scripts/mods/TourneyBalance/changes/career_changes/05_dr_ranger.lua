local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local random_utils = require("scripts/mods/TourneyBalance/_api/random_utils")

--[[
	$BEGIN_TB
		title	: 	Ranger Veteran Changes
		ult		: 	-
		passives:  	Survivalist - Added pseudeo-random 5% chance to drop engineer bombs with every survivalist drop (bag size 100 with 5 winning tickets).
					Fast Hands - Added double effective range for ranged weapons.
					Fast Hands - Added 10% increased ranged power.
		talent23:  	Foe-Feller - Attack speed increased to 15% (from 5%)
		talent41:  	Drunken Brawler - Lowered drinking time to 0.8s (from 1.9s)
		    	  	Drunken Brawler - Pseudo-random 50% (bag size 20 with 10 winning tickets)
		talent43:  	Scavenger - Removed bomb drops and reduced drop chance to pseudo-random 6% (from real-random 20%) (bag size 50 with 3 winning tickets).
					Scavenger - Potions drop pseudo-random from bag size 6 with 2 of each potion (speed, strength, cooldown reduction).
		talent52:  	Exuberance - Reduced damage reduction to 20% (from 30%)
		talent62:   Surprise Guest - Added 30% cooldown reduction.
		talent63:   Ranger's Parting Gift - Free bomb only applies to engineer bombs.
	$END_TB	
]]

--[[

	Passives

]]
--[[
	Scavenger
]]
-- State variables for pseudo-random drop chance
local ale_bag_state = {}
local bomb_bag_state = {}
local potion_spawn_bag_state = {}
local draw_ranger_potion = random_utils.shuffle_bag({
	"damage_boost_potion",
	"damage_boost_potion",
	"speed_boost_potion",
	"speed_boost_potion",
	"cooldown_reduction_potion",
	"cooldown_reduction_potion",
})
-- Pseudo-random surivalist drops
mod_api.insert_proc_function("bardin_ranger_scavenge_proc", function (owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local offset_position_1 = Vector3(0, 0.25, 0)
	local offset_position_2 = Vector3(0, -0.25, 0)
	local offset_position_3 = Vector3(0.25, 0, 0)

	if ALIVE[owner_unit] then
		local drop_chance = buff.template.drop_chance
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
		local result = math.random(1, 100)

		if result < drop_chance * 100 then
			local player_pos = POSITION_LOOKUP[owner_unit] + Vector3.up() * 0.1
			local raycast_down = true
			local pickup_system = Managers.state.entity:system("pickup_system")

			-- 5% chance for engineer bomb
			if random_utils.roll_virtual_bag(bomb_bag_state, 100, 5) then
				pickup_system:buff_spawn_pickup("engineer_grenade_t1", player_pos + offset_position_3, raycast_down)
			end

			if talent_extension:has_talent("bardin_ranger_passive_spawn_potions_or_bombs") then
				-- 6% chance for random potion
				if random_utils.roll_virtual_bag(potion_spawn_bag_state, 50, 3) then
					pickup_system:buff_spawn_pickup(draw_ranger_potion(), player_pos, raycast_down)
				else
					pickup_system:buff_spawn_pickup("ammo_ranger", player_pos, raycast_down)
				end
			elseif talent_extension:has_talent("bardin_ranger_passive_improved_ammo") then
				pickup_system:buff_spawn_pickup("ammo_ranger_improved", player_pos, raycast_down)
			elseif talent_extension:has_talent("bardin_ranger_passive_ale") then
				if random_utils.roll_virtual_bag(potion_spawn_bag_state, 20, 10) then
					pickup_system:buff_spawn_pickup("bardin_survival_ale", player_pos + offset_position_1, raycast_down)
					pickup_system:buff_spawn_pickup("ammo_ranger", player_pos + offset_position_2, raycast_down)
				else
					pickup_system:buff_spawn_pickup("ammo_ranger", player_pos, raycast_down)
				end
			else
				pickup_system:buff_spawn_pickup("ammo_ranger", player_pos, raycast_down)
			end
		end
	end
end)
mod_api.insert_text("career_passive_desc_dr_3a_2", "Whenever a special is killed, Bardin will drop an ammo pickup at his feet. This pickup restores 10% of the player's max ammunition, rounded down. Survivalit drops have a 5% chance to come with an engineer bomb.")
mod_api.insert_text("bardin_ranger_passive_spawn_potions_or_bombs_desc", "Killing a special has a 6%% chance to drop a potion instead of a Survivalist cache.")


--[[
	Fast Hands
]]
mod_api.insert_talent_buff_template("dwarf_ranger", "dwarf_ranger_ranged_power", {
	max_stacks = 1,
	multiplier = 0.1,
	stat_buff = "power_level_ranged",
})
mod_api.insert_career_passives("dr_3", {
	"dwarf_ranger_ranged_power",
	"markus_huntsman_passive_no_damage_dropoff",
})
mod_api.insert_text("career_passive_desc_dr_3c_2", "Double effective range for ranged weapons, 10% increased ranged power, and 15% increased reload speed.")

--[[

	Talents

]]
--[[
	Foe Feller
]]
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_ranger_attack_speed", {
	multiplier = 0.15 --0.05
})
mod_api.insert_text("bardin_ranger_attack_speed_desc", "Increases attack speed by 15.0%.")

--[[
	Drunken Brawler
]]
Weapons.bardin_survival_ale.actions.action_one.default.total_time = 0.8 -- 1.9

--[[
	Exuberance
]]
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_ranger_reduced_damage_taken_headshot_buff", {
	multiplier = -0.2 -- -0.3
})
mod_api.update_talent("dr_ranger", 5, 2, {
    description_values = {
		{
			value_type = "percent",
			value = -0.2 -- -0.3
		},
		{
			value = 7
		}
	},
})

--[[
	Parting Gift
]]
-- While having party
mod:hook(ActionChargedProjectileUtility, "fire_charged_projectile", function (func, projectile_context, ...)
	local buff_extension = projectile_context.buff_extension

	if not (projectile_context.is_grenade and not projectile_context.grenade_thrown) then
		return func(projectile_context, ...)
	end

	local free_grenade_buff = buff_extension:get_non_stacking_buff("bardin_ranger_ability_free_grenade_buff")

	if not free_grenade_buff then
		return func(projectile_context, ...)
	end

	local is_engineer_bomb = projectile_context.item_name == "engineer_grenade_t1"

	function buff_extension:has_buff_perk(perk_name)
		if perk_name == "free_grenade" then
			return is_engineer_bomb
		end

		return BuffExtension.has_buff_perk(self, perk_name)
	end

	-- Forwards errors in hooked function
	local ok, err = pcall(func, projectile_context, ...)

	buff_extension.has_buff_perk = nil

	if not ok then
		error(err, 0)
	end
end)
mod_api.insert_text("bardin_ranger_ability_free_grenade_desc", "Activating Disengage causes the next engineer bomb Bardin throws to not be consumed. Does not stack.")


--[[
	Surprise Guest
]]
-- Added 30% CDR
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_ranger_activated_ability_stealth_outside_of_smoke", {
	stat_buff = "activated_cooldown",
	multiplier = -0.3,
	max_stacks = 1
})
mod_api.insert_text("bardin_ranger_activated_ability_stealth_outside_of_smoke_desc", "Disengage's stealth does not break on moving beyond the smoke cloud. Reduces the cooldown of Disengage by 30%.")

