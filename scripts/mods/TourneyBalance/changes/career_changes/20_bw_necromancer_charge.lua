local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local stagger_types = require("scripts/utils/stagger_types")

--[[
	Skeleton charge (patch notes are in 20_bw_necromancer.lua)

	The charge is the pet_skeleton behaviour tree's ability_charge_attack node (BTChargeAttackAction). That node and its
	selector are fixed (the selector is generated code), so nothing can be added to the tree. Instead the node serves
	every skeleton type, and its enter/run/leave pick the charge data of the skeleton's breed.
]]
local CHARGE_DISTANCE = 20
local CHARGE_LEASH_MARGIN = 1 -- stop this far before the leash (max_commander_distance), which would resummon the skeleton mid-charge
local CHARGE_COMMAND_TIMEOUT = 3 -- a charge command that never got to run (stagger, ...) expires
local CHARGE_START_TIMEOUT = 1.5
local CHARGE_IMPACT_TIMEOUT = 2
local KNOCKDOWN_DURATION = 2

--[[
	Charge behaviours
]]
local armored_charge = BreedActions.pet_skeleton_armored.ability_charge

-- Unarmored Charge: the armored skeletons' charge as it was
local unarmored_charge = table.clone(armored_charge)

-- Armored Charge: knocks enemies down like the Foot Knight's Valiant Charge, which is an explosion stagger
armored_charge.push_ai = {
	stagger_distance = 1.5,
	stagger_impact = {
		stagger_types.explosion,
		stagger_types.explosion,
		stagger_types.explosion,
		stagger_types.explosion,
		stagger_types.explosion,
	},
	stagger_duration = {
		KNOCKDOWN_DURATION,
		KNOCKDOWN_DURATION,
		KNOCKDOWN_DURATION,
		KNOCKDOWN_DURATION,
		KNOCKDOWN_DURATION,
	},
}

-- Only the armored skeleton has the charge animations (and the callbacks the charge waits on: the start animation
-- finishing, the finish animation finishing). The others charge with their regular run animation, so for them those
-- steps are skipped (tb_plain_run): no start animation, straight into the run, and no finish animation either
local PLAIN_RUN_ANIM = "move_fwd"

local function tb_plain_run_charge(charge)
	local plain = table.clone(charge)

	plain.tb_plain_run = true
	plain.start_animation = PLAIN_RUN_ANIM
	plain.cancel_animation = PLAIN_RUN_ANIM
	plain.charge_blocked_animation = PLAIN_RUN_ANIM
	plain.charging_animations = {
		far = PLAIN_RUN_ANIM,
		medium = PLAIN_RUN_ANIM,
		short = PLAIN_RUN_ANIM,
	}
	plain.impact_animation = {
		PLAIN_RUN_ANIM,
	}

	return plain
end

local plain_unarmored_charge = tb_plain_run_charge(unarmored_charge)

-- The Unarmored Charge pushes like the Thornsister's thorn wall push (damage_wave_templates.lua,
-- thornsister_thorn_wall_push): enemies hit are staggered along the way of the charge and then dragged with it, for as
-- long as they stay in front of the skeleton. These are that template's tables, by enemy armor category
plain_unarmored_charge.hit_ai_radius = 1.5 -- ai_query_distance
plain_unarmored_charge.tb_drag = {
	drag_range = 1.5, -- ai_query_distance
	immune_breeds = {
		chaos_exalted_sorcerer = true,
		chaos_spawn = true,
		chaos_troll = true,
		skaven_grey_seer = true,
		skaven_rat_ogre = true,
		skaven_stormfiend = true,
	},
	stagger_impact = {
		stagger_types.heavy,
		stagger_types.heavy,
		stagger_types.heavy,
		stagger_types.none,
		stagger_types.heavy,
		stagger_types.medium,
	},
	stagger_duration = {
		0.5,
		0.5,
		0.5,
		0,
		0.5,
		0.5,
	},
	stagger_refresh_time = {
		0.5,
		0.5,
		0.5,
		math.huge,
		0.5,
		math.huge,
	},
	stagger_distance_table = {
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		1,
	},
	wave_drag_multiplier_table = {
		1,
		0.1,
		1,
		0,
		1,
		0,
	},
}
-- Shield skeletons charge like armored ones (same data, knockdown included), minus the animations
local plain_shield_charge = tb_plain_run_charge(armored_charge)

