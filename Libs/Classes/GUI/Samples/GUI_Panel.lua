local GUI_Panel = {}

function GUI_Panel.New()
    local Panel = {}

    Panel.panelImage = nil
    Panel.panelComp = nil
    Panel.panelGO = nil

    function Panel.SetSize(width, height)
        if Panel.panelComp ~= nil then
            Panel.panelComp.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function Panel.SetPosition(x, y)
        if Panel.panelComp ~= nil then
            Panel.panelComp.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function Panel.SetColor(r, g, b, a)
        if Panel.panelImage ~= nil then
            Panel.panelImage.SetField("color", Vector4.New(r, g, b, a))
        end
    end

    return Panel
end

function GUI_Panel.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreatePanelOverCanvas(parent, {
        width = options.width or 760,
        height = options.height or 350,
        x = options.x or 0,
        y = options.y or 0,
        r = options.r or 0,
        g = options.g or 0,
        b = options.b or 0,
        a = options.a or 0.8
    })
end

return GUI_Panel
