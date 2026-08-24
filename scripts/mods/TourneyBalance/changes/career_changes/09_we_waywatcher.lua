local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		---
		## Waystalker
		### Career Ability
		- Damage cleave buff.
		- Prioritizes specials now.
		- Does not consume Bloodshot anymore.

		### Passives
		**Amaranthe**
		- Additionally regen 1 ammo every tick.
		- Heath regen no longer replaces temp health.

		### Talents
		**Drakira's Alacrity**
		- Increased attack speed to 20% (from 15%) and duration to 10s (from 5s).

		**Isha's Embrace**
		- Increased health regen bonus to 100% (from 50%) and health regen cap to 100% max health.
		- No longer grants Amaranthe's ammo regen.
		**Spirit Arrows**
		- Additionally increases Amaranthes ammo regen by 1 ammo regen per tick (to total of 2 ammo per tick).

		**Fervent Huntress**
		- Additionally allows Kerillian to pass through enemies for 10s.

		**Ricochet**
		- Fully charging for 1 second grants ricochet projectiles true-flight.
		- Applying true-flight costs 20% ult cooldown drained over 10 seconds.
		- Fixed ricocheting after enemy cleave.

		**Piercing Shot**
		- Cooldown refund when headshotting enemy works when piercing through team mate first.

		**Loaded Bow**
		- Increased additional Trueshot Volley arrows to +2 (from +1).

		**Kurnous Reward**
		- Reduced ammo regen to 20% (from 30%) per kill.
	$END_TB
]]
	
--[[
	
	Ultimate

]]
-- Damage cleave buffs
local sniper_dropoff_ranges = {
	dropoff_start = 30,
	dropoff_end = 50
}
DamageProfileTemplates.arrow_sniper_trueflight = {
    charge_value = "projectile",
    no_stagger_damage_reduction_ranged = true,
    critical_strike = {
        attack_armor_power_modifer = {
            1.5, -- 1
            1,
            1,
            0.25, -- 1
            1,
            0.6 -- 0.25
        },
        impact_armor_power_modifer = {
            1,
            1,
            0,
            1,
            1,
            1
        }
    },
    armor_modifier_near = {
        attack = {
            1.5, -- 1
            1,
            1,
            0.25,
            1,
            0.6 -- 0.25
        },
        impact = {
            1,
            1,
            0,
            0,
            1,
            1
        }
    },
    armor_modifier_far = {
        attack = {
            1.5, -- 1
            1,
            2,
            0.25,
            1,
            0.6 -- 0.25
        },
        impact = {
            1,
            1,
            0,
            0,
            1,
            0
        }
    },
    cleave_distribution = {
        attack = 0.375, -- 0.25
        impact = 0.375 -- 0.25
    },
    default_target = {
        boost_curve_coefficient_headshot = 2.5,
        boost_curve_type = "ninja_curve",
        boost_curve_coefficient = 0.75,
        attack_template = "arrow_sniper",
        power_distribution_near = {
            attack = 0.5,
            impact = 0.3
        },
        power_distribution_far = {
            attack = 0.5,
            impact = 0.25
        },
        range_dropoff_settings = sniper_dropoff_ranges
    },
	max_friendly_damage = 0 -- Added
}
-- Fix consuming Bloodshot on Ult
mod_api.insert_proc_function("kerillian_waywatcher_consume_extra_shot_buff", function (player, buff, params)
    local is_career_skill = params[5]
    local should_consume_shot = nil

    if is_career_skill == "RANGED_ABILITY" or is_career_skill == nil then
        should_consume_shot = false
    else
        should_consume_shot = true
    end

    return should_consume_shot
end)

