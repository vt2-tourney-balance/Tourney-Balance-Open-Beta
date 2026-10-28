local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Outcast Engineer
		### Career Skill
		**Steam-Assisted Crank Gun (Mk II)**
		- Dodge count increased to 3 (from 1).
		- The Crank Gun now always starts at full rotation speed. Previously this required Linked Compression Chamber.
		- Shots fired while aiming with right click are now pinpoint accurate and increased damage fall off range to 30-50 (from 10-20).
		- Increased range where bullets dissappear to 100 (from 30)

		### Talents
		**Ingenious Ordnance**
		- Reduced the bomb cooldown to 60s (from 80s).

		**Armour Piercing Slugs**
		- Additionally non-explosive ranged attacks deal no friendly fire.

		**Bombadier**
		- Bardin can carry 4 bombs (from 3) and starts the mission with 6 random bombs (frag or fire).

		**Full Head of Steam**
		- Build Pressure stacks now expire one at a time, 12s apart, instead of all at once. Pumping again resets the timers.

		**Superior Gaskets**
		- Increased the time until a stack is lost to 3s (from 1.5s).

		**Ablative Armor**
		- A damage reduction stack is no longer lost immediately, but 2s after taking the hit that triggers losing it.

		**Combined Arms**
		- The Ranged Power buff also refills the ammo used by non-explosive ranged attacks into the reserve for its duration (10s).

		**Piston Power**
		- Losing a stamina shield reduces the cooldown by 1s per shield.

		**Linked Compression Chamber**
		- Still increases the Crank Gun's maximum fire rate by 30%.
		- Reduces the Crank Gun's spin-up time before firing to 0.2s (from 0.5s).
	$END_TB
]]

--[[

	Ultimate

]]
-- Linked Compression Chamber's instant windup is baseline for every crank gun variant.
-- Mirrors the talent branch in ActionCareerDREngineerSpin / ActionCareerDREngineer; the talent's
-- 30% max_rps boost is applied before this runs, so talented players keep their higher cap.
local function starting_windup()
	if Managers.mechanism:current_mechanism_name() == "versus" then
		return CareerConstants.dr_engineer.talent_6_2_starting_rps_vs
	end

	return CareerConstants.dr_engineer.talent_6_2_starting_rps
end

-- The spin actions don't handle spread_template_override themselves (only ActionRangedBase does), so the right click aim
-- applies and resets it here, which makes the crosshair show the aimed spread while aiming.
mod:hook_safe(ActionCareerDREngineerSpin, "client_owner_start_action", function (self, new_action, t)
	self._current_windup = starting_windup()

	local spread_template_override = new_action.spread_template_override

	if spread_template_override then
		local spread_extension = ScriptUnit.has_extension(self.weapon_unit, "spread_system")

		if spread_extension then
			spread_extension:override_spread_template(spread_template_override)
		end
	end
end)

mod:hook_safe(ActionCareerDREngineerSpin, "finish", function (self, reason)
	if self.current_action.spread_template_override then
		local spread_extension = ScriptUnit.has_extension(self.weapon_unit, "spread_system")

		if spread_extension then
			spread_extension:reset_spread_template()
		end
	end
end)

mod:hook_safe(ActionCareerDREngineer, "client_owner_start_action", function (self, new_action, t)
	self._current_rps = math.max(self._current_rps, self._max_rps * starting_windup())
end)

Weapons.bardin_engineer_career_skill_weapon.dodge_count = 3 -- 1
Weapons.bardin_engineer_career_skill_weapon_special.dodge_count = 3 -- 1

local TB_ENGINEER_AIMED_SPREAD = "tb_engineer_aimed"

