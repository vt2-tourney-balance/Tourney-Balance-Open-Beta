local mod = get_mod("TourneyBalance")
local mod_api = require("scripts/mods/TourneyBalance/_api/_mod_api")

--[[
	Desummon / resummon (patch notes are in 20_bw_necromancer.lua)

	Hold action_three + reload: every skeleton is taken off the field without dying. What is needed to bring
	it back (breed, template, damage taken, age) is kept on the server, in the necromancer's passive. Hold action_three +
	action_two: skeletons on the field are teleported to the necromancer (the game's own resummon, which replaces the
	skeleton with a new one that keeps the damage it has taken) and desummoned ones are spawned next to them.

	A desummoned skeleton still counts. Each one is a stack of a synced buff on the necromancer, so the owner's client
	knows the number too. AICommanderExtension.get_controlled_units_count adds those stacks, which is what the talents,
	the pet UI number and the achievements read. The pet UI also gets a skull for each, and reload can still sacrifice
	one: it is spawned and sacrificed on the spot, so everything a sacrifice normally does still happens.
]]
local STASH_BUFF = "tb_necromancer_desummoned_skeleton"
local DESUMMON_BUFF = "tb_necromancer_desummon_skeletons"
local RESUMMON_BUFF = "tb_necromancer_resummon_skeletons"
local SACRIFICE_STASHED_BUFF = "tb_necromancer_sacrifice_desummoned_skeleton"
local DESUMMON_SUB_ACTION = "desummon"
local RESUMMON_SUB_ACTION = "resummon"
local MAX_STASHED = 20
local RESUMMON_HEAT_PER_SKELETON = 1

-- The skeletons with a lifetime (the ultimate's, and the army talent's extra ones, which all have a duration in their
-- controlled unit template) expire on their own, so they are neither desummoned nor teleported. Desummoned they would
-- never expire, and would count as skeletons for good
local function tb_is_timed(template_name)
	local template = ControlledUnitTemplates[template_name]

	return template ~= nil and template.duration ~= nil
end

local function tb_get_passive(owner_unit)
	local career_extension = ScriptUnit.has_extension(owner_unit, "career_system")

	return career_extension and career_extension:get_passive_ability_by_name("bw_necromancer")
end

local function tb_stash_count(owner_unit)
	local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")

	return buff_extension and buff_extension:num_buff_type(STASH_BUFF) or 0
end

-- Skeletons that are on the field
local function tb_field_skeletons(owner_unit)
	local commander_extension = ScriptUnit.has_extension(owner_unit, "ai_commander_system")
	local num_skeletons = 0

	if commander_extension then
		for pet_unit in pairs(commander_extension:get_controlled_units()) do
			if HEALTH_ALIVE[pet_unit] then
				num_skeletons = num_skeletons + 1
			end
		end
	end

	return num_skeletons
end

--[[
	Counting desummoned skeletons
]]
mod_api.insert_buff_template(STASH_BUFF, {
	max_stacks = MAX_STASHED,
})

mod:hook_origin(AICommanderExtension, "get_controlled_units_count", function (self)
	local buff_extension = self._buff_extension

	return self._controlled_units_n + (buff_extension and buff_extension:num_buff_type(STASH_BUFF) or 0)
end)

--[[
	Server: the stash
]]
local function tb_template_name(passive, pet_unit, data)
	local template = data.template

	return template and template.name or passive._spawned_pets[pet_unit]
end

local function tb_get_stash(passive)
	local stash = passive._tb_stash

	if not stash then
		stash = {}
		passive._tb_stash = stash
	end

	return stash
end

local function tb_release_stash_entry(passive, entry)
	local stash = tb_get_stash(passive)

	for i = 1, #stash do
		if stash[i] == entry then
			table.remove(stash, i)

			break
		end
	end

	Managers.state.entity:system("buff_system"):remove_buff_synced(passive._owner_unit, entry.buff_id)
end

local function tb_clear_stash(passive)
	local stash = passive._tb_stash

	if not stash then
		return
	end

	-- also runs while the level is torn down
	local entity_manager = Managers.state.entity
	local buff_system = entity_manager and entity_manager:system("buff_system")

	for i = #stash, 1, -1 do
		if buff_system then
			buff_system:remove_buff_synced(passive._owner_unit, stash[i].buff_id)
		end

		stash[i] = nil
	end
end

