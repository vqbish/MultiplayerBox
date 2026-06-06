local GUI_Toggle = {}

function GUI_Toggle.New()
    local Toggle = {}

    Toggle.toggleGO = nil
    Toggle.toggleRect = nil
    Toggle.toggleComp = nil
    Toggle.backgroundGO = nil
    Toggle.checkmarkGO = nil
    Toggle.label = nil
    Toggle.valueChangedListeners = {}
    Toggle._lastIsOn = nil

    local function EmitValueChangedInternal(isOn, force)
        if force ~= true and Toggle._lastIsOn == isOn then
            return
        end

        Toggle._lastIsOn = isOn

        for i = 1, #Toggle.valueChangedListeners do
            local listener = Toggle.valueChangedListeners[i]
            if basicModule.type(listener) == "function" then
                listener(isOn, Toggle)
            end
        end
    end

    function Toggle.SetPosition(x, y)
        if Toggle.toggleRect ~= nil then
            Toggle.toggleRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function Toggle.SetSize(width, height)
        if Toggle.toggleRect ~= nil then
            Toggle.toggleRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function Toggle.SetText(text)
        if Toggle.label ~= nil then
            Toggle.label.SetText(text)
        end
    end

    function Toggle.SetIsOn(isOn)
        if Toggle.toggleComp ~= nil then
            Toggle.toggleComp.SetField("isOn", isOn)
        end

        EmitValueChangedInternal(isOn)
    end

    function Toggle.GetIsOn()
        if Toggle.toggleComp ~= nil then
            return Toggle.toggleComp.GetField("isOn")
        end

        return false
    end

    function Toggle.GetValue()
        return Toggle.GetIsOn()
    end

    function Toggle.AddValueChangedListener(funcCallback)
        if basicModule.type(funcCallback) ~= "function" then
            return nil
        end

        table.insert(Toggle.valueChangedListeners, funcCallback)
        return funcCallback
    end

    function Toggle.RemoveValueChangedListener(listener)
        if listener == nil then
            return
        end

        for i = #Toggle.valueChangedListeners, 1, -1 do
            if Toggle.valueChangedListeners[i] == listener then
                table.remove(Toggle.valueChangedListeners, i)
                break
            end
        end
    end

    function Toggle.EmitValueChanged(isOn)
        EmitValueChangedInternal(isOn)
    end

    return Toggle
end

function GUI_Toggle.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateToggle(parent, {
        text = options.text or "Toggle",
        width = options.width or 240,
        height = options.height or 36,
        x = options.x or 0,
        y = options.y or 0,
        fontSize = options.fontSize or 20,
        alignment = options.alignment or "Left",
        isOn = options.isOn or false,
        showLabel = options.showLabel,
        r = options.r,
        g = options.g,
        b = options.b,
        a = options.a
    })
end

return GUI_Toggle
