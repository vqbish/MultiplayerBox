---@class Logger
Logger = {}

function Logger.Log(message, LogType)
    if(basicModule.type(message) ~= "string") then
        message = basicModule.tostring(message)
    end
    local LoggerName = string.upper(File.GetModName())
    
    local logColorPrefix = "white"
    if LogType == "Warning" then
        logColorPrefix = "yellow"
    elseif LogType == "Error" then
        logColorPrefix = "red"
    end
    Debug.Log("<color=" .. logColorPrefix .. ">" ..  "[".. LoggerName .."]" .. message .."</color>")
end

