local FontStealer = {}

function FontStealer.StealFontAsset(textComponent)
    local fontAsset = textComponent.GetField("font")

    return fontAsset
end

function FontStealer.SetFont(textComponent, font)
    textComponent.SetField("font", font)
    textComponent.CallMethod("SetAllDirty")
end

return FontStealer