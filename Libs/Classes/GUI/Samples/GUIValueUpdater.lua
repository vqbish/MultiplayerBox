local GUIValueUpdater = {}

function GUIValueUpdater.New()
    local Updater = {}

    Updater.listeners = {}
    Updater.isTickSubscribed = false

    local function EmitListener(listener, value)
        if listener == nil or listener.isActive ~= true then
            return
        end

        listener.callback(value, listener.target)
    end

    local function EmitTargetValueChanged(target, value)
        if target == nil then
            return
        end

        if basicModule.type(target.EmitValueChanged) == "function" then
            target.EmitValueChanged(value)
        end
    end

    local function GetTargetValue(target)
        if target == nil then
            return nil
        end

        if basicModule.type(target.GetValue) == "function" then
            return target.GetValue()
        end

        if target.sliderComp ~= nil then
            return target.sliderComp.GetField("value")
        end

        if target.toggleComp ~= nil then
            return target.toggleComp.GetField("isOn")
        end

        if target.inputComp ~= nil then
            return target.inputComp.GetField("text")
        end

        return nil
    end

    local function TryAttachCustomEventListeners(listener)
        if listener == nil or listener.target == nil then
            return false
        end

        local target = listener.target
        if basicModule.type(target.AddValueChangedListener) == "function" then
            listener.customEventHandler = target.AddValueChangedListener(function(value)
                if listener.isActive ~= true then
                    return
                end

                listener.lastValue = value
                EmitListener(listener, value)
            end)

            return listener.customEventHandler ~= nil
        end

        local textChangedEvent = target.onTextChanged or target.onValueChanged
        if textChangedEvent == nil or basicModule.type(textChangedEvent.AddListener) ~= "function" then
            return false
        end

        listener.customEventHandler = function(value)
            if listener.isActive ~= true then
                return
            end

            listener.lastValue = value
            EmitListener(listener, value)
        end

        textChangedEvent.AddListener(listener.customEventHandler)

        return listener.customEventHandler ~= nil
    end

    local function EnsureTick()
        if Updater.isTickSubscribed == true then
            return
        end

        TickManager.AddCustomCallback(Updater.OnTick, 40)
        Updater.isTickSubscribed = true
    end

    function Updater.AddListener(target, funcCallback)
        if target == nil then
            return nil
        end

        if basicModule.type(funcCallback) ~= "function" then
            return nil
        end

        local listener = {
            target = target,
            callback = funcCallback,
            lastValue = GetTargetValue(target),
            isEventDriven = false,
            isActive = true,
            customEventHandler = nil
        }

        listener.isEventDriven = TryAttachCustomEventListeners(listener)

        table.insert(Updater.listeners, listener)
        EnsureTick()

        return listener
    end

    function Updater.RemoveListener(listener)
        if listener == nil then
            return
        end

        listener.isActive = false

        if listener.target ~= nil and listener.customEventHandler ~= nil then
            if basicModule.type(listener.target.RemoveValueChangedListener) == "function" then
                listener.target.RemoveValueChangedListener(listener.customEventHandler)
            else
                local textChangedEvent = listener.target.onTextChanged or listener.target.onValueChanged
                if textChangedEvent ~= nil and basicModule.type(textChangedEvent.RemoveListener) == "function" then
                    textChangedEvent.RemoveListener(listener.customEventHandler)
                end
            end
        end

        for i = #Updater.listeners, 1, -1 do
            if Updater.listeners[i] == listener then
                table.remove(Updater.listeners, i)
                break
            end
        end
    end

    function Updater.Clear()
        Updater.listeners = {}
    end

    function Updater.OnTick()
        local emittedTargets = {}

        for i = 1, #Updater.listeners do
            local listener = Updater.listeners[i]
            if listener ~= nil and listener.isActive == true then
                local currentValue = GetTargetValue(listener.target)
                if currentValue ~= listener.lastValue then
                    listener.lastValue = currentValue

                    if emittedTargets[listener.target] ~= true then
                        EmitTargetValueChanged(listener.target, currentValue)
                        emittedTargets[listener.target] = true
                    end

                    if listener.isEventDriven ~= true then
                        EmitListener(listener, currentValue)
                    end
                end
            end
        end
    end

    return Updater
end

return GUIValueUpdater
