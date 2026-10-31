local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

--[[
	$BEGIN_TB
		---
		## Necromancer

		### Mod Settings
		* Added Skeleton Transparency setting (default 65%, client-side only).
		* Purely visual and applies to all skeletons.

		### Skeletons
		* **Health**
			* Increased Regular/Bladed Skeleton max health to 200 (from 67.5 on cataclysm 3) for all difficulties.
			* Increased Armored/Shield Skeleton max health to 250 (from 84.4 on cataclysm 3) for all difficulties.
		* **Skeleton Resummon Distance**
			* Increased distance for automatic resummoning of skeletons by Necromancer to 50m (from 28m).
		* **Regular/Bladed Skeletons Unarmored Charge (CUSTOM CHARGE)**
			* Added custom charge to all Regular and Bladed Skeletons.
			* Regular/Bladed Skeletons charge for 20m and push enemies away (like SotT pushwall).
		* **Armored/Shielded Skeletons Armored Charge (CUSTOM CHARGE)**
			* Added custom charge to all Armored and Shielded Skeletons.
			* Skeletons charge for 20m and now knocks enemies away (like FK charge).

		### Skeleton Controller Skull
		* Existing commands:
			* `action_one` - Send skeletons to attack (target, if outlined).
			* `action_two` - Cancel skeletons command and default to following mode.
			* `action_two` (hold) + `action_one` - Put skeletons in guard mode at target position.
		* Removed `action_three` cancel skeleons command and default to following mode.
		* `action_three` (hold) - Heal Skeletons
			* Once per second heals all skeletons by 20% of their max health and generate 1 heat per living skeleton (max 6).
			* Quick tap counts as one tick.
		* `action_three` (hold) + `action_one` - Custom Charge
			* Command all skeletons on field to charge 20m towards Sienna's look direction
			* Generates 5 heat per charging skeleton.
			* Skeletons stop early, on wall collision or reaching the 50m auto-resummon distance.
		* `action_three` (hold) + `action_two` - Resummon Skeletons
			* Resummons all skeletons at Sienna's location with their current health.
			* Generates 1 heat per skeleton.
			* Desummoned skeletons are brought back this way.
		* `action_three` (hold) + `weapon_reload` - Desummons Skeletons
			* Desummons all skeletons on field at their current health.
			* Desummoned skeletons still count as living skeletons (for Vanhel's Dance Macabre) and the skeleton display still shows them.
			* `weapon_reload` sacrifices desummoned skeleton when none are on the field, venting heat as usual.
			* Timed skeletons from the ultimate are never desummoned.
			* Desummoned skeletons are lost, when Sienna dies.

		### Talents
		**Vanhel's Danse Macabre**
		- Changed to: For each raised skeleton (on the field or desummoned), increases attack speed by 5%. Max 3 stacks. (From 12% attack speed with at least 4 skeletons.)

		**Death Ascendant**
		- Changed buff to ranged weapon damage (from ranged power).
		- Stacks are now gained per ranged hit dealt (from per spell cast), including each damage tick of the Soulstealer's Soul Rip.

		**Reaping**
		- Changed to: Releasing a skeleton gives 3 stacks. Critical attacks use up a stack to have 25% power and unlimited cleave.

		**Cursed Blood**
		- Releasing a skeleton gives 3 stacks. Bursts use up a stack.
		- No longer requires the enemy to be afflicted by the Malediction of Nagash.

		**Soul Harvest**
		- Harvesting 8 souls now causes the next 3 attacks to be guaranteed Critical Hits (from the next attack). Max 8 stacks.
		- Killing a special with a guaranteed Critical Hit from this also raises a skeleton that decays after 20 seconds.

		**Withering Touch**
		- The burn lasts 20 seconds (from 4) and stacks up to 50 times (from 3).

		**Spirit Leech**
		- Killing an elite now raises a skeleton that decays after 20 seconds (instead of restoring 15% ultimate cooldown).

		**Curse of the Undeath**
		- Releasing a skeleton also gives 3 damage reduction stacks (as well as casting the ultimate).
		- Taking damage removes a stack after 5 seconds (instead of immediately).

		**Lost Souls**
		- Also removes the slowdown from overcharge.
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
	Skeleton release

	Reaping and Cursed Blood run on stacks that releasing (sacrificing) a skeleton gives. The stacks are synced buffs, so
	the client that releases and the server both have them: Reaping spends them on the client, Cursed Blood on the
	server. 20_bw_necromancer_desummon.lua calls on_necromancer_skeleton_released when a skeleton is sacrificed.
]]
local RELEASE_STACKS = 3
local RELEASE_MAX_STACKS = 4 -- three releases' worth
local REAPING_STACK_BUFF = "tb_necromancer_reaping_stack"
local CURSED_BLOOD_STACK_BUFF = "tb_necromancer_cursed_blood_stack"
local CURSE_COUNTER_BUFF = "sienna_necromancer_5_2_counter"
local RELEASE_TALENTS = {
	{
		talent = "sienna_necromancer_2_3",
		stack_buff = REAPING_STACK_BUFF,
	},
	{
		talent = "sienna_necromancer_4_1",
		stack_buff = CURSED_BLOOD_STACK_BUFF,
	},
}

for _, release in ipairs(RELEASE_TALENTS) do
	-- the icon comes from the live talent data, a name from the source dump can be missing in the live atlas
	mod_api.insert_talent_buff_template("bright_wizard", release.stack_buff, {
		icon = TalentUtils.get_talent("bright_wizard", release.talent).icon,
		max_stacks = RELEASE_MAX_STACKS,
	})
end

-- On the client of the necromancer that released the skeleton. Every release gives RELEASE_STACKS stacks
mod.on_necromancer_skeleton_released = function (owner_unit)
	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if not talent_extension then
		return
	end

	local buff_system = Managers.state.entity:system("buff_system")

	for i = 1, #RELEASE_TALENTS do
		local release = RELEASE_TALENTS[i]

		if talent_extension:has_talent(release.talent) then
			for _ = 1, RELEASE_STACKS do
				buff_system:add_buff_synced(owner_unit, release.stack_buff, BuffSyncType.LocalAndServer)
			end
		end
	end

	-- Curse of the Undeath: its stacks are local to the client (the damage reduction they stand for is synced by the
	-- counter buff itself), and a full set is the most there is
	if talent_extension:has_talent("sienna_necromancer_5_2") then
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

		for _ = 1, RELEASE_STACKS do
			buff_extension:add_buff(CURSE_COUNTER_BUFF)
		end
	end
end

--[[
	Vanhel's Danse Macabre
]]
local DANSE_MACABRE_BUFF = "sienna_necromancer_2_1_attack_speed"
local DANSE_MACABRE_MAX_STACKS = 3

mod_api.update_talent_buff_template("bright_wizard", DANSE_MACABRE_BUFF, {
	max_stacks = DANSE_MACABRE_MAX_STACKS, -- 1
	multiplier = 0.05, -- 0.12
})
-- A stack for each raised skeleton, on the field or desummoned (both are in the controlled units count). Checked on
-- a timer, since desummoning and resummoning change the count without the controlled unit events the talent used
mod_api.insert_buff_function("tb_danse_macabre_update", function (unit, buff, params)
	local commander_extension = ScriptUnit.has_extension(unit, "ai_commander_system")
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	if not commander_extension or not buff_extension then
		return
	end

	local wanted_stacks = math.min(commander_extension:get_controlled_units_count(), DANSE_MACABRE_MAX_STACKS)
	local stacks = buff_extension:get_stacking_buff(DANSE_MACABRE_BUFF)
	local current_stacks = stacks and #stacks or 0

	for _ = current_stacks + 1, wanted_stacks do
		buff_extension:add_buff(DANSE_MACABRE_BUFF)
	end

	for i = current_stacks, wanted_stacks + 1, -1 do
		buff_extension:remove_buff(stacks[i].id)
	end
end)
mod_api.insert_talent_buff_template("bright_wizard", "sienna_necromancer_2_1", {
	update_frequency = 0.25,
	update_func = "tb_danse_macabre_update",
})
mod_api.update_talent("bw_necromancer", 2, 1, {
	buffs = {
		"sienna_necromancer_2_1",
	},
	description = "sienna_necromancer_2_1_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_2_1_desc", "For each raised skeleton increases attack speed by 5%. Max 3 stacks.")

--[[
	Death Ascendant
]]
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_2_2_buff", {
    stat_buff = "increased_weapon_damage_ranged" -- "power_level_ranged"
})
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_2_2", {
	event = "on_ranged_hit" -- "on_spell_used"
})
mod_api.update_talent("bw_necromancer", 2, 2, {
    description = "sienna_necromancer_2_2_desc",
    description_values = {},
})
mod_api.insert_text("sienna_necromancer_2_2_desc", "Ranged hits grant 5% ranged damage for 6 seconds. Max stacks 5.")