--[[

	Passives

]]
--[[
	Amaranthe
	Isha's Embrace
	Spirit Arrows
	Rejuvenating Locus
]]
mod_api.insert_text("career_passive_desc_we_3a_2", "Kerillian regenerates 3 health when below 50.0% health and 1 ammo every 10 seconds. This does not replace temp health.")
mod_api.insert_text("kerillian_waywatcher_improved_regen_desc_2", "Increases Kerillian's health regenerated from Amaranthe by 100%%. Health regeneration caps at 100%%. No longer restores ammo.")
mod_api.insert_text("kerillian_waywatcher_passive_cooldown_restore_desc", "Amaranthe reduces the cooldown of Trueflight Volley by 5.0%% and restores 1 additional ammo every tick. No longer restores health.")
mod_api.insert_buff_function("update_kerillian_waywatcher_regen", function (unit, buff, params)
    local t = params.t
    local buff_template = buff.template
    local next_heal_tick = buff.next_heal_tick or 0
    local regen_cap = 0.5
    local network_manager = Managers.state.network
    local network_transmit = network_manager.network_transmit
    local heal_type_id = NetworkLookup.heal_types.career_skill
    local time_between_heals = buff_template.time_between_heals

    if next_heal_tick < t and Unit.alive(unit) then
        local talent_extension = ScriptUnit.extension(unit, "talent_system")
		
        local cooldown_talent = talent_extension:has_talent("kerillian_waywatcher_passive_cooldown_restore", "wood_elf", true)
		if cooldown_talent then
			local cooldown_reduction = 0.05
			local career_extension = ScriptUnit.extension(unit, "career_system")

			career_extension:reduce_activated_ability_cooldown_percent(cooldown_reduction)
		end

		-- Ammo Regen (if not Isha's Embrace)
		if not talent_extension:has_talent("kerillian_waywatcher_improved_regen", "wood_elf", true) then
			local weapon_slot = "slot_ranged"
			local inventory_extension = ScriptUnit.extension(unit, "inventory_system")
			local slot_data = inventory_extension:get_slot_data(weapon_slot)

			if slot_data then
				local right_unit_1p = slot_data.right_unit_1p
				local left_unit_1p = slot_data.left_unit_1p
				local right_hand_ammo_extension = ScriptUnit.has_extension(right_unit_1p, "ammo_system")
				local left_hand_ammo_extension = ScriptUnit.has_extension(left_unit_1p, "ammo_system")
				local ammo_extension = right_hand_ammo_extension or left_hand_ammo_extension

				if ammo_extension then
					local ammo_amount = 1
					if cooldown_talent then
						ammo_amount = ammo_amount + 1
					end
					ammo_extension:add_ammo_to_reserve(ammo_amount)
				end
			end
		end


        if Managers.state.network.is_server and not cooldown_talent then
            local health_extension = ScriptUnit.extension(unit, "health_system")
            local status_extension = ScriptUnit.extension(unit, "status_system")
            local heal_amount = buff_template.heal_amount

            if talent_extension:has_talent("kerillian_waywatcher_improved_regen", "wood_elf", true) then
                regen_cap = regen_cap * 2
                heal_amount = heal_amount * 2
            end

            if health_extension:is_alive() and not status_extension:is_knocked_down() and not status_extension:is_assisted_respawning() then
                if talent_extension:has_talent("kerillian_waywatcher_group_regen", "wood_elf", true) then
                    local side = Managers.state.side.side_by_unit[unit]

                    if not side then
                        return
                    end

                    local player_and_bot_units = side.PLAYER_AND_BOT_UNITS

                    for i = 1, #player_and_bot_units, 1 do
                        if Unit.alive(player_and_bot_units[i]) then
                            local health_extension = ScriptUnit.extension(player_and_bot_units[i], "health_system")
                            local status_extension = ScriptUnit.extension(player_and_bot_units[i], "status_system")

                            if health_extension:current_permanent_health_percent() <= regen_cap and not status_extension:is_knocked_down() and not status_extension:is_assisted_respawning() and health_extension:is_alive() then
								-- Give THP first so it doesn't grant GHP + THP resulting in double regen
								DamageUtils.heal_network(player_and_bot_units[i], unit, heal_amount, "heal_from_proc")
								DamageUtils.heal_network(player_and_bot_units[i], unit, heal_amount, "career_passive")
                            end
                        end
                    end
                elseif health_extension:current_permanent_health_percent() <= regen_cap then
					-- Give THP first so it doesn't grant GHP + THP resulting in double regen
					DamageUtils.heal_network(unit, unit, heal_amount, "heal_from_proc")
					DamageUtils.heal_network(unit, unit, heal_amount, "career_passive")
                end
            end
        end

        buff.next_heal_tick = t + time_between_heals
    end
end)

--[[

	Talents

]]
--[[
	Drakira's Alacrity
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_waywatcher_attack_speed_on_ranged_headshot_buff", {
    duration = 10, -- 5
	multiplier = 0.20 -- 0.15
})
mod_api.update_talent("we_waywatcher", 2, 3, {
    description_values = {
        {
            value_type = "baked_percent",
            value = 1.20 -- 1.15
        },
        {
            value = 10 -- 5
        }
    }
})

--[[
	Fervent Huntress
]]
local apply_movement_buff = BuffFunctionTemplates.functions.apply_movement_buff
local remove_movement_buff = BuffFunctionTemplates.functions.remove_movement_buff
mod_api.insert_buff_function("tb_apply_movement_buff_and_noclip", function (unit, buff, params)
	apply_movement_buff(unit, buff, params)

	if ALIVE[unit] then
		local status_extension = ScriptUnit.extension(unit, "status_system")

		status_extension:set_noclip(true, "tb_movement_buff_and_noclip") -- set id for later removing noclip
	end
end)
mod_api.insert_buff_function("tb_remove_movement_buff_and_noclip", function (unit, buff, params)
	remove_movement_buff(unit, buff, params)

	if ALIVE[unit] then
		local status_extension = ScriptUnit.extension(unit, "status_system")

		status_extension:set_noclip(false, "tb_movement_buff_and_noclip") -- id used for removing noclip
	end
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_waywatcher_movement_speed_on_special_kill_buff", {
	apply_buff_func = "tb_apply_movement_buff_and_noclip",
	remove_buff_func = "tb_remove_movement_buff_and_noclip",
})
mod_api.insert_text("kerillian_waywatcher_movement_speed_on_special_kill_desc", "Killing a special or elite enemy increases movement speed by 15.0%% and lets Kerillian pass through enemies for 10 seconds.")

