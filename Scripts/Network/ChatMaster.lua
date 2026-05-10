local ChatMaster = {}

function ChatMaster.OnChatMessage(message, sender)
    local message = ChatGUI.Trim(message)

    if message == "" then
        return
    end

    NetworkManager.Send({
        Type = "chatMessage",
        Message = message
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

    local sender = data.Sender or data.sender or "Peer"
    local message = data.Message or data.message or ""

    Server.SendChatMessage("<color=red>" .. sender .. "</color>: " .. message)
end
NetworkManager.AddOnGetListener(ChatMaster.OnNetworkData)

return ChatMaster