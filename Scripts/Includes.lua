local Includes = {}
setmetatable = metaTable.setmetatable
type = basicModule.type
error = Debug.LogError
tostring = basicModule.tostring
ipairs = tableIterators.ipairs
pcall = errorHandling.pcall
select = basicModule.select
pairs = tableIterators.pairs
next = tableIterators.next

Includes.LibsPath = "/Libs"
Includes.FileSystemPath = Includes.LibsPath .. "/FileSystem"

function Includes.GetLastFolderName(path)
    if not path or path == "" then return "" end
    path = string.gsub(path, "[/\\]+$", "")
    local lastFolderName = string.match(path, "[^/\\]+$")
    return lastFolderName or ""
end

function Includes.GetModFolderName()
    return Includes.GetLastFolderName(File.GetModRoot())
end

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
    else
        Debug.Log("Includes failed: files with name " .. name .. " not found!")
    end

    return lib
end

function Includes.IncludeFolder(folderName)
    local loadedLibs = {}
    local targetFolder = File.GetModName() .. folderName
    
    local files = FileSystemHelper.GetAllFiles(targetFolder, false)
    
    if files and #files > 0 then
        Debug.Log("Found " .. #files .. " files in folder: " .. targetFolder)
        for _, path in ipairs(files) do
            if path ~= nil then
                local lib = File.DoFile(path)
                if lib ~= nil then
                    Debug.Log("Loaded from folder: " .. path)
                    table.insert(loadedLibs, lib)
                end
            end
        end
    else
        Debug.Log("IncludeFolder failed: No files found or folder empty at " .. targetFolder)
    end
    
    return loadedLibs
end

Base64 = Includes.Include("base64.lua")
Logger = Includes.Include("Logger.lua")
LogTypes = Includes.Include("LogTypes.lua")
StringResolvers = Includes.Include("StringResolvers.lua")
TickManager = Includes.Include("TickManager.lua")
TableHelpers = Includes.Include("TableHelpers.lua")
Assembler = Includes.Include("Assembler.lua")
ObjectWrapper = Includes.Include("ObjectWrapper.lua")
using = Includes.Include("using.lua")
FuckAnticheat = Includes.Include("FuckAnticheat.lua")
GBDumper = Includes.Include("GBDumper.lua")

LuaGUI = Includes.IncludeFolder("/Libs/Classes/GUI/Samples")
LuaGUI.FontStealer = Includes.Include("FontStealer.lua")
LuaGUI.GUITool = Includes.Include("GUITool.lua")

NetworkManager = Includes.Include("NetworkManager.lua")
ChatGUI = Includes.Include("ChatGUI.lua")
ChatMaster = Includes.Include("ChatMaster.lua")

return Includes