BreedActions.pet_skeleton.ability_charge = plain_unarmored_charge
BreedActions.pet_skeleton_dual_wield.ability_charge = plain_unarmored_charge
BreedActions.pet_skeleton_with_shield.ability_charge = plain_shield_charge

local SKELETON_CHARGES = {
	pet_skeleton = plain_unarmored_charge,
	pet_skeleton_dual_wield = plain_unarmored_charge,
	pet_skeleton_armored = armored_charge,
	pet_skeleton_with_shield = plain_shield_charge,
}

-- The 6_3 charge command (charge at the commanded enemy) used to be armored only. Shield skeletons only charge on the
-- directional command
mod:hook_origin(CareerAbilityBWNecromancerCommand, "rpc_necromancer_command_charge", function (self, channel_id, target_unit_id)
	local peer_id = CHANNEL_TO_PEER_ID[channel_id]

	if peer_id ~= self._player.peer_id then
		return
	end

	local target_unit = self._unit_storage:unit(target_unit_id)
	local units = self._commander_extension:get_controlled_units()

	for controlled_unit in pairs(units) do
		local blackboard = BLACKBOARDS[controlled_unit]
		local breed_name = blackboard.breed.name

		if SKELETON_CHARGES[breed_name] and breed_name ~= "pet_skeleton_with_shield" then
			blackboard.charge_target = target_unit
		end
	end
end)

--[[
	Directional charge: charge_target is the necromancer (a marker, never an enemy), tb_charge_direction the way to go
]]
local original_enter = BTChargeAttackAction.enter
local original_run = BTChargeAttackAction.run
local original_leave = BTChargeAttackAction.leave
local original_hit_ai = BTChargeAttackAction._hit_ai
local original_start_finished = BTChargeAttackAction.anim_cb_charge_start_finished
local original_start_impact = BTChargeAttackAction._start_impact
local original_cancel_charge = BTChargeAttackAction._cancel_charge

-- Plain run charges: straight into the run, and out of it without a finish animation
local function tb_start_plain_charging(unit, blackboard, t)
	blackboard.charge_state = "charging"
	blackboard.charge_started_at_t = t

	Managers.state.network:anim_event(unit, PLAIN_RUN_ANIM)
	blackboard.locomotion_extension:set_rotation_speed(blackboard.action.charge_rotation_speed)
end

local function tb_finish_plain_charge(blackboard)
	blackboard.locomotion_extension:set_wanted_velocity(Vector3.zero())

	blackboard.charge_state = "finished"
end

local function tb_enter_directional(self, unit, blackboard, t)
	local action = SKELETON_CHARGES[blackboard.breed.name]
	local navigation_extension = blackboard.navigation_extension
	local locomotion_extension = blackboard.locomotion_extension

	blackboard.tb_charging_directional = true
	blackboard.tb_charge_enter_t = t
	blackboard.action = action
	blackboard.active_node = BTChargeAttackAction
	blackboard.attack_finished = false
	blackboard.attack_aborted = t > blackboard.tb_charge_expire_t
	blackboard.locked_attack_rotation = false
	blackboard.ray_can_go_update_time = t
	blackboard.attack_token = true
	blackboard.anim_cb_charge_impact_finished = nil
	blackboard.lunge_data = action.lunge
	blackboard.attacking_target = nil
	blackboard.animation_movement_extension = ScriptUnit.has_extension(unit, "animation_movement_system")
	blackboard.spawn_to_running = nil
	blackboard.charge_state = "starting"

	locomotion_extension:set_wanted_velocity(Vector3.zero())
	navigation_extension:set_enabled(false)
	navigation_extension:reset_destination()
	locomotion_extension:use_lerp_rotation(true)

	blackboard.stored_rotation = QuaternionBox(Quaternion.look(blackboard.tb_charge_direction:unbox(), Vector3.up()))
	blackboard.hit_units = {}
	blackboard.pushed_units = {}
	blackboard.tb_charge_start_position = Vector3Box(POSITION_LOOKUP[unit])

	Managers.state.entity:system("ai_slot_system"):do_slot_search(unit, false)

	ScriptUnit.extension(unit, "hit_reaction_system").force_ragdoll_on_death = true

	blackboard.lean_target_position_boxed = Vector3Box()

	local old_cost_table = navigation_extension:get_navtag_layer_cost_table()

	blackboard.old_navtag_layer_cost_table = old_cost_table

	local charge_cost_table = navigation_extension:get_navtag_layer_cost_table("charge")

	if charge_cost_table then
		GwNavTraverseLogic.set_navtag_layer_cost_table(navigation_extension:traverse_logic(), charge_cost_table)
	end

	if action.tb_plain_run then
		tb_start_plain_charging(unit, blackboard, t)
	else
		Managers.state.network:anim_event(unit, action.start_animation)
	end
