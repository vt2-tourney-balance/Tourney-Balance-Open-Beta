local mod = get_mod("TourneyBalance")

return {
	name = mod:localize("mod_name"),
	is_togglable = false,
	description = mod:localize("mod_description"),
	options = {
		widgets = {
			{
				setting_id = "tourney_checks",
				type = "group",
				sub_widgets = {
					{
						setting_id = "tourney_mode",
						type = "checkbox",
						title = "tourney_mode_title",
						tootlip = "tourney_mode_description",
						default_value = false,
					},
					{
						setting_id = "tourney_display_mods",
						type = "checkbox",
						title = "tourney_display_mods_title",
						tootlip = "tourney_display_mods_description",
						default_value = false,
					},
				},
			},
			{
				setting_id = "qol",
				type = "group",
				sub_widgets = {
					{
						type = "checkbox",
						setting_id = "disable_bots",
						default_value = true,
						title = "disable_bots_title",
						tooltip = "disable_bots_description",
					},
					{
						setting_id = "pause",
						type = "keybind",
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "do_pause",
						title = "pause_title",
						tooltip = "pause_description",
						default_value = {},
					},
					{
						setting_id = "restart",
						type = "keybind",
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "restart_level",
						title = "restart_title",
						tooltip = "restart_description",
						default_value = {},
					},
				},
			},
			{
				type = "checkbox",
				setting_id = "performance_logging",
				default_value = false,
				title = "performance_logging_title",
				tooltip = "performance_logging_description",
			},
			{
				setting_id = "accessibility",
				type = "group",
				sub_widgets = {
					{
						setting_id = "tb_ping_outline_color_group",
						type = "group",
						sub_widgets = {
							{
								type = "numeric",
								setting_id = "tb_ping_color_r",
								default_value = 30,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_ping_color_r_title",
								tooltip = "tb_ping_color_r_description",
							},
							{
								type = "numeric",
								setting_id = "tb_ping_color_g",
								default_value = 150,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_ping_color_g_title",
								tooltip = "tb_ping_color_g_description",
							},
							{
								type = "numeric",
								setting_id = "tb_ping_color_b",
								default_value = 255,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_ping_color_b_title",
								tooltip = "tb_ping_color_b_description",
							},
						},
					},
					{
						setting_id = "tb_isjya_ping_outline_color_group",
						type = "group",
						sub_widgets = {
							{
								type = "numeric",
								setting_id = "tb_special_tag_color_r",
								default_value = 227,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_special_tag_color_r_title",
								tooltip = "tb_special_tag_color_r_description",
							},
							{
								type = "numeric",
								setting_id = "tb_special_tag_color_g",
								default_value = 4,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_special_tag_color_g_title",
								tooltip = "tb_special_tag_color_g_description",
							},
							{
								type = "numeric",
								setting_id = "tb_special_tag_color_b",
								default_value = 4,
								range = {0, 255},
								decimals_number = 0,
								title = "tb_special_tag_color_b_title",
								tooltip = "tb_special_tag_color_b_description",
							},
						},
					},
				},
			},
			{
				setting_id = "debugging",
				type = "group",
				sub_widgets = {
					{
						type = "checkbox",
						setting_id = "stagger_state_visualizer",
						default_value = false,
						title = "stagger_state_visualizer_title",
						tooltip = "stagger_state_visualizer_description",
					},
					{
						type = "checkbox",
						setting_id = "stagger_state_visualizer_include_real",
						default_value = true,
						title = "stagger_state_visualizer_include_real_title",
						tooltip = "stagger_state_visualizer_include_real_description",
					},
					{
						type = "checkbox",
						setting_id = "stagger_state_visualizer_include_mainstay",
						default_value = true,
						title = "stagger_state_visualizer_include_mainstay_title",
						tooltip = "stagger_state_visualizer_include_mainstay_description",
					},
				},
			},
		}
	}
}