--[[
	Richochet
]]
mod_api.insert_text("kerillian_waywatcher_projectile_ricochet_desc", "Projectiles can ricochet up to 3 times before hitting an enemy. Fully charging for 1 second imbues ricochets with trueflight, but drains 20.0%% cooldown over 10 seconds.")

-- Cooldown regeneration debuff
mod_api.insert_buff_template("tb_ricochet_true_flight_cooldown_debuff", {
	stat_buff = "cooldown_regen",
	multiplier = -1.6,
	duration = 10,
	max_stacks = 1,
	refresh_durations = true,
	debuff = true,
	icon = "kerillian_waywatcher_projectile_ricochet",
})

-- While under ricochet debuff, Waystalker generates no ult from ranged attacks
local TB_RICOCHET_RANGED_ATTACK_TYPES = {
	instant_projectile = true,
	projectile = true,
	heavy_instant_projectile = true,
}
-- Set from the hit_enemy hook further below (impact_data.aoe, only ever set on Hagbane's charged shot among Kerillian's arrows),
-- synchronously readable here since this proc fires from inside that same call.
local tb_ricochet_last_hit_had_explosion = false

mod_api.insert_proc_function("tb_ricochet_reduce_activated_ability_cooldown", function (owner_unit, buff, params)
	local attack_type = params[2]
	local target_number = params[4]
	local is_ranged_direct_hit = target_number == 1 and TB_RICOCHET_RANGED_ATTACK_TYPES[attack_type] and not tb_ricochet_last_hit_had_explosion

	if is_ranged_direct_hit then
		local owner_buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

		if owner_buff_extension and owner_buff_extension:has_buff_type("tb_ricochet_true_flight_cooldown_debuff") then
			return
		end
	end

	return ProcFunctions.reduce_activated_ability_cooldown(owner_unit, buff, params)
end)
mod_api.update_talent_buff_template("wood_elf", "kerillian_waywatcher_ability_cooldown_on_hit", {
	buff_func = "tb_ricochet_reduce_activated_ability_cooldown",
})

-- Ricochet conversion additionally requires the shot to have been held (charged) for >= 1 real second before firing.
local TB_RICOCHET_HOLD_TIME_REQUIRED = 1
local tb_ricochet_pending_held_1s = false

