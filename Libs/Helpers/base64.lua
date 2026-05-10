local base64 = {}

local SEP = "|"

local function cp_to_utf8(cp)
	if cp <= 0x7F then
		return string.char(cp)
	elseif cp <= 0x7FF then
		local b1 = 0xC0 + math.floor(cp / 0x40)
		local b2 = 0x80 + (cp % 0x40)
		return string.char(b1, b2)
	elseif cp <= 0xFFFF then
		local b1 = 0xE0 + math.floor(cp / 0x1000)
		local b2 = 0x80 + (math.floor(cp / 0x40) % 0x40)
		local b3 = 0x80 + (cp % 0x40)
		return string.char(b1, b2, b3)
	elseif cp <= 0x10FFFF then
		local b1 = 0xF0 + math.floor(cp / 0x40000)
		local b2 = 0x80 + (math.floor(cp / 0x1000) % 0x40)
		local b3 = 0x80 + (math.floor(cp / 0x40) % 0x40)
		local b4 = 0x80 + (cp % 0x40)
		return string.char(b1, b2, b3, b4)
	end
	return "?"
end

local function utf8_next_codepoint(s, i)
	local b1 = string.byte(s, i)
	if not b1 then
		return nil, i
	end

	if b1 < 0x80 then
		return b1, i + 1
	end

	if b1 < 0xE0 then
		local b2 = string.byte(s, i + 1)
		if not b2 then return 0xFFFD, i + 1 end
		local cp = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
		return cp, i + 2
	end

	if b1 < 0xF0 then
		local b2 = string.byte(s, i + 1)
		local b3 = string.byte(s, i + 2)
		if not b2 or not b3 then return 0xFFFD, i + 1 end
		local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
		return cp, i + 3
	end

	local b2 = string.byte(s, i + 1)
	local b3 = string.byte(s, i + 2)
	local b4 = string.byte(s, i + 3)
	if not b2 or not b3 or not b4 then return 0xFFFD, i + 1 end
	local cp = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
	return cp, i + 4
end

local lower_cps = {
	0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0451, 0x0436, 0x0437, 0x0438,
	0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F, 0x0440, 0x0441, 0x0442,
	0x0443, 0x0444, 0x0445, 0x0446, 0x0447, 0x0448, 0x0449, 0x044A, 0x044B, 0x044C,
	0x044D, 0x044E, 0x044F
}

local upper_cps = {
	0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0401, 0x0416, 0x0417, 0x0418,
	0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F, 0x0420, 0x0421, 0x0422,
	0x0423, 0x0424, 0x0425, 0x0426, 0x0427, 0x0428, 0x0429, 0x042A, 0x042B, 0x042C,
	0x042D, 0x042E, 0x042F
}

local encode_map = {}
local decode_map = {}

for i, cp in tableIterators.ipairs(lower_cps) do
	local tag = string.format("r%02d", i)
	encode_map[cp] = tag
	decode_map[tag] = cp
end

for i, cp in tableIterators.ipairs(upper_cps) do
	local tag = string.format("R%02d", i)
	encode_map[cp] = tag
	decode_map[tag] = cp
end

function base64.encode(str)
	local out = {}
	local k = 1
	local i = 1

	while i <= #str do
		local cp, next_i = utf8_next_codepoint(str, i)
		if not cp then
			break
		end

		local tag = encode_map[cp]
		if tag then
			out[k] = tag
		else
			out[k] = "u" .. string.format("%X", cp)
		end

		k = k + 1
		i = next_i
	end

	return table.concat(out, SEP)
end

function base64.decode(data)
	local out = {}
	local k = 1

	for token in string.gmatch(data, "[^" .. SEP .. "]+") do
		local cp = decode_map[token]
		if cp then
			out[k] = cp_to_utf8(cp)
		else
			local hex = string.match(token, "^u([%x]+)$")
			if hex then
				out[k] = cp_to_utf8(basicModule.tonumber(hex, 16))
			else
				out[k] = token
			end
		end
		k = k + 1
	end

	return table.concat(out)
end

return base64