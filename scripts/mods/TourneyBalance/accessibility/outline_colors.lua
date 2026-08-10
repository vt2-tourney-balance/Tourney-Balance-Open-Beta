local mod = get_mod("TourneyBalance")
local color_presets = require("scripts/mods/TourneyBalance/accessibility/_color_presets")

--[[

	Outline Colors (Accessibility)

	General-purpose, non-career-specific outline color overrides. The WH Captain "judged
	special" outline color is a separate, talent-specific concern that lives in
	changes/career_changes/13_wh_captain.lua instead.

]]

--[[
	Ping Color

	Overrides the base game's ping-highlight color with a user-configurable RGB,
	for colorblind-friendly ping visibility.
]]
local function apply_ping_color()
	-- Mutated in place (not replaced) so every template already referencing this table picks
	-- up the change too, instead of only templates re-pointed at a new one.
	local color = OutlineSettings.colors.player_attention.color
	local r, g, b = color_presets.resolve_color("tb_ping_outline_color_group", "tb_ping_color_r", "tb_ping_color_g", "tb_ping_color_b", 30, 150, 255)

	color[2], color[3], color[4] = r, g, b
end

apply_ping_color()

mod:add_setting_changed_function(apply_ping_color)

--[[
	Dangerous Enemy Marker Color

	The auto-target-marking used by Sister of the Thorn's deepwood staff, Necromancer's staff,
	Waystalker ultimate, and Pyromancer ultimate. Outline_color is repointed here to a dedicated color,
	decoupling this marker from knocked_down.
]]
OutlineSettings.colors.tb_dangerous_enemy_marker = {
	pulsate = false,
	pulse_multiplier = 50,
	color = { 255, 0, 0, 0 }, -- alpha, r, g, b - populated below
}

OutlineSettings.templates.target_enemy.outline_color = OutlineSettings.colors.tb_dangerous_enemy_marker

local function apply_dangerous_enemy_marker_color()
	local color = OutlineSettings.colors.tb_dangerous_enemy_marker.color
	local r, g, b = color_presets.resolve_color("tb_dangerous_outline_color_group", "tb_dangerous_color_r", "tb_dangerous_color_g", "tb_dangerous_color_b", 227, 4, 4)

	color[2], color[3], color[4] = r, g, b
end

apply_dangerous_enemy_marker_color()

mod:add_setting_changed_function(apply_dangerous_enemy_marker_color)

--[[
	Player Outline Color

	Overrides ally/player body outline
	(PlayerOutlineExtension, PlayerHuskOutlineExtension). Also shared with the
	"ready for assisted respawn" revive-prompt outline (templates.ready_for_assisted_respawn_husk),
	which is left as-is rather than forked since it's a minor, closely related highlight.
]]
local function apply_player_outline_color()
	local color = OutlineSettings.colors.ally.color
	local r, g, b = color_presets.resolve_color("tb_player_outline_color_group", "tb_player_outline_color_r", "tb_player_outline_color_g", "tb_player_outline_color_b", 118, 186, 0)

	color[2], color[3], color[4] = r, g, b
end

apply_player_outline_color()

mod:add_setting_changed_function(apply_player_outline_color)

--[[
	Downed Player Indicator Color

	The downed/incapacitated ally indicator (templates.incapacitated, used in
	generic_status_extension.lua) originally reused OutlineSettings.colors.knocked_down too.
	templates.incapacitated is only ever referenced by that indicator, so its outline_color is
	repointed here to a dedicated color, decoupling it from knocked_down (and from the dangerous
	enemy marker / default enemy outline above, which now have their own dedicated color too).
]]
OutlineSettings.colors.tb_downed_player_indicator = {
	pulsate = false,
	pulse_multiplier = 50,
	color = { 255, 0, 0, 0 }, -- alpha, r, g, b - populated below
}

OutlineSettings.templates.incapacitated.outline_color = OutlineSettings.colors.tb_downed_player_indicator

local function apply_downed_player_indicator_color()
	local color = OutlineSettings.colors.tb_downed_player_indicator.color
	local r, g, b = color_presets.resolve_color("tb_downed_player_outline_color_group", "tb_downed_player_outline_color_r", "tb_downed_player_outline_color_g", "tb_downed_player_outline_color_b", 227, 4, 4)

	color[2], color[3], color[4] = r, g, b
end

apply_downed_player_indicator_color()

mod:add_setting_changed_function(apply_downed_player_indicator_color)

--[[
	Skeleton Outline Color

	Overrides OutlineSettings.colors.necromancer_command, used for the Necromancer's summoned
	skeleton pets (MinionOutlineExtension) as well as the Command ability's target-highlighting
	while directing a pet/ally (career_ability_bw_necromancer_command.lua). MinionOutlineExtension
	reads the color directly rather than through a template, so these can't be split apart without
	forking that extension - left shared since both are Necromancer-only.
]]
local function apply_skeleton_outline_color()
	local color = OutlineSettings.colors.necromancer_command.color
	local r, g, b = color_presets.resolve_color("tb_skeleton_outline_color_group", "tb_skeleton_outline_color_r", "tb_skeleton_outline_color_g", "tb_skeleton_outline_color_b", 89, 218, 158)

	color[2], color[3], color[4] = r, g, b
end

apply_skeleton_outline_color()

mod:add_setting_changed_function(apply_skeleton_outline_color)
