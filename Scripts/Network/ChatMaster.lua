local ChatMaster = {}

function ChatMaster.OnChatMessage(message, sender)
    if message == "" then
        return
    end

    NetworkManager.Send({
        Type = "chatMessage",
        Message = Base64.encode(message, nil, false),
        SenderNickname = Base64.encode(sender.GetName(), nil, false)
    })
end

function ChatMaster.OnNetworkData(data)
    if basicModule.type(data) ~= "table" then
        return
    end
    Logger.Log("message: " .. json.serialize(data))

    local packetType = data.Type or data.type

    if packetType ~= "chatMessage" then
        return
    end

    local sender = Base64.decode(data.SenderNickname, nil, false)
    local message = Base64.decode(data.Message, nil, false)

    Server.SendChatMessage("<color=red>" .. sender .. "</color>: " .. message)
end
NetworkManager.AddOnGetListener(ChatMaster.OnNetworkData)

return ChatMaster