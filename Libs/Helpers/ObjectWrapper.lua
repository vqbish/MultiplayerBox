local ObjectWrapper = {}

ObjectWrapper.showDebugLogs = false

local function debugLog(...)
    if ObjectWrapper.showDebugLogs then
        Debug.Log("[ObjectWrapper] " .. table.concat({...}, " "))
    end
end

local function makeInstanceMethodInvoker(obj, objType, methodName, overloads)
    return function(...)
        local args = {...}
        local lastError = nil
        for _, method in ipairs(overloads) do
            local params = method:CallMethod("GetParameters")
            local paramCount = params and #params or 0
            if paramCount == 0 then
                local success, result = pcall(function()
                    return method:CallMethod("Invoke", obj, {})
                end)
                if success then
                    return result
                else
                    lastError = result
                end
            end
        end

        for _, method in ipairs(overloads) do
            local success, result = pcall(function()
                return method:CallMethod("Invoke", obj, args)
            end)
            if success then
                return result
            else
                lastError = result
            end
        end
        error("Failed to invoke instance method '" .. methodName .. "': " .. tostring(lastError))
    end
end

function ObjectWrapper.Wrap(dotNetObject)
    if type(dotNetObject) ~= "userdata" then
        error("ObjectWrapper.Wrap expects a .NET object (userdata)")
    end

    local objType = dotNetObject:CallMethod("GetType")
    if not objType then
        error("Unable to get type of provided object")
    end

    local members = { properties = {}, fields = {} }
    local props = objType:CallMethod("GetProperties")
    if props then
        for i = 1, #props do
            local prop = props[i]
            local name = prop:CallMethod("get_Name")
            if name then members.properties[name] = prop end
        end
    end
    local fields = objType:CallMethod("GetFields")
    if fields then
        for i = 1, #fields do
            local field = fields[i]
            local name = field:CallMethod("get_Name")
            if name then members.fields[name] = field end
        end
    end

    local proxy = {}
    local mt = {
        __index = function(_, key)
            if members.properties[key] then
                local prop = members.properties[key]
                local getMethod = prop:CallMethod("GetGetMethod")
                if getMethod then
                    return getMethod:CallMethod("Invoke", dotNetObject, {})
                end
                return nil
            end
            if members.fields[key] then
                local field = members.fields[key]
                return field:CallMethod("GetValue", dotNetObject)
            end
            local allMethods = objType:CallMethod("GetMethods")
            local overloads = {}
            if allMethods then
                for i = 1, #allMethods do
                    local m = allMethods[i]
                    local name = m:CallMethod("get_Name")
                    if name == key then
                        table.insert(overloads, m)
                    end
                end
            end
            if #overloads > 0 then
                return makeInstanceMethodInvoker(dotNetObject, objType, key, overloads)
            end
            return nil
        end,
        __newindex = function(_, key, value)
            if members.properties[key] then
                local prop = members.properties[key]
                local setMethod = prop:CallMethod("GetSetMethod")
                if setMethod then
                    setMethod:CallMethod("Invoke", dotNetObject, {value})
                    return
                end
            end
            if members.fields[key] then
                local field = members.fields[key]
                field:CallMethod("SetValue", dotNetObject, value)
                return
            end
            error("Cannot set '" .. key .. "' – no writable property or field")
        end,
        __tostring = function()
            local toString = dotNetObject:CallMethod("ToString")
            return toString or tostring(dotNetObject)
        end,
        __call = function(_, ...)
            local invokeMethod = dotNetObject:CallMethod("Invoke")
            if invokeMethod then
                return invokeMethod:CallMethod("Invoke", dotNetObject, {...})
            else
                error("Object is not callable (no Invoke method)")
            end
        end
    }
    setmetatable(proxy, mt)
    return proxy
end

function ObjectWrapper.WrapStatic(typeName)
    debugLog("WrapStatic: looking for type " .. typeName)
    local t = Assembler.FindType(typeName)
    if not t then error("Type not found: " .. typeName) end
    debugLog("WrapStatic: type found, full name = " .. (t:CallMethod("get_FullName") or "?"))

    local members = { properties = {}, fields = {} }
    local props = t:CallMethod("GetProperties")
    if props then
        for i = 1, #props do
            local prop = props[i]
            local name = prop:CallMethod("get_Name")
            if name then members.properties[name] = prop end
        end
    end
    local fields = t:CallMethod("GetFields")
    if fields then
        for i = 1, #fields do
            local field = fields[i]
            local name = field:CallMethod("get_Name")
            if name then members.fields[name] = field end
        end
    end

    local proxy = {}
    local mt = {
        __index = function(_, key)
            debugLog("WrapStatic __index: accessing " .. key)
            if members.properties[key] then
                debugLog("  -> static property " .. key)
                local prop = members.properties[key]
                local getMethod = prop:CallMethod("GetGetMethod")
                if getMethod then
                    return getMethod:CallMethod("Invoke", nil, {})
                end
                return nil
            end
            if members.fields[key] then
                debugLog("  -> static field " .. key)
                local field = members.fields[key]
                return field:CallMethod("GetValue", nil)
            end
            debugLog("  -> trying to get static method " .. key)
            local allMethods = t:CallMethod("GetMethods")
            local overloads = {}
            if allMethods then
                for i = 1, #allMethods do
                    local m = allMethods[i]
                    local name = m:CallMethod("get_Name")
                    if name == key then
                        table.insert(overloads, m)
                    end
                end
            end
            if #overloads > 0 then
                debugLog("  -> found " .. #overloads .. " overloads for " .. key)
                return function(...)
                    local args = {...}
                    debugLog("    --> invoking static method '" .. key .. "' with args count=" .. #args)
                    for _, method in ipairs(overloads) do
                        local params = method:CallMethod("GetParameters")
                        local paramCount = params and #params or 0
                        if paramCount == 0 then
                            debugLog("        trying zero-parameter overload")
                            local success, result = pcall(function()
                                return method:CallMethod("Invoke", nil, {})
                            end)
                            if success then
                                debugLog("        SUCCESS (zero-param), result = " .. tostring(result))
                                return result
                            else
                                debugLog("        FAILED (zero-param): " .. tostring(result))
                            end
                        end
                    end
                    for idx, method in ipairs(overloads) do
                        local params = method:CallMethod("GetParameters")
                        local paramCount = params and #params or 0
                        if paramCount ~= 0 then
                            debugLog("        trying overload #" .. idx .. " with " .. paramCount .. " param(s)")
                            local success, result = pcall(function()
                                return method:CallMethod("Invoke", nil, args)
                            end)
                            if success then
                                debugLog("        SUCCESS, result = " .. tostring(result))
                                return result
                            else
                                debugLog("        FAILED: " .. tostring(result))
                            end
                        end
                    end
                    error("Failed to invoke static method '" .. key .. "'")
                end
            else
                debugLog("  -> method " .. key .. " NOT FOUND")
            end
            return nil
        end,
        __newindex = function(_, key, value)
            debugLog("WrapStatic __newindex: " .. key .. " = " .. tostring(value))
            if members.properties[key] then
                local prop = members.properties[key]
                local setMethod = prop:CallMethod("GetSetMethod")
                if setMethod then
                    setMethod:CallMethod("Invoke", nil, {value})
                    return
                end
            end
            if members.fields[key] then
                local field = members.fields[key]
                field:CallMethod("SetValue", nil, value)
                return
            end
            error("Cannot set static member '" .. key .. "'")
        end
    }
    setmetatable(proxy, mt)
    return proxy
end

return ObjectWrapper