local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

--[[
	$BEGIN_TB
		---
		## Outcast Engineer
		### Career Skill
		**Steam-Assisted Crank Gun (Mk II)**
		- The Crank Gun now always starts at full rotation speed. Previously this required Linked Compression Chamber.
		- Shots fired while aiming with right click are now pinpoint accurate.
		- Increased range where bullets dissappear to 100 (from 30) for all crank gun shots.

		### Talents
		**Ingenious Ordnance**
		- Reduced the bomb cooldown to 60s (from 80s).
		- If Bardin's inventory is full, the bomb is dropped on the ground.

		**Armour Piercing Slugs**
		- Additionally non-explosive ranged attacks deal no friendly fire.

		**Bombadier**
		- Bardin starts the mission with 3 bombs (from 2).
		- Explosive barrels Bardin sets off also explode like a regular bomb.
		- Lamp oil Bardin sets off also explodes like an incendiary bomb.

		**Full Head of Steam**
		- Build Pressure stacks now expire one at a time.

		**Superior Gaskets**
		- Firing now starts a separate 6s debuff timer (from 1.5s) that removes one Build Pressure stack when it runs out.
		
		**Ablative Armor**
		- A damage reduction stack is no longer lost immediately, but 1s after taking damage.

		**Combined Arms**
		- The 10s also make non-explosive ranged attacks not use up ammo and venting overcharge deals no damage.

		**Piston Power**
		- The heavy attack also has infinite cleave.
		- Losing a stamina shield from blocking an attack reduces the cooldown by 1s per shield.

		**Linked Compression Chamber**
		- Still increases the Crank Gun's maximum fire rate by 30%.
		- Reduces the Crank Gun's spin-up time before firing, and before the right click aim is ready, to 0.2s (from 0.5s).

		**Innovative Ammo Hoppers**
		- No longer increases the ability bar by 50%.
		- The 4s after killing a special now also make guns consume no ammo from the clip and Drakefire weapons generate no heat. Explosive shots (the Trollhammer torpedo) are excluded.
	$END_TB
]]

--[[

	Ultimate

]]
-- See weapon_changes/career_ability/dr_engineer_crank_gun.lua

--[[

	Talents

]]
--[[
	Ingenious Ordnance
]]
local TB_INGENIOUS_ORDNANCE_COOLDOWN = 60 -- 80
-- The cooldown buff's duration only drives the HUD icon; the grant timing itself is the update_frequency/delay.
-- Full inventory drops the bomb on the ground instead (like GK)
local TB_INGENIOUS_ORDNANCE_DROP_PICKUP = "engineer_grenade_t1"

