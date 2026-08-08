local mod = get_mod("TourneyBalance")

--[[

	Ping Color (Accessibility)

	Overrides the base game's ping-highlight color (OutlineSettings.colors.player_attention,
	shared by every hero's ping - ping_unit, target_ally, etc.) with a user-configurable RGB
	from the "accessibility" settings group, for colorblind-friendly ping visibility. Not tied
	to any specific career - the WH Captain "judged special" outline color is a separate,
	talent-specific concern that lives in changes/career_changes/13_wh_captain.lua instead.

]]

local function apply_ping_color()
	-- Mutated in place (not replaced) so every template already referencing this table picks
	-- up the change too, instead of only templates re-pointed at a new one.
	local color = OutlineSettings.colors.player_attention.color

	color[2] = mod:get("tb_ping_color_r")
	color[3] = mod:get("tb_ping_color_g")
	color[4] = mod:get("tb_ping_color_b")
end

apply_ping_color()

mod:add_setting_changed_function(apply_ping_color)
