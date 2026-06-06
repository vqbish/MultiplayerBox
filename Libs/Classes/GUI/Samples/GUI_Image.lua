local GUI_Image = {}

function GUI_Image.New()
    local Image = {}

    Image.imageGO = nil
    Image.imageRect = nil
    Image.imageComp = nil

    function Image.SetPosition(x, y)
        if Image.imageRect ~= nil then
            Image.imageRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function Image.SetSize(width, height)
        if Image.imageRect ~= nil then
            Image.imageRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function Image.SetColor(r, g, b, a)
        if Image.imageComp ~= nil then
            Image.imageComp.SetField("color", Vector4.New(r, g, b, a))
        end
    end

    function Image.SetSprite(sprite)
        if Image.imageComp ~= nil then
            Image.imageComp.SetField("sprite", sprite)
        end
    end

    return Image
end

function GUI_Image.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateImage(parent, {
        width = options.width or 100,
        height = options.height or 100,
        x = options.x or 0,
        y = options.y or 0,
        r = options.r or 1,
        g = options.g or 1,
        b = options.b or 1,
        a = options.a or 1,
        sprite = options.sprite
    })
end

return GUI_Image
