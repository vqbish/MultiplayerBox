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
    found = FindFilesWithName("Includes.lua", "MultiplayerBox-main/Scripts")
    if #found <= 0 then
        Debug.Log("Critical error in mod loading: includes not found")
        return
    end
end
Includes = File.DoFile(found[#found])

function Update()
    TickManager.Update()
    NetworkManager.Update()
end


function OnChatMessage(message, sender)
    ChatMaster.OnChatMessage(message, sender)
end