function FindFilesWithName(targetName, relPath)
    local foundFiles = {}

    local function searchInDirectory(path)
        local files = File.GetAllFiles(path)

        for i = 0, #files do
            local fileName = files[i]

            if fileName then
                local fullPath = (path == "" or path == nil) and fileName or (path .. "/" .. fileName)

                if string.find(fullPath, targetName, 1, true) then
                    table.insert(foundFiles, fullPath)
                end
            end
        end

        local folders = File.GetAllFolders(path)

        for i = 0, #folders do
            local folderName = folders[i]

            if folderName and folderName ~= "" then
                local nextPath = (path == "" or path == nil) and folderName or (path .. "/" .. folderName)
                searchInDirectory(nextPath)
            end
        end
    end

    searchInDirectory(relPath)
    return foundFiles
end

local loggerPrefix = File.GetModName()
Debug.Log(loggerPrefix .. " Init")

local found = FindFilesWithName("Includes.lua", File.GetModName() .. "/Scripts")

if #found <= 0 then
    Debug.Log("Critical error in mod loading: includes not found")
    return
end

Includes = File.DoFile(found[#found])
--ChatGUI.BindNetwork()

function Update()
    TickManager.Update()
    NetworkManager.Update()
end

function OnGUIOver()
    --ChatGUI.Draw()
end

function OnChatMessage(message, sender)
    local message = ChatGUI.Trim(message)

    if message == "" then
        return
    end

    NetworkManager.Send({
        Type = "chatMessage",
        Message = message
    })
end

function OnNetworkData(data)
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
NetworkManager.AddOnGetListener(OnNetworkData)