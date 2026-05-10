local ChatGUI = {}

ChatGUI.ifchatMessage = ""
function ChatGUI.Draw()
    ChatGUI.ifchatMessage = GUI.TextField(ChatGUI.ifchatMessage, 50, 100, 50, nil)
    if GUI.Button("Send", 100, 25, nil) then
        SendChatMessage()
    end
end

function SendChatMessage()
    NetworkManager.Send({Type = "chatMessage", Message = ChatGUI.ifchatMessage})
end

return ChatGUI