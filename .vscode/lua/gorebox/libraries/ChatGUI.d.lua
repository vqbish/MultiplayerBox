---@class ChatGUI
ChatGUI = {}

ChatGUI.Input = ""
ChatGUI.Messages = {}
ChatGUI.MaxMessages = 8
ChatGUI.IsBound = false

function ChatGUI.BindNetwork()
    if ChatGUI.IsBound then
        return
    end

    NetworkManager.AddOnGetListener(ChatGUI.OnNetworkData)
    ChatGUI.IsBound = true
end

function ChatGUI.Draw()
    GUI.Label("MultiplayerBox Chat", 260, 24, nil)

    local firstMessage = math.max(1, #ChatGUI.Messages - ChatGUI.MaxMessages + 1)

    for i = firstMessage, #ChatGUI.Messages do
        GUI.Label(ChatGUI.Messages[i], 420, 22, nil)
    end

    ChatGUI.Input = GUI.TextField(ChatGUI.Input, 120, 280, 26, nil)

    if GUI.Button("Send", 70, 26, nil) then
        ChatGUI.SendMessage()
    end
end

function ChatGUI.SendMessage()
    local message = ChatGUI.Trim(ChatGUI.Input)

    if message == "" then
        return
    end

    NetworkManager.Send({
        Type = "chatMessage",
        Message = message
    })

    ChatGUI.AddMessage("You", message)
    ChatGUI.Input = ""
end

function ChatGUI.OnNetworkData(data)
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

    ChatGUI.AddMessage(sender, message)
end

function ChatGUI.AddMessage(sender, message)
    local line = basicModule.tostring(sender) .. ": " .. basicModule.tostring(message)
    table.insert(ChatGUI.Messages, line)

    while #ChatGUI.Messages > ChatGUI.MaxMessages do
        table.remove(ChatGUI.Messages, 1)
    end
end

function ChatGUI.Trim(value)
    if basicModule.type(value) ~= "string" then
        return ""
    end

    return string.gsub(value, "^%s*(.-)%s*$", "%1")
end


