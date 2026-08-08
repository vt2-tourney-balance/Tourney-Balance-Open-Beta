local mod = get_mod("TourneyBalance")

--[[
    Piercing Shot
]]
-- pinpoint accuracy (career skill only, base Longbow untouched) 
--[[
Weapons.kerillian_waywatcher_career_skill_weapon_piercing_shot.crosshair_style = "dot"
Weapons.kerillian_waywatcher_career_skill_weapon_piercing_shot.default_spread_template = "tb_piercing_shot"
SpreadTemplates.tb_piercing_shot = {
    continuous = {
        still = {
            max_pitch = 0,
            max_yaw = 0,
        },
        moving = {
            max_pitch = 0,
            max_yaw = 0,
        },
        crouch_still = {
            max_pitch = 0,
            max_yaw = 0,
        },
        crouch_moving = {
            max_pitch = 0,
            max_yaw = 0,
        },
        zoomed_still = {
            max_pitch = 0,
            max_yaw = 0,
        },
        zoomed_moving = {
            max_pitch = 0,
            max_yaw = 0,
        },
        zoomed_crouch_still = {
            max_pitch = 0,
            max_yaw = 0,
        },
        zoomed_crouch_moving = {
            max_pitch = 0,
            max_yaw = 0,
        },
    },
    immediate = {
        being_hit = {
            immediate_pitch = 0,
            immediate_yaw = 0,
        },
        shooting = {
            immediate_pitch = 0,
            immediate_yaw = 0,
        },
    },
} 
Weapons.kerillian_waywatcher_career_skill_weapon_piercing_shot.default_spread_template = "tb_piercing_shot"
]]