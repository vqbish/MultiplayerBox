Debug.Log("DependenciesLib Init. Trying to load other modules...")
Includes = File.DoFile(File.GetModName() .. "/Scripts/Includes.lua")
Debug.Log("Includes.lua loaded.")

function IsValid(obj)
    if obj == nil then return false end

    local strObj = basicModule.tostring(obj)
    if string.find(strObj, "Component", 1, true) then
        return true
    end

    return obj.IsValid == nil or obj.IsValid()
end

CurrentConfigId = File.GetPlayerPrefsVal("CurrentConfigId", 1)
LoadInventoryOnSpawn = false

function SelectConfig(cfgName)
    local path = File.GetModName() .. "/Configs"
    local ConfigPaths = FileSystemHelper.GetFilesByExtension(".json", path, false)
    
    if #ConfigPaths == 0 then
        Logger.Log("No configs found in /Configs folder!", LogTypes.Warning)
        return
    end

    local found = false
    for i = 1, #ConfigPaths do
        if string.find(ConfigPaths[i], cfgName, 1, true) then
            CurrentConfigId = i
            File.SetPlayerPrefsVal("CurrentConfigId", CurrentConfigId)
            found = true
            break
        end
    end

    if found then
        LoadInventory()
    else
        Logger.Log("Config with name '" .. cfgName .. "' not found!", LogTypes.Error)
    end
end

function LoadInventory()
    if not IsValid(PlayerMaster) then return end

    local path = File.GetModName() .. "/Configs"
    local ConfigPaths = FileSystemHelper.GetFilesByExtension(".json", path, false)
    
    if #ConfigPaths == 0 then return end

    CurrentConfigId = ((CurrentConfigId - 1) % #ConfigPaths) + 1
    File.SetPlayerPrefsVal("CurrentConfigId", CurrentConfigId)
    
    local content = File.ImportFile(ConfigPaths[CurrentConfigId])
    local data = json.parse(content)

    if not data or not data.weapons then 
        Logger.Log("Cfg invalid!", LogTypes.Warning) 
        return 
    end

    LoadInventoryOnSpawn = data.loadOnSpawn or false

    local _hasCam, _ = GetPlayerCamera()
    if _hasCam then
        PlayerMaster.ClearWeapons()
        for _, w in tableIterators.ipairs(data.weapons) do
            local name = w.name or "Unknown"
            local ammo = w.currentAmmo or 0
            local r = w.color_r or 0
            local g = w.color_g or 0
            local b = w.color_b or 0
            local mag = w.extraMag or 0
            local skin = w.skin or 0
            local scope = w.scope or 0
            local barrel = w.barrel or 0
            local shield = w.shield or false

            PlayerMaster.GiveWeapon(name, ammo, Vector3.New(r, g, b), mag, skin, scope, barrel, shield)
        end
    end
end

function ExportInventory(saveName)
    local _hasWS, WS = GetPlayerWeaponSwitcher()
    if not _hasWS then return end

    local Recoil = WS.GameObject.GetComponentInChildren("RecoilEffect")
    if not IsValid(Recoil) or not IsValid(Recoil.GameObject.Transform) then return end

    local collected = {}
    local tr = Recoil.GameObject.Transform
    for i = 0, tr.ChildCount - 1 do
        local child = tr.GetChild(i)
        if IsValid(child) and IsValid(child.GameObject) then
            table.insert(collected, CollectWeaponInfo(child.GameObject))
        end
    end

    File.ExportFile("Configs/" .. saveName, json.serialize({ weapons = collected, loadOnSpawn = false}))
end

function CollectWeaponInfo(WeaponGO)
    if WeaponGO == nil or not WeaponGO.IsValid() then
        return
    end

    local info = {
        name = "",
        currentAmmo = 0,
        color_r = 0,
        color_g = 0,
        color_b = 0,
        extraMag = 0,
        skin = 0,
        scope = 0,
        barrel = 0,
        shield = false
    }

    local WeaponComp = WeaponGO.GetComponent("GBWeapon")

    info.name = WeaponGO.Name or ""
    if WeaponComp ~= nil then
        info.name = WeaponGO.Name or ""
        info.currentAmmo = WeaponComp.GetField("MagSize") or 0 --WeaponComp.GetField("AmmoLeft") or 0
        local weaponColor = Vector3.New(0,0,0) --WeaponComp.GetField() or Vector3.New(0,0,0)
        info.color_r = weaponColor.x
        info.color_g = weaponColor.y
        info.color_b = weaponColor.z
        info.extraMag = 0 --WeaponComp.GetField("") or 0
        info.skin = WeaponComp.GetField("skin") or 0
        info.scope = 0 --WeaponComp.GetField("") or 0
        info.barrel = 0 --WeaponComp.GetField("") or 0
        info.shield = false --WeaponComp.GetField("") or false
    end

    return info
end

function GetPlayerCamera() return GetPlayerComponentField("PlayerMaster", "cam") end
function GetPlayerWeaponSwitcher() return GetPlayerComponentField("PlayerMaster", "WS") end

function GetPlayerComponent(compName)
    local player = Player.GetLocal()
    if not IsValid(player) then return nil end
    
    local tr = Transform.GetPlayer(player)
    if not IsValid(tr) or not IsValid(tr.GameObject) then return nil end
    
    return tr.GameObject.GetComponent(compName)
end

function GetPlayerComponentField(componentName, fieldName, targetPlayer)
    local player = targetPlayer or Player.GetLocal()
    if player == nil then return false, nil end
    local playerTransform = Transform.GetPlayer(player)
    if not IsValid(playerTransform) then return false, nil end
    local playerGO = playerTransform.GameObject
    if not IsValid(playerGO) then return false, nil end
    local component = playerGO.GetComponent(componentName)
    if not IsValid(component) then return false, nil end
    local value = component.GetField(fieldName)
    return value ~= nil, value
end

local ChatCommands = {}

function AddChatCommand(commandName, callback)
    ChatCommands[commandName] = callback
end

function OnChatMessage(message, sender)
    if string.sub(message, 1, 1) ~= "?" then return end

    local spacePos = string.find(message, " ")
    local cmd, args
    
    if spacePos then
        cmd = string.sub(message, 2, spacePos - 1)
        args = string.sub(message, spacePos + 1)
    else
        cmd = string.sub(message, 2)
        args = ""
    end

    if ChatCommands[cmd] then
        ChatCommands[cmd](args, sender)
    end
end

AddChatCommand("save", function(args, sender)
    if args == "" or args == " " then 
        Debug.Log("Usage: ?save [name]")
        return 
    end
    
    ExportInventory(args .. ".json")
    Debug.Log("Inventory saved as: " .. args)
end)

AddChatCommand("load", function(args, sender)
    if args == "" then
        Debug.Log("Usage: ?load [name]")
        return
    end
    
    SelectConfig(args .. ".json")
end)

function OnLocalSpawned()
    if LoadInventoryOnSpawn then
        LoadInventory() 
    end
end