mod_api.insert_buff_function("tb_engineer_bomb_grant_or_drop", function (unit, buff, params)
	local inventory_extension = ScriptUnit.extension(unit, "inventory_system")
	local slot_name = "slot_grenade"

	if not inventory_extension:get_slot_data(slot_name) or inventory_extension:can_store_additional_item(slot_name) then
		return BuffFunctionTemplates.functions.bardin_engineer_bomb_grant(unit, buff, params)
	end

	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	if buff_extension then
		buff_extension:add_buff(buff.template.cooldown_buff)
	end

	-- Only the owner's copy of the buff drops it, the server's copy of a remote player's buff must not.
	local player = Managers.player:owner(unit)

	if not player or player.remote then
		return
	end

	local pickup_name_id = NetworkLookup.pickup_names[TB_INGENIOUS_ORDNANCE_DROP_PICKUP]
	local spawn_type_id = NetworkLookup.pickup_spawn_types.dropped
	local position = POSITION_LOOKUP[unit] + Vector3.up()

	if Managers.state.network.is_server then
		Managers.state.entity:system("pickup_system"):rpc_spawn_pickup_with_physics(Network.peer_id(), pickup_name_id, position, Quaternion.identity(), spawn_type_id)
	else
		Managers.state.network.network_transmit:send_rpc_server("rpc_spawn_pickup_with_physics", pickup_name_id, position, Quaternion.identity(), spawn_type_id)
	end
end)
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_2_1", {
	update_func = "tb_engineer_bomb_grant_or_drop",
	update_frequency = TB_INGENIOUS_ORDNANCE_COOLDOWN,
	update_start_delay = TB_INGENIOUS_ORDNANCE_COOLDOWN,
})
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_2_1_cooldown", {
	duration = TB_INGENIOUS_ORDNANCE_COOLDOWN,
})
mod_api.update_talent("dr_engineer", 2, 1, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_improved_explosives_desc_2", "Craft an engineer bomb every 60 seconds. Explosives no longer damage allies.")

--[[
	Armour Piercing Slugs
]]
-- Non-explosive ranged attacks (hitscan, projectiles, beams) ask DamageUtils.allow_friendly_fire_ranged, but so do
-- explosions and aoe clouds, so those are tracked and left alone.
local tb_explosive_depth = 0

local function tb_end_explosive(...)
	tb_explosive_depth = tb_explosive_depth - 1

	return ...
end

mod:add_create_explosion_wrapper(function (func, ...)
	tb_explosive_depth = tb_explosive_depth + 1

	return tb_end_explosive(func(...))
end)

mod:hook(DamageUtils, "create_aoe", function (func, ...)
	tb_explosive_depth = tb_explosive_depth + 1

	return tb_end_explosive(func(...))
end)

mod:hook(DamageUtils, "allow_friendly_fire_ranged", function (func, difficulty_settings, attacker_player)
	if tb_explosive_depth == 0 and attacker_player then
		local attacker_unit = attacker_player.player_unit
		local talent_extension = attacker_unit and ScriptUnit.has_extension(attacker_unit, "talent_system")

		if talent_extension and talent_extension:has_talent("bardin_engineer_ranged_pierce") then
			return false
		end
	end

	return func(difficulty_settings, attacker_player)
end)

mod_api.update_talent("dr_engineer", 2, 2, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_ranged_pierce_desc_2", "Non-explosive ranged attacks pierce 1 additional enemy and no longer damage allies.")

--[[
	Bombadier
]]
local TB_BOMBADIER_TALENT = "bardin_engineer_upgraded_grenades"

-- Read at runtime by PassiveAbilityEngineer._add_5_2_bombs; official realm only has 2.
CareerConstants.dr_engineer.num_starting_bombs = 3 -- 2

mod_api.update_talent("dr_engineer", 2, 3, {
	description_values = {},
})

-- Explosive barrels and lamp oil that Bardin last hit also go off like a thrown bomb: regular for barrels, incendiary
-- for lamp oil. Both are created as if the bomb item was thrown, so they follow the usual bomb damage rules.
local TB_BOMBADIER_BARREL_EXPLOSION = "grenade"
local TB_BOMBADIER_BARREL_BOMB_ITEM = "grenade_frag_01"
local TB_BOMBADIER_LAMP_OIL_EXPLOSION = "fire_grenade"
local TB_BOMBADIER_LAMP_OIL_BOMB_ITEM = "grenade_fire_01"

local function tb_is_bombadier(unit)
	if not ALIVE[unit] then
		return false
	end

	local career_extension = ScriptUnit.has_extension(unit, "career_system")
	local talent_extension = ScriptUnit.has_extension(unit, "talent_system")

	return career_extension ~= nil and talent_extension ~= nil and career_extension:career_name() == "dr_engineer" and talent_extension:has_talent(TB_BOMBADIER_TALENT)
end

-- Barrels explode through the explosion chain (on every peer, the damage only on the server). The wrapper's func is the
-- rest of the chain, so the extra explosion doesn't come back through this wrapper.
mod:add_create_explosion_wrapper(function (func, world, attacker_unit, impact_position, rotation, explosion_template, scale, damage_source, ...)
	local result = func(world, attacker_unit, impact_position, rotation, explosion_template, scale, damage_source, ...)

	if explosion_template and explosion_template.name == "explosive_barrel" and tb_is_bombadier(attacker_unit) then
		local bomb_template = ExplosionUtils.get_template(TB_BOMBADIER_BARREL_EXPLOSION)

		func(world, attacker_unit, impact_position, rotation, bomb_template, scale, TB_BOMBADIER_BARREL_BOMB_ITEM, ...)
	end

	return result
end)

-- Lamp oil only spawns a fire pool on the server, with no explosion, so the incendiary bomb goes off from here.
-- Server only, the explosion and the fire patch are networked from there.
local lamp_oil_death_reaction = DeathReactions and DeathReactions.templates and DeathReactions.templates.lamp_oil

if lamp_oil_death_reaction and lamp_oil_death_reaction.unit then
	mod:hook(lamp_oil_death_reaction.unit, "update", function (func, unit, dt, context, t, data)
		local was_exploded = data.exploded
		local result = func(unit, dt, context, t, data)

		if not was_exploded and data.exploded then
			local health_extension = ScriptUnit.has_extension(unit, "health_system")
			local attacker_unit_id = health_extension and health_extension.last_damage_data.attacker_unit_id
			local attacker_unit = attacker_unit_id and Managers.state.network:game_object_or_level_unit(attacker_unit_id, false)

			if tb_is_bombadier(attacker_unit) then
				local position = POSITION_LOOKUP[unit]
				local bomb_template = ExplosionUtils.get_template(TB_BOMBADIER_LAMP_OIL_EXPLOSION)

				Managers.state.entity:system("area_damage_system"):create_explosion(attacker_unit, position, Unit.local_rotation(unit, 0), TB_BOMBADIER_LAMP_OIL_EXPLOSION, 1, TB_BOMBADIER_LAMP_OIL_BOMB_ITEM, nil, false)

				if bomb_template.aoe then
					DamageUtils.create_aoe(Managers.world:world("level_world"), attacker_unit, position, TB_BOMBADIER_LAMP_OIL_BOMB_ITEM, bomb_template)
				end
			end
		end

		return result
	end)
end

mod_api.insert_text("bardin_engineer_upgraded_grenades_desc_b", "Bardin starts the mission with 3 bombs. Bombs have both regular and incendiary effect. Explosive barrels and lamp oils set off by Bardin have regular bomb and incendiary bomb effect correspondingly.")

--[[
	Full Head of Steam
]]
-- Stacks decay 1 at a time
local TB_FULL_HEAD_OF_STEAM_TALENT = "bardin_engineer_power_on_max_pump"
local TB_BUILD_PRESSURE_BUFF = "bardin_engineer_pump_buff"

mod_api.insert_buff_function("tb_build_pressure_remove", function (unit, buff, params, world)
	BuffFunctionTemplates.functions.remove_buff_local(unit, buff, params, world)

	local talent_extension = ScriptUnit.has_extension(unit, "talent_system")
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	local stacks = buff_extension and buff_extension:get_stacking_buff(TB_BUILD_PRESSURE_BUFF)

	if not stacks or not talent_extension or not talent_extension:has_talent(TB_FULL_HEAD_OF_STEAM_TALENT) then
		return
	end

	local t = Managers.time:time("game")

	-- The removed stack is still in the list at this point.
	for i = 1, #stacks do
		local stack = stacks[i]

		if stack ~= buff then
			stack.start_time = t
		end
	end
end)
mod_api.update_talent_buff_template("dwarf_ranger", TB_BUILD_PRESSURE_BUFF, {
	remove_buff_func = "tb_build_pressure_remove",
})

mod_api.update_talent("dr_engineer", 4, 1, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_power_on_max_pump_desc_b", "While at 5 stacks of Pressure, Bardin gains 15% Attack Speed. Pressure stacks expire one at a time.")

--[[
	Superior Gaskets
]]
-- Build Pressure stacks have no duration with this talent. Firing starts a separate timer buff instead, which takes one
-- stack away when it runs out, so the stacks themselves stay readable on the HUD while the timer is shown by its own icon.
local TB_GASKETS_TALENT = "bardin_engineer_pump_buff_long"
local TB_GASKETS_TIMER_BUFF = "tb_engineer_gaskets_stack_timer"
local TB_GASKETS_STACK_DURATION = 6 -- 1.5

mod_api.insert_buff_function("tb_engineer_gaskets_lose_stack", function (unit, buff, params)
	local buff_extension = ALIVE[unit] and ScriptUnit.has_extension(unit, "buff_system")
	local stacks = buff_extension and buff_extension:get_stacking_buff(TB_BUILD_PRESSURE_BUFF)

	if stacks and stacks[1] then
		buff_extension:remove_buff(stacks[1].id)
	end
end)
mod_api.insert_buff_template(TB_GASKETS_TIMER_BUFF, {
	-- Talent icons only exist in the live atlas under the names the talent itself uses.
	icon = Talents.dwarf_ranger[TalentIDLookup[TB_GASKETS_TALENT].talent_id].icon,
	debuff = true,
	max_stacks = 1,
	duration = TB_GASKETS_STACK_DURATION,
	remove_buff_func = "tb_engineer_gaskets_lose_stack",
})
mod_api.insert_text(TB_GASKETS_TIMER_BUFF, "Build Pressure Loss")

-- Replaces the vanilla countdown on the stacks. Called on every shot tick, so it only looks for the timer first.
mod:hook_origin(ActionCareerDREngineer, "_handle_infinite_stacks", function (self, dt, t)
	local buff_extension = self.buff_extension

	if not self._talent_extension:has_talent(TB_GASKETS_TALENT) or buff_extension:has_buff_type(TB_GASKETS_TIMER_BUFF) then
		return
	end

	if buff_extension:get_stacking_buff(TB_BUILD_PRESSURE_BUFF) then
		buff_extension:add_buff(TB_GASKETS_TIMER_BUFF)
	end
end)


--[[
	Ablative Armor
]]
-- Loses DR stack after delay
local TB_ABLATIVE_ARMOR_LOSS_DELAY = 1
local TB_ABLATIVE_ARMOR_REGAIN_INTERVAL = 5 -- vanilla update_frequency
local TB_ABLATIVE_ARMOR_TICK = 0.25

mod_api.insert_proc_function("tb_ablative_armor_queue_loss", function (owner_unit, buff, params)
	local stack_ids = buff.server_buff_ids
	local pending_losses = buff.tb_pending_losses

	if not pending_losses then
		pending_losses = {}
		buff.tb_pending_losses = pending_losses
	end

	-- Hits taken without a stack to lose don't queue anything, same as vanilla.
	if stack_ids and #pending_losses < #stack_ids then
		pending_losses[#pending_losses + 1] = Managers.time:time("game") + TB_ABLATIVE_ARMOR_LOSS_DELAY
	end
end)

mod_api.insert_buff_function("tb_ablative_armor_update", function (unit, buff, params)
	local t = Managers.time:time("game")
	local pending_losses = buff.tb_pending_losses

	if pending_losses and pending_losses[1] and pending_losses[1] <= t then
		table.remove(pending_losses, 1)

		local stack_ids = buff.server_buff_ids

		if ALIVE[unit] and stack_ids and #stack_ids > 0 then
			Managers.state.entity:system("buff_system"):remove_server_controlled_buff(unit, table.remove(stack_ids))
		end

		buff.tb_next_regain_t = t + TB_ABLATIVE_ARMOR_REGAIN_INTERVAL
	end

	if t >= (buff.tb_next_regain_t or 0) then
		BuffFunctionTemplates.functions.add_buff_server_controlled(unit, buff, params)

		buff.tb_next_regain_t = t + TB_ABLATIVE_ARMOR_REGAIN_INTERVAL
	end
end)

mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_stacking_damage_reduction", {
	buff_func = "tb_ablative_armor_queue_loss",
	update_func = "tb_ablative_armor_update",
	update_frequency = TB_ABLATIVE_ARMOR_TICK,
})
mod_api.update_talent("dr_engineer", 5, 1, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_stacking_damage_reduction_desc", "Every 5 seconds Bardin gains a stack of Damage Reduction. Stacks up to 5 times. Each stack reduces damage taken by 5%. Taking damage removes a stack after 2 seconds.")

--[[
	Combined Arms
]]
-- The 10s ranged power buff (applied by the next ranged attack after 5 melee strikes) also stops shots from using up
-- reserve ammo (the clip still empties, see the use_ammo hook below) and makes venting overcharge deal no damage.
-- The overcharge extension skips the vent damage while its no_damage flag is set (it is also set in the inn and for some
-- overcharge setups), so the buff raises it and puts the original value back when it ends.
local TB_COMBINED_ARMS_BUFF = "bardin_engineer_melee_power_range_power_buff"

mod_api.insert_buff_function("tb_combined_arms_no_vent_damage_apply", function (unit, buff, params, world)
	local overcharge_extension = ScriptUnit.has_extension(unit, "overcharge_system")

	if overcharge_extension and overcharge_extension.tb_original_no_damage == nil then
		overcharge_extension.tb_original_no_damage = overcharge_extension.no_damage or false
		overcharge_extension.no_damage = true
	end
end)
mod_api.insert_buff_function("tb_combined_arms_no_vent_damage_remove", function (unit, buff, params, world)
	local overcharge_extension = ScriptUnit.has_extension(unit, "overcharge_system")

	if overcharge_extension and overcharge_extension.tb_original_no_damage ~= nil then
		overcharge_extension.no_damage = overcharge_extension.tb_original_no_damage
		overcharge_extension.tb_original_no_damage = nil
	end
end)
mod_api.update_talent_buff_template("dwarf_ranger", TB_COMBINED_ARMS_BUFF, {
	apply_buff_func = "tb_combined_arms_no_vent_damage_apply",
	remove_buff_func = "tb_combined_arms_no_vent_damage_remove",
})

local function tb_is_explosive_action(weapon_unit)
	local weapon_extension = ScriptUnit.has_extension(weapon_unit, "weapon_system")
	local action = weapon_extension and weapon_extension.current_action_settings
	local impact_data = action and action.impact_data

	return impact_data and impact_data.aoe ~= nil
end

-- Innovative Ammo Hoppers' buff after killing a special, which makes every non-explosive shot free too.
local TB_HOPPERS_BUFF = "bardin_engineer_increased_ability_bar_buff"

-- Hoppers: the shot doesn't touch the clip. Combined Arms: the clip empties as usual, but the reserve ammo it would
-- use up on the reload is given back right away. Explosive shots (the Trollhammer torpedo) are left alone by both.
mod:hook(GenericAmmoUserExtension, "use_ammo", function (func, self, ...)
	local shots_fired_before = self._shots_fired

	func(self, ...)

	local shots = self._shots_fired - shots_fired_before
	local buff_extension = self.owner_buff_extension

	if shots > 0 and self.slot_name == "slot_ranged" and buff_extension and not tb_is_explosive_action(self.unit) then
		if buff_extension:has_buff_type(TB_HOPPERS_BUFF) then
			-- The clip's ammo is its current ammo minus the shots fired, so undoing the shots leaves it untouched.
			self._shots_fired = shots_fired_before

			self:_update_anim_ammo()
		elseif buff_extension:has_buff_type(TB_COMBINED_ARMS_BUFF) then
			-- Same cap as when ammo is added to the reserve: reserve plus clip can't go above the max ammo.
			local max_reserve = self._max_ammo - (self._current_ammo - self._shots_fired)

			self._available_ammo = math.max(self._available_ammo, math.min(self._available_ammo + shots, max_reserve))
		end
	end
end)

mod_api.update_talent("dr_engineer", 5, 2, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_melee_power_ranged_power_desc", "10% Melee Power. Every 5 Melee Strikes makes the next Ranged Attack grant 15% Ranged Power for 10 seconds. During this non-explosive Ranged Weapons consume no ammo and venting Drakefire heat deals no damage.")

--[[
	Piston Power
]]
-- The heavy attack that triggers Piston Power has infinite cleave
local TB_PISTON_POWER_READY_BUFF = "bardin_engineer_piston_powered_ready"

mod:add_action_sweep_start_function(function (self, new_action, ...)
	local damage_profile = self._damage_profile
	local buff_extension = ScriptUnit.has_extension(self.owner_unit, "buff_system")

	if damage_profile and damage_profile.charge_value == "heavy_attack" and buff_extension and buff_extension:has_buff_type(TB_PISTON_POWER_READY_BUFF) then
		self._unlimited_cleave = true
	end
end)

-- Every whole stamina shield lost from blocking an attack shortens the cooldown by 1 second
local TB_PISTON_POWER_COOLDOWN_BUFF = "bardin_engineer_piston_powered_delay"
local TB_PISTON_POWER_REDUCTION_PER_SHIELD = 1

mod:hook(GenericStatusExtension, "set_fatigue_points", function (func, self, fatigue, fatigue_type, ...)
	local fatigue_before = self.fatigue

	func(self, fatigue, fatigue_type, ...)

	local max_fatigue_points = self.max_fatigue_points
	local player = self.player

	if fatigue <= fatigue_before or max_fatigue_points == 0 or not player or not player.local_player or not string.find(fatigue_type, "blocked", 1, true) then
		return
	end

	local talent_extension = ScriptUnit.has_extension(self.unit, "talent_system")

	local fatigue_per_shield = PlayerUnitStatusSettings.MAX_FATIGUE / max_fatigue_points
	local shields_lost = math.ceil(fatigue / fatigue_per_shield) - math.ceil(fatigue_before / fatigue_per_shield)

	if shields_lost > 0 and talent_extension and talent_extension:has_talent("bardin_engineer_piston_powered") then
		local cooldown_buff = self.buff_extension:get_non_stacking_buff(TB_PISTON_POWER_COOLDOWN_BUFF)

		if cooldown_buff then
			-- The buff expires at start_time + duration, so moving the start back shortens what's left.
			cooldown_buff.start_time = cooldown_buff.start_time - shields_lost * TB_PISTON_POWER_REDUCTION_PER_SHIELD
		end
	end
end)

mod_api.update_talent("dr_engineer", 5, 3, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_piston_powered_desc_b", "Every 15 seconds Bardin's next Charged Attack gains massive stagger and cleave, and restores all stamina. Each stamina shield lost from blocking reduces cooldown by 1 second.")

--[[
	Linked Compression Chamber
]]
-- Reduce the 0.5s spin-up to 0.2s, so the spin actions chain onwards sooner: left click spin into fire, and the right
-- click aim into its charged state.
local TB_LINKED_COMPRESSION_SPIN_UP = 0.2 -- 0.5
local reduced_spin_up_chain_actions = setmetatable({}, { __mode = "k" })

local function tb_is_spin_up_chain(lookup_data, next_chain_action)
	if not lookup_data then
		return false
	end

	local action_name = lookup_data.action_name
	local sub_action_name = lookup_data.sub_action_name

	return action_name == "action_one" and sub_action_name == "spin" and next_chain_action.sub_action == "fire"
		or action_name == "action_two" and sub_action_name == "default" and next_chain_action.sub_action == "charged"
end

mod:hook(WeaponUnitExtension, "is_chain_action_available", function (func, self, next_chain_action, t, time_offset)
	local current_action_settings = self.current_action_settings

	if current_action_settings and current_action_settings.kind == "career_dr_four_spin" then
		local talent_extension = self._talent_extension

		if talent_extension and tb_is_spin_up_chain(current_action_settings.lookup_data, next_chain_action) and talent_extension:has_talent("bardin_engineer_reduced_ability_fire_slowdown") then
			local reduced_chain_action = reduced_spin_up_chain_actions[next_chain_action]

			if not reduced_chain_action then
				reduced_chain_action = table.shallow_copy(next_chain_action)
				reduced_chain_action.start_time = math.min(next_chain_action.start_time or TB_LINKED_COMPRESSION_SPIN_UP, TB_LINKED_COMPRESSION_SPIN_UP)
				reduced_spin_up_chain_actions[next_chain_action] = reduced_chain_action
			end

			next_chain_action = reduced_chain_action
		end
	end

	return func(self, next_chain_action, t, time_offset)
end)

mod_api.insert_text("bardin_engineer_reduced_ability_fire_slowdown_desc_2", "The Steam-Assisted Crank Gun (Mk II) gains 30%% firing speed and 60%% reduced spin-up time.")

--[[
	Innovative Ammo Hoppers
]]
-- The larger ability bar moved to Linked Compression Chamber.
for _, templates in ipairs({ TalentBuffTemplates.dwarf_ranger, BuffTemplates }) do
	local hoppers_buff = templates.bardin_engineer_increased_ability_bar.buffs[1]

	hoppers_buff.apply_buff_func = nil
	hoppers_buff.remove_buff_func = nil
end

-- Killing a special starts a 4s buff that already makes the Crank Gun free. Heat is stopped by the no_overcharge perk,
-- the clip by the use_ammo hook above, which leaves explosive shots (the Trollhammer torpedo) alone.
mod_api.update_talent_buff_template("dwarf_ranger", TB_HOPPERS_BUFF, {
	perks = {
		buff_perks.free_ability_engineer,
		buff_perks.no_overcharge,
	},
})
mod_api.update_talent("dr_engineer", 6, 3, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_increased_ability_bar_desc", "Killing a special makes non-explosive ranged attacks consume no resources for 4 seconds.")
