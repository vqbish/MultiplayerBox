local GUI_Foldout = {}

local function SetGameObjectActive(targetGO, isActive)
    if targetGO == nil then
        return
    end

    targetGO.Active = isActive
end

local function ResolveElementGO(element)
    if element == nil then
        return nil
    end

    if basicModule.type(element) ~= "table" then
        return element
    end

    if element.foldoutGO ~= nil then
        return element.foldoutGO
    end

    if element.buttonGO ~= nil then
        return element.buttonGO
    end

    if element.panelGO ~= nil then
        return element.panelGO
    end

    if element.textGO ~= nil then
        return element.textGO
    end

    if element.toggleGO ~= nil then
        return element.toggleGO
    end

    if element.sliderGO ~= nil then
        return element.sliderGO
    end

    if element.inputGO ~= nil then
        return element.inputGO
    end

    if element.imageGO ~= nil then
        return element.imageGO
    end

    if element.scrollGO ~= nil then
        return element.scrollGO
    end

    if element.contentGO ~= nil then
        return element.contentGO
    end

    if element.canvasGO ~= nil then
        return element.canvasGO
    end

    return element
end

function GUI_Foldout.New()
    local Foldout = {}

    Foldout.foldoutGO = nil
    Foldout.foldoutRect = nil
    Foldout.layoutElement = nil
    Foldout.headerButton = nil
    Foldout.itemsContainerGO = nil
    Foldout.itemsContainerRect = nil
    Foldout.itemsContainerLayoutElement = nil
    Foldout.itemsLayoutGroup = nil
    Foldout.itemsSizeFitter = nil

    Foldout.title = "Foldout"
    Foldout.expanded = false
    Foldout.headerHeight = 38
    Foldout.itemSpacing = 0
    Foldout.children = {}
    Foldout.sizeChangedListeners = {}

    local function NotifySizeChanged(totalHeight)
        for i = 1, #Foldout.sizeChangedListeners do
            local listener = Foldout.sizeChangedListeners[i]
            if basicModule.type(listener) == "function" then
                listener(totalHeight)
            end
        end
    end

    local function ApplyHeaderTitle()
        if Foldout.headerButton == nil or Foldout.headerButton.label == nil or Foldout.headerButton.label.textComp == nil then
            return
        end

        local prefix = "► "
        if Foldout.expanded then
            prefix = "▼ "
        end

        Foldout.headerButton.label.textComp.SetField("text", prefix .. basicModule.tostring(Foldout.title))
    end

    local function ResolveChildHeight(entry)
        if entry == nil then
            return 0
        end

        if entry.height ~= nil then
            return entry.height
        end

        if entry.rect ~= nil then
            local size = entry.rect.GetField("sizeDelta")
            if size ~= nil then
                return size.y
            end
        end

        return 0
    end

    function Foldout.RefreshSize()
        local itemsHeight = 0

        if Foldout.expanded then
            for i = 1, #Foldout.children do
                itemsHeight = itemsHeight + ResolveChildHeight(Foldout.children[i])
            end

            if #Foldout.children > 1 then
                itemsHeight = itemsHeight + Foldout.itemSpacing * (#Foldout.children - 1)
            end
        end

        if Foldout.itemsContainerLayoutElement ~= nil then
            Foldout.itemsContainerLayoutElement.SetField("preferredHeight", itemsHeight)
            Foldout.itemsContainerLayoutElement.SetField("minHeight", itemsHeight)
            Foldout.itemsContainerLayoutElement.SetField("flexibleHeight", 0)
        end

        local totalHeight = Foldout.headerHeight + itemsHeight

        if Foldout.layoutElement ~= nil then
            Foldout.layoutElement.SetField("preferredHeight", totalHeight)
            Foldout.layoutElement.SetField("minHeight", totalHeight)
            Foldout.layoutElement.SetField("flexibleHeight", 0)
        end

        if Foldout.foldoutRect ~= nil then
            local currentSize = Foldout.foldoutRect.GetField("sizeDelta")
            local currentWidth = 0
            if currentSize ~= nil then
                currentWidth = currentSize.x
            end
            Foldout.foldoutRect.SetField("sizeDelta", Vector2.New(currentWidth, totalHeight))
        end

        NotifySizeChanged(totalHeight)
    end

    function Foldout.RegisterSizeChangedListener(listener)
        if basicModule.type(listener) ~= "function" then
            return false
        end

        for i = 1, #Foldout.sizeChangedListeners do
            if Foldout.sizeChangedListeners[i] == listener then
                return false
            end
        end

        Foldout.sizeChangedListeners[#Foldout.sizeChangedListeners + 1] = listener
        return true
    end

    function Foldout.UnregisterSizeChangedListener(listener)
        for i = 1, #Foldout.sizeChangedListeners do
            if Foldout.sizeChangedListeners[i] == listener then
                table.remove(Foldout.sizeChangedListeners, i)
                return true
            end
        end

        return false
    end

    function Foldout.SetTitle(value)
        Foldout.title = value
        ApplyHeaderTitle()
    end

    function Foldout.SetExpanded(isExpanded)
        Foldout.expanded = isExpanded

        for i = 1, #Foldout.children do
            local entry = Foldout.children[i]
            SetGameObjectActive(entry.go, Foldout.expanded)
        end

        ApplyHeaderTitle()
        Foldout.RefreshSize()
    end

    function Foldout.Toggle()
        Foldout.SetExpanded(not Foldout.expanded)
    end

    function Foldout.AddElement(element, options)
        options = options or {}

        local targetGO = ResolveElementGO(element)
        if targetGO == nil then
            return nil
        end

        if Foldout.itemsContainerGO ~= nil and Foldout.itemsContainerGO.Transform ~= nil and targetGO.Transform ~= nil and options.keepParent ~= true then
            targetGO.Transform.SetParent(Foldout.itemsContainerGO.Transform)
        end

        local targetRect = nil
        if targetGO.GetComponent ~= nil then
            targetRect = targetGO.GetComponent("RectTransform")
        end

        local entry = {
            element = element,
            go = targetGO,
            rect = targetRect,
            height = options.height,
            sizeListener = nil
        }

        if element ~= nil and basicModule.type(element) == "table" and basicModule.type(element.RegisterSizeChangedListener) == "function" then
            entry.sizeListener = function()
                Foldout.RefreshSize()
            end
            element.RegisterSizeChangedListener(entry.sizeListener)
        end

        Foldout.children[#Foldout.children + 1] = entry

        if Foldout.expanded ~= true then
            SetGameObjectActive(targetGO, false)
        end

        Foldout.RefreshSize()
        return entry
    end

    function Foldout.RemoveElement(element)
        local targetGO = ResolveElementGO(element)
        if targetGO == nil then
            return false
        end

        for i = 1, #Foldout.children do
            if Foldout.children[i].go == targetGO then
                local removed = table.remove(Foldout.children, i)
                if removed ~= nil and removed.go ~= nil then
                    SetGameObjectActive(removed.go, true)
                end
                if removed ~= nil and removed.element ~= nil and basicModule.type(removed.element) == "table" and removed.sizeListener ~= nil and basicModule.type(removed.element.UnregisterSizeChangedListener) == "function" then
                    removed.element.UnregisterSizeChangedListener(removed.sizeListener)
                end
                Foldout.RefreshSize()
                return true
            end
        end

        return false
    end

    function Foldout.ClearElements()
        for i = 1, #Foldout.children do
            local entry = Foldout.children[i]
            if entry ~= nil and entry.go ~= nil then
                SetGameObjectActive(entry.go, true)
            end
            if entry ~= nil and entry.element ~= nil and basicModule.type(entry.element) == "table" and entry.sizeListener ~= nil and basicModule.type(entry.element.UnregisterSizeChangedListener) == "function" then
                entry.element.UnregisterSizeChangedListener(entry.sizeListener)
            end
        end

        Foldout.children = {}
        Foldout.RefreshSize()
    end

    return Foldout
end

function GUI_Foldout.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateFoldout(parent, {
        title = options.title or "Foldout",
        width = options.width or 780,
        headerHeight = options.headerHeight or 38,
        expanded = options.expanded,
        x = options.x or 0,
        y = options.y or 0
    })
end

return GUI_Foldout
