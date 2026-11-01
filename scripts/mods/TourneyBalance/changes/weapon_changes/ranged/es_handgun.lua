local mod = get_mod("TourneyBalance")

-- handgun_template_1
Weapons.handgun_template_1.actions.action_one.default.allowed_chain_actions[1].start_time = 0.35 -- official: 0.66
Weapons.handgun_template_1.actions.action_one.default.total_time = 0.35 -- official: 0.5
Weapons.handgun_template_1.actions.action_one.zoomed_shot.allowed_chain_actions[1].start_time = 0.35 -- official: 0.6
Weapons.handgun_template_1.actions.action_one.zoomed_shot.total_time = 0.35 -- official: 0.8