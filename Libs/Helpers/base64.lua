local base64 = {}

local char = string.char
local byte = string.byte
local concat = table.concat
local insert = table.insert

function base64.makeencoder(s62, s63, spad)
	local encoder = {}

	local chars = {
		[0]='A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
		'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
		'o','p','q','r','s','t','u','v','w','x','y','z',
		'0','1','2','3','4','5','6','7','8','9',
		s62 or '+',
		s63 or '-',
		spad or '='
	}

	for i, v in tableIterators.pairs(chars) do
		encoder[i] = v
	end

	return encoder
end

function base64.makedecoder(s62, s63, spad)
	local decoder = {}
	local encoder = base64.makeencoder(s62, s63, spad)

	for i, v in tableIterators.pairs(encoder) do
		decoder[v] = i
	end

	return decoder
end

local DEFAULT_ENCODER = base64.makeencoder()
local DEFAULT_DECODER = base64.makedecoder()

local function utf8_to_bytes(str)
    local bytes = {}
    local length = string.len(str)

    for i = 1, length do
        local code = string.byte(str, i)

        if code < 0x80 then
            insert(bytes, code)
        elseif code < 0x800 then
            insert(bytes, 0xC0 + math.floor(code / 0x40))
            insert(bytes, 0x80 + (code % 0x40))
        elseif code < 0x10000 then
            insert(bytes, 0xE0 + math.floor(code / 0x1000))
            insert(bytes, 0x80 + (math.floor(code / 0x40) % 0x40))
            insert(bytes, 0x80 + (code % 0x40))
        else
            insert(bytes, 0xF0 + math.floor(code / 0x40000))
            insert(bytes, 0x80 + (math.floor(code / 0x1000) % 0x40))
            insert(bytes, 0x80 + (math.floor(code / 0x40) % 0x40))
            insert(bytes, 0x80 + (code % 0x40))
        end
    end
    return bytes
end

-- BYTE ARRAY -> RAW STRING
local function bytes_to_string(bytes)
    local res = {}
    local i = 1
    while i <= #bytes do
        local b1 = bytes[i]
        local code
        
        if b1 < 0x80 then
            code = b1
            i = i + 1
        elseif b1 < 0xE0 then
            local b2 = bytes[i + 1]
            code = ((b1 % 0x20) * 0x40) + (b2 % 0x40)
            i = i + 2
        elseif b1 < 0xF0 then
            local b2 = bytes[i + 1]
            local b3 = bytes[i + 2]
            code = ((b1 % 0x10) * 0x1000) + ((b2 % 0x40) * 0x40) + (b3 % 0x40)
            i = i + 3
        else
            local b2 = bytes[i + 1]
            local b3 = bytes[i + 2]
            local b4 = bytes[i + 3]
            code = ((b1 % 0x08) * 0x40000) + ((b2 % 0x40) * 0x1000) + ((b3 % 0x40) * 0x40) + (b4 % 0x40)
            i = i + 4
        end
        table.insert(res, char(code))
    end
    return table.concat(res)
end

function base64.encode(str, encoder)
	encoder = encoder or DEFAULT_ENCODER

	local bytes = utf8_to_bytes(str)

	local t = {}
	local k = 1

	local n = #bytes
	local lastn = n % 3

	for i = 1, n - lastn, 3 do
		local a = bytes[i]
		local b = bytes[i + 1]
		local c = bytes[i + 2]

		local v =
			a * 0x10000 +
			b * 0x100 +
			c

		t[k] =
			encoder[bit32.extract(v, 18, 6)] ..
			encoder[bit32.extract(v, 12, 6)] ..
			encoder[bit32.extract(v, 6, 6)] ..
			encoder[bit32.extract(v, 0, 6)]

		k = k + 1
	end

	if lastn == 2 then
		local a = bytes[n - 1]
		local b = bytes[n]

		local v =
			a * 0x10000 +
			b * 0x100

		t[k] =
			encoder[bit32.extract(v, 18, 6)] ..
			encoder[bit32.extract(v, 12, 6)] ..
			encoder[bit32.extract(v, 6, 6)] ..
			encoder[64]

	elseif lastn == 1 then
		local v = bytes[n] * 0x10000

		t[k] =
			encoder[bit32.extract(v, 18, 6)] ..
			encoder[bit32.extract(v, 12, 6)] ..
			encoder[64] ..
			encoder[64]
	end

	return concat(t)
end

function base64.decode(b64, decoder)
    decoder = decoder or DEFAULT_DECODER
    b64 = string.gsub(b64, '[^%w%+%-%=]', '')

    local bytes = {}
    local n = #b64
    local padding = string.sub(b64, -2) == '==' and 2 or string.sub(b64, -1) == '=' and 1 or 0

    for i = 1, padding > 0 and n - 4 or n, 4 do
        local a, b, c, d = string.sub(b64, i, i), string.sub(b64, i+1, i+1), string.sub(b64, i+2, i+2), string.sub(b64, i+3, i+3)
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40 + decoder[d]
        
        table.insert(bytes, bit32.extract(v, 16, 8))
        table.insert(bytes, bit32.extract(v, 8, 8))
        table.insert(bytes, bit32.extract(v, 0, 8))
    end

    if padding == 1 then
        local a, b, c = string.sub(b64, n-3, n-3), string.sub(b64, n-2, n-2), string.sub(b64, n-1, n-1)
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40
        table.insert(bytes, bit32.extract(v, 16, 8))
        table.insert(bytes, bit32.extract(v, 8, 8))
    elseif padding == 2 then
        local a, b = string.sub(b64, n-3, n-3), string.sub(b64, n-2, n-2)
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000
        table.insert(bytes, bit32.extract(v, 16, 8))
    end

    return bytes_to_string(bytes)
end

return base64