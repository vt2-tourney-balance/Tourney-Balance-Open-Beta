local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Sister of the Thorn
		### Career Ability
		- Increased ultimate cooldown to 70s (from 40s).

		### Passives
		**A Cluster of Radiants**
		- Increased passive ultimate cooldown to 70s (from 60s).

		**A Sustenance of Leechlings**
		- Decreased temp health siphon from team to 10% (from 100%).

		### Talents
		**Briar's Malice**
		- Only consume crit stacks on hit, and at most 1 stack per attack (even against multiple enemies).

		**Atharti's Delight**
		- Only applies on melee headshots.

		**Bonded Spirit**
		- Updated description: Internal CD of losing cooldown is  1s.

		**Radiant Inheritance**
		- Can be activated with Thornwake (regular ult).
		- Recasting refreshes the and extends the duration to 20s.

		**Ironbark Thicket**
		- Reduced wall duration to 6s (from 10s).
		- When holding cast, pressing weapon special key toggles a shortened-wall mode (Ironbark Thicket icon)
		- A shortened wall no longer blocks movement, but enemies touching it are slowed by 50% for 10s.

		**Blackvenom Thicket**
		- Added 40% cooldown reduction.
	$END_TB
]]

--[[

	Ultimate

]]
mod_api.update_career_ability_cooldown("we_thornsister", 70) -- 40


--[[
	Passive
]]
--[[
	A Cluster of Radiants
]]
PassiveAbilitySettings.we_thornsister.passive_ability_classes[1].init_data.cooldown = 70 -- 60
mod_api.insert_text("career_passive_desc_we_thornsister", "Kerillian is granted Radiance (a free use of her career skill) every 70 seconds.")

--[[
	A Sustenance of Leechlings
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_passive_temp_health_funnel_aura_buff", {
	multiplier = 0.10
})

--[[

	Talents

]]
--[[
	Briar's Malice
]]
-- consume only on hit
mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_crit_on_any_ability_handler", {
	event = "on_hit",
})

--[[
	Atharti's Delight
]]
-- only converts poison to bleed on headshots (no native "on headshot" event exists, so gate the vanilla func on hit_zone_name instead)
mod_api.insert_proc_function("tb_thorn_sister_add_bleed_on_headshot", function (owner_unit, buff, params)
	local hit_zone_name = params[3]

	if hit_zone_name == "head" or hit_zone_name == "neck" then
		return ProcFunctions.thorn_sister_add_bleed_on_hit(owner_unit, buff, params)
	end
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_big_bleed", {
	buff_func = "tb_thorn_sister_add_bleed_on_headshot"
})
mod_api.insert_text("kerillian_thorn_sister_crit_big_bleed_desc_2", "Melee headshots against poisoned targets make them bleed.")

--[[
	Bonded Spirit
]]
mod_api.insert_text("kerillian_thorn_sister_faster_passive_desc", "Reduce the cooldown of Radiance by 50%%, taking damage increases the cooldown by 2 seconds (1 second internal cooldown).")

--[[
	Radiant Inheritance
]]
-- longer duration for radiant inheritance
local radiant_thorn_stack_count = {}
local function tb_radiant_thorn_duration_modifier(unit, sub_buff_template, duration, buff_extension, params)
	local is_active = buff_extension:has_buff_type("kerillian_thorn_sister_team_buff_aura")
	local current_count = radiant_thorn_stack_count[unit] or 0
	local new_count = math.min(is_active and current_count + 1 or 1, 2)

	radiant_thorn_stack_count[unit] = new_count

	return duration * new_count
end
mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_team_buff_aura", {
	duration = 10,
	max_stacks = 2,
	refresh_durations = true,
	duration_modifier_func = tb_radiant_thorn_duration_modifier,
})
-- trigger radiant inheritance on regular ult too, not just extra-charge uses
mod_api.update_talent_buff_template("wood_elf", "kerillian_thorn_sister_passive_team_buff", {
	event = "on_ability_cooldown_started",
})
mod_api.insert_text("kerillian_thorn_sister_passive_team_buff_desc", "Consuming Radiance or Thornwake grants Kerillian and nearby allies 15.0%% power and 5.0%% critical strike chance for 10 seconds. Duration can stack 2 times.")

