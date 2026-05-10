---@class Mod
Mod = {}

function Mod.New()
    local ModInfo = {}

    ModInfo.name = "NULL"
    ModInfo.description = "NULL"
    ModInfo.mainScript = "main.lua"
    ModInfo.version = "0.0.0"
    ModInfo.active = false
    ModInfo.unloadOnError = false
    ModInfo.safeMode = false
    ModInfo.isPlugin = false
    ModInfo.InfoPath = ""
    ModInfo.ReqFile = ""

    function ModInfo.GetRootPath()
        local root = string.match(ModInfo.InfoPath, "(.*)/.-$")
        return root or ""
    end

    function ModInfo.GetCanLoadMod()
        local allLoadedMods = Mod.GetAllMods()
        if ModInfo.ReqFile == "" then return true end

        local reqContent = File.ImportFile(ModInfo.ReqFile)
        if reqContent == "" then return true end

        local reqData = json.parse(reqContent)
        if not reqData or not reqData.req then return true end

        for reqModName, requirements in tableIterators.pairs(reqData.req) do
            local found = false
            
            for _, loadedMod in tableIterators.ipairs(allLoadedMods) do
                if loadedMod.name == reqModName then
                    found = true
                    
                    if requirements.version and loadedMod.version < requirements.version then
                        Logger.Log("Mod " .. ModInfo.name .. " requires " .. reqModName .. " v" .. requirements.version, LogTypes.Warning)
                        return false
                    end

                    if requirements.active ~= nil and loadedMod.active ~= requirements.active then
                        return false
                    end
                    
                    break
                end
            end

            if not found then
                Logger.Log("Dependency not found for " .. ModInfo.name .. ": " .. reqModName, LogTypes.Error)
                return false
            end
        end

        return true
    end

    function ModInfo.GetInfoString()
        local status = ModInfo.active and "[ACTIVE]" or "[DISABLED]"
        local typeMod = ModInfo.isPlugin and "Plugin" or "Mod"

        local final = "\n" .. "========== " .. ModInfo.name .. " ==========" .. "\n"
        final = final .. "Status: " .. status .. "\n"
        final = final .. "Version: " .. ModInfo.version .. "\n"
        final = final .. "Type: " .. typeMod .. "\n"
        final = final .. "Description: " .. ModInfo.description .. "\n"
        final = final .. "Main Script: " .. ModInfo.mainScript .. "\n"
        final = final .. "Root Path: " .. ModInfo.GetRootPath() .. "\n"
        final = final .. "Safe Mode: " .. basicModule.tostring(ModInfo.safeMode) .. "\n"
        final = final .. "================================="

        return final
    end

    return ModInfo
end

function Mod.LoadFromJson(pathToJson)
    local ModInfo = Mod.New()
    
    if basicModule.type(pathToJson) ~= "string" then
        Logger.Log("Path to mod is not string!", LogTypes.Error)
        return ModInfo
    end

    local fileContent = File.ImportFile(pathToJson)
    if fileContent == "" then
        return ModInfo
    end
    
    local decodedJson = json.parse(fileContent)

    ModInfo.name = decodedJson.name or "Unknown"
    ModInfo.description = decodedJson.description or ""
    ModInfo.mainScript = decodedJson.mainScript or "main.lua"
    ModInfo.version = decodedJson.version or "1.0.0"
    ModInfo.active = decodedJson.active or false
    ModInfo.unloadOnError = decodedJson.unloadOnError or false
    ModInfo.safeMode = decodedJson.safeMode or false
    ModInfo.isPlugin = decodedJson.isPlugin or false
    ModInfo.InfoPath = pathToJson

    local reqPath = ModInfo.GetRootPath() .. "/req.json"
    if File.ImportFile(reqPath) ~= nil then
        ModInfo.ReqFile = reqPath
    end

    return ModInfo
end

function Mod.GetAllMods()
    local Mods = {}
    local found = FileSystemHelper.FindFilesWithName("info.json")
    
    for i = 1, #found do 
        local currentPath = found[i]
        if currentPath then
            table.insert(Mods, Mod.LoadFromJson(currentPath))
        end
    end

    return Mods
end

