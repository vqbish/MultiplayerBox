local GUI_Slider = {}

function GUI_Slider.New()
    local Slider = {}

    Slider.sliderGO = nil
    Slider.sliderRect = nil
    Slider.sliderComp = nil
    Slider.fillGO = nil
    Slider.handleGO = nil
    Slider.valueChangedListeners = {}
    Slider._lastValue = nil

    local function EmitValueChangedInternal(value, force)
        if force ~= true and Slider._lastValue == value then
            return
        end

        Slider._lastValue = value

        for i = 1, #Slider.valueChangedListeners do
            local listener = Slider.valueChangedListeners[i]
            if basicModule.type(listener) == "function" then
                listener(value, Slider)
            end
        end
    end

    function Slider.SetPosition(x, y)
        if Slider.sliderRect ~= nil then
            Slider.sliderRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function Slider.SetSize(width, height)
        if Slider.sliderRect ~= nil then
            Slider.sliderRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function Slider.SetValue(value)
        if Slider.sliderComp ~= nil then
            Slider.sliderComp.SetField("value", value)
        end

        EmitValueChangedInternal(value)

        if basicModule.type(Slider.UpdateShowValue) == "function" then
            Slider.UpdateShowValue(value)
        end
    end

    function Slider.GetValue()
        if Slider.sliderComp ~= nil then
            return Slider.sliderComp.GetField("value")
        end

        return nil
    end

    function Slider.AddValueChangedListener(funcCallback)
        if basicModule.type(funcCallback) ~= "function" then
            return nil
        end

        table.insert(Slider.valueChangedListeners, funcCallback)
        return funcCallback
    end

    function Slider.RemoveValueChangedListener(listener)
        if listener == nil then
            return
        end

        for i = #Slider.valueChangedListeners, 1, -1 do
            if Slider.valueChangedListeners[i] == listener then
                table.remove(Slider.valueChangedListeners, i)
                break
            end
        end
    end

    function Slider.EmitValueChanged(value)
        EmitValueChangedInternal(value)
    end

    function Slider.SetRange(minValue, maxValue)
        if Slider.sliderComp ~= nil then
            Slider.sliderComp.SetField("minValue", minValue)
            Slider.sliderComp.SetField("maxValue", maxValue)
        end
    end

    return Slider
end

function GUI_Slider.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateSlider(parent, {
        width = options.width or 320,
        height = options.height or 32,
        x = options.x or 0,
        y = options.y or 0,
        minValue = options.minValue or 0,
        maxValue = options.maxValue or 1,
        value = options.value or 0.5,
        wholeNumbers = options.wholeNumbers or false,
        showValue = options.showValue or false,
        direction = options.direction or "LeftToRight"
    })
end

return GUI_Slider