-- Center-screen popup + persistent icon while trueflight is imbued
mod_api.insert_buff_template("tb_ricochet_charged_shot_ready", {
	max_stacks = 1,
	duration = 0.5,
	refresh_durations = true,
	priority_buff = true,
	icon = "kerillian_waywatcher_projectile_ricochet",
})

-- Shared by every charge-phase class is called every frame past the 1s threshold - refresh_durations above
-- means this keeps the same buff alive (and the bar icon visible) for as long as the player keeps holding,
-- while the popup itself still only plays once per continuous hold.
local function tb_ricochet_maybe_show_charged_popup(self, t)
	if not self._tb_charge_start_t or t - self._tb_charge_start_t < TB_RICOCHET_HOLD_TIME_REQUIRED then
		return
	end

	local owner_unit = self.owner_unit
	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if not talent_extension or not talent_extension:has_talent("kerillian_waywatcher_projectile_ricochet") then
		return
	end

	local owner_buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

	if owner_buff_extension then
		owner_buff_extension:add_buff("tb_ricochet_charged_shot_ready")
	end
end

mod:hook_safe(ActionAim, "client_owner_start_action", function (self, new_action, t)
	self._tb_charge_start_t = t
end)
mod:hook_safe(ActionAim, "client_owner_post_update", function (self, dt, t, world, can_damage)
	tb_ricochet_maybe_show_charged_popup(self, t)
end)
-- finish()'s return value becomes chain_action_data for the next chained action (ActionBow.client_owner_start_action
-- below) - this is how the base game itself threads charge_level between ActionAim and its follow-up action.
-- ActionAim.finish currently returns nothing, so replacing that with our own table is safe.
mod:hook(ActionAim, "finish", function (func, self, reason)
	func(self, reason)

	return {
		_tb_charge_start_t = self._tb_charge_start_t,
	}
end)
mod:hook_safe(ActionBow, "client_owner_start_action", function (self, new_action, t, chain_action_data, power_level, action_init_data)
	self._tb_ricochet_held_1s = not not (chain_action_data and chain_action_data._tb_charge_start_t and (t - chain_action_data._tb_charge_start_t) >= TB_RICOCHET_HOLD_TIME_REQUIRED)
end)
mod:hook(ActionBow, "fire", function (func, self, current_action, add_spread)
	tb_ricochet_pending_held_1s = self._tb_ricochet_held_1s or false

	func(self, current_action, add_spread)

	tb_ricochet_pending_held_1s = false
end)
mod:hook_safe(PlayerProjectileUnitExtension, "init", function (self, extension_init_context, unit, extension_init_data)
	self._tb_ricochet_held_1s = tb_ricochet_pending_held_1s
end)

-- Moonfire Bow
mod:hook(ActionAimEnergy, "finish", function (func, self, reason)
	func(self, reason)

	return {
		_tb_charge_start_t = self._tb_charge_start_t,
	}
end)
mod:hook_safe(ActionBowEnergy, "client_owner_start_action", function (self, new_action, t, chain_action_data, power_level, action_init_data)
	self._tb_ricochet_held_1s = not not (chain_action_data and chain_action_data._tb_charge_start_t and (t - chain_action_data._tb_charge_start_t) >= TB_RICOCHET_HOLD_TIME_REQUIRED)
end)

-- Javelin
mod:hook_safe(ActionMeleeStart, "client_owner_start_action", function (self, new_action, t, chain_action_data, power_level, action_init_data)
	self._tb_charge_start_t = t
end)
mod:hook_safe(ActionMeleeStart, "client_owner_post_update", function (self, dt, t, world)
	tb_ricochet_maybe_show_charged_popup(self, t)
end)
mod:hook(ActionMeleeStart, "finish", function (func, self, reason, data)
	func(self, reason, data)

	return {
		_tb_charge_start_t = self._tb_charge_start_t,
	}
end)
mod:hook_safe(ActionThrownProjectile, "client_owner_start_action", function (self, new_action, t, chain_action_data, power_level)
	self._tb_ricochet_held_1s = not not (chain_action_data and chain_action_data._tb_charge_start_t and (t - chain_action_data._tb_charge_start_t) >= TB_RICOCHET_HOLD_TIME_REQUIRED)
end)
mod:hook(ActionThrownProjectile, "_fire", function (func, self, add_spread)
	tb_ricochet_pending_held_1s = self._tb_ricochet_held_1s or false

	func(self, add_spread)

	tb_ricochet_pending_held_1s = false
end)

