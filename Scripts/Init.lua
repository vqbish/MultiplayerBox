
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
Debug.Log(File.GetModName() .. " Init. Trying to load other modules...")
local found = FindFilesWithName("Includes.lua", File.GetModName() .. "/Scripts")
if #found <= 0 then
    Debug.Log("Critical error in mod loading: includes not found")
end
Includes = File.DoFile(found[#found])
Debug.Log("Includes.lua loaded.")

function Update()
    TickManager.Update()
    NetworkManager.Update()
end

function OnGet(args, time)
    Logger.Log("Args: " .. json.serialize(args) .. " Time: " .. basicModule.tostring(time))
end
NetworkManager.AddOnGetListener(OnGet)