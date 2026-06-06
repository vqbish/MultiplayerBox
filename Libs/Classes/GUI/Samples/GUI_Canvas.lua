local GUI_Canvas = {}

function GUI_Canvas.New()
    local Canvas = {}

    Canvas.canvasGO = nil
    Canvas.canvasComp = nil
    Canvas.canvasScaler = nil
    Canvas.graphicRaycaster = nil

    function Canvas.SetSortingOrder(order)
        if Canvas.canvasComp ~= nil then
            Canvas.canvasComp.SetField("sortingOrder", order)
        end
    end

    function Canvas.SetPixelPerfect(isEnabled)
        if Canvas.canvasComp ~= nil then
            Canvas.canvasComp.SetField("pixelPerfect", isEnabled)
        end
    end

    return Canvas
end

function GUI_Canvas.Create(options)
    options = options or {}
    return LuaGUI.GUITool.CreateBaseCanvas(options.name or "BaseCanvas", {
        renderMode = options.renderMode,
        pixelPerfect = options.pixelPerfect,
        uiScaleMode = options.uiScaleMode,
        referenceWidth = options.referenceWidth or 1920,
        referenceHeight = options.referenceHeight or 1080
    })
end

return GUI_Canvas
