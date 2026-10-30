local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Necromancer

		### Skeletons
		- Increased regular and dual wield skeleton health to 200 on all difficulties (from 16.65 on the lowest, up to 67.5 on the highest).
		- Increased armoured and shield skeleton health to 250 on all difficulties (from 20.8 up to 84.4).
		- Increased the distance at which skeletons are resummoned next to the Necromancer to 50 meters (from 28).
		- Holding the recall command now also generates 1 heat for each living skeleton (counts up to 6) and heals every skeleton for 20% of its max health, once when pressed and then every second while held.
		- The recall command no longer cancels the skeletons' commands and sends them back to following.
		- Pressing action two while holding the recall command teleports all skeletons back to the Necromancer for 1 heat per skeleton, keeping their current health (replaces the hold position chain from recall).
		- Pressing reload while holding the recall command desummons all skeletons, removing them from the field without killing them (replaces the sacrifice chain from recall). Desummoned skeletons keep their health, still count as alive skeletons (for talents and the skeleton display) and are brought back next to the Necromancer by the teleport command above. Reload still sacrifices a desummoned skeleton when none are on the field, venting heat as usual.
		- Pressing attack while holding the recall command makes all skeletons charge 20 meters in the direction the Necromancer is looking, for 5 heat per charging skeleton (replaces the attack command chain from recall).
		- Regular and Bladed skeletons now perform the same charge as Armored skeletons (as a separate Unarmored Charge), including the charge at the targeted enemy. The Unarmored Charge pushes enemies the way the Thornsister's thorn wall push does: enemies hit are staggered and dragged along with the charging skeleton.
		- Armored skeletons' charge now knocks enemies down, like the Foot Knight's Valiant Charge.

		### Talents
		**Death Ascendant**
		- Changed buff to ranged weapon damage (from ranged power).

		**Reaping**
		- Removed power bonus (from 25%).

		**Cursed Blood**
		- Reduced explosion damage to 10% (from 25%) of the crit attack triggering the explosion.
		- Added internal cooldown of 0.3s.
		- Removed stagger from the blood explosion (from 0.08) and crit burst from (0.7).

		**Lost Souls**
		- Removed stagger from unleashed souls (from 0.25).
	$END_TB
]]

--[[
	Skeletons
]]
-- Distance from the necromancer at which a skeleton is resummoned next to them
local SKELETON_LEASH_DISTANCE = 50 -- 28

-- Flat health on every difficulty rank. Vanilla: 37/37/55/65/100/150/150/150/37 * 0.45 (x1.25 for armoured and shield)
-- Difficulty Names: Recruit/Veteran/Champion/Legend/Cata/Cata2/Cata3/Tutorial
local SKELETON_HEALTH = 200
local ARMORED_SKELETON_HEALTH = 250
local SKELETON_BREED_HEALTH = {
	pet_skeleton = SKELETON_HEALTH,
	pet_skeleton_dual_wield = SKELETON_HEALTH,
	pet_skeleton_armored = ARMORED_SKELETON_HEALTH,
	pet_skeleton_with_shield = ARMORED_SKELETON_HEALTH,
}
for breed_name, health in pairs(SKELETON_BREED_HEALTH) do
	local breed = Breeds[breed_name]
	local max_health = breed.max_health
	for rank = 1, #max_health do
		max_health[rank] = health
	end
	breed.max_commander_distance = SKELETON_LEASH_DISTANCE
end

-- Holding the Skeleton Controller Skull's action_three: heat in, skeleton healing out. It is also the modifier for the
-- charge / teleport / desummon commands (20_bw_necromancer_charge.lua, 20_bw_necromancer_desummon.lua)
local CHANNEL_BUFF = "tb_necromancer_skeleton_channel"
local CHANNEL_TICK = 1 -- one tick when the hold starts (so a tap pays for one too), then one per second held
local CHANNEL_HEAT_PER_SKELETON = 1 -- per tick
local CHANNEL_MAX_HEAT_SKELETONS = 6
local CHANNEL_HEAL_FRACTION = 0.2 -- of max health, per tick

