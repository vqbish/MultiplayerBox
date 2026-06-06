local FuckAnticheat = {}

using("System", true)

FuckAnticheat.sholLogs = false

FuckAnticheat.itgType = nil
FuckAnticheat.mwtType = nil
FuckAnticheat.fatalType = nil
FuckAnticheat.acBootType = nil
FuckAnticheat.acNativeType = nil

local function DebugLog(msg)
    if FuckAnticheat.sholLogs then
        Debug.Log("[AC] " .. msg) 
    end
end

local function FindAntiCheatTypes()
    FuckAnticheat.itgType = Assembler.FindType("ITGTCKR")
    FuckAnticheat.mwtType = Assembler.FindType("MWTCHDG")
    FuckAnticheat.fatalType = Assembler.FindType("FatalPopup")
    FuckAnticheat.acBootType = Assembler.FindType("ACBoot")
    FuckAnticheat.acNativeType = Assembler.FindType("ACNative")
    if FuckAnticheat.itgType then DebugLog("ITGTCKR type found") end
    if FuckAnticheat.mwtType then DebugLog("MWTCHDG type found") end
    if FuckAnticheat.fatalType then DebugLog("FatalPopup type found") end
    if FuckAnticheat.acBootType then DebugLog("ACBoot type found") end
    if FuckAnticheat.acNativeType then DebugLog("ACNative type found") end
end

local function DisableFatalPopup()
    if FuckAnticheat.fatalType then
        local failedField = FuckAnticheat.fatalType.CallMethod("GetField", "failed")
        if failedField then
            failedField:CallMethod("SetValue", nil, { true })
            DebugLog("FatalPopup.failed = true")
        end
    end
end

local function DestroyObject(obj)
    if obj then
        local unityObjectType = Assembler.FindType("UnityEngine.Object")
        if unityObjectType then
            local destroyMethod = unityObjectType:CallMethod("GetMethod", "Destroy", { Assembler.FindType("UnityEngine.Object") })
            if destroyMethod then
                destroyMethod:CallMethod("Invoke", nil, { obj })
                return true
            end
        end
        pcall(function() obj:CallMethod("Destroy") end)
        return true
    end
    return false
end

local function DestroyComponent(comp)
    if not comp then return false end
    local go = comp:CallMethod("get_gameObject")
    if go then
        return DestroyObject(go)
    end
    return false
end

local function DestroyAntiCheatComponents()
    -- ITGTCKR
    if FuckAnticheat.itgType then
        local instanceField = FuckAnticheat.itgType:CallMethod("GetField", "instance")
        if instanceField then
            local inst = instanceField:CallMethod("GetValue", nil, {})
            if inst then
                DestroyComponent(inst)
                instanceField:CallMethod("SetValue", nil, { nil })
            end
        end
        local all = GameObject.FindAllByComponent("ITGTCKR")
        if all then
            local len = #all
            for i = 0, len - 1 do
                local comp = all[i]
                if comp then DestroyComponent(comp) end
            end
        end
    end
    -- MWTCHDG
    if FuckAnticheat.mwtType then
        local instanceField = FuckAnticheat.mwtType:CallMethod("GetField", "instance")
        if instanceField then
            local inst = instanceField:CallMethod("GetValue", nil, {})
            if inst then
                DestroyComponent(inst)
                instanceField:CallMethod("SetValue", nil, { nil })
            end
        end
        local all = GameObject.FindAllByComponent("MWTCHDG")
        if all then
            local len = #all
            for i = 0, len - 1 do
                local comp = all[i]
                if comp then DestroyComponent(comp) end
            end
        end
    end
end

local function GetRealtime()
    local timeType = Assembler.FindType("UnityEngine.Time")
    if timeType then
        local prop = timeType:CallMethod("GetProperty", "realtimeSinceStartup")
        if prop then
            return prop:CallMethod("GetValue", nil, {})
        end
    end
    return 0
end

local function UpdateHeartbeat()
    if FuckAnticheat.itgType then
        local hbField = FuckAnticheat.itgType:CallMethod("GetField", "lastHeartbeatTime")
        if hbField then
            local future = GetRealtime() + 10000
            hbField:CallMethod("SetValue", nil, { future })
        end
    end
end

local function NeutralizeACBoot()
    if FuckAnticheat.acBootType then
        FuckAnticheat.acBootType.SetField("s_initialized", true)
        DebugLog("ACBoot.s_initialized set to true")
        FuckAnticheat.acBootType.SetField("s_keyCb", nil)
        DebugLog("ACBoot.s_keyCb nulled")
    end
    if FuckAnticheat.acNativeType then

    end
end

function FuckAnticheat.FullDisable()
    FindAntiCheatTypes()
    DisableFatalPopup()
    NeutralizeACBoot()
    DestroyAntiCheatComponents()
    UpdateHeartbeat()
end


FuckAnticheat.lastCleanup = 0
FuckAnticheat.cleanupInterval = 0
function FuckAnticheat.Update()
    local now = GetRealtime()
    if now - FuckAnticheat.lastCleanup >= FuckAnticheat.cleanupInterval then
        FuckAnticheat.lastCleanup = now
        if FuckAnticheat.itgType or FuckAnticheat.mwtType then
            DestroyAntiCheatComponents()
            UpdateHeartbeat()
        end
    end
end

return FuckAnticheat