-- The soulstealer's soul rip (ActionDamageTarget) only runs the ranged hit procs on its final damage step, its other
-- damage ticks never do. So each of those ticks grants a stack here, and the final step if the proc did not
mod:hook(ActionDamageTarget, "_apply_damage_step", function (func, self, hit_unit, power_level, step_data, t)
	local owner_unit = self.owner_unit
	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if not talent_extension or not talent_extension:has_talent("sienna_necromancer_2_2") or not HEALTH_ALIVE[hit_unit] or not Managers.state.side:is_enemy(owner_unit, hit_unit) then
		return func(self, hit_unit, power_level, step_data, t)
	end

	local buff_extension = self.owner_buff_extension
	local stacks_before = buff_extension:num_buff_type("sienna_necromancer_2_2_buff")

	func(self, hit_unit, power_level, step_data, t)

	if not step_data.proc_buffs or buff_extension:num_buff_type("sienna_necromancer_2_2_buff") == stacks_before then
		buff_extension:add_buff("sienna_necromancer_2_2_buff")
	end
end)

--[[
	Reaping
]]
-- A stack is used up by a critical attack, which has the original talent effect (power on critical strikes, melee or
-- ranged, and unlimited cleave) for the attack: the next action ends it
local REAPING_ACTIVE_BUFF = "tb_necromancer_reaping_active"
local REAPING_SHARED_STACK_TIME = 0.5

