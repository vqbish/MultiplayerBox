local Includes = {}

Includes.LibsPath = "/Libs"
Includes.FileSystemPath = Includes.LibsPath .. "/FileSystem"
FileSystemHelper = File.DoFile(File.GetModName() .. Includes.FileSystemPath .. "/FileSystemHelper.lua")

function Includes.Include(name)
    local lib = nil

    local files = FileSystemHelper.FindFilesWithName(name, File.GetModName())

    if #files > 0 then
        Debug.Log("Found libs with name '" .. name .. "': " .. #files)
        local path = files[1]
        if path ~= nil then
            lib = File.DoFile(path)
            if lib ~= nil then
                Debug.Log("Loaded: " .. path)
            end
        end
    end

    return lib
end

Logger = Includes.Include("Logger.lua")
LogTypes = Includes.Include("LogTypes.lua")
StringResolvers = Includes.Include("StringResolvers.lua")
NetworkManager = Includes.Include("NetworkManager.lua")
TickManager = Includes.Include("TickManager.lua")
TableHelpers = Includes.Include("TableHelpers.lua")
ChatGUI = Includes.Include("ChatGUI.lua")
ChatMaster = Includes.Include("ChatMaster.lua")

return Includes