-- Only the left click spin sets the barrel rotation animation, so the right click aim never showed the full rotation speed.
for _, weapon_name in ipairs({ "bardin_engineer_career_skill_weapon", "bardin_engineer_career_skill_weapon_special" }) do
	local action_two = Weapons[weapon_name].actions.action_two

	action_two.default.fp_speed_anim_variable = "barrel_spin_speed"
	action_two.charged.fp_speed_anim_variable = "barrel_spin_speed"
	action_two.default.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	action_two.charged.spread_template_override = TB_ENGINEER_AIMED_SPREAD
end

--[[
	Aimed fire (holding right click)
]]
-- Shots fired out of the right click aim (action_two.charged -> action_one) use their own sub actions, so they get
-- their own spread and damage profile without touching the left click shots.
local TB_ENGINEER_AIMED_SHOT ="tb_engineer_ability_shot_aimed"
local TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE = "tb_engineer_ability_shot_armor_pierce_aimed"
-- Same falloff as the handgun (general_weapon_changes.lua).
local aimed_dropoff_ranges = {
	dropoff_end = 50,
	dropoff_start = 30,
}

local pinpoint = { max_pitch = 0, max_yaw = 0 }
SpreadTemplates[TB_ENGINEER_AIMED_SPREAD] = {
	continuous = {
		still = pinpoint,
		moving = pinpoint,
		crouch_still = pinpoint,
		crouch_moving = pinpoint,
		zoomed_still = pinpoint,
		zoomed_moving = pinpoint,
		zoomed_crouch_still = pinpoint,
		zoomed_crouch_moving = pinpoint,
	},
	immediate = {
		being_hit = { immediate_pitch = 0, immediate_yaw = 0 },
		shooting = { immediate_pitch = 0, immediate_yaw = 0 },
	},
}

local function make_aimed_damage_profile(base_profile_name)
	local profile = table.clone(DamageProfileTemplates[base_profile_name])

	profile.default_target.range_modifier_settings = aimed_dropoff_ranges

	return profile
end
NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT] = make_aimed_damage_profile("engineer_ability_shot")
NewDamageProfileTemplates[TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE] = make_aimed_damage_profile("engineer_ability_shot_armor_pierce")

-- Hitscan range of a shot; the crank gun has none set and falls back to ActionRangedBase's 30m, which made aimed shots vanish.
local TB_ENGINEER_AIMED_RANGE = 100
local AIMED_SUB_ACTIONS ={ "aimed_fire", "aimed_base_fire", "aimed_armor_pierce_fire" }

for _, weapon_name in ipairs({ "bardin_engineer_career_skill_weapon", "bardin_engineer_career_skill_weapon_special" }) do
	local actions = Weapons[weapon_name].actions
	local action_one = actions.action_one

	local aimed_base_fire = table.shallow_copy(action_one.base_fire)
	aimed_base_fire.damage_profile = TB_ENGINEER_AIMED_SHOT
	aimed_base_fire.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	aimed_base_fire.range = TB_ENGINEER_AIMED_RANGE
	action_one.aimed_base_fire = aimed_base_fire

	local aimed_armor_pierce_fire = table.shallow_copy(action_one.armor_pierce_fire)
	aimed_armor_pierce_fire.damage_profile = TB_ENGINEER_AIMED_SHOT_ARMOR_PIERCE
	aimed_armor_pierce_fire.spread_template_override = TB_ENGINEER_AIMED_SPREAD
	aimed_armor_pierce_fire.range = TB_ENGINEER_AIMED_RANGE
	action_one.aimed_armor_pierce_fire = aimed_armor_pierce_fire

	local aimed_fire = table.shallow_copy(action_one.fire)
	aimed_fire.conditional_actions = {
		{
			sub_action = "aimed_armor_pierce_fire",
			condition = action_one.fire.conditional_actions[1].condition,
		},
	}
	aimed_fire.default_action = { sub_action = "aimed_base_fire" }
	action_one.aimed_fire = aimed_fire

	for _, chain_action in ipairs(actions.action_two.charged.allowed_chain_actions) do
		if chain_action.action == "action_one" and chain_action.sub_action == "fire" then
			chain_action.sub_action = "aimed_fire"
		end
	end
