local GBDumper = {}

using("System", true)

local dumpCoroutine = nil
local totalTypes = 0
local processedTypes = 0
local assemblies = {}

local function EscapeJSON(str)
    if str == nil then return "null" end
    str = tostring(str)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\r", "\\r")
    return '"' .. str .. '"'
end

local function GetFullTypeName(csType)
    if not csType then return "null" end
    local ok, name = pcall(function()
        local n = csType:CallMethod("get_FullName")
        if not n or n == "" then
            n = csType:CallMethod("get_Name")
        end
        return n or "Unknown"
    end)
    if ok and name then
        return EscapeJSON(name)
    end
    return EscapeJSON("Unknown")
end

local function CleanFilename(name)
    if not name then return "Unknown_Assembly" end
    local clean = string.match(name, "^[^,]+") or name
    clean = string.gsub(clean, "[%s%c%<%>\x00-\x1F\\%/%:%*%?%'%'|]", "_")
    return clean
end

local function ProcessType(t, buffer, indentLevel)
    if not t then return end

    local ind = string.rep("  ", indentLevel)
    local ind2 = string.rep("  ", indentLevel + 1)
    local ind3 = string.rep("  ", indentLevel + 2)
    local ind4 = string.rep("  ", indentLevel + 3)

    local currentTypeName = GetFullTypeName(t)

    table.insert(buffer, ind .. "{")
    table.insert(buffer, ind2 .. '"FullName": ' .. currentTypeName .. ',')

    local baseType = nil
    local baseTypeName = "null"
    local rawBaseName = ""
    pcall(function()
        baseType = t:CallMethod("get_BaseType")
        if baseType then
            baseTypeName = GetFullTypeName(baseType)
            rawBaseName = baseType:CallMethod("get_FullName") or baseType:CallMethod("get_Name") or ""
        end
    end)

    local isEnum = false
    local isAbstract = false
    local isSealed = false
    local isClass = false
    local isInterface = false
    local isValueType = false
    local isDelegate = false
    
    pcall(function()
        isEnum = t:CallMethod("get_IsEnum") == true
        isAbstract = t:CallMethod("get_IsAbstract") == true
        isSealed = t:CallMethod("get_IsSealed") == true
        isClass = t:CallMethod("get_IsClass") == true
        isInterface = t:CallMethod("get_IsInterface") == true
        isValueType = t:CallMethod("get_IsValueType") == true
        isDelegate = (rawBaseName == "System.MulticastDelegate" or rawBaseName == "System.Delegate")
    end)
    
    local typeKind = "Unknown"
    if isEnum then
        typeKind = "Enum"
    elseif isDelegate then
        typeKind = "Delegate"
    elseif isInterface then
        typeKind = "Interface"
    elseif isValueType then
        typeKind = "Struct"
    elseif isClass then
        if isAbstract and isSealed then
            typeKind = "StaticClass"
        elseif isAbstract then
            typeKind = "AbstractClass"
        elseif isSealed then
            typeKind = "SealedClass"
        else
            typeKind = "Class"
        end
    end

    table.insert(buffer, ind2 .. '"TypeKind": "' .. typeKind .. '",')
    table.insert(buffer, ind2 .. '"BaseType": ' .. baseTypeName .. ',')

    if typeKind == "Enum" then
        table.insert(buffer, ind2 .. '"EnumValues": [')
        local enumNames = nil
        pcall(function() enumNames = t:CallMethod("GetEnumNames") end)
        local enumVals = {}
        if enumNames and #enumNames > 0 then
            for i = 1, #enumNames do
                table.insert(enumVals, EscapeJSON(enumNames[i]))
            end
        end
        for i = 1, #enumVals do
            local comma = (i == #enumVals) and "" or ","
            table.insert(buffer, ind3 .. enumVals[i] .. comma)
        end
        table.insert(buffer, ind2 .. ']')
    else
        table.insert(buffer, ind2 .. '"Fields": [')
        local fields = nil
        pcall(function() fields = t:CallMethod("GetFields") end)
        local validFields = {}
        if fields and #fields > 0 then
            for i = 1, #fields do
                local f = fields[i]
                if f then
                    local declaringType = nil
                    pcall(function() declaringType = f:CallMethod("get_DeclaringType") end)
                    if GetFullTypeName(declaringType) == currentTypeName then
                        table.insert(validFields, f)
                    end
                end
            end
            for i = 1, #validFields do
                local f = validFields[i]
                local fName = EscapeJSON(f:CallMethod("get_Name"))
                local fType = GetFullTypeName(f:CallMethod("get_FieldType"))
                local isStatic = false
                pcall(function() isStatic = f:CallMethod("get_IsStatic") == true end)
                local comma = (i == #validFields) and "" or ","
                table.insert(buffer, ind3 .. '{ "Name": ' .. fName .. ', "Type": ' .. fType .. ', "IsStatic": ' .. tostring(isStatic) .. ' }' .. comma)
            end
        end
        table.insert(buffer, ind2 .. '],')

        table.insert(buffer, ind2 .. '"Properties": [')
        local props = nil
        pcall(function() props = t:CallMethod("GetProperties") end)
        local validProps = {}
        if props and #props > 0 then
            for i = 1, #props do
                local p = props[i]
                if p then
                    local declaringType = nil
                    pcall(function() declaringType = p:CallMethod("get_DeclaringType") end)
                    if GetFullTypeName(declaringType) == currentTypeName then
                        table.insert(validProps, p)
                    end
                end
            end
            for i = 1, #validProps do
                local p = validProps[i]
                local pName = EscapeJSON(p:CallMethod("get_Name"))
                local pType = GetFullTypeName(p:CallMethod("get_PropertyType"))
                local comma = (i == #validProps) and "" or ","
                table.insert(buffer, ind3 .. '{ "Name": ' .. pName .. ', "Type": ' .. pType .. ' }' .. comma)
            end
        end
        table.insert(buffer, ind2 .. '],')

        table.insert(buffer, ind2 .. '"Methods": [')
        local methods = nil
        pcall(function() methods = t:CallMethod("GetMethods") end)
        local validMethods = {}
        if methods and #methods > 0 then
            for i = 1, #methods do
                local m = methods[i]
                if m then
                    local declaringType = nil
                    pcall(function() declaringType = m:CallMethod("get_DeclaringType") end)
                    if GetFullTypeName(declaringType) == currentTypeName then
                        table.insert(validMethods, m)
                    end
                end
            end
            for i = 1, #validMethods do
                local m = validMethods[i]
                local mName = EscapeJSON(m:CallMethod("get_Name"))
                local mRet = GetFullTypeName(m:CallMethod("get_ReturnType"))
                local isStatic = false
                local isVirtual = false
                pcall(function() isStatic = m:CallMethod("get_IsStatic") == true end)
                pcall(function() isVirtual = m:CallMethod("get_IsVirtual") == true end)
                local paramsStr = "["
                local params = nil
                pcall(function() params = m:CallMethod("GetParameters") end)
                if params and #params > 0 then
                    for p = 1, #params do
                        local param = params[p]
                        local pName = EscapeJSON(param:CallMethod("get_Name"))
                        local pType = GetFullTypeName(param:CallMethod("get_ParameterType"))
                        paramsStr = paramsStr .. '{"Name": ' .. pName .. ', "Type": ' .. pType .. '}'
                        if p < #params then paramsStr = paramsStr .. ", " end
                    end
                end
                paramsStr = paramsStr .. "]"

                local comma = (i == #validMethods) and "" or ","
                table.insert(buffer, ind3 .. '{')
                table.insert(buffer, ind4 .. '"Name": ' .. mName .. ',')
                table.insert(buffer, ind4 .. '"ReturnType": ' .. mRet .. ',')
                table.insert(buffer, ind4 .. '"IsStatic": ' .. tostring(isStatic) .. ',')
                table.insert(buffer, ind4 .. '"IsVirtual": ' .. tostring(isVirtual) .. ',')
                table.insert(buffer, ind4 .. '"Parameters": ' .. paramsStr)
                table.insert(buffer, ind3 .. '}' .. comma)
            end
        end
        table.insert(buffer, ind2 .. '],')

        table.insert(buffer, ind2 .. '"NestedTypes": [')
        local nested = nil
        pcall(function() nested = t:CallMethod("GetNestedTypes") end)
        if nested and #nested > 0 then
            for i = 1, #nested do
                ProcessType(nested[i], buffer, indentLevel + 2)
                if i < #nested then table.insert(buffer, ind2 .. "  ,") end
            end
        end
        table.insert(buffer, ind2 .. ']')
    end

    table.insert(buffer, ind .. "}")
end

function GBDumper.PefrormDump()
    assemblies = Assembler.GetAllAssemblies()
    
    if assemblies then
        for i = 1, #assemblies do
            local types = assemblies[i]:CallMethod("GetTypes")
            if types then
                totalTypes = totalTypes + #types
            end
        end
    end
    
    Debug.Log(string.format("Found %d assemblies. Total types to dump: %d", #assemblies, totalTypes))
    dumpCoroutine = coroutine.create(DumpCoroutine)
end

function GBDumper.Update()
    if dumpCoroutine then
        local status, result = coroutine.resume(dumpCoroutine)
        if status == false then
            Debug.LogError("Coroutine error: " .. tostring(result))
            dumpCoroutine = nil
        elseif coroutine.status(dumpCoroutine) == "dead" then
            dumpCoroutine = nil
            Debug.Log("All assemblies dumped successfully!")
        end
    end
end

function DumpCoroutine()
    Debug.Log("Starting detached assembly JSON dump...")
    
    if not assemblies or #assemblies == 0 then
        Debug.LogError("No assemblies found to dump.")
        return
    end

    local allAssembliesBuffer = {}

    for asmIdx = 1, #assemblies do
        local asm = assemblies[asmIdx]
        local asmFullName = tostring(asm:CallMethod("get_FullName") or "Unknown")
        local asmShortName = CleanFilename(asmFullName)
        local filePath = string.format("GBDump_%s.json", asmShortName)
        
        Debug.Log(string.format("Processing assembly [%d/%d]: %s", asmIdx, #assemblies, asmShortName))
        
        local buffer = {}
        table.insert(buffer, "{")
        table.insert(buffer, '  "AssemblyName": ' .. EscapeJSON(asmFullName) .. ',')
        table.insert(buffer, '  "Types": [')

        local types = asm:CallMethod("GetTypes")
        if types then
            for typeIdx = 1, #types do
                local ok, err = pcall(ProcessType, types[typeIdx], buffer, 4)
                if not ok then
                    Debug.LogError(string.format("Error processing type %s: %s", 
                        tostring(types[typeIdx]:CallMethod("get_FullName") or "?"), err))
                    table.insert(buffer, string.format('    { "FullName": %s, "Error": true }', 
                        EscapeJSON(tostring(types[typeIdx]:CallMethod("get_FullName") or "?"))))
                end
                
                if typeIdx < #types then
                    table.insert(buffer, '    ,')
                end

                processedTypes = processedTypes + 1
                
                if processedTypes % 5 == 0 then
                    local percent = (processedTypes / totalTypes) * 100
                    Debug.Log(string.format("Total Progress: %.2f%% (%d/%d types)", percent, processedTypes, totalTypes))
                    coroutine.yield()
                end
            end
        end
        
        table.insert(buffer, '  ]')
        table.insert(buffer, "}")

        local finalJson = table.concat(buffer, "\n")
        
        table.insert(allAssembliesBuffer, finalJson)

        local success, err = pcall(function()
            File.ExportFile(filePath, finalJson)
        end)
        
        if success then
            Debug.Log(string.format("Saved: %s (%d chars)", filePath, #finalJson))
        else
            Debug.LogError(string.format("Failed to save %s: %s", filePath, tostring(err)))
        end
        
        coroutine.yield()
    end

    Debug.Log("Creating master merged JSON dump...")
    
    local globalBuffer = {}
    table.insert(globalBuffer, "{")
    table.insert(globalBuffer, '  "TotalAssemblies": ' .. #assemblies .. ',')
    table.insert(globalBuffer, '  "TotalTypes": ' .. totalTypes .. ',')
    table.insert(globalBuffer, '  "Assemblies": [')
    
    for i = 1, #allAssembliesBuffer do
        local indentedAsm = string.gsub(allAssembliesBuffer[i], "\n", "\n    ")
        table.insert(globalBuffer, "    " .. indentedAsm)
        
        if i < #allAssembliesBuffer then
            table.insert(globalBuffer, "    ,")
        end
    end
    
    table.insert(globalBuffer, "  ]")
    table.insert(globalBuffer, "}")
    
    local masterJson = table.concat(globalBuffer, "\n")
    local masterPath = "GBDump_All_Assemblies.json"
    
    local gSuccess, gErr = pcall(function()
        File.ExportFile(masterPath, masterJson)
    end)
    
    if gSuccess then
        Debug.Log(string.format("Successfully saved master dump: %s (%d chars)", masterPath, #masterJson))
    else
        Debug.LogError(string.format("Failed to save master dump %s: %s", masterPath, tostring(gErr)))
    end
end

function GBDumper.OnGUI() end
function GBDumper.Awake() end
function GBDumper.OnUnload() end
function GBDumper.FixedUpdate() end
function GBDumper.LateUpdate() end
function GBDumper.OnGUIOver() end

return GBDumper