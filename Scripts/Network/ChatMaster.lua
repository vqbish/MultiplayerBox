local ChatMaster = {}

function ChatMaster.OnChatMessage(message, sender)
    if message == "" then
        return
    end

    local data = {
        Type = "chatMessage",
        Message = Base64.encode(message, nil, false),
        SenderNickname = Base64.encode(sender.GetName(), nil, false)
    }
    NetworkManager.Send(data)

    Debug.Log("Original: " .. message .. ", encoded: " .. Base64.decode(data.Message) .. ", coded: " .. data.Message)
end

function ChatMaster.OnNetworkData(data)
    if basicModule.type(data) ~= "table" then
        return
    end

    local packetType = data.Type or data.type

    if packetType ~= "chatMessage" then
        return
    end

    if data.Message == nil then
        data.Message = "NULL"
    end
    if data.SenderNickname == nil then
        data.SenderNickname = "NULL"
    end

    local sender = Base64.decode(data.SenderNickname, nil, false)
    local message = Base64.decode(data.Message, nil, false)

    Debug.Log("Sender: " .. sender .. ", Message: " .. message)
    Server.SendChatMessage("<color=red>" .. sender .. "</color>: " .. message)
end
NetworkManager.AddOnGetListener(ChatMaster.OnNetworkData)

return ChatMaster