local hold_action = Weapons.bw_necromancer_career_utility_weapon.actions.action_three.default
hold_action.hold_input = "action_three_hold"
hold_action.minimum_hold_time = 0.3
hold_action.total_time = math.huge -- 0.7
hold_action.tb_channel_buff = CHANNEL_BUFF
-- Pressing it used to cancel every skeleton's command (back to following), this only keeps the input handling of that
hold_action.enter_function = function (attacker_unit, input_extension)
	input_extension:clear_input_buffer()

	return input_extension:reset_release_input()
end

-- One tick: the server heals the skeletons (where their health is), the owner client adds the heat
local function tb_channel_tick(unit)
	if not ALIVE[unit] or not HEALTH_ALIVE[unit] then
		return
	end

	local commander_extension = ScriptUnit.has_extension(unit, "ai_commander_system")

	if not commander_extension then
		return
	end

	local is_server = Managers.state.network.is_server
	local owner_player = Managers.player:owner(unit)
	local is_owner = owner_player and owner_player.local_player
	local num_skeletons = 0

	for pet_unit in pairs(commander_extension:get_controlled_units()) do
		if HEALTH_ALIVE[pet_unit] then
			num_skeletons = num_skeletons + 1

			if is_server then
				local health_extension = ScriptUnit.extension(pet_unit, "health_system")
				local max_health = health_extension:get_max_health()

				if health_extension:current_health() < max_health then
					DamageUtils.heal_network(pet_unit, unit, max_health * CHANNEL_HEAL_FRACTION, "raw_heal")
				end
			end
		end
	end

	if is_owner and num_skeletons > 0 then
		local overcharge_extension = ScriptUnit.extension(unit, "overcharge_system")

		-- "charging" is one of the types that skips the per-shot ammo procs and their rpc
		overcharge_extension:add_charge(math.min(num_skeletons, CHANNEL_MAX_HEAT_SKELETONS) * CHANNEL_HEAT_PER_SKELETON, nil, "charging")
	end
end

mod_api.insert_buff_function("tb_necromancer_skeleton_channel_tick", function (unit, buff, params)
	tb_channel_tick(unit)
end)
-- The apply function is the first tick, the update function the ones after
mod_api.insert_buff_template(CHANNEL_BUFF, {
	max_stacks = 1,
	update_frequency = CHANNEL_TICK,
	update_start_delay = CHANNEL_TICK,
	apply_buff_func = "tb_necromancer_skeleton_channel_tick",
	update_func = "tb_necromancer_skeleton_channel_tick",
})

-- The action is a dummy action, so the buff follows its start and finish (flagged on the action settings)
mod:hook_safe(ActionDummy, "client_owner_start_action", function (self, new_action)
	local buff_name = new_action.tb_channel_buff

	if buff_name then
		self._tb_channel_buff_id = Managers.state.entity:system("buff_system"):add_buff_synced(self._owner_unit, buff_name, BuffSyncType.LocalAndServer)
	end
end)
mod:hook_safe(ActionDummy, "finish", function (self)
	local buff_id = self._tb_channel_buff_id

	if buff_id then
		self._tb_channel_buff_id = nil

		Managers.state.entity:system("buff_system"):remove_buff_synced(self._owner_unit, buff_id)
	end
end)

--[[

	Talents

]]
--[[
	Death Ascendant
]]
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_2_2_buff", {
    stat_buff = "increased_weapon_damage_ranged" -- "power_level_ranged"
})
mod_api.update_talent("bw_necromancer", 2, 2, {
    description = "sienna_necromancer_2_2_desc",
    description_values = {},
})
mod_api.insert_text("sienna_necromancer_2_2_desc", "Casting spells grants 5% ranged damage for 6 seconds. Max stacks 5.")

--[[
	Reaping
]]
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_2_3", {
	multiplier = 0 -- 0.25
})
mod_api.insert_text("sienna_necromancer_2_3_desc", "Melee critical attacks have unlimited cleave.")

