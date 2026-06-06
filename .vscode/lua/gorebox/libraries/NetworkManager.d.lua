---@class NetworkManager
NetworkManager = {}

NetworkManager.Listeners = {}

local handlersRegistered = false

local function RegisterWebHandlers()
    if handlersRegistered then return end

    local function OnPostHandler(path, body)
        if path ~= NetworkManager.Endpoint then return end
        if not body or body == "" then return end

        local ok, packet = pcall(json.parse, body)
        if not ok or type(packet) ~= "table" then
            Debug.Log("[NetworkManager] Failed to parse incoming POST body")
            return
        end

        if packet.from == NetworkManager.FromId then
            return
        end

        if type(packet.data) ~= "table" then
            return
        end

        for _, listener in ipairs(NetworkManager.Listeners) do
            local ok, err = pcall(listener, packet.data, packet.time or 0)
            if not ok then
                Debug.Log("[NetworkManager] Listener error: " .. tostring(err))
            end
        end
    end

    local function OnGetHandler(path)
        if path == "ping" then
        end
    end

    WebManager.OnPost:AddListener(OnPostHandler)
    WebManager.OnGet:AddListener(OnGetHandler)

    handlersRegistered = true
    Debug.Log("[NetworkManager] Web handlers registered")
end

function NetworkManager.AddListener(callback)
    if type(callback) ~= "function" then
        Debug.Log("[NetworkManager] Callback must be a function")
        return
    end

    for _, existing in ipairs(NetworkManager.Listeners) do
        if existing == callback then
            return
        end
    end

    table.insert(NetworkManager.Listeners, callback)
    Debug.Log("[NetworkManager] Listener added, total: " .. #NetworkManager.Listeners)
end

function NetworkManager.RemoveListener(callback)
    for i = #NetworkManager.Listeners, 1, -1 do
        if NetworkManager.Listeners[i] == callback then
            table.remove(NetworkManager.Listeners, i)
        end
    end
end


function NetworkManager.Send(data, callback)
    if type(data) ~= "table" then
        Debug.Log("[NetworkManager] Send expects a table")
        return
    end

    local packet = {
        from = NetworkManager.FromId,
        time = tostring(Time.GetRealTimeMs()),
        data = data
    }

    local jsonStr = json.serialize(packet)
    local fullUrl = NetworkManager.ServerUrl .. NetworkManager.Endpoint

    if callback then
        local function successHandler(path, response)
            if path == NetworkManager.Endpoint then
                callback(true, response)
                WebManager.OnRequestSuccess:RemoveListener(successHandler)
                WebManager.OnRequestError:RemoveListener(errorHandler)
            end
        end
        local function errorHandler(err)
            callback(false, err)
            WebManager.OnRequestSuccess:RemoveListener(successHandler)
            WebManager.OnRequestError:RemoveListener(errorHandler)
        end
        WebManager.OnRequestSuccess:AddListener(successHandler)
        WebManager.OnRequestError:AddListener(errorHandler)
    end

    WebManager.SendPost(NetworkManager.Endpoint, jsonStr, "application/json", fullUrl, 5000)
    Debug.Log("[NetworkManager] Data sent: " .. jsonStr)
end

function NetworkManager.Init()
    RegisterWebHandlers()
    Debug.Log("[NetworkManager] Initialized with localWeb transport")
end

function NetworkManager.Shutdown()
    handlersRegistered = false
    NetworkManager.Listeners = {}
    Debug.Log("[NetworkManager] Shutdown")
end

