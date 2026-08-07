local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	$BEGIN_TB
		title	: 	Sister of the Thorn Changes
		ult		: 	Increased ultimate cooldown to 70s (from 40s).
		passives:  	A Cluster of Radiants - Increased passive ultimate cooldown to 70s (from 60s).
					A Sustenance of Leechlings - Decreased temp health siphon from team to 10% (from 100%).
		talent23:  	Briar's Malice - Only consume crit stacks on hit.
		talent42:  	Bonded Spirit - Updated description
		talent43:  	Radiant Inheritance - Can be activated with Thornwake (regular ult).
					Radiant Inheritnace - Recasting refreshes the and extends the duration to 20s.
		talent61:  	Ironbark Thicket - Reduced wall duration to 6s (from 10s).
		talent63:  	Blackvenom Thicket - Added 40% cooldown reduction.
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
	event = "on_hit"
})

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
		local area_damage_params = {
			aoe_dot_damage = 0,
			radius = 0.3,
			area_damage_template = "we_thornsister_thorn_wall",
			invisible_unit = false,
			nav_tag_volume_layer = "temporary_wall",
			create_nav_tag_volume = true,
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
		local random_rotation = Quaternion(Vector3.up(), math.random() * 2 * math.pi - math.pi)

		Unit.set_local_rotation(wall_unit, 0, random_rotation)

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
mod_api.insert_text("kerillian_thorn_sister_tanky_wall_desc_2", "Increase the width of the Thorn Wall.")

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


