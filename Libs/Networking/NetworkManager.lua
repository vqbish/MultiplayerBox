local NetworkManager = {}

NetworkManager.PrefsKey = "Handshake"
NetworkManager.EmptyValue = "<NULLARGUMENTEXTEPTION>"
NetworkManager.Listeners = {}
NetworkManager.LastPrefs = nil

function NetworkManager.AddOnGetListener(func)
    if basicModule.type(func) ~= "function" then
        Logger.Log("Network listener must be a function", LogTypes.Warning)
        return
    end

    for _, listener in tableIterators.ipairs(NetworkManager.Listeners) do
        if listener == func then
            return
        end
    end

    table.insert(NetworkManager.Listeners, func)
end

function NetworkManager.RemoveOnGetListener(func)
    for i = #NetworkManager.Listeners, 1, -1 do
        if NetworkManager.Listeners[i] == func then
            table.remove(NetworkManager.Listeners, i)
        end
    end
end

function NetworkManager.Update()
    local currentPrefs = File.GetPlayerPrefsStr(NetworkManager.PrefsKey, NetworkManager.EmptyValue)

    if currentPrefs == NetworkManager.EmptyValue or currentPrefs == NetworkManager.LastPrefs then
        return
    end

    NetworkManager.LastPrefs = currentPrefs

    local status, packet = errorHandling.pcall(json.parse, currentPrefs)

    if not status or basicModule.type(packet) ~= "table" then
        Logger.Log("Network packet json parse failed. Message: " .. currentPrefs, LogTypes.Warning)
        return
    end
    Logger.Log(currentPrefs, LogTypes.Log)

    if packet.from == "MOD" then
        return
    end

    if basicModule.type(packet.data) ~= "table" then
        Logger.Log("Network packet data is empty", LogTypes.Warning)
        return
    end

    NetworkManager.OnGet(NetworkManager.DecodeData(packet.data), packet.Time)
end

function NetworkManager.OnGet(data, time)
    for i = 1, #NetworkManager.Listeners do
        local listener = NetworkManager.Listeners[i]
        local ok, err = errorHandling.pcall(listener, data, time)

        if not ok then
            Logger.Log("Network listener failed: " .. basicModule.tostring(err), LogTypes.Error)
        end
    end
end

function NetworkManager.Send(data)
    if basicModule.type(data) ~= "table" then
        Logger.Log("NetworkManager.Send expects table data", LogTypes.Warning)
        return
    end

    local packet = {
        Type = "POST",
        Time = basicModule.tostring(Time.GetRealTimeMs()),
        data = NetworkManager.EncodeData(data),
        from = "MOD"
    }

    File.SetPlayerPrefsStr(NetworkManager.PrefsKey, json.serialize(packet))
end

function NetworkManager.EncodeData(data)
    local encoded = {}

    for key, value in tableIterators.pairs(data) do
        encoded[basicModule.tostring(key)] = StringResolvers.TransferTypeToString(value)
    end

    return encoded
end

function NetworkManager.DecodeData(data)
    local decoded = {}

    for key, value in tableIterators.pairs(data) do
        decoded[key] = StringResolvers.TransferStringToType(value)
    end

    return decoded
end

return NetworkManager
