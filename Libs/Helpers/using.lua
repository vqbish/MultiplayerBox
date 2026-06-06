setmetatable = metaTable.setmetatable
type = basicModule.type
error = Debug.LogError
tostring = basicModule.tostring
ipairs = tableIterators.ipairs
pcall = errorHandling.pcall

local cache = {}

local function getAllAssemblies()
    return Assembler.GetAllAssemblies()
end

local function wrapStaticType(fullTypeName)
    local success, wrapped = pcall(ObjectWrapper.WrapStatic, fullTypeName)
    if success then
        return wrapped
    else
        return nil, wrapped
    end
end

local function getShortName(fullName)
    local lastDot = string.match(fullName, ".*%.(.+)$")
    return lastDot or fullName
end

function using(name, autoGlobal)
    if autoGlobal == nil then
        autoGlobal = true
    end

    if cache[name] ~= nil then
        local result = cache[name]
        if autoGlobal then
            local globalName = getShortName(name)
            _G[globalName] = result
        end
        return result
    end

    local directType = Assembler.TryFindType(name)
    if directType then
        local wrapped = wrapStaticType(name)
        if wrapped then
            cache[name] = wrapped
            if autoGlobal then
                local globalName = getShortName(name)
                _G[globalName] = wrapped
            end
            return wrapped
        else
            error("Failed to wrap type '" .. name .. "': " .. tostring(wrapped))
        end
    end

    local namespaceTable = {}
    local assemblies = getAllAssemblies()
    local foundAny = false

    for _, asm in ipairs(assemblies) do
        local types = asm:CallMethod("GetTypes")
        if types then
            for i = 1, #types do
                local t = types[i]
                local fullName = t:CallMethod("get_FullName")
                if fullName and type(fullName) == "string" then
                    if string.find(fullName, "^" .. name .. "%.") then
                        local shortName = string.match(fullName, "^" .. name .. "%.([^%.]+)$")
                        if shortName and not namespaceTable[shortName] then
                            local wrapped, err = wrapStaticType(fullName)
                            if wrapped then
                                namespaceTable[shortName] = wrapped
                                foundAny = true
                            else
                                Debug.Log("[using] Could not wrap " .. fullName .. ": " .. tostring(err))
                            end
                        end
                    end
                end
            end
        end
    end

    if foundAny then
        cache[name] = namespaceTable
        if autoGlobal then
            local globalName = getShortName(name)
            _G[globalName] = namespaceTable
        end
        return namespaceTable
    else
        error("Namespace or class not found: " .. name)
    end
end

_G.using = using

return using