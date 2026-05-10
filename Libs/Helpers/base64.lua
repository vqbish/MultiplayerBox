local base64 = {}

local function extract(v, from, width)
	return math.floor(v / 2^from) % 2^width
end

function base64.makeencoder(s62, s63, spad)
	local encoder = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" .. (s62 or "+") .. (s63 or "/") .. (spad or "=")
	for i = 1, #alphabet do
		encoder[i - 1] = string.byte(alphabet,i)
	end
	return encoder
end

function base64.makedecoder(s62, s63, spad)
	local decoder = {}
	local encoder = base64.makeencoder(s62, s63, spad)
	for b64code, charcode in tableIterators.pairs(encoder) do
		decoder[charcode] = b64code
	end
	return decoder
end

local DEFAULT_ENCODER = base64.makeencoder()
local DEFAULT_DECODER = base64.makedecoder()

local char, concat = string.char, table.concat

function base64.encode(str, encoder, usecaching)
	encoder = encoder or DEFAULT_ENCODER
	local t, k, n = {}, 1, #str
	local lastn = n % 3
	local cache = {}

	for i = 1, n - lastn, 3 do
		local a, b, c = string.byte(str,i, i + 2)
		local v = a * 0x10000 + b * 0x100 + c
		local s

		if usecaching then
			s = cache[v]
			if not s then
				s = char(
					encoder[extract(v, 18, 6)],
					encoder[extract(v, 12, 6)],
					encoder[extract(v, 6, 6)],
					encoder[extract(v, 0, 6)]
				)
				cache[v] = s
			end
		else
			s = char(
				encoder[extract(v, 18, 6)],
				encoder[extract(v, 12, 6)],
				encoder[extract(v, 6, 6)],
				encoder[extract(v, 0, 6)]
			)
		end

		t[k] = s
		k = k + 1
	end

	if lastn == 2 then
		local a, b = string.byte(str,n - 1, n)
		local v = a * 0x10000 + b * 0x100
		t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[extract(v, 6, 6)], encoder[64])
	elseif lastn == 1 then
		local v = string.byte(str,n) * 0x10000
		t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[64], encoder[64])
	end

	return concat(t)
end

function base64.decode(b64, decoder, usecaching)
	decoder = decoder or DEFAULT_DECODER

	local s62, s63
	for charcode, b64code in tableIterators.pairs(decoder) do
		if b64code == 62 then
			s62 = charcode
		elseif b64code == 63 then
			s63 = charcode
		end
	end

	local pattern = '[^%w%+%/%=]'
	if s62 and s63 then
		pattern = string.format(('[^%%w%%%s%%%s%%=]'), char(s62), char(s63))
	end

	b64 = string.gsub(b64, pattern, '')
	local cache = usecaching and {}
	local t, k = {}, 1
	local n = #b64
	local padding = string.sub(b64, -2) == '==' and 2 or string.sub(b64, -1) == '=' and 1 or 0

	local function dv(x)
		return decoder[x] or 0
	end

	for i = 1, padding > 0 and n - 4 or n, 4 do
		local a, b, c, d = string.byte(b64, i, i + 3)
		if not a or not b then
			break
		end

		local s

		if usecaching then
			local v0 = a * 0x1000000 + (b or 0) * 0x10000 + (c or 0) * 0x100 + (d or 0)
			s = cache[v0]
			if not s then
				local v = dv(a) * 0x40000 + dv(b) * 0x1000 + dv(c) * 0x40 + dv(d)
				s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
				cache[v0] = s
			end
		else
			local v = dv(a) * 0x40000 + dv(b) * 0x1000 + dv(c) * 0x40 + dv(d)
			s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
		end

		t[k] = s
		k = k + 1
	end

	if padding == 1 then
		local a, b, c = string.byte(b64, n - 3, n - 1)
		if a and b and c then
			local v = dv(a) * 0x40000 + dv(b) * 0x1000 + dv(c) * 0x40
			t[k] = char(extract(v, 16, 8), extract(v, 8, 8))
		end
	elseif padding == 2 then
		local a, b = string.byte(b64, n - 3, n - 2)
		if a and b then
			local v = dv(a) * 0x40000 + dv(b) * 0x1000
			t[k] = char(extract(v, 16, 8))
		end
	end

	return concat(t)
end

return base64