end

local function tb_run_charging_directional(self, unit, blackboard, t, dt)
	local action = blackboard.action
	local locomotion_extension = blackboard.locomotion_extension
	local self_position = POSITION_LOOKUP[unit]
	local direction = blackboard.tb_charge_direction:unbox()
	local time_spent_charging = t - blackboard.charge_started_at_t
	local charge_speed_min = action.charge_speed_min
	local charge_speed_max = action.charge_speed_max
	local speed = math.min(charge_speed_min + time_spent_charging / action.charge_max_speed_at * (charge_speed_max - charge_speed_min), charge_speed_max)

	locomotion_extension:set_wanted_rotation(blackboard.stored_rotation:unbox())
	blackboard.navigation_extension:set_max_speed(speed)
	locomotion_extension:set_wanted_velocity(Quaternion.forward(Unit.local_rotation(unit, 0)) * speed)

	blackboard.current_charge_speed = speed

	self:_check_overlap(unit, blackboard, action)

	local commander_unit = blackboard.commander_unit
	local traveled = Vector3.length(Vector3.flat(self_position - blackboard.tb_charge_start_position:unbox()))
	local at_leash = ALIVE[commander_unit] and Vector3.length(Vector3.flat(self_position - POSITION_LOOKUP[commander_unit])) >= blackboard.breed.max_commander_distance - CHARGE_LEASH_MARGIN

	if traveled >= CHARGE_DISTANCE or at_leash or self:_check_wall_collision(unit, blackboard, dt) then
		if action.tb_plain_run then
			tb_finish_plain_charge(blackboard)
		else
			self:_start_impact(unit, blackboard, false, true)
		end

		return
	end

	self:_update_leaning_position(unit, blackboard, dt, self_position + direction * 10)
	self:_update_animation_movement_speed(unit, blackboard, dt)
end

local function tb_run_directional(self, unit, blackboard, t, dt)
	if blackboard.attack_aborted then
		return "done"
	end

	local charge_state = blackboard.charge_state

	if charge_state == "starting" then
		blackboard.locomotion_extension:set_wanted_rotation(blackboard.stored_rotation:unbox())

		if t > blackboard.tb_charge_enter_t + CHARGE_START_TIMEOUT then
			self:_start_charging(unit, blackboard)
		end
	elseif charge_state == "charging" then
		tb_run_charging_directional(self, unit, blackboard, t, dt)
	elseif charge_state == "impact" then
		self:_run_impact(unit, blackboard, t, dt)

		local impact_t = blackboard.tb_charge_impact_t

		if not impact_t then
			blackboard.tb_charge_impact_t = t
		elseif t > impact_t + CHARGE_IMPACT_TIMEOUT then
			blackboard.charge_state = "finished"
		end
	elseif charge_state == "finished" then
		return "done"
	end

	return "running"
end

local function tb_leave_directional(self, unit, blackboard, t, reason, destroy)
	blackboard.attack_token = false

	if HEALTH_ALIVE[unit] then
		local navigation_extension = blackboard.navigation_extension

		navigation_extension:set_enabled(true)
		navigation_extension:set_max_speed(AiUtils.get_default_breed_move_speed(unit, blackboard))
		blackboard.locomotion_extension:set_rotation_speed(nil)
		GwNavTraverseLogic.set_navtag_layer_cost_table(navigation_extension:traverse_logic(), blackboard.old_navtag_layer_cost_table)

		ScriptUnit.extension(unit, "hit_reaction_system").force_ragdoll_on_death = nil

		blackboard.locomotion_extension:use_lerp_rotation(true)
		LocomotionUtils.set_animation_driven_movement(unit, false)
	end

	self:_set_leaning_enabled(unit, blackboard, false)

	blackboard.old_navtag_layer_cost_table = nil
	blackboard.action = nil
	blackboard.active_node = nil
	blackboard.anim_cb_disable_charge_collision = nil
	blackboard.anim_cb_rotation_stop = nil
	blackboard.attack_aborted = nil
	blackboard.charge_started_at_t = nil
	blackboard.charge_state = nil
	blackboard.current_charge_speed = nil
	blackboard.hit_units = nil
	blackboard.lean_target_position_boxed = nil
	blackboard.pushed_units = nil
	blackboard.stored_rotation = nil
	blackboard.animation_movement_extension = nil
	blackboard.tb_charging_directional = nil
	blackboard.tb_charge_direction = nil
	blackboard.tb_charge_enter_t = nil
	blackboard.tb_charge_expire_t = nil
	blackboard.tb_charge_impact_t = nil
	blackboard.tb_charge_start_position = nil

	Managers.state.entity:system("ai_slot_system"):do_slot_search(unit, true)