local function tb_desummon(owner_unit)
	local commander_extension = ScriptUnit.has_extension(owner_unit, "ai_commander_system")
	local passive = tb_get_passive(owner_unit)

	if not commander_extension or not passive then
		return
	end

	local stash = tb_get_stash(passive)
	local controlled_units = commander_extension:get_controlled_units()
	local buff_system = Managers.state.entity:system("buff_system")
	local conflict_director = Managers.state.conflict
	local peer_id = passive._player.peer_id
	-- removing a skeleton changes the controlled units
	local skeletons = FrameTable.alloc_table()

	for pet_unit in pairs(controlled_units) do
		if HEALTH_ALIVE[pet_unit] then
			skeletons[#skeletons + 1] = pet_unit
		end
	end

	for i = 1, #skeletons do
		local pet_unit = skeletons[i]
		local data = controlled_units[pet_unit]
		local template_name = tb_template_name(passive, pet_unit, data)

		if template_name and not tb_is_timed(template_name) and #stash < MAX_STASHED then
			local blackboard = BLACKBOARDS[pet_unit]

			-- counted first, so the number never dips while the skeleton is taken off the field
			stash[#stash + 1] = {
				breed_name = blackboard.breed.name,
				template_name = template_name,
				damage_taken = ScriptUnit.extension(pet_unit, "health_system"):get_damage_taken(),
				start_t = data.start_t,
				buff_id = buff_system:add_buff_synced(owner_unit, STASH_BUFF, BuffSyncType.ClientAndServer, nil, peer_id),
			}

			passive:_remove_unit(pet_unit)
			conflict_director:destroy_unit(pet_unit, blackboard, "tb_desummoned")
		end
	end
end

-- Queues the spawn of a desummoned skeleton. It gets its damage and age back when it spawns (_extract_resummon_data)
local function tb_spawn_stashed(passive, entry, sacrifice_on_spawn)
	if entry.spawning then
		return
	end

	entry.spawning = true
	entry.sacrifice_on_spawn = sacrifice_on_spawn

	local template_name = entry.template_name
	local pending = passive._resummon_spawn_data[template_name]

	if not pending then
		pending = {}
		passive._resummon_spawn_data[template_name] = pending
	end

	pending[#pending + 1] = {
		breed_name = entry.breed_name,
		damage_taken = entry.damage_taken,
		start_t = entry.start_t,
		tb_stash_entry = entry,
	}

	passive:spawn_pet(template_name, entry.breed_name)
end

local function tb_resummon(owner_unit)
	local commander_extension = ScriptUnit.has_extension(owner_unit, "ai_commander_system")
	local passive = tb_get_passive(owner_unit)

	if not commander_extension or not passive then
		return
	end

	-- resummoning swaps the units in the controlled units table
	local controlled_units = commander_extension:get_controlled_units()
	local skeletons = FrameTable.alloc_table()

	for pet_unit, data in pairs(controlled_units) do
		if HEALTH_ALIVE[pet_unit] and not tb_is_timed(tb_template_name(passive, pet_unit, data)) then
			skeletons[#skeletons + 1] = pet_unit
		end
	end

	for i = 1, #skeletons do
		passive:resummon_pet(skeletons[i])
	end

	local stash = tb_get_stash(passive)

	for i = 1, #stash do
		tb_spawn_stashed(passive, stash[i], false)
	end
end

local function tb_sacrifice_stashed(owner_unit)
	local passive = tb_get_passive(owner_unit)

	if not passive then
		return
	end

	local stash = tb_get_stash(passive)

	for i = #stash, 1, -1 do
		if not stash[i].spawning then
			tb_spawn_stashed(passive, stash[i], true)

			return
		end
	end
end

-- Spawned desummoned skeletons: hand the stash entry back, and sacrifice the ones that were spawned for that
mod:hook(PassiveAbilityNecromancerCharges, "_extract_resummon_data", function (func, self, unit, template_name)
	local pending = self._resummon_spawn_data[template_name]
	local data

	if pending then
		-- the data of a breed's skeleton goes to a skeleton of that breed
		local breed_name = BLACKBOARDS[unit].breed.name

		for i = #pending, 1, -1 do
			local candidate = pending[i]

			if not candidate.breed_name or candidate.breed_name == breed_name then
				pending[i], pending[#pending] = pending[#pending], pending[i]

				break
			end
		end

		data = pending[#pending]
	end

	func(self, unit, template_name)

	local entry = data and data.tb_stash_entry

	if not entry then
		return
	end

	tb_release_stash_entry(self, entry)

	if entry.sacrifice_on_spawn then
		local career_extension = ScriptUnit.has_extension(self._owner_unit, "career_system")
		local command_ability = career_extension and career_extension:get_passive_ability_by_name("bw_necromancer_command")

		if command_ability and BLACKBOARDS[unit].locomotion_extension then
			command_ability:_server_command_sacrifice_pet(unit)
		else
			AiUtils.kill_unit(unit)
		end
	end
end)

-- Skeletons dying with the necromancer (down, dead, level end) take the desummoned ones with them
mod:hook_safe(PassiveAbilityNecromancerCharges, "_kill_all_pets_server", function (self)
	tb_clear_stash(self)
end)

--[[
	Synced buffs: the owner's client asks, the server does it
]]
local function tb_server_buff_function(name, func)
	mod_api.insert_buff_function(name, function (unit, buff, params)
		if Managers.state.network.is_server and ALIVE[unit] and HEALTH_ALIVE[unit] then
			func(unit)
		end
	end)
end

tb_server_buff_function("tb_necromancer_desummon_apply", tb_desummon)
tb_server_buff_function("tb_necromancer_resummon_apply", tb_resummon)
tb_server_buff_function("tb_necromancer_sacrifice_desummoned_apply", tb_sacrifice_stashed)
mod_api.insert_buff_template(DESUMMON_BUFF, {
	duration = 0.1,
	apply_buff_func = "tb_necromancer_desummon_apply",
})
mod_api.insert_buff_template(RESUMMON_BUFF, {
	duration = 0.1,
	apply_buff_func = "tb_necromancer_resummon_apply",
})
mod_api.insert_buff_template(SACRIFICE_STASHED_BUFF, {
	duration = 0.1,
	apply_buff_func = "tb_necromancer_sacrifice_desummoned_apply",
})

--[[
	Controls
]]
local function tb_add_synced_buff(owner_unit, buff_name)
	Managers.state.entity:system("buff_system"):add_buff_synced(owner_unit, buff_name, BuffSyncType.LocalAndServer)
end

local function tb_chain_actions()
	return {
		{
			action = "action_wield",
			input = "action_wield",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_one",
			input = "action_one",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_two",
			input = "action_two",
			release_required = "action_two_hold",
			start_time = 0.2,
			sub_action = "default",
		},
		{
			action = "action_three",
			input = "action_three",
			start_time = 0.2,
			sub_action = "default",
		},
	}
end

local function tb_can_desummon(owner_unit)
	return tb_field_skeletons(owner_unit) > 0
end

-- Teleporting (and sacrificing) works on skeletons on the field as well as desummoned ones
local function tb_has_any_skeletons(owner_unit)
	return tb_field_skeletons(owner_unit) > 0 or tb_stash_count(owner_unit) > 0
end

local utility_actions = Weapons.bw_necromancer_career_utility_weapon.actions

-- The command item's own conditions count the controlled units, which now include the desummoned ones
local function tb_require_field_skeletons(action_settings, field_name)
	local original = action_settings[field_name]

	action_settings[field_name] = function (owner_unit, ...)
		return tb_field_skeletons(owner_unit) > 0 and original(owner_unit, ...)
	end
end

tb_require_field_skeletons(utility_actions.action_one.default, "condition_func")
tb_require_field_skeletons(utility_actions.action_one.default, "chain_condition_func")

local stand_conditions = utility_actions.action_two.default.conditional_actions[1]
local original_stand_condition = stand_conditions.condition

stand_conditions.condition = function (talent_extension, buff_extension, weapon_extension, owner_unit)
	return tb_field_skeletons(owner_unit) > 0 and original_stand_condition(talent_extension, buff_extension, weapon_extension, owner_unit)
end

-- Reload sacrifices a skeleton, a desummoned one if there is none on the field
utility_actions.weapon_reload.default.condition_func = tb_has_any_skeletons
utility_actions.weapon_reload.default.chain_condition_func = tb_has_any_skeletons

-- With no skeleton to sacrifice on the field, a desummoned one is. Releasing either gives Reaping and Cursed Blood
-- their stacks. The target is looked at first: the action sacrifices it, and it can be gone right after
mod:hook(ActionCareerBWNecromancerCommandVent, "client_owner_start_action", function (func, self, ...)
	local owner_unit = self._owner_unit
	local releases_field_skeleton = not not HEALTH_ALIVE[self._command_ability:vent_command_target()]
	local releases_desummoned = not releases_field_skeleton and tb_stash_count(owner_unit) > 0

	func(self, ...)

	if releases_desummoned then
		tb_add_synced_buff(owner_unit, SACRIFICE_STASHED_BUFF)
	end

	if (releases_field_skeleton or releases_desummoned) and mod.on_necromancer_skeleton_released then
		mod.on_necromancer_skeleton_released(owner_unit)
	end
end)

-- No condition_func on these: sub actions that have one are also started straight from idle by their action's input
utility_actions.weapon_reload[DESUMMON_SUB_ACTION] = {
	anim_event = "pet_control_target_command_return",
	anim_event_3p = "pet_control_target_command",
	kind = "dummy",
	total_time = 0.7,
	weapon_action_hand = "left",
	chain_condition_func = tb_can_desummon,
	allowed_chain_actions = tb_chain_actions(),
	enter_function = function (attacker_unit, input_extension)
		tb_add_synced_buff(attacker_unit, DESUMMON_BUFF)
		input_extension:clear_input_buffer()

		return input_extension:reset_release_input()
	end,
}
utility_actions.action_two[RESUMMON_SUB_ACTION] = {
	anim_event = "pet_control_target_command_return",
	anim_event_3p = "pet_control_target_command",
	kind = "dummy",
	total_time = 0.7,
	weapon_action_hand = "left",
	chain_condition_func = tb_has_any_skeletons,
	allowed_chain_actions = tb_chain_actions(),
	enter_function = function (attacker_unit, input_extension)
		-- every skeleton it teleports or brings back; "charging" is one of the overcharge types that skips the per-shot ammo procs and their rpc
		local num_skeletons = tb_field_skeletons(attacker_unit) + tb_stash_count(attacker_unit)

		ScriptUnit.extension(attacker_unit, "overcharge_system"):add_charge(num_skeletons * RESUMMON_HEAT_PER_SKELETON, nil, "charging")
		tb_add_synced_buff(attacker_unit, RESUMMON_BUFF)
		input_extension:clear_input_buffer()

		return input_extension:reset_release_input()
	end,
}

-- From action_three, reload used to chain into the sacrifice and action_two into the hold position targeting
for _, chain_action in ipairs(utility_actions.action_three.default.allowed_chain_actions) do
	if chain_action.action == "weapon_reload" then
		chain_action.sub_action = DESUMMON_SUB_ACTION
	elseif chain_action.action == "action_two" then
		chain_action.sub_action = RESUMMON_SUB_ACTION
		chain_action.release_required = nil
	end
end

-- Sub action names are synced by index; the base game only fills this lookup from the vanilla weapon templates.
for _, sub_action_name in ipairs({ DESUMMON_SUB_ACTION, RESUMMON_SUB_ACTION }) do
	if not rawget(NetworkLookup.sub_actions, sub_action_name) then
		local index = #NetworkLookup.sub_actions + 1

		NetworkLookup.sub_actions[index] = sub_action_name
		NetworkLookup.sub_actions[sub_action_name] = index
	end
end

--[[
	Pet UI: a skull for each desummoned skeleton (the number is already right through the count above)
]]
local function tb_install_pet_ui_hooks()
	PetUI._tb_original_update_pet_widget = PetUI._update_pet_widget

	mod:hook(PetUI, "_update_pet_container", function (func, self, dt, t, player)
		local player_unit = player.player_unit

		self._tb_num_ghosts = player_unit and tb_stash_count(player_unit) or 0

		func(self, dt, t, player)

		local ghosts = self._tb_ghost_widgets

		if not ghosts then
			ghosts = {}
			self._tb_ghost_widgets = ghosts
		end

		-- the ones the update above let go
		local widget_by_unit = self._pet_widget_by_unit

		for i = #ghosts, 1, -1 do
			local widget = ghosts[i]

			if widget_by_unit[widget.content.unit] ~= widget then
				table.remove(ghosts, i)
			end
		end

		local reposition = false

		for i = #ghosts + 1, self._tb_num_ghosts do
			local widget = self:_create_pet_widget({})

			widget.content.tb_ghost = i
			ghosts[i] = widget
			reposition = true
		end

		if reposition then
			local widgets = self._pet_widget_list

			table.sort(widgets, function (a, b)
				return a.content.order_index < b.content.order_index
			end)

			for index, widget in ipairs(widgets) do
				widget.offset[1] = 36 * (6 - index)

				self:_set_widget_dirty(widget)
			end
		end
	end)
	mod:hook_origin(PetUI, "_update_pet_widget", function (self, widget, commander_extension, in_command_mode, hovered_unit)
		local ghost_index = widget.content.tb_ghost

		if ghost_index then
			return ghost_index <= (self._tb_num_ghosts or 0)
		end

		return self._tb_original_update_pet_widget(self, widget, commander_extension, in_command_mode, hovered_unit)
	end)
end

if PetUI then
	tb_install_pet_ui_hooks()
else
	mod:hook_require("scripts/ui/hud_ui/pet_ui", tb_install_pet_ui_hooks)
end