-- On first ricochet bounce of projectile, convert it into Trueshot Volley (true-flight/homing) arrow: despawn
-- the original (now-bounced, non-homing) projectile and spawn a trueflight one in its place, at the same point
-- and heading in the same post-bounce direction. item_name/item_template_name point at the career skill's own
-- weapon so the spawned arrow gets its homing/impact behavior, independent of whichever physical bow is
-- actually equipped.
local TB_RICOCHET_SPAWN_ITEM = "kerillian_waywatcher_career_skill_weapon"
local TB_RICOCHET_SPAWN_ACTION = "action_career_release"
local TB_RICOCHET_SPAWN_SUB_ACTION = "default"
local tb_ricochet_spawn_speed
local tb_ricochet_spawn_true_flight_template_id

local function tb_ricochet_ensure_spawn_data()
	if tb_ricochet_spawn_speed then
		return
	end

	local weapon_action = WeaponUtils.get_weapon_template(TB_RICOCHET_SPAWN_ITEM).actions[TB_RICOCHET_SPAWN_ACTION][TB_RICOCHET_SPAWN_SUB_ACTION]

	tb_ricochet_spawn_speed = weapon_action.speed
	tb_ricochet_spawn_true_flight_template_id = TrueFlightTemplates[weapon_action.true_flight_template].lookup_id
end

-- Give the spawned trueflight arrow the original bouncing arrow's own damage_profile/aoe (hagbane explosion)
-- Mutating shared table would corrupt every future use of the career skill for the rest of the session.
local tb_ricochet_impact_data_override

mod:hook(PlayerProjectileUnitExtension, "initialize_projectile", function (func, self, projectile_info, impact_data)
	if tb_ricochet_impact_data_override and impact_data then
		self._tb_ricochet_converted = true
		impact_data = table.shallow_copy(impact_data)

		for key, value in pairs(tb_ricochet_impact_data_override) do
			impact_data[key] = value
		end

		self._impact_data = impact_data
		self._impact_damage_profile_id = NetworkLookup.damage_profiles[impact_data.damage_profile or "default"]
	end

	func(self, projectile_info, impact_data)
end)

-- Marks the spawned arrow as ricochet-converted
local tb_ricochet_last_hit_was_converted = false
mod:hook(PlayerProjectileUnitExtension, "hit_enemy", function (func, self, impact_data, ...)
	tb_ricochet_last_hit_was_converted = not not self._tb_ricochet_converted
	tb_ricochet_last_hit_had_explosion = not not impact_data.aoe

	-- Prevent further ricochets after cleaving enemy
	if not impact_data.bounce_on_level_units then
		self._num_bounces = math.huge
	end

	func(self, impact_data, ...)

	tb_ricochet_last_hit_was_converted = false
	tb_ricochet_last_hit_had_explosion = false
end)

