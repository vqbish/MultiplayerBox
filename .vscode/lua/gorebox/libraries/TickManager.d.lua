---@class TickManager
TickManager = {}

TickManager.CallBacks = {}
TickManager.CustomCallBacks = {}
TickManager.CurrentOwner = nil

TickManager.TickInterval = 1
TickManager.LastTime = Time.GetRealTimeMs()

local function GetCallbackFunc(entry)
    if basicModule.type(entry) == "function" then
        return entry
    end

    if basicModule.type(entry) == "table" then
        return entry.func
    end

    return nil
end

local function GetCallbackOwner(entry)
    if basicModule.type(entry) == "table" then
        return entry.owner
    end

    return nil
end

function TickManager.ExecuteWithOwner(owner, func)
    if basicModule.type(func) ~= "function" then
        Logger.Log("Owner scope target is not function!", LogTypes.Warning)
        return false
    end

    local previousOwner = TickManager.CurrentOwner
    TickManager.CurrentOwner = owner

    local ok, result = errorHandling.pcall(func)

    TickManager.CurrentOwner = previousOwner

    if not ok then
        Logger.Log("Owner scoped execution failed: " .. basicModule.tostring(result), LogTypes.Error)
        return false
    end

    return true
end

function TickManager.AddCallback(func)
    if basicModule.type(func) ~= "function" then
        Logger.Log("Callback target is not function!", LogTypes.Warning)
        return
    end

    for i = 1, #TickManager.CallBacks do
        local currentFunc = GetCallbackFunc(TickManager.CallBacks[i])
        if currentFunc == func then
            return
        end
    end

    table.insert(TickManager.CallBacks, {
        func = func,
        owner = TickManager.CurrentOwner
    })
end

function TickManager.AbortByOwner(owner)
    local removed = 0

    for i = #TickManager.CallBacks, 1, -1 do
        local entryOwner = GetCallbackOwner(TickManager.CallBacks[i])
        if entryOwner == owner then
            table.remove(TickManager.CallBacks, i)
            removed = removed + 1
        end
    end

    for i = #TickManager.CustomCallBacks, 1, -1 do
        local entryOwner = GetCallbackOwner(TickManager.CustomCallBacks[i])
        if entryOwner == owner then
            table.remove(TickManager.CustomCallBacks, i)
            removed = removed + 1
        end
    end

    return removed
end

function TickManager.AbortAllOwned()
    local removed = 0

    for i = #TickManager.CallBacks, 1, -1 do
        local entryOwner = GetCallbackOwner(TickManager.CallBacks[i])
        if entryOwner ~= nil then
            table.remove(TickManager.CallBacks, i)
            removed = removed + 1
        end
    end

    for i = #TickManager.CustomCallBacks, 1, -1 do
        local entryOwner = GetCallbackOwner(TickManager.CustomCallBacks[i])
        if entryOwner ~= nil then
            table.remove(TickManager.CustomCallBacks, i)
            removed = removed + 1
        end
    end

    return removed
end

function TickManager.RemoveCallback(func)
    if basicModule.type(func) ~= "function" then
        Logger.Log("Callback target is not function!", LogTypes.Warning)
        return
    end

    for i = #TickManager.CallBacks, 1, -1 do
        local currentFunc = GetCallbackFunc(TickManager.CallBacks[i])
        if currentFunc == func then
            table.remove(TickManager.CallBacks, i)
            return
        end
    end
end

function TickManager.AddCustomCallback(func, tps)
    if basicModule.type(func) ~= "function" then
        Logger.Log("Custom callback target is not function!", LogTypes.Warning)
        return
    end

    if basicModule.type(tps) ~= "number" or tps <= 0 then
        Logger.Log("TPS must be positive number!", LogTypes.Warning)
        return
    end

    for i = 1, #TickManager.CustomCallBacks do
        if TickManager.CustomCallBacks[i].func == func then
            return
        end
    end

    local intervalMs = (1 / tps) * 1000

    table.insert(TickManager.CustomCallBacks, {
        func = func,
        intervalMs = intervalMs,
        lastTime = Time.GetRealTimeMs(),
        owner = TickManager.CurrentOwner
    })
end

function TickManager.OnTick()
    for i = 1, #TickManager.CallBacks do
        local current = GetCallbackFunc(TickManager.CallBacks[i])

        if basicModule.type(current) == "function" then
            current()
        end
    end
end

function TickManager.Update()
    local CTime = Time.GetRealTimeMs()
    local intervalMs = (1 / TickManager.TickInterval) * 1000

    local mainTickCount = 0
    while CTime >= TickManager.LastTime + intervalMs and mainTickCount < 3 do
        TickManager.OnTick()
        TickManager.LastTime = TickManager.LastTime + intervalMs
        mainTickCount = mainTickCount + 1
    end

    if mainTickCount >= 3 and CTime >= TickManager.LastTime + intervalMs then
        TickManager.LastTime = CTime
    end

    for i = 1, #TickManager.CustomCallBacks do
        local data = TickManager.CustomCallBacks[i]

        local customTickCount = 0
        while CTime >= data.lastTime + data.intervalMs and customTickCount < 3 do
            data.func()
            data.lastTime = data.lastTime + data.intervalMs
            customTickCount = customTickCount + 1
        end

        if customTickCount >= 3 and CTime >= data.lastTime + data.intervalMs then
            data.lastTime = CTime
        end
    end
end