--[[
	Cursed Blood
]]
-- Direct hit stagger
DamageProfileTemplates.sienna_necromancer_blood_explosion.default_target.power_distribution.impact = 0 -- 0.08
-- Crit burst stagger
DamageProfileTemplates.necromancer_crit_burst_stagger.default_target.power_distribution.impact = 0 -- 0.7
-- Prevent chain bursts
mod_api.insert_proc_function("necromancer_crit_burst", function (owner_unit, buff, params, world, param_order)
	local is_crit = params [param_order.is_critical_strike]
	if not is_crit then
		return
	end

	local is_first_hit = params [param_order.first_hit]
	if not is_first_hit then
		return
	end

	-- Check explosion
	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local exploded_already = false
	if buff_extension then
		exploded_already = buff_extension:has_buff_type("tb_bw_necromancer_cursed_blood_icd")
	end
	if exploded_already then
		return
	end

	local hit_unit = params [param_order.attacked_unit]
	local is_burning, applied_this_frame = Managers.state.status_effect:has_status(hit_unit, StatusEffectNames.burning_balefire)
	if not is_burning or applied_this_frame then
		return
	end

	local damage_dealt = params [param_order.damage_amount]
	if damage_dealt <= 0 then
		return
	end

	local template = buff.template
	local side = Managers.state.side.side_by_unit [owner_unit]
	local hit_pos = POSITION_LOOKUP [hit_unit]
	if not hit_pos then

		return
	end

	local unit_storage = Managers.state.unit_storage
	local hit_go_id = unit_storage:go_id(hit_unit)
	local node_id = 0
	if Unit.has_node(hit_unit, "j_spine") then
		node_id = Unit.node(hit_unit, "j_spine")
	end

	local network_manager = Managers.state.network
	network_manager.network_transmit:send_rpc_server("rpc_play_particle_effect", NetworkLookup.effects ["fx/necromancer_cursed_explosion_blood"], hit_go_id, node_id, Vector3.zero(), Quaternion.identity(), false)
	network_manager.network_transmit:send_rpc_server("rpc_play_particle_effect", NetworkLookup.effects ["fx/necromancer_cursed_explosion_blue"], hit_go_id, node_id, Vector3(0.5, 0, 0), Quaternion.identity(), false)

	local audio_system = Managers.state.entity:system("audio_system")
	audio_system:play_audio_unit_event("Play_career_necro_ability_cursed_blood", hit_unit, "j_spine")

	local broadphase_categories = side.enemy_broadphase_categories
	local nearby_units = FrameTable.alloc_table()
	local num_nearby = AiUtils.broadphase_query(hit_pos, template.radius, nearby_units, broadphase_categories)

	if num_nearby == 0 then
		return
	end

	local t = Managers.time:time("game")
	local propagated_damage = damage_dealt * template.propagation_multiplier
	local career_extension = ScriptUnit.extension(owner_unit, "career_system")
	local power_level = career_extension:get_career_power_level()
	for i = 1, num_nearby do
		local target_unit = nearby_units [i]
		if target_unit ~= hit_unit then
			local damage_direction = Vector3.normalize(POSITION_LOOKUP [target_unit] - hit_pos)
			DamageUtils.add_damage_network(target_unit, owner_unit, propagated_damage, "torso", "buff", nil, damage_direction, "buff", nil, owner_unit, nil, nil, false, nil, nil, nil, nil, true, i)
			DamageUtils.stagger_ai(t, DamageProfileTemplates.necromancer_crit_burst_stagger, i + 1, power_level, target_unit, owner_unit, "torso", damage_direction, nil, nil, false, "buff", owner_unit)
		end
	end

	local buff_system = Managers.state.entity:system("buff_system")
	local buff_to_add = "tb_bw_necromancer_cursed_blood_icd"
	buff_system:add_buff(owner_unit, buff_to_add, owner_unit, false)
end)
-- Added Internal cooldown to prevent chain procs
mod_api.insert_talent_buff_template("bright_wizard", "tb_bw_necromancer_cursed_blood_icd", {
	duration = 0.3
})
-- Cursed blood explosion damage
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_4_1_cursed_blood", {
	propagation_multiplier = 0.10 -- 0.25 
})
mod_api.insert_text("sienna_necromancer_4_1_desc", "Critical attacks against enemies afflicted by the Malediction of Nagash cause them to burst, damaging nearby enemies for 10% of the attack. Cannot trigger more than once every 0.3 seconds.")

--[[
	Lost Souls
]]
-- Remove lost soul stagger
DamageProfileTemplates.trapped_soul.default_target.power_distribution_near.impact = 0 -- 0.25
DamageProfileTemplates.trapped_soul.default_target.power_distribution_far.impact = 0 -- 0.25