mod:hook(PlayerProjectileUnitExtension, "hit_level_unit", function (func, self, impact_data, hit_unit, hit_position, hit_direction, hit_normal, hit_actor, level_index, has_ranged_boost, ranged_boost_curve_multiplier)
	local num_bounces_before = self._num_bounces

	func(self, impact_data, hit_unit, hit_position, hit_direction, hit_normal, hit_actor, level_index, has_ranged_boost, ranged_boost_curve_multiplier)

	-- impact_data.bounce_on_level_units to prevent career ability bounces (piercing shot) to spawn converted arrow
	if not self._is_server or impact_data.bounce_on_level_units or self._num_bounces <= num_bounces_before then
		return
	end

	-- Only a shot held (charged) for >= 1s is eligible to convert - see the ActionAim/ActionBow hooks above.
	if not self._tb_ricochet_held_1s then
		return
	end

	local owner_unit = self._owner_unit

	if not owner_unit or not ALIVE[owner_unit] then
		return
	end

	local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

	if not talent_extension or not talent_extension:has_talent("kerillian_waywatcher_projectile_ricochet") then
		return
	end

	-- True-flight imbue requires at least 20% ult cd
	local career_extension = ScriptUnit.extension(owner_unit, "career_system")
	local ability_bar_fill = 1 - career_extension:current_ability_cooldown_percentage(1)

	if ability_bar_fill < 0.2 then
		return
	end

	local locomotion_extension = self.locomotion_extension

	if not locomotion_extension.target_vector_boxed then
		return
	end

	local bounce_dir = Vector3Box.unbox(locomotion_extension.target_vector_boxed)
	local bounce_pos = Vector3Box.unbox(locomotion_extension.initial_position_boxed)
	local rotation = Quaternion.look(bounce_dir)
	local angle = ActionUtils.pitch_from_rotation(rotation)
	local target_unit = nil
	local scale = 1
	local is_critical_strike = self._is_critical_strike
	local power_level = self.power_level
	local impact_data_override = {
		damage_profile = impact_data.damage_profile_prop or impact_data.damage_profile or "default",
		aoe = impact_data.aoe,
		aoe_on_bounce = impact_data.aoe_on_bounce,
	}

	-- Prevent spawning second trueflight arrow.
	self._stop_impacts = true

	Managers.state.unit_spawner:mark_for_deletion(self._projectile_unit)

	local owner_buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

	if owner_buff_extension then
		owner_buff_extension:add_buff("tb_ricochet_true_flight_cooldown_debuff")
	end

	tb_ricochet_ensure_spawn_data()

	-- pcall guarantees the flag always gets cleared, even if the spawn call errors
	tb_ricochet_impact_data_override = impact_data_override

	local success, err = pcall(ActionUtils.spawn_true_flight_projectile, owner_unit, target_unit, tb_ricochet_spawn_true_flight_template_id, bounce_pos, rotation, angle, bounce_dir, tb_ricochet_spawn_speed, TB_RICOCHET_SPAWN_ITEM, TB_RICOCHET_SPAWN_ITEM, TB_RICOCHET_SPAWN_ACTION, TB_RICOCHET_SPAWN_SUB_ACTION, scale, is_critical_strike, power_level)

	tb_ricochet_impact_data_override = nil

	if not success then
		mod:echo("[TourneyBalance] Ricochet true-flight spawn failed: " .. tostring(err))
	end
end)

--[[
	Piercing Shot
]]
-- Fix no refund on headshot through teammate
ProcFunctions.kerillian_waywatcher_reduce_activated_ability_cooldown = function (owner_unit, buff, params)
    if ALIVE[owner_unit] then
        local hit_zone = params[3]
        local buff_type = params[5]

        -- Prevent ricochete refunding Piercing Shot.
        if buff_type == "RANGED_ABILITY" and (hit_zone == "head" or hit_zone == "neck" or hit_zone == "weakspot") and not tb_ricochet_last_hit_was_converted then
            local career_extension = ScriptUnit.extension(owner_unit, "career_system")

            career_extension:reduce_activated_ability_cooldown_percent(buff.multiplier)
        end
    end
end

--[[
	Loaded Bow
]]
mod:hook(ActionTrueFlightBow, "client_owner_start_action", function (func, self, new_action, t, chain_action_data, power_level, action_init_data)
	func(self, new_action, t, chain_action_data, power_level, action_init_data)

	local talent_extension = ScriptUnit.has_extension(self.owner_unit, "talent_system")

	if talent_extension:has_talent("kerillian_waywatcher_activated_ability_additional_projectile") then
		self.num_projectiles = self.num_projectiles + 1 -- stacks with original +1; total of +2
	end
end)
mod_api.insert_text("kerillian_waywatcher_activated_ability_additional_projectile_desc", "Trueflight Volley fires 5 arrows.")


--[[
	Kurnous' Reward
]]
mod_api.update_talent_buff_template("wood_elf", "kerillian_waywatcher_activated_ability_restore_ammo_on_career_skill_special_kill", {
	ammo_bonus_fraction = 0.2, -- 0.3
})
mod_api.update_talent("we_waywatcher", 6, 3, {
	description_values = {
		{
			value_type = "percent",
			value = 0.2, -- 0.3
		},
	},
})