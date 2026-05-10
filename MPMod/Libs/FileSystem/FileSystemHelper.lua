local FileSystemHelper = {}

function FileSystemHelper.LogRootModsFolders()
    local RootFolders = File.GetAllFolders("")

    local final = "======FOLDERS======\n"
    for i = 0, #RootFolders, 1 do
        local current = RootFolders[i]
        if current ~= nil then
            final = final .. current .. "\n"
        end
    end
    final = final .. "====END FOLDERS===="

    Debug.Log(final)
end

function FileSystemHelper.FindFilesWithName(targetName, relPath)
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

function FileSystemHelper.GetAllFiles(relPath, recursive)
    local foundFiles = {}

    local function search(path)
        local files = File.GetAllFiles(path)
        for i = 0, #files do
            local fileName = files[i]
            if fileName then
                local fullPath = (path == "" or path == nil) and fileName or (path .. "/" .. fileName)
                table.insert(foundFiles, fullPath)
            end
        end

        if recursive then
            local folders = File.GetAllFolders(path)
            for i = 0, #folders do
                local folderName = folders[i]
                if folderName and folderName ~= "" then
                    local nextPath = (path == "" or path == nil) and folderName or (path .. "/" .. folderName)
                    search(nextPath)
                end
            end
        end
    end

    search(relPath)
    return foundFiles
end

function FileSystemHelper.GetFilesByExtension(extension, relPath, recursive)
    local foundFiles = {}

    local function search(path)
        local files = File.GetAllFiles(path)
        for i = 0, #files do
            local fileName = files[i]
            if fileName then
                if string.sub(fileName, -#extension) == extension then
                    local fullPath = (path == "" or path == nil) and fileName or (path .. "/" .. fileName)
                    table.insert(foundFiles, fullPath)
                end
            end
        end

        if recursive then
            local folders = File.GetAllFolders(path)
            for i = 0, #folders do
                local folderName = folders[i]
                if folderName and folderName ~= "" then
                    local nextPath = (path == "" or path == nil) and folderName or (path .. "/" .. folderName)
                    search(nextPath)
                end
            end
        end
    end

    search(relPath)
    return foundFiles
end

Debug.Log("FileSystemHelper loaded")

return FileSystemHelper