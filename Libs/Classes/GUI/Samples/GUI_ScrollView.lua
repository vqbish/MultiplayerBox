local GUI_ScrollView = {}

function GUI_ScrollView.New()
    local ScrollView = {}

    ScrollView.scrollGO = nil
    ScrollView.scrollRect = nil
    ScrollView.scrollComp = nil
    ScrollView.viewportGO = nil
    ScrollView.viewportRect = nil
    ScrollView.contentGO = nil
    ScrollView.contentRect = nil
    ScrollView.contentLayoutGroup = nil
    ScrollView.contentSizeFitter = nil

    function ScrollView.SetPosition(x, y)
        if ScrollView.scrollRect ~= nil then
            ScrollView.scrollRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function ScrollView.SetSize(width, height)
        if ScrollView.scrollRect ~= nil then
            ScrollView.scrollRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function ScrollView.SetScrollEnabled(horizontal, vertical)
        if ScrollView.scrollComp ~= nil then
            ScrollView.scrollComp.SetField("horizontal", horizontal)
            ScrollView.scrollComp.SetField("vertical", vertical)
        end
    end

    return ScrollView
end

function GUI_ScrollView.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateScrollView(parent, {
        width = options.width or 400,
        height = options.height or 250,
        x = options.x or 0,
        y = options.y or 0,
        horizontal = options.horizontal or false,
        vertical = options.vertical or true,
        contentWidth = options.contentWidth,
        contentHeight = options.contentHeight
    })
end

return GUI_ScrollView
