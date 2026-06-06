local GUI_InputField = {}

function GUI_InputField.New()
    local InputField = {}

    InputField.inputGO = nil
    InputField.inputRect = nil
    InputField.inputComp = nil
    InputField.backgroundImage = nil
    InputField.textAreaGO = nil
    InputField.textRect = nil
    InputField.textComp = nil
    InputField.placeholderComp = nil
    InputField.onTextChanged = nil
    InputField.onValueChanged = nil
    InputField.valueChangedListeners = {}
    InputField._lastText = nil
    InputField._isCustomWatcherSubscribed = false

    local function EmitValueChangedInternal(value, force)
        if force ~= true and InputField._lastText == value then
            return
        end

        InputField._lastText = value

        for i = 1, #InputField.valueChangedListeners do
            local listener = InputField.valueChangedListeners[i]
            if basicModule.type(listener) == "function" then
                listener(value, InputField)
            end
        end
    end

    local function EnsureCustomValueWatcher()
        if InputField._isCustomWatcherSubscribed == true then
            return
        end

        InputField._isCustomWatcherSubscribed = true

        TickManager.AddCustomCallback(function()
            if #InputField.valueChangedListeners == 0 then
                return
            end

            local currentValue = InputField.GetText()
            EmitValueChangedInternal(currentValue)
        end, 60)
    end

    function InputField.SetPosition(x, y)
        if InputField.inputRect ~= nil then
            InputField.inputRect.SetField("anchoredPosition", Vector2.New(x, y))
        end
    end

    function InputField.SetSize(width, height)
        if InputField.inputRect ~= nil then
            InputField.inputRect.SetField("sizeDelta", Vector2.New(width, height))
        end
    end

    function InputField.SetText(value)
        if InputField.inputComp ~= nil then
            InputField.inputComp.SetField("text", value)
        end

        EmitValueChangedInternal(value)
    end

    function InputField.SetValue(value)
        InputField.SetText(value)
    end

    function InputField.GetText()
        if InputField.inputComp ~= nil then
            return InputField.inputComp.GetField("text")
        end

        return ""
    end

    function InputField.GetValue()
        return InputField.GetText()
    end

    function InputField.AddValueChangedListener(funcCallback)
        if basicModule.type(funcCallback) ~= "function" then
            return nil
        end

        table.insert(InputField.valueChangedListeners, funcCallback)
        EnsureCustomValueWatcher()

        return funcCallback
    end

    function InputField.RemoveValueChangedListener(listener)
        if listener == nil then
            return
        end

        for i = #InputField.valueChangedListeners, 1, -1 do
            if InputField.valueChangedListeners[i] == listener then
                table.remove(InputField.valueChangedListeners, i)
                break
            end
        end
    end

    function InputField.EmitValueChanged(value)
        EmitValueChangedInternal(value)
    end

    function InputField.SetPlaceholder(value)
        if InputField.placeholderComp ~= nil then
            InputField.placeholderComp.SetField("text", value)
        end
    end

    return InputField
end

function GUI_InputField.Create(parent, options)
    options = options or {}
    return LuaGUI.GUITool.CreateInputField(parent, {
        text = options.text or "",
        placeholder = options.placeholder or "Input...",
        width = options.width or 320,
        height = options.height or 42,
        x = options.x or 0,
        y = options.y or 0,
        fontSize = options.fontSize or 18,
        multiLine = options.multiLine or false,
        characterLimit = options.characterLimit
    })
end

return GUI_InputField
