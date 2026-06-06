local MainEntry = {}

function MainEntry.Update() end
function MainEntry.Start() end
function MainEntry.OnGUI() end
function MainEntry.Awake()
    Logger.Log("Hi", LogTypes.Log)
    NetworkManager.Send({"Hi"}, nil)
end
function MainEntry.OnUnload() end
function MainEntry.FixedUpdate() end
function MainEntry.LateUpdate() end
function MainEntry.OnGUIOver() end
function MainEntry.OnChatMessage(message, sender) end

return MainEntry