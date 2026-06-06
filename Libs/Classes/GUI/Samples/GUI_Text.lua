local GUI_Text = {}

function GUI_Text.New()
    local Text = {}

    Text.textGO = nil
    Text.textRect = nil
    Text.textComp = nil
    Text.backGroundPanel = nil

    function Text.SetValue(value)
        if Text.textComp ~= nil then
            Text.textComp.SetField("text", value)
        end
    end

    function Text.SetFontSize(size)
        if Text.textComp ~= nil then
            Text.textComp.SetField("fontSize", size)
        end
    end

    function Text.SetAlignment(alignment)
        if Text.textComp ~= nil then
            Text.textComp.SetField("alignment", alignment)
        end
    end

    function Text.SetColor(r, g, b, a)
        if Text.textComp ~= nil then
            Text.textComp.SetField("color", Vector4.New(r, g, b, a))
        end
    end

    function Text.SetColorBackground(r, g, b, a)
        if Text.backGroundPanel ~= nil then
            Text.backGroundPanel.SetColor(r, g, b, a)
        end
    end

    function Text.SetPosition(x, y)
        if Text.textRect ~= nil then
            Text.textRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
        if Text.backGroundPanel ~= nil then
            Text.backGroundPanel.SetPosition(x, y)
        end
    end

    function Text.SetSize(width, height)
        if Text.textRect ~= nil then
            Text.textRect.SetField("sizeDelta", Vector2.New(width, height))
        end
        if Text.backGroundPanel ~= nil then
            Text.backGroundPanel.SetSize(width, height)
        end
    end

    function Text.SetWordWrap(enabled)
        if Text.textComp ~= nil then
            Text.textComp.SetField("enableWordWrapping", enabled)
        end
    end

    return Text
end

function GUI_Text.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateText(parent, {
        text = options.text or "Text",
        width = options.width or 200,
        height = options.height or 50,
        x = options.x or 0,
        y = options.y or 0,
        fontSize = options.fontSize or 24,
        alignment = options.alignment or "Center",
        wordWrap = options.wordWrap or false,
        r = options.r,
        g = options.g,
        b = options.b,
        a = options.a,
        useBackGround = options.useBackGround or false
    })
end

return GUI_Text
