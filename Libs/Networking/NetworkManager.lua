local NetworkManager = {}

NetworkManager.PrefsKey = "Handshake"
NetworkManager.Listeners = {}
NetworkManager.prevprefs =  nil

function NetworkManager.AddOnGetListener(func)
    if basicModule.type(func) ~= "function" then
        Debug.Log("NetworkManager: Попытка добавить слушателя, который не является функцией!")
        return
    end
    
    for _, listener in tableIterators.ipairs(NetworkManager.Listeners) do
        if listener == func then return end
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
    local curprefs = File.GetPlayerPrefsStr(NetworkManager.PrefsKey, "<NULLARGUMENTEXTEPTION>")
    
    if curprefs ~= "<NULLARGUMENTEXTEPTION>" and curprefs ~= NetworkManager.prevprefs then
        NetworkManager.prevprefs = curprefs
        local status, tableData = errorHandling.pcall(json.parse, NetworkManager.prevprefs)
        
        if not status then
            Debug.Log("NetworkManager: Ошибка парсинга JSON")
            return
        end

        local argsraw = tableData.data
        local getTime = tableData.Time
        local args = {}
        local counter = 0

        for i, data in tableIterators.pairs(argsraw) do
            counter = counter + 1
            data = string.gsub(data, '"', "")
            args[counter] = StringResolvers.TransferStringToType(data)
        end

        NetworkManager.OnGet(args, getTime)
    end
end

function NetworkManager.OnGet(args, getTime)
    Debug.Log("get " .. #args .. " objs at " .. getTime)
    
    for i = 1, #NetworkManager.Listeners do
        local listener = NetworkManager.Listeners[i]
        local ok, err = errorHandling.pcall(listener, args, getTime)
        if not ok then
            Debug.Log("NetworkManager: Ошибка в слушателе: " .. basicModule.tostring(err))
        end
    end
end

function NetworkManager.Send(args)
    local argsforjson = {}
    for i, data in tableIterators.pairs(args) do
        argsforjson["args" .. i - 1] = basicModule.tostring(data)
    end

    local newTable = {
        Type = "POST",
        Time = basicModule.tostring(Time.GetRealTimeMs()),
        data = argsforjson
    }

    local resultJson = json.serialize(newTable)
    Debug.Log("post " .. resultJson)
    File.SetPlayerPrefsStr(NetworkManager.PrefsKey, resultJson)
end

return NetworkManager