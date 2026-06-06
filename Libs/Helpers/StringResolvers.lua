local StringResolvers = {}

local function isDotNetTypeName(str)
    if type(str) ~= "string" then return false end
    return string.find(str, "[.]") ~= nil or string.find(str, "`") ~= nil or string.find(str,"^System%.")
end

local function tryGetDotNetType(typeName)
    if not typeName or typeName == "" then return nil end
    if Assembler and Assembler.FindType then
        local ok, t = pcall(Assembler.FindType, typeName)
        if ok and t then
            return t
        end
    end
    return nil
end

function StringResolvers.TransferTypeToString(value)
    local valType = basicModule.type(value) or "nil"
    
    if valType ~= "userdata" then
        if valType == "table" then
            return json.serialize(value)
        end
        return basicModule.tostring(value)
    end
    
    local isType = false
    local typeFullName = nil
    pcall(function()
        if value.CallMethod and value:CallMethod("get_FullName") then
            isType = true
            typeFullName = value:CallMethod("get_FullName")
        end
    end)
    
    if isType and typeFullName then
        return typeFullName
    end
    
    local toStr = value.ToString()
    if toStr and toStr ~= "" then
        return toStr
    end

    local objType = value:CallMethod("GetType")
    if objType then
        local typeName = objType:CallMethod("get_FullName") or objType:CallMethod("get_Name") or "Unknown"
        return string.format("[%s object]", typeName)
    end
    
    return basicModule.tostring(value)
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
        local vecClass = _G["Vector" .. #coords]
        if vecClass and vecClass.new then
            return vecClass.new(table.unpack(coords))
        end
    end
    
    if isDotNetTypeName(value) then
        local dotNetType = tryGetDotNetType(value)
        if dotNetType then
            return dotNetType
        end
    end
    
    return value
end

return StringResolvers