local GUI_Button = {}

function GUI_Button.New()
    local Button = {}

    Button.buttonGO = nil
    Button.buttonRect = nil
    Button.buttonComp = nil
    Button.buttonImage = nil
    Button.label = nil
    Button.onClick = nil

    function Button.SetPosition(x, y)
        if Button.buttonRect ~= nil then
            Button.buttonRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function Button.SetSize(width, height)
        if Button.buttonRect ~= nil then
            Button.buttonRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function Button.SetColor(r, g, b, a)
        if Button.buttonImage ~= nil then
            Button.buttonImage.SetField("color", Vector4.New(r, g, b, a))
        end
    end

    function Button.SetText(value)
        if Button.label ~= nil and Button.label.textComp ~= nil then
            Button.label.textComp.SetField("text", value)
        end
    end

    return Button
end

function GUI_Button.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateButton(parent, {
        text = options.text or "Button",
        width = options.width or 180,
        height = options.height or 50,
        x = options.x or 0,
        y = options.y or 0,
        fontSize = options.fontSize or 20,
        alignment = options.alignment or "Center",
        r = options.r,
        g = options.g,
        b = options.b,
        a = options.a,
        sprite = options.sprite
    })
end

return GUI_Button
