local mod = get_mod("TourneyBalance")

--[[

	Career strings export (dev tool)

	"/tb_copy_career_strings" copies every career's career ability, passive, perks and
	talents (id, localized name, formatted description) to the clipboard as JSON.

	Strings are read at command time, so they reflect this mod's text/value changes and
	match what the in-game UI shows: descriptions go through the same UIUtils.get_*_description
	formatting the hero/talent windows use.

	Order follows the game: heroes in hero-select order (ProfilePriority), careers in each
	hero's career order, then per career:
		career_ability, passive, perks (in order), talents (tier 1..6, left to right)

	cjson isn't used because it doesn't keep object key order (and escapes "/"), so the
	JSON is written by hand below.

]]

local function json_string(value)
	local str = tostring(value or "")

	str = str:gsub('[%c"\\]', function (c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		elseif c == "\r" then
			return "\\r"
		elseif c == "\t" then
			return "\\t"
		end

		return string.format("\\u%04x", c:byte())
	end)

	return '"' .. str .. '"'
end

local function safe_localize(key)
	if not key then
		return ""
	end

	local ok, result = pcall(Localize, key)

	return ok and result or key
end

-- UIUtils formatting can error on a broken string/description_values pair; fall back to the raw localized string
local function safe_description(format_func, data)
	if not data.description then
		return ""
	end

	local ok, result = pcall(format_func, data)

	return ok and result or safe_localize(data.description)
end

-- One ordered {"id","name","description"} object, plus optional leading fields
local function entry_json(indent, id, name, description, extra_key, extra_value)
	local parts = {}

	if extra_key then
		parts[#parts + 1] = json_string(extra_key) .. ": " .. tostring(extra_value)
	end

	parts[#parts + 1] = '"id": ' .. json_string(id)
	parts[#parts + 1] = '"name": ' .. json_string(name)
	parts[#parts + 1] = '"description": ' .. json_string(description)

	return indent .. "{ " .. table.concat(parts, ", ") .. " }"
end

local function array_json(indent, lines)
	if #lines == 0 then
		return "[]"
	end

	return "[\n" .. table.concat(lines, ",\n") .. "\n" .. indent .. "]"
end

local function career_json(profile, career_settings)
	local hero_name = profile.display_name
	local tree = TalentTrees[hero_name] and TalentTrees[hero_name][career_settings.talent_tree_index]
	local ability = CareerUtils.get_ability_data_by_career(career_settings, 1)
	local passive = CareerUtils.get_passive_ability_by_career(career_settings)

	if not (tree and ability and passive) then
		return nil
	end

	local fields = {}

	fields[#fields + 1] = '\t\t"name": ' .. json_string(safe_localize(career_settings.display_name))
	fields[#fields + 1] = '\t\t"hero_id": ' .. json_string(hero_name)
	fields[#fields + 1] = '\t\t"hero_name": ' .. json_string(safe_localize(profile.character_name))

	fields[#fields + 1] = '\t\t"career_ability": ' .. entry_json("", ability.display_name, safe_localize(ability.display_name), safe_description(UIUtils.get_ability_description, ability))
	fields[#fields + 1] = '\t\t"passive": ' .. entry_json("", passive.display_name, safe_localize(passive.display_name), safe_description(UIUtils.get_ability_description, passive))

	local perk_lines = {}

	for _, perk in ipairs(passive.perks or {}) do
		perk_lines[#perk_lines + 1] = entry_json("\t\t\t", perk.display_name, safe_localize(perk.display_name), safe_description(UIUtils.get_perk_description, perk))
	end

	fields[#fields + 1] = '\t\t"perks": ' .. array_json("\t\t", perk_lines)

	local talent_lines = {}

	for tier = 1, #tree do
		local row = tree[tier]

		for column = 1, #row do
			local talent_name = row[column]
			local lookup = TalentIDLookup[talent_name]
			local talent = lookup and TalentUtils.get_talent_by_id(hero_name, lookup.talent_id)

			if talent then
				talent_lines[#talent_lines + 1] = entry_json("\t\t\t", talent_name, safe_localize(talent.display_name or talent.name), safe_description(UIUtils.get_talent_description, talent), "tier", tier)
			else
				talent_lines[#talent_lines + 1] = entry_json("\t\t\t", talent_name, "", "", "tier", tier)
			end
		end
	end

	fields[#fields + 1] = '\t\t"talents": ' .. array_json("\t\t", talent_lines)

	return "\t" .. json_string(career_settings.name) .. ": {\n" .. table.concat(fields, ",\n") .. "\n\t}"
end

local function build_career_strings_json()
	local career_blocks = {}

	for _, profile_index in ipairs(ProfilePriority) do
		local profile = SPProfiles[profile_index]

		if profile and profile.careers then
			for _, career_settings in ipairs(profile.careers) do
				local block = career_json(profile, career_settings)

				if block then
					career_blocks[#career_blocks + 1] = block
				end
			end
		end
	end

	return "{\n" .. table.concat(career_blocks, ",\n") .. "\n}", #career_blocks
end

mod:command("tb_copy_career_strings", "Copies every career's ability, passive, perks and talents (id, name, description) to the clipboard as JSON.", function ()
	local ok, json, num_careers = pcall(build_career_strings_json)

	if not ok then
		mod:echo("[TourneyBalance] Career strings export failed: " .. tostring(json))
		return
	end

	Clipboard.put(json)
	mod:echo(string.format("[TourneyBalance] Copied strings for %d careers to clipboard.", num_careers))
end)
