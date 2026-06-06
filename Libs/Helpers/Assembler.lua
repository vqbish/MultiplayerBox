local Assembler = {}

local function safeCall(func, ...)
    local ok, result = errorHandling.pcall(func, ...)
    if not ok then
        Debug.Log("Assembler error. " .. tostring(result))
        return nil
    end
    return result
end

function Assembler.GetMscorlibAssembly()
    local tempGO = GameObject.Create("TempForAssembly")
    if not tempGO then
        return nil
    end

    local transformComp = tempGO.GetComponent("Transform")
    if not transformComp then
        tempGO.Destroy()
        return nil
    end

    local transformType = transformComp.CallMethod("GetType")
    if not transformType then
        tempGO.Destroy()
        return nil
    end

    local runtimeType = transformType.CallMethod("GetType")
    if not runtimeType then
        tempGO.Destroy()
        return nil
    end

    local mscorlibAssembly = runtimeType.GetField("Assembly")
    tempGO.Destroy()
    return mscorlibAssembly
end

function Assembler.GetAllAssemblies()
    local sysAssembly = Assembler.GetMscorlibAssembly()
    if not sysAssembly then
        return {}
    end

    local appDomainType = sysAssembly.CallMethod("GetType", "System.AppDomain")
    if not appDomainType then
        local objType = sysAssembly.CallMethod("GetType", "System.Object")
        if objType then
            local objAssembly = objType.GetField("Assembly")
            if objAssembly then
                appDomainType = objAssembly.CallMethod("GetType", "System.AppDomain")
            end
        end
    end

    if not appDomainType then
        return {}
    end

    local getCurrentDomainMethod = appDomainType.CallMethod("GetMethod", "get_CurrentDomain")
    if not getCurrentDomainMethod then
        return {}
    end

    local currentDomain = getCurrentDomainMethod.CallMethod("Invoke", nil, nil)
    if not currentDomain then
        return {}
    end

    local assemblies = currentDomain.CallMethod("GetAssemblies")
    if not assemblies then
        return {}
    end

    return assemblies
end

function Assembler.FindType(typeName)
    local assemblies = Assembler.GetAllAssemblies()
    for i = 1, #assemblies do
        local asm = assemblies[i]
        local t = asm.CallMethod("GetType", typeName)
        if t then
            return t
        end
    end
    return nil
end

function Assembler.FindTypesWithPattern(pattern)
    local result = {}
    local assemblies = Assembler.GetAllAssemblies()
    for i = 1, #assemblies do
        local types = assemblies[i].CallMethod("GetTypes")
        if types then
            for j = 1, #types do
                local t = types[j]
                local name = t.CallMethod("get_Name")
                if name and string.find(name, pattern) then
                    table.insert(result, t)
                end
            end
        end
    end
    return result
end

function Assembler.GetTypeMethods(typeObj, namePattern, flags)
    namePattern = namePattern or ".*"
    flags = flags or { Public = true, Instance = true }
    local bindingFlags = 0
    for k, v in pairs(flags) do
        if v then
            -- In .NET, BindingFlags are integer values; you may need to map them.
            -- Simpler. we'll call GetMethods with a string representation or assume a helper method exists.
            -- Since the environment may not expose BindingFlags constants, we provide a fallback. GetMethods() returns all public instance methods.
            -- For advanced filtering, user should call the methods directly on the type object if needed.
        end
    end
    local methods = typeObj.CallMethod("GetMethods")
    if not methods then return {} end
    local result = {}
    for i = 1, #methods do
        local m = methods[i]
        local name = m.CallMethod("get_Name")
        if name and string.find(name, namePattern) then
            table.insert(result, m)
        end
    end
    return result
end

function Assembler.InvokeMethod(targetObj, methodName, ...)
    local args = {...}
    if targetObj then
        return targetObj.CallMethod(methodName, table.unpack(args))
    else
        error("Assembler.InvokeMethod. For static methods, provide the type as third parameter.")
    end
end

function Assembler.InvokeStaticMethod(typeObj, methodName, ...)
    if not typeObj then return nil end
    return typeObj.CallMethod(methodName, ...)
end