--[[
	Ironbark Thicket
]]
-- Only kerillian_thorn_sister_tanky_wall gets this. action_three toggles "short mode" while aiming (unused by
-- this weapon otherwise). Off = vanilla upright wall. On = spawns as TWO units instead of one:
--   - an invisible "collision" unit, tilted a full 90 degrees - the exact mechanism already proven to shrink
--     the actual hitbox (both for movement-blocking and weapon sweeps), since rotation reliably propagates to
--     collision here where scale does not (Unit.set_local_scale doesn't reliably resize Havok collision
--     shapes, especially non-uniformly - confirmed by attacks still landing at the old, unscaled height when
--     we tried scale alone). This unit alone governs everything gameplay-relevant (enemy-slow, walkability) -
--     the rest of this comment block only concerns how the OTHER unit looks; nothing below changes this one.
--   - a visible "cosmetic" unit for looks only. Originally scaled short while staying upright, but that hit
--     the same scale-doesn't-move-collision problem: attacks were still landing at its old, unscaled height,
--     since filter_trigger alone didn't reliably stop weapon-sweep hit detection either. Fixed the same way as
--     the collision unit - not by trying to disable its collision, but by physically relocating it: flipped a
--     full 180 degrees (root end now on top) and raised so only the root end pokes above ground -
--     TB_SHORT_WALL_VISIBLE_HEIGHT above ground, TB_SHORT_WALL_HEIGHT - TB_SHORT_WALL_VISIBLE_HEIGHT buried
--     below it, so wherever its collision actually is, it's out of the way rather than relying on a filter.
-- Both units share the same wall_index, so they despawn together via ThornSisterWallExtension's group logic.
local TB_SHORT_WALL_SIGNAL_ANGLE = math.rad(2) -- imperceptible; only used to smuggle "short mode" through the RPC (see note below)
local TB_SHORT_WALL_COLLISION_TILT_ANGLE = math.pi / 2 -- full tilt for the invisible collision unit
local TB_SHORT_WALL_FLIP_ANGLE = math.pi -- 180 degrees, for the cosmetic unit
-- Assumes ~3 unit base mesh height (matches the targeting decal's own Z-scale).
local TB_SHORT_WALL_HEIGHT = 3
local TB_SHORT_WALL_VISIBLE_HEIGHT = 0.5 -- how much of the flipped cosmetic unit pokes up above the ground
local function tb_signal_short_mode_rotation(wall_rotation, short_mode_angle)
	local up = Vector3.up()
	local forward = Quaternion.forward(wall_rotation)
	local cos_t = math.cos(short_mode_angle)
	local sin_t = math.sin(short_mode_angle)
	local tilted_up = up * cos_t + forward * sin_t
	local tilted_forward = forward * cos_t - up * sin_t

	return Quaternion.look(tilted_forward, tilted_up)
end

-- Short wall segments, weak-keyed; set in spawn_func below, read by the enemy-slow hook further down.
local tb_short_wall_units = setmetatable({}, { __mode = "k" })
-- The cosmetic companion (see spawn_func) shares the same extension_init_data, so it gets its own
-- AreaDamageExtension and independently ticks into the same hook - tracked here so that hook can recognize
-- and fully ignore it (the paired collision unit at the same position already handles everything it needs to).
local tb_short_wall_cosmetic_units = setmetatable({}, { __mode = "k" })
-- Shared by both slow mechanisms below.
local TB_SHORT_WALL_ENEMY_SLOW_MULTIPLIER = 0.5 -- 50% slowdown

-- AI movement has two independent code paths, so the slow is applied in two places:
-- (1) navbot-driven pathing (normal walk/run), via AINavigationExtension's movement-modifier stack - same
-- API the Necromancer's own charge slow uses.
mod_api.insert_buff_function("tb_apply_short_wall_enemy_slow", function (unit, buff, params, world)
	if Managers.state.network.is_server then
		local navigation_extension = ScriptUnit.has_extension(unit, "ai_navigation_system")

		if navigation_extension then
			buff.movement_modifier_id = navigation_extension:add_movement_modifier(buff.template.multiplier)
		end
	end
end)
mod_api.insert_buff_function("tb_remove_short_wall_enemy_slow", function (unit, buff, params, world)
	if Managers.state.network.is_server and buff.movement_modifier_id then
		local navigation_extension = ScriptUnit.has_extension(unit, "ai_navigation_system")

		if navigation_extension then
			navigation_extension:remove_movement_modifier(buff.movement_modifier_id)
		end
	end
end)
mod_api.insert_buff_template("tb_short_wall_enemy_slow", {
	apply_buff_func = "tb_apply_short_wall_enemy_slow",
	remove_buff_func = "tb_remove_short_wall_enemy_slow",
	multiplier = TB_SHORT_WALL_ENEMY_SLOW_MULTIPLIER, -- direct factor, not a stacking_multiplier delta
	duration = 10, -- runs its full course from first touch - refresh_durations deliberately omitted
	max_stacks = 1,
})
-- (2) charges/lunges bypass the navbot and set velocity directly via locomotion_extension:set_wanted_velocity,
-- so scale it there too. Two parallel extension implementations exist (Lua vs engine-optimized); hook both.
-- Confirmed normal navbot movement never calls set_wanted_velocity, so no double-application between (1)/(2).
local function tb_scale_velocity_if_slowed(unit, wanted_velocity)
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	if buff_extension and buff_extension:has_buff_type("tb_short_wall_enemy_slow") then
		return wanted_velocity * TB_SHORT_WALL_ENEMY_SLOW_MULTIPLIER
	end

	return wanted_velocity
end
mod:hook(AILocomotionExtension, "set_wanted_velocity", function (func, self, wanted_velocity)
	func(self, tb_scale_velocity_if_slowed(self._unit, wanted_velocity))
end)
mod:hook(AILocomotionExtensionC, "set_wanted_velocity", function (func, self, wanted_velocity)
	func(self, tb_scale_velocity_if_slowed(self._unit, wanted_velocity))
end)

-- Cosmetic marker buff: shows Ironbark's own talent icon while short-wall mode is toggled on.
mod_api.insert_buff_template("tb_short_wall_mode_active", {
	icon = "kerillian_thornsister_healing_wall",
	max_stacks = 1,
})
local function tb_remove_buff_type(buff_extension, buff_name)
	local stacks = buff_extension:get_stacking_buff(buff_name)

	if stacks then
		for i = 1, #stacks do
			buff_extension:remove_buff(stacks[i].id)
		end
	end
end
-- Toggle (not hold) via action_three, edge-detected so holding it doesn't rapid-fire the toggle. State lives
-- on owner_unit (not self) so it persists across separate casts rather than resetting each time.
local tb_short_wall_toggle_state = setmetatable({}, { __mode = "k" })
mod:hook_safe(ActionCareerWEThornsisterTargetWall, "_update_targeting", function (self)
	if self.is_bot then
		self._wall_short_mode_angle = 0
		return
	end

	local owner_unit = self.owner_unit
	local input_extension = ScriptUnit.extension(owner_unit, "input_system")
	local action_three_held = input_extension:get("action_three")

	if action_three_held and not self._tb_action_three_was_held then
		local is_now_active = not tb_short_wall_toggle_state[owner_unit]

		tb_short_wall_toggle_state[owner_unit] = is_now_active

		local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

		if buff_extension then
			if is_now_active then
				buff_extension:add_buff("tb_short_wall_mode_active")
			else
				tb_remove_buff_type(buff_extension, "tb_short_wall_mode_active")
			end
		end
	end

	self._tb_action_three_was_held = action_three_held
	self._wall_short_mode_angle = tb_short_wall_toggle_state[owner_unit] and TB_SHORT_WALL_SIGNAL_ANGLE or 0
end)
-- Carry the short-mode angle through the action chain to spawn_func.
mod:hook(ActionCareerWEThornsisterTargetWall, "finish", function (func, self, reason)
	local targeting_data = func(self, reason)

	if targeting_data then
		targeting_data.wall_short_mode_angle = self._wall_short_mode_angle or 0
	end

	return targeting_data
end)
mod:hook(ActionCareerWEThornsisterWall, "client_owner_start_action", function (func, self, new_action, t, chain_action_data, power_level, action_init_data)
	self._wall_short_mode_angle = chain_action_data and chain_action_data.wall_short_mode_angle or 0

	func(self, new_action, t, chain_action_data, power_level, action_init_data)
end)
-- Fold the short-mode signal into wall_rotation here so it survives request_spawn_template_unit's RPC - a
-- plain Lua variable doesn't, since spawn_func runs later from the RPC handler, not synchronously inside this.
mod:hook(ActionCareerWEThornsisterWall, "_spawn_wall", function (func, self, num_segments, segments, wall_rotation)
	local wants_short_mode = self.talent_extension:has_talent("kerillian_thorn_sister_tanky_wall")
	local short_mode_angle = wants_short_mode and self._wall_short_mode_angle or 0
	local final_wall_rotation = short_mode_angle > 0 and tb_signal_short_mode_rotation(wall_rotation, short_mode_angle) or wall_rotation

	func(self, num_segments, segments, final_wall_rotation)
end)

local WALL_TYPES = table.enum("default", "bleed")
local UNIT_NAMES = {
	default = "units/beings/player/way_watcher_thornsister/abilities/ww_thornsister_thorn_wall_01",
	bleed = "units/beings/player/way_watcher_thornsister/abilities/ww_thornsister_thorn_wall_01_bleed"
}
SpawnUnitTemplates.thornsister_thorn_wall_unit = {
	spawn_func = function (source_unit, position, rotation, state_int, group_spawn_index)
		local UNIT_NAME = UNIT_NAMES[WALL_TYPES.default]
		local UNIT_TEMPLATE_NAME = "thornsister_thorn_wall_unit"
		local wall_index = state_int
		local despawn_sound_event = "career_ability_kerillian_sister_wall_disappear"
		local life_time = 6
		-- forward.z is exactly 0 for an untilted wall_rotation; any deviation means short mode's signal tilt
		-- was folded in above. Also gates the nav-tag volume below, which is rotation/scale-independent and
		-- would otherwise still block AI pathing through a shortened wall.
		local is_short_mode = math.abs(Quaternion.forward(rotation).z) > 0.0001
		local area_damage_params = {
			aoe_dot_damage = 0,
			radius = 0.3,
			area_damage_template = "we_thornsister_thorn_wall",
			invisible_unit = false,
			nav_tag_volume_layer = "temporary_wall",
			create_nav_tag_volume = not is_short_mode,
			aoe_init_damage = 0,
			damage_source = "career_ability",
			aoe_dot_damage_interval = 0,
			damage_players = false,
			source_attacker_unit = source_unit,
			life_time = life_time
		}
		local props_params = {
			life_time = life_time,
			owner_unit = source_unit,
			despawn_sound_event = despawn_sound_event,
			wall_index = wall_index
		}
		local health_params = {
			health = 20
		}
		local buffs_to_add = nil
		local source_talent_extension = ScriptUnit.has_extension(source_unit, "talent_system")

		if source_talent_extension then
			if source_talent_extension:has_talent("kerillian_thorn_sister_tanky_wall") then
				local life_time_mult = 1
				local life_time_bonus = 4.2
				area_damage_params.life_time = area_damage_params.life_time * life_time_mult + life_time_bonus
				props_params.life_time = (6/10) *(props_params.life_time * life_time_mult + life_time_bonus)
			elseif source_talent_extension:has_talent("kerillian_thorn_sister_debuff_wall") then
				local life_time_mult = 0.17
				local life_time_bonus = 0
				area_damage_params.create_nav_tag_volume = false
				area_damage_params.life_time = area_damage_params.life_time * life_time_mult + life_time_bonus
				props_params.life_time = props_params.life_time * life_time_mult + life_time_bonus
				UNIT_NAME = UNIT_NAMES[WALL_TYPES.bleed]
			end
		end

		local extension_init_data = {
			area_damage_system = area_damage_params,
			props_system = props_params,
			health_system = health_params,
			death_system = {
				death_reaction_template = "thorn_wall",
				is_husk = false
			},
			hit_reaction_system = {
				is_husk = false,
				hit_reaction_template = "level_object"
			}
		}
		local wall_unit = Managers.state.unit_spawner:spawn_network_unit(UNIT_NAME, UNIT_TEMPLATE_NAME, extension_init_data, position, rotation)
		local random_spin = Quaternion(Vector3.up(), math.random() * 2 * math.pi - math.pi)

		if is_short_mode then
			tb_short_wall_units[wall_unit] = true

			-- wall_unit becomes the invisible collision backbone: fully tilted (proven to correctly shrink
			-- both movement-blocking and attack-hit collision, unlike scale) so attacks aimed at normal swing
			-- height pass over it.
			local collision_rotation = tb_signal_short_mode_rotation(rotation, TB_SHORT_WALL_COLLISION_TILT_ANGLE)

			Unit.set_local_rotation(wall_unit, 0, Quaternion.multiply(collision_rotation, random_spin))
			Unit.set_unit_visibility(wall_unit, false)

			-- Separate, purely cosmetic companion: wall_unit above is what actually governs gameplay. Flipped
			-- 180 (root end on top) and raised so only the root end - TB_SHORT_WALL_VISIBLE_HEIGHT of it -
			-- sticks up; the rest (including its own collision, moving with it since this is rotation/position,
			-- not scale) is buried below ground where it can't interfere with attacks or movement.
			local cosmetic_position = position + Vector3.up() * TB_SHORT_WALL_VISIBLE_HEIGHT
			local cosmetic_unit = Managers.state.unit_spawner:spawn_network_unit(UNIT_NAME, UNIT_TEMPLATE_NAME, extension_init_data, cosmetic_position, rotation)

			tb_short_wall_cosmetic_units[cosmetic_unit] = true

			local flipped_rotation = tb_signal_short_mode_rotation(rotation, TB_SHORT_WALL_FLIP_ANGLE)

			Unit.set_local_rotation(cosmetic_unit, 0, Quaternion.multiply(flipped_rotation, random_spin))

			-- Belt-and-suspenders: shouldn't matter now that the collision itself is buried, but harmless to keep.
			local cosmetic_actor = Unit.actor(cosmetic_unit, "c_simple")

			if cosmetic_actor then
				Actor.set_collision_filter(cosmetic_actor, "filter_trigger")
			end

			local cosmetic_props_extension = ScriptUnit.has_extension(cosmetic_unit, "props_system")

			if cosmetic_props_extension then
				cosmetic_props_extension.group_spawn_index = group_spawn_index
			end
		else
			Unit.set_local_rotation(wall_unit, 0, random_spin)
		end

		local buff_extension = ScriptUnit.has_extension(wall_unit, "buff_system")

		if buff_extension and buffs_to_add then
			for i = 1, #buffs_to_add do
				buff_extension:add_buff(buffs_to_add[i])
			end
		end

		local thorn_wall_extension = ScriptUnit.has_extension(wall_unit, "props_system")

		if thorn_wall_extension then
			thorn_wall_extension.group_spawn_index = group_spawn_index
		end
	end
}
mod_api.insert_text("kerillian_thorn_sister_tanky_wall_desc_2", "Increase the width of the Thorn Wall. While casting, press weapon special to switch to Thorn Bush. Enemies walking through Thron Bush are slowed by 50% for 10s.")

-- Registered last on purpose: piggybacks on the wall's own per-tick area-effect to slow nearby enemies, for
-- segments tracked as short-mode above. If registering a hook on this particular table
-- (AreaDamageTemplates.templates[name], not AreaDamageTemplates[name] directly) ever breaks, keeping it last
-- means that failure can't silently prevent the rest of this section from loading.
--
-- Also swaps who the wall slows, standing vs short: vanilla's own client.update (func) is what slows nearby
-- allies - only call it for standing walls (which still fully block enemies, so there's nothing for the enemy
-- slow to compensate for) and skip it for short walls (movement isn't blocked there, so players shouldn't pay
-- the ally-slow tax just for being near it - enemies get the tb_short_wall_enemy_slow debuff instead).
local tb_short_wall_last_check_t = setmetatable({}, { __mode = "k" })
local TB_SHORT_WALL_CHECK_INTERVAL = 0.1 -- fixed interval; per-frame scanning got expensive with many enemies nearby
local TB_SHORT_WALL_ENEMY_SLOW_RADIUS = 0.5 -- kept separate from the 0.3 "radius" param (ally-slow/nav-tag)
mod:hook(AreaDamageTemplates.templates.we_thornsister_thorn_wall.client, "update", function (func, world, radius, aoe_unit, ...)
	if tb_short_wall_cosmetic_units[aoe_unit] then
		return -- purely visual; the paired collision unit at the same position handles everything
	end

	if not tb_short_wall_units[aoe_unit] then
		func(world, radius, aoe_unit, ...) -- standing wall: vanilla ally-slow only, no enemy-slow scan below
		return
	end

	local t = Managers.time:time("game")
	local last_check_t = tb_short_wall_last_check_t[aoe_unit]

	if last_check_t and t - last_check_t < TB_SHORT_WALL_CHECK_INTERVAL then
		return
	end

	tb_short_wall_last_check_t[aoe_unit] = t

	local side = Managers.state.side.side_by_unit[aoe_unit]

	if not side then
		return
	end

	local area_damage_position = POSITION_LOOKUP[aoe_unit]

	if not area_damage_position then
		return
	end

	local enemy_units = side:enemy_units()

	for _, enemy_unit in pairs(enemy_units) do
		local unit_position = POSITION_LOOKUP[enemy_unit]

		if unit_position then
			-- horizontal-only, so terrain height differences between the wall and an enemy's feet don't matter
			local distance = Vector3.distance_squared(Vector3.flat(unit_position), Vector3.flat(area_damage_position))

			if distance < TB_SHORT_WALL_ENEMY_SLOW_RADIUS * TB_SHORT_WALL_ENEMY_SLOW_RADIUS then
				local buff_extension = ScriptUnit.has_extension(enemy_unit, "buff_system")

				if buff_extension then
					buff_extension:add_buff("tb_short_wall_enemy_slow")
				end
			end
		end
	end
end)

--[[
	Blackvenom Thicket
]]
mod_api.update_talent("we_thornsister", 6, 3, {
    buffs = {
        "tb_blackvenom_cdr"
    }
})
mod_api.insert_talent_buff_template("wood_elf", "tb_blackvenom_cdr", {
	stat_buff = "activated_cooldown",
	multiplier = -0.4,
	max_stacks = 1
})
mod_api.insert_text("kerillian_thorn_sister_debuff_wall_desc_2", "Thornwake instead causes roots to burst from the ground, staggering enemies and applying Blackvenom to them. Reduces cooldown by 40%%.")