end

-- Sub action names are synced by index; the base game only fills this lookup from the vanilla weapon templates.
for _, sub_action_name in ipairs(AIMED_SUB_ACTIONS) do
	if not rawget(NetworkLookup.sub_actions, sub_action_name) then
		local index = #NetworkLookup.sub_actions + 1

		NetworkLookup.sub_actions[index] = sub_action_name
		NetworkLookup.sub_actions[sub_action_name] = index
	end
end

--[[

	Talents

]]
--[[
	Full Head of Steam
]]
-- Stacks only lost 1 at a time
local TB_FULL_HEAD_OF_STEAM_TALENT = "bardin_engineer_power_on_max_pump"
local TB_BUILD_PRESSURE_BUFF = "bardin_engineer_pump_buff"
local TB_BUILD_PRESSURE_STACK_DURATION = 12

mod_api.insert_buff_function("tb_full_head_of_steam_stagger_stacks", function (unit, buff, params, world)
	local talent_extension = ScriptUnit.has_extension(unit, "talent_system")
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	local stacks = buff_extension and buff_extension:get_stacking_buff(TB_BUILD_PRESSURE_BUFF)

	if not stacks or not talent_extension or not talent_extension:has_talent(TB_FULL_HEAD_OF_STEAM_TALENT) then
		return
	end

	local num_stacks = #stacks
	-- This runs before the pump's new stack is added, unless the stacks are already maxed out and nothing is added.
	local newest_rank = num_stacks >= buff.template.max_stacks and 1 or 2

	for i = 1, num_stacks do
		if stacks[i] == buff then
			buff.duration = TB_BUILD_PRESSURE_STACK_DURATION * (num_stacks - i + newest_rank)

			return
		end
	end
end)
mod_api.update_talent_buff_template("dwarf_ranger", TB_BUILD_PRESSURE_BUFF, {
	reapply_buff_func = "tb_full_head_of_steam_stagger_stacks",
})
mod_api.update_talent("dr_engineer", 4, 1, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_power_on_max_pump_desc_b", "While at 5 stacks of Pressure, Bardin gains 15% Attack Speed. Build Pressure stacks now expire one at a time.")

--[[
	Linked Compression Chamber
]]
-- Reduce the 0.5s spin-up to 0.1s, so the spin action chains into fire sooner.
local TB_LINKED_COMPRESSION_SPIN_UP = 0.2 -- 0.5
local reduced_spin_up_chain_actions = setmetatable({}, { __mode = "k" })

mod:hook(WeaponUnitExtension, "is_chain_action_available", function (func, self, next_chain_action, t, time_offset)
	local current_action_settings = self.current_action_settings

	if current_action_settings and current_action_settings.kind == "career_dr_four_spin" and next_chain_action.sub_action == "fire" then
		local lookup_data = current_action_settings.lookup_data
		local talent_extension = self._talent_extension

		if lookup_data and lookup_data.sub_action_name == "spin" and talent_extension and talent_extension:has_talent("bardin_engineer_reduced_ability_fire_slowdown") then
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

mod_api.insert_text("bardin_engineer_reduced_ability_fire_slowdown_desc_2", "Increases the Crank Gun's maximum fire rate by 30%% and reduces its spin-up time before firing to 0.2 seconds.")

--[[
	Ingenious Ordnance
]]
local TB_INGENIOUS_ORDNANCE_COOLDOWN = 60 -- 80
-- The cooldown buff's duration only drives the HUD icon; the grant timing itself is the update_frequency/delay.
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_2_1", {
	update_frequency = TB_INGENIOUS_ORDNANCE_COOLDOWN,
	update_start_delay = TB_INGENIOUS_ORDNANCE_COOLDOWN,
})
mod_api.update_talent_buff_template("dwarf_ranger", "bardin_engineer_2_1_cooldown", {
	duration = TB_INGENIOUS_ORDNANCE_COOLDOWN,
})
mod_api.update_talent("dr_engineer", 2, 1, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_improved_explosives_desc_2", "Bardin receives a bomb every 60 seconds if he has room for it. Explosions deal no friendly fire.")

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
mod_api.insert_text("bardin_engineer_ranged_pierce_desc_2", "Ranged attacks penetrate 1 additional enemy. Non-explosive ranged attacks deal no friendly fire.")

--[[
	Bombadier
]]
-- Same flow as vanilla's PassiveAbilityEngineer._add_5_2_bombs (server only, once per mission via the party status,
-- topped up every time in the keep), but with a bigger bomb capacity and random bombs.
local TB_BOMBADIER_TALENT = "bardin_engineer_upgraded_grenades"
local TB_BOMBADIER_BOMBS = 4 -- 3
local TB_BOMBADIER_ITEMS = { "grenade_frag_01", "grenade_fire_01" }
local TB_BOMBADIER_GIVEN_FLAG = "_engineer_upgraded_grenades_added"
-- The equipped bomb doesn't count towards the additional slots.
local TB_BOMBADIER_EXTRA_SLOTS = TB_BOMBADIER_BOMBS - 1
local TB_BOMBADIER_BASE_EXTRA_SLOTS = CareerSettings.dr_engineer.additional_item_slots.slot_grenade

