local StringResolvers = {}

function StringResolvers.TransferTypeToString(value)
    local valType = basicModule.type(value) or "nil"
    if valType ~= "userdata" then
        if valType == "table" then
            return json.serialize(value)
        end
        return basicModule.tostring(value)
    end

    return value.ToString()
end

function StringResolvers.TransferStringToType(value)
    if basicModule.type(value) ~= "string" then return value end

    if value == "nil" then return nil end
    if value == "true" then return true end
    if value == "false" then return false end

    local num = basicModule.tonumber(value)
    if num and tostring(num) == value then
        return num
    end

    local status, res = errorHandling.pcall(json.parse, value)
    if status and basicModule.type(res) == "table" then
        return res
    end

    local coords = {}
    local vectorPattern = "^%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*(,%s*(-?%d+%.?%d*)%s*)?(,%s*(-?%d+%.?%d*)%s*)?$"
    local a, b, c, d = string.match(value, vectorPattern)

    if a then coords[#coords + 1] = basicModule.tonumber(a) end
    if b then coords[#coords + 1] = basicModule.tonumber(b) end
    if c then coords[#coords + 1] = basicModule.tonumber(c) end
    if d then coords[#coords + 1] = basicModule.tonumber(d) end

    if #coords >= 2 and #coords <= 4 then
        local class = _G["Vector" .. #coords]
        if class and class.new then
            return class.new(table.unpack(coords))
        end
    end

    return value
end

return StringResolvers