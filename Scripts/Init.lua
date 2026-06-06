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
local function GetLastFolderName(path)
    if not path or path == "" then return "" end
    path = string.gsub(path, "[/\\]+$", "")
    local lastFolderName = string.match(path, "[^/\\]+$")
    return lastFolderName or ""
end
local function GetModFolderName()
    return GetLastFolderName(File.GetModRoot())
end
local found = FindFilesWithName("Includes.lua", GetModFolderName() .. "/Scripts")
if #found <= 0 then
    Debug.Log("Critical error in mod loading. includes not found")
end
Debug.Log("Found Includes.lua")
Includes = File.DoFile(found[#found])
MainEntry = File.DoFile(FindFilesWithName("MainEntry.lua", GetModFolderName() .. "/Scripts")[1])
function Awake() MainEntry.Awake() end
function OnUnload() MainEntry.OnUnload() end
function FixedUpdate() MainEntry.FixedUpdate() end
function OnGUI() MainEntry.OnGUI() end
function OnGUIOver() MainEntry.OnGUIOver() end
function Start()
    MainEntry.Start()
end
function Update()
    MainEntry.Update()
    GBDumper.Update()
    TickManager.Update()
end
function LateUpdate()
    MainEntry.LateUpdate()
end

function OnChatMessage(message, sender)
    MainEntry.OnChatMessage(message, sender)
    ChatMaster.OnChatMessage(message, sender)
end