mod:hook_origin(PassiveAbilityEngineer, "_add_5_2_bombs", function (self)
	local has_talent = self._talent_extension:has_talent(TB_BOMBADIER_TALENT)
	local inventory_extension = self._inventory_extension

	-- The capacity lives on every peer's inventory extension, so this runs before the server only part.
	inventory_extension:get_additional_items_table().slot_grenade.max_slots = has_talent and TB_BOMBADIER_EXTRA_SLOTS or TB_BOMBADIER_BASE_EXTRA_SLOTS

	if not self._is_server or not has_talent then
		return
	end

	local game_mode_data = Managers.party:get_status_from_unique_id(self._player:unique_id()).game_mode_data

	if not global_is_inside_inn and game_mode_data[TB_BOMBADIER_GIVEN_FLAG] then
		return
	end

	game_mode_data[TB_BOMBADIER_GIVEN_FLAG] = true

	local slot_name = "slot_grenade"
	local unit_id = Managers.state.unit_storage:go_id(self._owner_unit)
	local slot_id = NetworkLookup.equipment_slots[slot_name]
	local network_transmit = Managers.state.network.network_transmit

	for _ = inventory_extension:get_total_item_count(slot_name) + 1, TB_BOMBADIER_BOMBS do
		local item_name_id = NetworkLookup.item_names[TB_BOMBADIER_ITEMS[math.random(#TB_BOMBADIER_ITEMS)]]

		network_transmit:send_rpc_server("rpc_give_equipment", NetworkConstants.invalid_game_object_id, unit_id, slot_id, item_name_id, Vector3.zero())
	end
end)

mod_api.update_talent("dr_engineer", 2, 3, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_upgraded_grenades_desc_b", "Bardin can carry 6 bombs and starts the mission with 6 random bombs. Bardin's bombs explode with additional fire.")

--[[
	Superior Gaskets
]]
-- Read by ActionCareerDREngineer._handle_infinite_stacks every time the talent starts a stack's countdown while firing.
CareerConstants.dr_engineer.talent_4_3_stack_duration = 3 -- 1.5


--[[
	Ablative Armor
]]
-- Vanilla removes a stack straight away on damage taken and restarts the 5s regain timer. Now the loss is queued on the
-- buff and applied after the delay, which is when the regain timer restarts. The buff only exists on the server, which
-- also owns the server controlled stacks, so a short update tick works through the queue and the regain timer.
local TB_ABLATIVE_ARMOR_LOSS_DELAY = 2
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
mod_api.insert_text("bardin_engineer_stacking_damage_reduction_desc", "Bardin gains a stack of 5% damage reduction every 5 seconds, up to 5 stacks. Taking damage makes Bardin lose a stack 5 seconds later.")

--[[
	Combined Arms
]]
-- Shots still empty the clip, but whatever they used is put straight back into the reserve. Non-explosive means the
-- shot isn't an explosive projectile (impact_data.aoe), e.g. the Trollhammer and the Drakefire Pistols' explosive
-- shots don't get the refund. Bombs aren't ammo based.
local TB_COMBINED_ARMS_BUFF = "bardin_engineer_melee_power_range_power_buff"

local function tb_is_explosive_action(weapon_unit)
	local weapon_extension = ScriptUnit.has_extension(weapon_unit, "weapon_system")
	local action = weapon_extension and weapon_extension.current_action_settings
	local impact_data = action and action.impact_data

	return impact_data and impact_data.aoe ~= nil
end

mod:hook(GenericAmmoUserExtension, "use_ammo", function (func, self, ...)
	local shots_fired_before = self._shots_fired

	func(self, ...)

	local buff_extension = self.owner_buff_extension
	local ammo_used = self._shots_fired - shots_fired_before

	if ammo_used > 0 and self.slot_name == "slot_ranged" and buff_extension and buff_extension:has_buff_type(TB_COMBINED_ARMS_BUFF) and not tb_is_explosive_action(self.unit) then
		-- Same as add_ammo_to_reserve, without its "gained ammo from no ammo" proc and rpc.
		if self._ammo_immediately_available then
			self._current_ammo = math.min(self._max_ammo, self._current_ammo + ammo_used)
		else
			self._available_ammo = math.min(self._max_ammo - self:ammo_count(), self._available_ammo + ammo_used)
		end

		self:_update_anim_ammo()
	end
end)

mod_api.update_talent("dr_engineer", 5, 2, {
	description_values = {},
})
mod_api.insert_text("bardin_engineer_melee_power_ranged_power_desc", "Melee Power is increased by 10%. Every 5 Melee Strikes makes Bardin's next Ranged Attack grant 15% Ranged Power and non-explosive Ranged Attacks replenish ammo for 10 seconds.")

--[[
	Piston Power
]]
-- Hooks set_fatigue_points because add_fatigue_points is already replaced by 19_bw_unchained.lua, and every way of losing
-- shields ends up there. Only increases count, and only the owner's client runs it since the cooldown buff is local.
local TB_PISTON_POWER_TALENT = "bardin_engineer_piston_powered"
local TB_PISTON_POWER_COOLDOWN_BUFF = "bardin_engineer_piston_powered_delay"
local TB_PISTON_POWER_REDUCTION_PER_SHIELD = 1

mod:hook(GenericStatusExtension, "set_fatigue_points", function (func, self, fatigue, ...)
	local fatigue_before = self.fatigue

	func(self, fatigue, ...)

	local max_fatigue_points = self.max_fatigue_points
	local player = self.player

	if fatigue <= fatigue_before or max_fatigue_points == 0 or not player or not player.local_player then
		return
	end

	local fatigue_per_shield = PlayerUnitStatusSettings.MAX_FATIGUE / max_fatigue_points
	local shields_lost = math.ceil(fatigue / fatigue_per_shield) - math.ceil(fatigue_before / fatigue_per_shield)

	if shields_lost <= 0 then
		return
	end

	local talent_extension = ScriptUnit.has_extension(self.unit, "talent_system")

	if talent_extension and talent_extension:has_talent(TB_PISTON_POWER_TALENT) then
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
mod_api.insert_text("bardin_engineer_piston_powered_desc_b", "Heavy melee attacks restore all stamina and cause a powerful stagger, once every 15 seconds. Losing a stamina shield reduces this cooldown by 1 second per shield.")