function Assembler.GetFieldValue(targetObj, fieldName)
    if not targetObj then return nil end
    return targetObj.GetField(fieldName)
end

function Assembler.SetFieldValue(targetObj, fieldName, value)
    if not targetObj then return false end
    targetObj.SetField(fieldName, value)
    return true
end

function Assembler.GetPropertyValue(targetObj, propName)
    if not targetObj then return nil end
    return targetObj.GetProperty(propName)
end

function Assembler.SetPropertyValue(targetObj, propName, value)
    if not targetObj then return false end
    targetObj.SetProperty(propName, value)
    return true
end

function Assembler.CreateInstance(typeName, ...)
    local args = {...}
    
    local t = Assembler.FindType(typeName)
    if not t then
        Debug.Log("Assembler.CreateInstance. Type not found. " .. typeName)
        return nil
    end
    
    local activator = Assembler.FindType("System.Activator")
    if activator then
        local success, obj = pcall(function()
            if #args == 0 then
                return activator.CallMethod("CreateInstance", t)
            else
                return activator.CallMethod("CreateInstance", t, args)
            end
        end)
        if success and obj then
            return obj
        else
            Debug.Log("Assembler.CreateInstance. Activator failed, falling back to constructor search")
        end
    end
    
    local constructor = nil
    if #args == 0 then
        constructor = t.CallMethod("GetConstructor", {})
    else
        local argTypes = {}
        for i, arg in ipairs(args) do
            local argType = nil
            if type(arg) == "userdata" then
                argType = arg.CallMethod("GetType")
            elseif type(arg) == "string" then
                argType = Assembler.FindType("System.String")
            elseif type(arg) == "number" then
                argType = Assembler.FindType("System.Double")
            elseif type(arg) == "boolean" then
                argType = Assembler.FindType("System.Boolean")
            elseif type(arg) == "table" then
                argType = Assembler.FindType("System.Object")
            end
            if not argType then
                argType = Assembler.FindType("System.Object")
            end
            table.insert(argTypes, argType)
        end
        constructor = t.CallMethod("GetConstructor", argTypes)
    end
    
    if constructor then
        local success, obj = pcall(function()
            return constructor.CallMethod("Invoke", args)
        end)
        if success and obj then
            return obj
        else
            Debug.Log("Assembler.CreateInstance. Constructor invoke failed. " .. tostring(obj))
        end
    end
    
    local success, obj = pcall(function()
        return t.CallMethod("InvokeMember", nil, "CreateInstance", nil, args)
    end)
    if success and obj then
        return obj
    else
        Debug.Log("Assembler.CreateInstance. All creation methods failed for type. " .. typeName)
        return nil
    end
end

function Assembler.Activate(typeName, ...)
    local activator = Assembler.FindType("System.Activator")
    if not activator then
        return Assembler.CreateInstance(typeName, ...)
    end
    local t = Assembler.FindType(typeName)
    if not t then return nil end
    local args = {...}
    return activator.CallMethod("CreateInstance", t, args)
end

function Assembler.GetAssemblyByName(assemblyName)
    local assemblies = Assembler.GetAllAssemblies()
    for i = 1, #assemblies do
        local asm = assemblies[i]
        local name = asm.CallMethod("get_FullName")
        if name and name == assemblyName then
            return asm
        end
    end
    return nil
end

function Assembler.GetTypesFromAssembly(assembly)
    if not assembly then return {} end
    local types = assembly.CallMethod("GetTypes")
    return types or {}
end

function Assembler.TryFindType(typeName)
    return safeCall(Assembler.FindType, typeName)
end

function Assembler.TypeExists(typeName)
    return Assembler.TryFindType(typeName) ~= nil
end

function Assembler.GetTypeInfo(obj)
    if not obj then return nil end
    local t = obj.CallMethod("GetType")
    if t then
        return {
            Name = t.CallMethod("get_Name"),
            FullName = t.CallMethod("get_FullName"),
            IsValueType = t.CallMethod("get_IsValueType"),
            IsEnum = t.CallMethod("get_IsEnum")
        }
    end
    return nil
end

function Assembler.TryInvoke(func, ...)
    return safeCall(func, ...)
end

return Assembler