mod_api.insert_talent_buff_template("bright_wizard", REAPING_ACTIVE_BUFF, {
	duration = 2,
	max_stacks = 1,
	multiplier = 0.25,
	refresh_durations = true,
	stat_buff = "power_level_critical_strike",
	perks = {
		buff_perks.crit_unlimited_cleave,
	},
})

local function tb_remove_reaping_active(buff_extension)
	local active = buff_extension:get_stacking_buff(REAPING_ACTIVE_BUFF)

	if active then
		for i = #active, 1, -1 do
			buff_extension:remove_buff(active[i].id)
		end
	end
end

-- Beams roll a critical every tick: the ticks that follow a spent stack share it (melee swings always spend their own)
mod_api.insert_proc_function("tb_reaping_critical_action", function (owner_unit, buff, params)
	local action_kind = params[1]
	local is_melee = action_kind == "sweep" or action_kind == "shield_slam"
	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local t = Managers.time:time("game")

	if not is_melee and buff.tb_spent_t and t < buff.tb_spent_t + REAPING_SHARED_STACK_TIME then
		buff_extension:add_buff(REAPING_ACTIVE_BUFF)

		return
	end

	local stacks = buff_extension:get_stacking_buff(REAPING_STACK_BUFF)

	if stacks and #stacks > 0 then
		buff.tb_spent_t = t

		buff_extension:remove_buff(stacks[#stacks].id)
		buff_extension:add_buff(REAPING_ACTIVE_BUFF)
	else
		tb_remove_reaping_active(buff_extension)
	end
end)
mod_api.insert_proc_function("tb_reaping_non_critical_action", function (owner_unit, buff, params)
	tb_remove_reaping_active(ScriptUnit.extension(owner_unit, "buff_system"))
end)
mod_api.insert_talent_buff_template("bright_wizard", "sienna_necromancer_2_3", {
	{
		buff_func = "tb_reaping_critical_action",
		event = "on_critical_action",
		name = "tb_reaping_critical_action",
	},
	{
		buff_func = "tb_reaping_non_critical_action",
		event = "on_non_critical_action",
		name = "tb_reaping_non_critical_action",
	},
})
mod_api.update_talent("bw_necromancer", 2, 3, {
	description = "sienna_necromancer_2_3_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_2_3_desc", "Releasing a skeleton grant the next 3 critical attacks 25% power and unlimited cleave.")

--[[
	Cursed Blood
]]
local CURSED_BLOOD_SAME_ATTACK_TIME = 0.1
-- Direct hit stagger
DamageProfileTemplates.sienna_necromancer_blood_explosion.default_target.power_distribution.impact = 0.08 -- 0
-- Crit burst stagger
DamageProfileTemplates.necromancer_crit_burst_stagger.default_target.power_distribution.impact = 0.7 -- 0
mod_api.insert_proc_function("necromancer_crit_burst", function (owner_unit, buff, params, world, param_order)
	local is_crit = params [param_order.is_critical_strike]
	if not is_crit then
		return
	end

	local is_first_hit = params [param_order.first_hit]
	if not is_first_hit then
		return
	end

	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

	-- Prevent chain bursts (internal cooldown of 0.3s)
	-- local exploded_already = false
	-- if buff_extension then
	-- 	exploded_already = buff_extension:has_buff_type("tb_bw_necromancer_cursed_blood_icd")
	-- end
	-- if exploded_already then
	-- 	return
	-- end

	-- Bursts use up the stacks that releasing a skeleton gives, one per attack: first_hit is one hit per attack, but
	-- every pellet of a shot has its own, so the hits that land together share a burst
	local stacks = buff_extension:get_stacking_buff(CURSED_BLOOD_STACK_BUFF)
	if not stacks or #stacks == 0 then
		return
	end

	local t = Managers.time:time("game")
	if buff.tb_burst_t and t < buff.tb_burst_t + CURSED_BLOOD_SAME_ATTACK_TIME then
		return
	end

	-- Any enemy, not only the ones afflicted by the Malediction of Nagash (balefire)
	local hit_unit = params [param_order.attacked_unit]
	if not Managers.state.side:is_enemy(owner_unit, hit_unit) then
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

	buff.tb_burst_t = t

	buff_extension:remove_buff(stacks[#stacks].id)

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

	-- local buff_system = Managers.state.entity:system("buff_system")
	-- local buff_to_add = "tb_bw_necromancer_cursed_blood_icd"
	-- buff_system:add_buff(owner_unit, buff_to_add, owner_unit, false)
end)
-- Added Internal cooldown to prevent chain procs
-- mod_api.insert_talent_buff_template("bright_wizard", "tb_bw_necromancer_cursed_blood_icd", {
-- 	duration = 0.3
-- })
-- Cursed blood explosion damage
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_4_1_cursed_blood", {
	propagation_multiplier = 0.25 -- 0.10
})
mod_api.insert_text("sienna_necromancer_4_1_desc", "Releasing a skeleton cause the next 3 critical attacks against enemies to burst, damaging nearby enemies for 25% of the attack.")

--[[
	Raising a skeleton that decays (Soul Harvest, Spirit Leech)
]]
-- The necromancer_pet template has a 20s duration: the commander extension takes the skeleton away when it is over
local TIMED_SKELETON_TEMPLATE = "necromancer_pet"
local TIMED_SKELETON_BREED = "pet_skeleton"

-- Server only
local function tb_raise_timed_skeleton(owner_unit)
	if not Managers.state.network.is_server or not ALIVE[owner_unit] or not HEALTH_ALIVE[owner_unit] then
		return
	end

	local career_extension = ScriptUnit.has_extension(owner_unit, "career_system")
	local passive = career_extension and career_extension:get_passive_ability_by_name("bw_necromancer")

	if passive then
		passive:spawn_pet(TIMED_SKELETON_TEMPLATE, TIMED_SKELETON_BREED)
	end
end

--[[
	Soul Harvest
]]
local SOUL_HARVEST_CRITS = 3
local SOUL_HARVEST_MAX_CRITS = 8
local SOUL_HARVEST_EXECUTE_BUFF = "sienna_necromancer_4_2_execute"
local SOUL_HARVEST_ARMED_BUFF = "tb_necromancer_soul_harvest_armed"

-- 8 souls give guaranteed crits, one for each of the next attacks
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_4_2_soul_rip_stack", {
	max_stack_data = {
		buffs_to_add = table.fill({}, SOUL_HARVEST_CRITS, SOUL_HARVEST_EXECUTE_BUFF), -- { SOUL_HARVEST_EXECUTE_BUFF }
	},
})
mod_api.update_talent_buff_template("bright_wizard", SOUL_HARVEST_EXECUTE_BUFF, {
	max_stacks = SOUL_HARVEST_MAX_CRITS, -- math.huge
})
-- Set while an attack that used up one of those crits is under way. It is synced and carries the kill proc, so it is
-- also on the server, where the skeleton is raised (the talent itself only has its buffs on the client)
mod_api.insert_proc_function("tb_soul_harvest_kill", function (owner_unit, buff, params)
	local breed = params[2]

	if breed and breed.special then
		tb_raise_timed_skeleton(owner_unit)

		-- one skeleton for each attack
		ScriptUnit.extension(owner_unit, "buff_system"):remove_buff(buff.id)
	end
end)
mod_api.insert_talent_buff_template("bright_wizard", SOUL_HARVEST_ARMED_BUFF, {
	buff_func = "tb_soul_harvest_kill",
	duration = 2,
	event = "on_kill",
	max_stacks = 1,
	refresh_durations = true,
})

local function tb_remove_soul_harvest_armed(buff_extension)
	local armed = buff_extension:get_stacking_buff(SOUL_HARVEST_ARMED_BUFF)

	if armed then
		for i = #armed, 1, -1 do
			buff_extension:remove_buff(armed[i].id)
		end
	end
end

-- The vanilla handler used up a guaranteed crit on every critical action. This one also remembers that it did
mod_api.insert_proc_function("tb_soul_harvest_critical_action", function (owner_unit, buff, params)
	local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	local stacks = buff_extension:get_stacking_buff(SOUL_HARVEST_EXECUTE_BUFF)

	if stacks and #stacks > 0 then
		buff_extension:remove_buff(stacks[#stacks].id)

		Managers.state.entity:system("buff_system"):add_buff_synced(owner_unit, SOUL_HARVEST_ARMED_BUFF, BuffSyncType.LocalAndServer)
	else
		tb_remove_soul_harvest_armed(buff_extension)
	end
end)
mod_api.insert_proc_function("tb_soul_harvest_non_critical_action", function (owner_unit, buff, params)
	tb_remove_soul_harvest_armed(ScriptUnit.extension(owner_unit, "buff_system"))
end)
mod_api.insert_talent_buff_template("bright_wizard", "sienna_necromancer_4_2_soul_rip_handler", {
	{
		buff_func = "tb_soul_harvest_critical_action",
		event = "on_critical_action",
		name = "tb_soul_harvest_critical_action",
	},
	{
		buff_func = "tb_soul_harvest_non_critical_action",
		event = "on_non_critical_action",
		name = "tb_soul_harvest_non_critical_action",
	},
})

mod_api.update_talent("bw_necromancer", 4, 2, {
	description = "sienna_necromancer_4_2_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_4_2_desc", "The Malediction of Nagash rips the soul from targets that die. Harvesting 8 souls grants 3 guaranteed critical strikes, which on special kill raise a skeleton that decays after 20 seconds.")

--[[
	Withering Touch
]]
-- Its own copy of the burn, the ultimate and the dual wield skeletons' pets use the regular one
local WITHERING_TOUCH_DOT = "tb_sienna_necromancer_4_3_dot"
local withering_touch_dot = table.clone(BuffTemplates.sienna_necromancer_4_3_dot.buffs[1])

withering_touch_dot.name = WITHERING_TOUCH_DOT
withering_touch_dot.duration = 30 -- 4
withering_touch_dot.max_stacks = 100 -- 3

mod_api.insert_buff_template(WITHERING_TOUCH_DOT, withering_touch_dot)

DotTypeLookup[WITHERING_TOUCH_DOT] = "burning_dot"
BalefireDots[WITHERING_TOUCH_DOT] = true

mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_4_3_withering_touch", {
	dot_template_name = WITHERING_TOUCH_DOT, -- "sienna_necromancer_4_3_dot"
})

--[[
	Spirit Leech
]]
-- Same trigger as before (killing an elite), a skeleton instead of the ultimate cooldown
mod_api.insert_proc_function("sienna_necromancer_5_1_on_kill", function (owner_unit, buff, params)
	local breed = params[2]

	if breed and breed.elite then
		tb_raise_timed_skeleton(owner_unit)
	end
end)
mod_api.update_talent("bw_necromancer", 5, 1, {
	description = "sienna_necromancer_5_1_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_5_1_desc", "Killing an elite enemy raises a skeleton that decays after 20 seconds.")

--[[
	Curse of the Undeath
]]
-- Stacks come from casting the ultimate and from releasing a skeleton (on_necromancer_skeleton_released). Like Ablative
-- Armor (08_dr_engineer.lua) a hit queues the loss of a stack, which happens later
local CURSE_LOSS_DELAY = 5
local CURSE_CHECK_INTERVAL = 0.25

mod_api.insert_proc_function("tb_curse_of_the_undeath_queue_loss", function (owner_unit, buff, params)
	local stacks = ScriptUnit.extension(owner_unit, "buff_system"):get_stacking_buff(CURSE_COUNTER_BUFF)
	local pending_losses = buff.tb_pending_losses

	if not pending_losses then
		pending_losses = {}
		buff.tb_pending_losses = pending_losses
	end

	-- Hits taken without a stack to lose don't queue anything
	if stacks and #pending_losses < #stacks then
		pending_losses[#pending_losses + 1] = Managers.time:time("game") + CURSE_LOSS_DELAY
	end
end)
mod_api.insert_buff_function("tb_curse_of_the_undeath_update", function (unit, buff, params)
	local pending_losses = buff.tb_pending_losses

	if pending_losses and pending_losses[1] and pending_losses[1] <= Managers.time:time("game") then
		table.remove(pending_losses, 1)

		local buff_extension = ScriptUnit.extension(unit, "buff_system")
		local stacks = buff_extension:get_stacking_buff(CURSE_COUNTER_BUFF)

		if stacks and #stacks > 0 then
			buff_extension:remove_buff(stacks[#stacks].id)
		end
	end
end)
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_5_2_counter_remover", {
	buff_func = "tb_curse_of_the_undeath_queue_loss", -- "remove_buff_stack"
	update_func = "tb_curse_of_the_undeath_update",
	update_frequency = CURSE_CHECK_INTERVAL,
})
mod_api.update_talent("bw_necromancer", 5, 2, {
	description = "sienna_necromancer_5_2_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_5_2_desc", "Casting Raisde Dead or releasing a skeleton grants 3 stacks of 80% damage reduction. Taking damage removes a stack after 5 seconds.")

--[[
	Lost Souls
]]
-- Remove lost soul stagger
--DamageProfileTemplates.trapped_soul.default_target.power_distribution_near.impact = 0 -- 0.25
--DamageProfileTemplates.trapped_soul.default_target.power_distribution_far.impact = 0 -- 0.25
-- No overcharge slowdown: the overcharge state buffs without the attack speed and movement penalties
mod_api.update_talent_buff_template("bright_wizard", "sienna_necromancer_5_3", {
	perks = {
		buff_perks.overcharge_no_slow,
	},
})
mod_api.update_talent("bw_necromancer", 5, 3, {
	description = "sienna_necromancer_5_3_desc",
	description_values = {},
})
mod_api.insert_text("sienna_necromancer_5_3_desc", "Venting 12% overcharge unleashes a soul that steals health from a nearby enemy restoring 2 temporary health. No overcharge slowdown.")


