local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		title	: 	Waystalker Changes
		ult		: 	Damage cleave buff.
					Prioritizes specials now.
					Does not consume Bloodshot anymore.
		passives:  	Amaranthe - Additionally regen 1 ammo every tick.
					Amaranthe - Heath regen no longer replaces temp health.
		talent23:  	Drakira's Alacrity - Increased attack speed to 20% (from 15%) and duration to 10s (from 5s)
		talent41:	Isha's Embrace - Increased health regen bonus to 100% (from 50%) and health regen cap to 100% max health
					Isha's Embrace - No longer grants Amaranthe's ammo regen.
		talent42:	Spirit Arrows - Additionally increases Amaranthes ammo regen by 1 ammo regen per tick (to total of 2 ammo per tick)
		talent51:	Fervent Huntress - Additionally allows Kerillian to pass through enemies for 10s.
		talent52:	Ricochet - When below 10 ammo, ricochet shots hitting enemies return 1 ammo.
		talent61:	Piercing Shot - Cooldown refund when headshotting enemy works when piercing through team mate first.
		talent62:	Loaded Bow - Increased additional Trueshot Volley arrows to +2 (from +1)
		talent63:	Kurnous Reward - Reduced ammo regen to 20% (from 30%) per kill.
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
-- Added breed prioritization
Weapons.kerillian_waywatcher_career_skill_weapon.actions.action_career_hold.prioritized_breeds = {
    skaven_warpfire_thrower = 1,
    chaos_vortex_sorcerer = 1,
    skaven_gutter_runner = 1,
    skaven_pack_master = 1,
    skaven_poison_wind_globadier = 1,
    chaos_corruptor_sorcerer = 1,
    skaven_ratling_gunner = 1,
    beastmen_standard_bearer = 1,
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
-- TODO:REWORK
-- Prevent extra arrow from Bloodshot to trigger ammo refund
local pending_bonus_shot = {}
mod:hook(ActionBow, "fire", function (func, self, current_action, add_spread)
	pending_bonus_shot[self.owner_unit] = add_spread == false

	func(self, current_action, add_spread) -- ActionBow.fire's "add_spread" is false only for that bonus arrow

	pending_bonus_shot[self.owner_unit] = nil
end)
mod:hook_safe(PlayerProjectileUnitExtension, "init", function (self, extension_init_context, unit, extension_init_data)
	self._is_bonus_shot = pending_bonus_shot[extension_init_data.owner_unit] or false
end)

mod:hook_origin(PlayerProjectileUnitExtension, "hit_enemy", function(self, impact_data, hit_unit, hit_position, hit_direction, hit_normal, hit_actor, breed, has_ranged_boost, ranged_boost_curve_multiplier)
	local shield_blocked = false
	local damage_profile_name = impact_data.damage_profile or "default"
	local damage_profile = DamageProfileTemplates[damage_profile_name]
	local allow_link = true
	local forced_penetration = false
	local aoe_data = impact_data.aoe

	breed = AiUtils.unit_breed(hit_unit)

	if not breed then
		return
	end

	local hit_zone_name

	if damage_profile then
		local node = Actor.node(hit_actor)
		local hit_zone = breed.hit_zones_lookup[node]

		hit_zone_name = hit_zone.name

		local send_to_server = true
		local charge_value = damage_profile.charge_value or "projectile"
		local is_critical_strike = self._is_critical_strike
		local owner_unit = self._owner_unit
		local num_targets_hit = self._num_targets_hit + 1
		local unmodified = true

		-- Ricochet ammo refund
		if HEALTH_ALIVE[hit_unit] and ALIVE[owner_unit] then
			local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")

			if  talent_extension and talent_extension:has_talent("kerillian_waywatcher_projectile_ricochet") then
				local inventory_extension = ScriptUnit.extension(owner_unit, "inventory_system")
				local slot_data = inventory_extension:get_slot_data("slot_ranged")
				local ammo_extension = GearUtils.get_ammo_extension(slot_data.right_unit_1p, slot_data.left_unit_1p)

				if ammo_extension and self._num_bounces > 0 and not self._is_bonus_shot then
					local current_ammo = ammo_extension:ammo_count() + ammo_extension:remaining_ammo()
					ammo_threshold = 10

					if current_ammo < ammo_threshold then
						local ammo_amount = self._num_bounces
						ammo_extension:add_ammo_to_reserve(ammo_amount)
					end
                end
			end
		end

		if hit_zone_name ~= "head" and HEALTH_ALIVE[hit_unit] and breed and breed.hit_zones and breed.hit_zones.head then
			local owner_buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")
			local auto_headshot = owner_buff_extension and owner_buff_extension:has_buff_perk("auto_headshot")

			if auto_headshot and hit_zone_name ~= "afro" then
				hit_zone_name = "head"
				unmodified = false

				owner_buff_extension:trigger_procs("on_auto_headshot")
			end
		end

		local buff_type = DamageUtils.get_item_buff_type(self.item_name)
		
		DamageUtils.buff_on_attack(owner_unit, hit_unit, charge_value, is_critical_strike, hit_zone_name, num_targets_hit, send_to_server, buff_type, unmodified, self.item_name)
		shield_blocked, forced_penetration = self:hit_enemy_damage(damage_profile, hit_unit, hit_position, hit_direction, hit_normal, hit_actor, breed, has_ranged_boost, ranged_boost_curve_multiplier)
		allow_link = hit_zone_name ~= "ward"

		if allow_link and breed and not shield_blocked then
			local impact_pickup_settings = impact_data.pickup_settings

			if impact_pickup_settings then
				allow_link = not not impact_pickup_settings.link_hit_zones[hit_zone_name]
			end
		end
	end

	if self._num_additional_penetrations == 1 and aoe_data and aoe_data.explosion then
		local talent_extension = ScriptUnit.has_extension(self._owner_unit, "talent_system")

		if talent_extension and talent_extension:has_talent("bardin_engineer_ranged_pierce") then
			self._num_additional_penetrations = self._num_additional_penetrations - 1
		end
	end

	local grenade = impact_data.grenade

	if self._num_additional_penetrations == 0 then
		local should_stop = false

		if aoe_data and (grenade or self._amount_of_mass_hit >= self._max_mass) then
			self:do_aoe(aoe_data, hit_position)

			if grenade then
				local owner_unit = self._owner_unit
				local owner_buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

				if owner_buff_extension then
					owner_buff_extension:trigger_procs("on_grenade_exploded", impact_data, hit_position, self._is_critical_strike, self.item_name, Unit.local_rotation(self._projectile_unit, 0), self.scale, self.power_level)
				end
			end

			should_stop = true
		end

		if self.chain_hit_settings then
			local t = Managers.time:time("game")
			local source_pos = Unit.has_node(hit_unit, "j_spine") and Unit.world_position(hit_unit, Unit.node(hit_unit, "j_spine")) or POSITION_LOOKUP[hit_unit] + Vector3(0, 0, 1.5)

			self._weapon_system:try_fire_chained_projectile(self.chain_hit_settings, self.item_name, self._is_critical_strike, self.power_level, ranged_boost_curve_multiplier, t, self._owner_unit, source_pos, nil, hit_unit, 1)

			should_stop = true
		end

		if should_stop then
			self:stop(hit_unit, hit_zone_name, hit_normal)
		end
	end

	if self._amount_of_mass_hit >= self._max_mass then
		if self._num_additional_penetrations > 0 then
			forced_penetration = true
		else
			local hit_enemy_or_player = true

			self:_handle_linking(impact_data, hit_unit, hit_position, hit_direction, hit_normal, hit_actor, self._did_damage, allow_link, shield_blocked, hit_enemy_or_player)
			self:stop(hit_unit, hit_zone_name, hit_normal)
		end
	end

	if breed.is_player or breed.play_ranged_hit_reacts then
		local husk = not self._owner_player.local_player

		DamageUtils.insert_hit_reaction(hit_unit, breed, husk, hit_direction, false)
	end

	if self.locomotion_extension.notify_hit_enemy then
		self.locomotion_extension:notify_hit_enemy(hit_unit)
	end

	if forced_penetration then
		self._num_additional_penetrations = self._num_additional_penetrations - 1
	end
end)
mod_api.insert_text("kerillian_waywatcher_projectile_ricochet_desc", "Kerillian's arrows now ricochet, bouncing up to 3 times or until it hits an enemy. While below 10 ammo ricochet hits refund 1 ammo.")

--[[
	Piercing Shot
]]
-- Fix no refund on headshot through teammate
ProcFunctions.kerillian_waywatcher_reduce_activated_ability_cooldown = function (owner_unit, buff, params)
    if ALIVE[owner_unit] then
        local hit_zone = params[3]
        local buff_type = params[5]

        if buff_type == "RANGED_ABILITY" and (hit_zone == "head" or hit_zone == "neck" or hit_zone == "weakspot") then
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