end

local function tb_armor_category(breed)
	return breed.stagger_armor_category or breed.primary_armor_category or breed.armor_category or 1
end

-- Stagger along the way of the charge (the wave's push), refreshed while the enemy is dragged
local function tb_drag_stagger(unit, hit_unit, hit_unit_blackboard, drag_data, t)
	local stagger_type, stagger_duration = DamageUtils.calculate_stagger(drag_data.stagger_impact, drag_data.stagger_duration, hit_unit, unit)

	if stagger_type > stagger_types.none then
		local direction = Vector3.normalize(Vector3.flat(Quaternion.forward(Unit.local_rotation(unit, 0))))
		local distance = drag_data.stagger_distance_table[tb_armor_category(hit_unit_blackboard.breed)]

		AiUtils.stagger(hit_unit, hit_unit_blackboard, unit, direction, distance, stagger_type, stagger_duration, nil, t)
	end
end

-- Enemies being dragged along by a charge: carried at the skeleton's speed, and kept staggered
local function tb_update_drag(unit, blackboard, t)
	local drag_units = blackboard.tb_drag_units

	if not drag_units then
		return
	end

	local drag_data = blackboard.action.tb_drag
	local self_position = POSITION_LOOKUP[unit]
	local drag_velocity = Quaternion.forward(Unit.local_rotation(unit, 0)) * (blackboard.current_charge_speed or 0)
	local drag_range_sq = drag_data.drag_range * drag_data.drag_range

	for hit_unit, entry in pairs(drag_units) do
		local hit_unit_blackboard = HEALTH_ALIVE[hit_unit] and BLACKBOARDS[hit_unit]
		local locomotion_extension = hit_unit_blackboard and hit_unit_blackboard.locomotion_extension

		if not locomotion_extension or Vector3.length_squared(Vector3.flat(POSITION_LOOKUP[hit_unit] - self_position)) > drag_range_sq then
			drag_units[hit_unit] = nil
		else
			if entry.multiplier > 0 then
				locomotion_extension:set_animation_external_velocity(drag_velocity * entry.multiplier)
			end

			if t >= entry.refresh_t then
				entry.refresh_t = t + entry.refresh_time * (math.random() / 2 + 0.5)

				tb_drag_stagger(unit, hit_unit, hit_unit_blackboard, drag_data, t)
			end
		end
	end
end

local function tb_hit_ai_drag(unit, hit_unit, action, blackboard, t)
	local drag_data = action.tb_drag
	local hit_unit_blackboard = BLACKBOARDS[hit_unit]
	local breed = hit_unit_blackboard.breed

	if not drag_data.immune_breeds[breed.name] then
		local armor_category = tb_armor_category(breed)
		local drag_units = blackboard.tb_drag_units

		if not drag_units then
			drag_units = {}
			blackboard.tb_drag_units = drag_units
		end

		drag_units[hit_unit] = {
			multiplier = drag_data.wave_drag_multiplier_table[armor_category] or 0,
			refresh_time = drag_data.stagger_refresh_time[armor_category],
			refresh_t = t + drag_data.stagger_refresh_time[armor_category] * (math.random() / 2 + 0.5),
		}

		tb_drag_stagger(unit, hit_unit, hit_unit_blackboard, drag_data, t)
	end

	AiUtils.damage_target(hit_unit, unit, action, action.damage)
end

-- BTChargeAttackAction._hit_ai without the part that needs a charge target (it alerts the target's friends), and with
-- the thorn wall style push when the charge has one
local function tb_hit_ai(self, unit, hit_unit, action, blackboard, t)
	if action.tb_drag then
		return tb_hit_ai_drag(unit, hit_unit, action, blackboard, t)
	end

	local push_data = action.push_ai
	local hit_unit_blackboard = BLACKBOARDS[hit_unit]

	if push_data then
		local stagger_type, stagger_duration = DamageUtils.calculate_stagger(push_data.stagger_impact, push_data.stagger_duration, hit_unit, unit)

		if stagger_type > stagger_types.none then
			local direction_to_ai = Vector3.normalize(POSITION_LOOKUP[hit_unit] - POSITION_LOOKUP[unit])
			local right = Quaternion.right(Unit.local_rotation(unit, 0))
			local push_direction = Vector3.dot(right, direction_to_ai) > 0 and right or -right

			AiUtils.stagger(hit_unit, hit_unit_blackboard, unit, push_direction, push_data.stagger_distance, stagger_type, stagger_duration, nil, t, nil, nil, nil, true)
		end
	end

	AiUtils.damage_target(hit_unit, unit, action, action.damage)
end

mod:hook_origin(BTChargeAttackAction, "enter", function (self, unit, blackboard, t)
	local breed_name = blackboard.breed.name
	local breed_charge = SKELETON_CHARGES[breed_name]

	if not breed_charge then
		return original_enter(self, unit, blackboard, t)
	end

	local charge_target = blackboard.charge_target

	if charge_target and charge_target == blackboard.commander_unit and blackboard.tb_charge_direction then
		return tb_enter_directional(self, unit, blackboard, t)
	end

	-- the node's own data is the armored charge
	local tree_node = self._tree_node
	local node_action_data = tree_node.action_data

	tree_node.action_data = breed_charge

	original_enter(self, unit, blackboard, t)

	tree_node.action_data = node_action_data

	if breed_charge.tb_plain_run then
		-- no start animation to wait for
		original_start_finished(self, unit, blackboard)
	end
end)
mod:hook_origin(BTChargeAttackAction, "_start_impact", function (self, unit, blackboard, ...)
	original_start_impact(self, unit, blackboard, ...)

	if blackboard.action and blackboard.action.tb_plain_run then
		tb_finish_plain_charge(blackboard)
	end
end)
mod:hook_origin(BTChargeAttackAction, "_cancel_charge", function (self, unit, blackboard)
	original_cancel_charge(self, unit, blackboard)

	if blackboard.action and blackboard.action.tb_plain_run then
		tb_finish_plain_charge(blackboard)
	end
end)
mod:hook_origin(BTChargeAttackAction, "run", function (self, unit, blackboard, t, dt)
	local action = blackboard.action

	if action and action.tb_drag then
		tb_update_drag(unit, blackboard, t)
	end

	if blackboard.tb_charging_directional then
		return tb_run_directional(self, unit, blackboard, t, dt)
	end

	return original_run(self, unit, blackboard, t, dt)
end)
mod:hook_origin(BTChargeAttackAction, "leave", function (self, unit, blackboard, t, reason, destroy)
	blackboard.tb_drag_units = nil

	if blackboard.tb_charging_directional then
		return tb_leave_directional(self, unit, blackboard, t, reason, destroy)
	end

	return original_leave(self, unit, blackboard, t, reason, destroy)
end)
mod:hook_origin(BTChargeAttackAction, "_hit_ai", function (self, unit, hit_unit, action, blackboard, t)
	if blackboard.tb_charging_directional or action.tb_drag then
		return tb_hit_ai(self, unit, hit_unit, action, blackboard, t)
	end

	return original_hit_ai(self, unit, hit_unit, action, blackboard, t)
end)
mod:hook_origin(BTChargeAttackAction, "anim_cb_charge_start_finished", function (self, unit, blackboard)
	if blackboard.tb_charging_directional then
		if blackboard.charge_state == "starting" then
			self:_start_charging(unit, blackboard)
		end

		return
	end

	return original_start_finished(self, unit, blackboard)
end)

--[[
	Hold action_three + attack (action_one): every skeleton charges the way the necromancer is looking. The server
	sets the order up, through a short synced buff the owner's client adds.
]]
local CHARGE_HEAT_PER_SKELETON = 5
local CHARGE_BUFF = "tb_necromancer_charge_forward"
local CHARGE_SUB_ACTION = "charge_forward"

mod_api.insert_buff_function("tb_necromancer_charge_forward_apply", function (unit, buff, params)
	if not Managers.state.network.is_server or not ALIVE[unit] or not HEALTH_ALIVE[unit] then
		return
	end

	local commander_extension = ScriptUnit.has_extension(unit, "ai_commander_system")

	if not commander_extension then
		return
	end

	local first_person_extension = ScriptUnit.has_extension(unit, "first_person_system")
	local aim_direction

	if first_person_extension then
		aim_direction = Quaternion.forward(first_person_extension:current_rotation())
	else
		local game = Managers.state.network:game()

		aim_direction = GameSession.game_object_field(game, Managers.state.unit_storage:go_id(unit), "aim_direction")
	end

	local direction = Vector3.flat(aim_direction)

	if Vector3.length(direction) < 0.01 then
		return
	end

	direction = Vector3.normalize(direction)

	local expire_t = Managers.time:time("game") + CHARGE_COMMAND_TIMEOUT

	for pet_unit in pairs(commander_extension:get_controlled_units()) do
		local blackboard = HEALTH_ALIVE[pet_unit] and BLACKBOARDS[pet_unit]

		if blackboard and SKELETON_CHARGES[blackboard.breed.name] then
			blackboard.tb_charge_direction = Vector3Box(direction)
			blackboard.tb_charge_expire_t = expire_t
			blackboard.charge_target = unit
		end
	end
end)
mod_api.insert_buff_template(CHARGE_BUFF, {
	duration = 0.1,
	apply_buff_func = "tb_necromancer_charge_forward_apply",
})

local function tb_count_chargers(owner_unit)
	local commander_extension = ScriptUnit.has_extension(owner_unit, "ai_commander_system")
	local num_chargers = 0

	if commander_extension then
		-- also called on the owner's client, where the breed comes from the unit data (blackboards are the server's)
		for pet_unit in pairs(commander_extension:get_controlled_units()) do
			if HEALTH_ALIVE[pet_unit] and SKELETON_CHARGES[Unit.get_data(pet_unit, "breed").name] then
				num_chargers = num_chargers + 1
			end
		end
	end

	return num_chargers
end

local function tb_has_chargers(owner_unit)
	return tb_count_chargers(owner_unit) > 0
end

local utility_actions = Weapons.bw_necromancer_career_utility_weapon.actions

utility_actions.action_one[CHARGE_SUB_ACTION] = {
	anim_event = "pet_control_target_command",
	kind = "dummy",
	total_time = 0.5,
	weapon_action_hand = "left",
	-- no condition_func: sub actions that have one are also started straight from idle by their action's input
	chain_condition_func = tb_has_chargers,
	allowed_chain_actions = {
		{
			action = "action_wield",
			input = "action_wield",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_one",
			input = "action_one",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_two",
			input = "action_two_hold",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_three",
			input = "action_three",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "weapon_reload",
			input = "weapon_reload",
			start_time = 0.2,
			sub_action = "default",
		},
	},
	enter_function = function (attacker_unit, input_extension)
		-- "charging" is one of the overcharge types that skips the per-shot ammo procs and their rpc
		ScriptUnit.extension(attacker_unit, "overcharge_system"):add_charge(tb_count_chargers(attacker_unit) * CHARGE_HEAT_PER_SKELETON, nil, "charging")
		Managers.state.entity:system("buff_system"):add_buff_synced(attacker_unit, CHARGE_BUFF, BuffSyncType.LocalAndServer)
		input_extension:clear_input_buffer()

		return input_extension:reset_release_input()
	end,
}

-- From action_three, attack used to chain into the normal attack command
for _, chain_action in ipairs(utility_actions.action_three.default.allowed_chain_actions) do
	if chain_action.action == "action_one" then
		chain_action.sub_action = CHARGE_SUB_ACTION
	end
end

-- Sub action names are synced by index; the base game only fills this lookup from the vanilla weapon templates.
if not rawget(NetworkLookup.sub_actions, CHARGE_SUB_ACTION) then
	local index = #NetworkLookup.sub_actions + 1

	NetworkLookup.sub_actions[index] = CHARGE_SUB_ACTION
	NetworkLookup.sub_actions[CHARGE_SUB_ACTION] = index
end
