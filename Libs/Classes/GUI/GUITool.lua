local GUITool = {}

GUITool.Theme = {}
GUITool.GBFont = nil
GUITool.useGBFont = true

function GUITool.GetGBFont()
    local GetGBFontGOPath = "WidgetMaster/0Main/ButtonBottomHolder/Play/Text (TMP)"
    local GetGBFontGOMapPath = "UI/FPS & Ping Counter"
    local function TryGetFontInMenu()
        if EnvironmentMaster.GetCurrentScene() ~= "sys_Menu" then
            return
        end
        local MenuGO = GameObject.FindByName("Menu")
        if MenuGO == nil then
            Logger.Log("MENUGO NOT FOUND!", LogTypes.Error)
            return
        end

        local Text = MenuGO.Transform.Find(GetGBFontGOPath)
        if Text == nil then
            Logger.Log("TEXT NOT FOUND!", LogTypes.Error)
            return
        end

        local TextComp = Text.GameObject.GetComponent("TextMeshProUGUI")
        if TextComp == nil then
            Logger.Log("TEXT COMPONENT NOT FOUND!", LogTypes.Error)
            return
        end

        GUITool.GBFont = LuaGUI.FontStealer.StealFontAsset(TextComp)
    end
    local function TryGetFontInGame()
        if EnvironmentMaster.GetCurrentScene() == "sys_Menu" then
            return
        end
        local MenuGO = GameObject.FindAllByComponent("GameMaster")[1]
        if MenuGO == nil then
            Logger.Log("GameMaster NOT FOUND!", LogTypes.Error)
            return
        end

        local Text = MenuGO.Transform.Find(GetGBFontGOMapPath)
        if Text == nil then
            Logger.Log("TEXT NOT FOUND!", LogTypes.Error)
            return
        end

        local TextComp = Text.GameObject.GetComponent("TextMeshProUGUI")
        if TextComp == nil then
            Logger.Log("TEXT COMPONENT NOT FOUND!", LogTypes.Error)
            return
        end

        GUITool.GBFont = LuaGUI.FontStealer.StealFontAsset(TextComp)
    end
    TryGetFontInMenu()
    TryGetFontInGame()
end

local function IsTable(value)
    return value ~= nil and basicModule.type(value) == "table"
end

local function DeepCopy(value)
    if not IsTable(value) then
        return value
    end

    local clone = {}
    for key, child in tableIterators.pairs(value) do
        clone[key] = DeepCopy(child)
    end

    return clone
end

local function DeepMerge(target, source)
    if not IsTable(target) or not IsTable(source) then
        return target
    end

    for key, value in tableIterators.pairs(source) do
        if IsTable(value) then
            if not IsTable(target[key]) then
                target[key] = {}
            end
            DeepMerge(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

local function BuildThemeDefaultsPath(path)
    if path == nil then
        return nil
    end

    local replaced = string.gsub(path, "GUIConfig%.json$", "GUIConfigDef.json")
    if replaced == path then
        return nil
    end

    return replaced
end

function GUITool.LoadTheme(path)
    local defaultsTheme = nil
    local defaultsPath = BuildThemeDefaultsPath(path)
    if defaultsPath ~= nil then
        local defaultsRaw = File.ImportFile(defaultsPath)
        if defaultsRaw ~= nil and defaultsRaw ~= "" then
            defaultsTheme = json.parse(defaultsRaw)
        end
    end

    local raw = File.ImportFile(path)
    local loadedTheme = nil
    if raw ~= nil and raw ~= "" then
        loadedTheme = json.parse(raw)
    end

    if not IsTable(defaultsTheme) then
        defaultsTheme = {}
    end

    if not IsTable(loadedTheme) then
        loadedTheme = {}
    end

    local mergedTheme = DeepCopy(defaultsTheme)
    DeepMerge(mergedTheme, loadedTheme)
    GUITool.Theme = mergedTheme
end

local function IsColorTable(value)
    if value == nil or basicModule.type(value) ~= "table" then
        return false
    end

    local hasR = value.r ~= nil or value.R ~= nil
    local hasG = value.g ~= nil or value.G ~= nil
    local hasB = value.b ~= nil or value.B ~= nil

    return hasR and hasG and hasB
end

local function ReadColorValue(value, keyLower, keyUpper, fallback)
    if value == nil then
        return fallback
    end

    local result = value[keyLower]
    if result == nil then
        result = value[keyUpper]
    end

    if result == nil then
        return fallback
    end

    return result
end

local function ResolveThemeBranch(path)
    local current = GUITool.Theme
    if current == nil then
        return nil
    end

    if path == nil or path == "" then
        return current
    end

    local token = ""
    for i = 1, string.len(path) do
        local ch = string.sub(path, i, i)
        if ch == "." then
            if token ~= "" then
                if current == nil or basicModule.type(current) ~= "table" then
                    return nil
                end
                current = current[token]
                token = ""
            end
        else
            token = token .. ch
        end
    end

    if token ~= "" then
        if current == nil or basicModule.type(current) ~= "table" then
            return nil
        end
        current = current[token]
    end

    return current
end

local THEME_PATH_ALIASES = {
    ["Theme.Components.Panel"] = "Theme.Root.SubPanel",
    ["Theme.Components.Image"] = "Theme.Text.AccentBackground",
    ["Theme.Components.Text"] = "Theme.Text.Primary",
    ["Theme.Components.TextBackground"] = "Theme.Text.BackgroundPrimary",
    ["Theme.Components.Button.Background"] = "Theme.Controls.Button.Background",
    ["Theme.Components.Button.Text"] = "Theme.Controls.Button.Text",
    ["Theme.Components.Foldout.Header"] = "Theme.Controls.Button.FoldoutHeader",
    ["Theme.Components.ScrollRect.Background"] = "Theme.Root.ScrollBackground",
    ["Theme.Components.ScrollRect.Viewport"] = "Theme.Root.ScrollBackground",
    ["Theme.Components.ScrollRect.Scrollbar.Background"] = "Theme.Controls.Slider.Background",
    ["Theme.Components.ScrollRect.Scrollbar.Handle"] = "Theme.Controls.Slider.Handle",
    ["Theme.Components.Toggle.Background"] = "Theme.Controls.Button.Background",
    ["Theme.Components.Toggle.Checkmark"] = "Theme.Tabs.Active",
    ["Theme.Components.Toggle.Text"] = "Theme.Text.Primary",
    ["Theme.Components.InputField.Background"] = "Theme.Root.Input",
    ["Theme.Components.InputField.Placeholder"] = "Theme.Text.Muted",
    ["Theme.Components.InputField.Text"] = "Theme.Text.Primary",
    ["Theme.Components.Slider.Background"] = "Theme.Controls.Slider.Background",
    ["Theme.Components.Slider.Fill"] = "Theme.Controls.Slider.Fill",
    ["Theme.Components.Slider.Handle"] = "Theme.Controls.Slider.Handle",
    ["Theme.Components.Slider.ValueLabel"] = "Theme.Text.Meta"
}

local function ResolveThemeBranchWithAliases(path)
    local direct = ResolveThemeBranch(path)
    if direct ~= nil then
        return direct
    end

    local alias = THEME_PATH_ALIASES[path]
    if alias ~= nil and alias ~= path then
        return ResolveThemeBranch(alias)
    end

    return nil
end

function GUITool.GetThemeColor(path, fallback)
    local branch = ResolveThemeBranchWithAliases(path)
    if not IsColorTable(branch) then
        return fallback
    end

    local result = {
        r = ReadColorValue(branch, "r", "R", ReadColorValue(fallback, "r", "R", 1)),
        g = ReadColorValue(branch, "g", "G", ReadColorValue(fallback, "g", "G", 1)),
        b = ReadColorValue(branch, "b", "B", ReadColorValue(fallback, "b", "B", 1)),
        a = ReadColorValue(branch, "a", "A", ReadColorValue(fallback, "a", "A", 1))
    }

    return result
end

function GUITool.GetThemeValue(path, fallback)
    local value = ResolveThemeBranchWithAliases(path)
    if value == nil then
        return fallback
    end

    return value
end

local function Opt(value, fallback)
    if value == nil then
        return fallback
    end

    return value
end

local function ResolveColorFromOptions(options, keyMap, themePath, fallback)
    options = options or {}
    keyMap = keyMap or { r = "r", g = "g", b = "b", a = "a" }

    local themeColor = GUITool.GetThemeColor(themePath, fallback)
    themeColor = themeColor or fallback or { r = 1, g = 1, b = 1, a = 1 }

    return {
        r = Opt(options[keyMap.r], themeColor.r),
        g = Opt(options[keyMap.g], themeColor.g),
        b = Opt(options[keyMap.b], themeColor.b),
        a = Opt(options[keyMap.a], themeColor.a)
    }
end

local function NormalizeTMPAlignment(alignment)
    if alignment == nil then
        return "Center"
    end

    local map = {
        UpperLeft = "TopLeft",
        UpperCenter = "Top",
        UpperRight = "TopRight",
        MiddleLeft = "Left",
        MiddleCenter = "Center",
        MiddleRight = "Right",
        LowerLeft = "BottomLeft",
        LowerCenter = "Bottom",
        LowerRight = "BottomRight"
    }

    return Opt(map[alignment], alignment)
end

local function ResolveParentGO(parent)
    if parent == nil then
        return nil
    end

    if basicModule.type(parent) ~= "table" then
        return parent
    end

    if parent.canvasGO ~= nil then
        return parent.canvasGO
    end

    if parent.panelGO ~= nil then
        return parent.panelGO
    end

    if parent.scrollGO ~= nil then
        return parent.scrollGO
    end

    if parent.contentGO ~= nil then
        return parent.contentGO
    end

    if parent.foldoutGO ~= nil then
        return parent.foldoutGO
    end

    if parent.itemsContainerGO ~= nil then
        return parent.itemsContainerGO
    end

    return parent
end

local function CreateLayoutElement(targetGO, options)
    if targetGO == nil then
        return nil
    end

    options = options or {}

    local layoutElement = targetGO.AddComponent("UnityEngine.UI.LayoutElement")

    if options.minWidth ~= nil then
        layoutElement.SetField("minWidth", options.minWidth)
    end

    if options.minHeight ~= nil then
        layoutElement.SetField("minHeight", options.minHeight)
    end

    if options.preferredWidth ~= nil then
        layoutElement.SetField("preferredWidth", options.preferredWidth)
    end

    if options.preferredHeight ~= nil then
        layoutElement.SetField("preferredHeight", options.preferredHeight)
    end

    if options.flexibleWidth ~= nil then
        layoutElement.SetField("flexibleWidth", options.flexibleWidth)
    end

    if options.flexibleHeight ~= nil then
        layoutElement.SetField("flexibleHeight", options.flexibleHeight)
    end

    return layoutElement
end

local function ApplyLayoutGroupSettings(layoutGroupComp, settings)
    if layoutGroupComp == nil or settings == nil then
        return
    end

    if settings.spacing ~= nil then
        layoutGroupComp.SetField("spacing", settings.spacing)
    end

    if settings.childAlignment ~= nil then
        layoutGroupComp.SetField("childAlignment", settings.childAlignment)
    end

    if settings.childControlWidth ~= nil then
        layoutGroupComp.SetField("childControlWidth", settings.childControlWidth)
    end

    if settings.childControlHeight ~= nil then
        layoutGroupComp.SetField("childControlHeight", settings.childControlHeight)
    end

    if settings.childForceExpandWidth ~= nil then
        layoutGroupComp.SetField("childForceExpandWidth", settings.childForceExpandWidth)
    end

    if settings.childForceExpandHeight ~= nil then
        layoutGroupComp.SetField("childForceExpandHeight", settings.childForceExpandHeight)
    end

    if settings.childScaleWidth ~= nil then
        layoutGroupComp.SetField("childScaleWidth", settings.childScaleWidth)
    end

    if settings.childScaleHeight ~= nil then
        layoutGroupComp.SetField("childScaleHeight", settings.childScaleHeight)
    end

    if settings.reverseArrangement ~= nil then
        layoutGroupComp.SetField("reverseArrangement", settings.reverseArrangement)
    end

    local hasPadding = settings.paddingLeft ~= nil or settings.paddingRight ~= nil or settings.paddingTop ~= nil or settings.paddingBottom ~= nil
    if hasPadding then
        local offsetMin = Vector2.New(Opt(settings.paddingLeft, 0), Opt(settings.paddingBottom, 0))
        local offsetMax = Vector2.New(-Opt(settings.paddingRight, 0), -Opt(settings.paddingTop, 0))
        local rectTransform = layoutGroupComp.gameObject.GetComponent("RectTransform")
        if rectTransform ~= nil then
            rectTransform.SetField("offsetMin", offsetMin)
            rectTransform.SetField("offsetMax", offsetMax)
        end
    end
end

local function CreateContentLayoutGroup(contentGO, options)
    options = options or {}

    local layoutType = Opt(options.type, Opt(options.layoutType, "Vertical"))
    local normalizedType = basicModule.tostring(layoutType)

    local componentName = nil
    if normalizedType == "Vertical" or normalizedType == "VerticalLayoutGroup" then
        componentName = "UnityEngine.UI.VerticalLayoutGroup"
    elseif normalizedType == "Horizontal" or normalizedType == "HorizontalLayoutGroup" then
        componentName = "UnityEngine.UI.HorizontalLayoutGroup"
    elseif normalizedType == "Grid" or normalizedType == "GridLayoutGroup" then
        componentName = "UnityEngine.UI.GridLayoutGroup"
    else
        return nil
    end

    local layoutComp = contentGO.AddComponent(componentName)

    if componentName == "UnityEngine.UI.GridLayoutGroup" then
        layoutComp.SetField("cellSize", Vector2.New(Opt(options.cellWidth, 100), Opt(options.cellHeight, 30)))
        layoutComp.SetField("spacing", Vector2.New(Opt(options.spacingX, Opt(options.spacing, 0)), Opt(options.spacingY, Opt(options.spacing, 0))))
        layoutComp.SetField("constraint", Opt(options.constraint, "Flexible"))
        if options.constraintCount ~= nil then
            layoutComp.SetField("constraintCount", options.constraintCount)
        end
        layoutComp.SetField("startAxis", Opt(options.startAxis, "Horizontal"))
        layoutComp.SetField("startCorner", Opt(options.startCorner, "UpperLeft"))
        layoutComp.SetField("childAlignment", Opt(options.childAlignment, "UpperLeft"))
    else
        ApplyLayoutGroupSettings(layoutComp, {
            spacing = Opt(options.spacing, 0),
            childAlignment = Opt(options.childAlignment, "UpperLeft"),
            childControlWidth = Opt(options.childControlWidth, true),
            childControlHeight = Opt(options.childControlHeight, false),
            childForceExpandWidth = Opt(options.childForceExpandWidth, true),
            childForceExpandHeight = Opt(options.childForceExpandHeight, false),
            childScaleWidth = options.childScaleWidth,
            childScaleHeight = options.childScaleHeight,
            reverseArrangement = options.reverseArrangement,
            paddingLeft = Opt(options.paddingLeft, 0),
            paddingRight = Opt(options.paddingRight, 0),
            paddingTop = Opt(options.paddingTop, 0),
            paddingBottom = Opt(options.paddingBottom, 0)
        })
    end

    return layoutComp
end

local function CreateContentSizeFitter(targetGO, options)
    options = options or {}
    local fitterComp = targetGO.AddComponent("UnityEngine.UI.ContentSizeFitter")
    fitterComp.SetField("horizontalFit", Opt(options.horizontalFit, "Unconstrained"))
    fitterComp.SetField("verticalFit", Opt(options.verticalFit, "PreferredSize"))
    return fitterComp
end

local function CreateRectTransform(parentGO, name, options, defaults)
    local go = GameObject.Create(name .. "_" .. math.random(0, 10000))
    local rect = go.AddComponent("RectTransform")

    local resolvedParent = ResolveParentGO(parentGO)
    if resolvedParent ~= nil and resolvedParent.Transform ~= nil then
        go.Transform.SetParent(resolvedParent.Transform)
    end

    options = options or {}
    defaults = defaults or {}

    rect.SetField("anchoredPosition", Vector2.New(Opt(options.x, Opt(defaults.x, 0)), Opt(options.y, Opt(defaults.y, 0))))
    rect.SetField("anchorMin", Vector2.New(Opt(options.anchorMinX, Opt(defaults.anchorMinX, 0.5)), Opt(options.anchorMinY, Opt(defaults.anchorMinY, 0.5))))
    rect.SetField("anchorMax", Vector2.New(Opt(options.anchorMaxX, Opt(defaults.anchorMaxX, 0.5)), Opt(options.anchorMaxY, Opt(defaults.anchorMaxY, 0.5))))
    rect.SetField("pivot", Vector2.New(Opt(options.pivotX, Opt(defaults.pivotX, 0.5)), Opt(options.pivotY, Opt(defaults.pivotY, 0.5))))
    rect.SetField("sizeDelta", Vector2.New(Opt(options.width, Opt(defaults.width, 100)), Opt(options.height, Opt(defaults.height, 100))))

    return go, rect
end

local function StretchRect(rectTransform, left, right, top, bottom)
    if rectTransform == nil then
        return
    end

    rectTransform.SetField("anchorMin", Vector2.New(0, 0))
    rectTransform.SetField("anchorMax", Vector2.New(1, 1))
    rectTransform.SetField("pivot", Vector2.New(0.5, 0.5))
    rectTransform.SetField("anchoredPosition", Vector2.New(0, 0))
    rectTransform.SetField("sizeDelta", Vector2.New(0, 0))
    rectTransform.SetField("offsetMin", Vector2.New(Opt(left, 0), Opt(bottom, 0)))
    rectTransform.SetField("offsetMax", Vector2.New(-Opt(right, 0), -Opt(top, 0)))
end

local function ResolveInputLineTypeValue(lineType)
    if basicModule.type(lineType) == "number" then
        return lineType
    end

    if lineType == "SingleLine" then
        return 0
    end

    if lineType == "MultiLineSubmit" then
        return 1
    end

    if lineType == "MultiLineNewline" then
        return 2
    end

    return 0
end

function GUITool.CreateBaseCanvas(name, options)
    options = options or {}

    local canvasGO = GameObject.Create(Opt(name, "Base") .. "Canvas")
    local canvasComp = canvasGO.AddComponent("Canvas")
    canvasComp.SetField("renderMode", Opt(options.renderMode, "ScreenSpaceOverlay"))
    canvasComp.SetField("pixelPerfect", Opt(options.pixelPerfect, true))

    local canvasScaler = canvasGO.AddComponent("CanvasScaler")
    canvasScaler.SetField("uiScaleMode", Opt(options.uiScaleMode, "ScaleWithScreenSize"))
    canvasScaler.SetField("referencePixelsPerUnit", Opt(options.referencePixelsPerUnit, 100))
    canvasScaler.SetField("referenceResolution", Vector2.New(Opt(options.referenceWidth, 1920), Opt(options.referenceHeight, 1080)))
    canvasScaler.SetField("matchWidthOrHeight", Opt(options.matchWidthOrHeight, 1))

    local graphicRaycaster = canvasGO.AddComponent("GraphicRaycaster")

    local canvas = LuaGUI.LuaGUI.GUI_Canvas.New()
    canvas.canvasGO = canvasGO
    canvas.canvasComp = canvasComp
    canvas.canvasScaler = canvasScaler
    canvas.graphicRaycaster = graphicRaycaster

    return canvas
end

function GUITool.CreatePanelOverCanvas(baseCanvasGO, options)
    local panelGO, panelComp = CreateRectTransform(baseCanvasGO, "Panel", options, {
        width = 760,
        height = 350,
        x = 0,
        y = 0,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local panelImage = panelGO.AddComponent("UnityEngine.UI.Image")
    options = options or {}
    local panelColor = ResolveColorFromOptions(options, { r = "r", g = "g", b = "b", a = "a" }, "Theme.Components.Panel", {
        r = 0,
        g = 0,
        b = 0,
        a = 0.8
    })
    panelImage.SetField("color", Vector4.New(panelColor.r, panelColor.g, panelColor.b, panelColor.a))

    local panel = LuaGUI.LuaGUI.GUI_Panel.New()
    panel.panelGO = panelGO
    panel.panelComp = panelComp
    panel.panelImage = panelImage

    return panel
end

function GUITool.CreateImage(parentGO, options)
    local imageGO, imageRect = CreateRectTransform(parentGO, "Image", options, {
        width = 100,
        height = 100
    })

    local imageComp = imageGO.AddComponent("UnityEngine.UI.Image")
    options = options or {}
    local imageColor = ResolveColorFromOptions(options, { r = "r", g = "g", b = "b", a = "a" }, "Theme.Components.Image", {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    })
    imageComp.SetField("color", Vector4.New(imageColor.r, imageColor.g, imageColor.b, imageColor.a))

    if options.sprite ~= nil then
        imageComp.SetField("sprite", options.sprite)
    end

    local image = LuaGUI.LuaGUI.GUI_Image.New()
    image.imageGO = imageGO
    image.imageRect = imageRect
    image.imageComp = imageComp

    return image
end

function GUITool.CreateText(parentGO, options)
    options = options or {}

    local textGO, textRect = CreateRectTransform(parentGO, "Text", options, {
        width = Opt(options.width, 200),
        height = Opt(options.height, 50),
        x = Opt(options.x, 0),
        y = Opt(options.y, 0)
    })

    local textComp = textGO.AddComponent("TMPro.TextMeshProUGUI")

    textComp.SetField("text", Opt(options.text, "Text"))
    textComp.SetField("fontSize", Opt(options.fontSize, 24))
    textComp.SetField("alignment", NormalizeTMPAlignment(options.alignment))
    textComp.SetField("enableWordWrapping", Opt(options.wordWrap, false))
    textComp.SetField("overflowMode", Opt(options.overflowMode, "Overflow"))
    local textColor = ResolveColorFromOptions(options, { r = "r", g = "g", b = "b", a = "a" }, "Theme.Components.Text", {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    })
    textComp.SetField("color", Vector4.New(textColor.r, textColor.g, textColor.b, textColor.a))

    if GUITool.useGBFont and GUITool.GBFont ~= nil then
        LuaGUI.FontStealer.SetFont(textComp, GUITool.GBFont)
    end

    if Opt(options.stretchToParent, options.stretch) == true then
        StretchRect(textRect, Opt(options.paddingLeft, 0), Opt(options.paddingRight, 0), Opt(options.paddingTop, 0),
            Opt(options.paddingBottom, 0))
    end

    local text = LuaGUI.LuaGUI.GUI_Text.New()
    text.textGO = textGO
    text.textRect = textRect
    text.textComp = textComp

    if options.useBackGround then
        if options.useBackGround == true then
            text.backGroundPanel = GUITool.CreatePanelOverCanvas(parentGO, {
                width = Opt(options.width, 200),
                height = Opt(options.height, 50),
                r = Opt(options.backGroundR, GUITool.GetThemeColor("Theme.Components.TextBackground", {
                    r = 0.2,
                    g = 0.2,
                    b = 0.2,
                    a = 1
                }).r),
                g = Opt(options.backGroundG, GUITool.GetThemeColor("Theme.Components.TextBackground", {
                    r = 0.2,
                    g = 0.2,
                    b = 0.2,
                    a = 1
                }).g),
                b = Opt(options.backGroundB, GUITool.GetThemeColor("Theme.Components.TextBackground", {
                    r = 0.2,
                    g = 0.2,
                    b = 0.2,
                    a = 1
                }).b),
                a = Opt(options.backGroundA, GUITool.GetThemeColor("Theme.Components.TextBackground", {
                    r = 0.2,
                    g = 0.2,
                    b = 0.2,
                    a = 1
                }).a),
                x = Opt(options.x, 0),
                y = Opt(options.y, 0)
            })

            text.textGO.Transform.SetParent(text.backGroundPanel.panelGO.Transform)
            text.textRect.SetField("anchoredPosition", Vector2.New(0, 0))
        else
            text.backGroundPanel = nil
        end
    end

    return text
end

local CreateButtonInternal

CreateButtonInternal = function(parentGO, options)
    local buttonGO, buttonRect = CreateRectTransform(parentGO, "Button", options, {
        width = 180,
        height = 50
    })

    local buttonImage = buttonGO.AddComponent("UnityEngine.UI.Image")
    options = options or {}
    local buttonColor = ResolveColorFromOptions(options, { r = "r", g = "g", b = "b", a = "a" }, "Theme.Components.Button.Background", {
        r = 0.2,
        g = 0.2,
        b = 0.2,
        a = 1
    })
    buttonImage.SetField("color", Vector4.New(buttonColor.r, buttonColor.g, buttonColor.b, buttonColor.a))

    local buttonTextTheme = GUITool.GetThemeColor("Theme.Components.Button.Text", { r = 1, g = 1, b = 1, a = 1 })

    local spritePath = options.sprite
    if spritePath ~= nil and basicModule.tostring(spritePath) ~= "" then
        local image = Importer.ImportTexture(spritePath)
        if image ~= nil then
            local sprite = image.ToSprite()
            buttonImage.SetField("sprite", sprite)
        end
    end

    local buttonComp = buttonGO.AddComponent("UnityEngine.UI.Button")

    local label = GUITool.CreateText(buttonGO, {
        text = Opt(options.text, "Button"),
        fontSize = Opt(options.fontSize, 20),
        alignment = Opt(options.alignment, "Center"),
        width = Opt(options.width, 180),
        height = Opt(options.height, 50),
        x = 0,
        y = 0,
        stretch = true,
        paddingLeft = Opt(options.textPaddingLeft, 0),
        paddingRight = Opt(options.textPaddingRight, 0),
        paddingTop = Opt(options.textPaddingTop, 0),
        paddingBottom = Opt(options.textPaddingBottom, 0),
        r = Opt(options.textR, buttonTextTheme.r),
        g = Opt(options.textG, buttonTextTheme.g),
        b = Opt(options.textB, buttonTextTheme.b),
        a = Opt(options.textA, buttonTextTheme.a)
    })

    local button = LuaGUI.LuaGUI.GUI_Button.New()
    button.buttonGO = buttonGO
    button.buttonRect = buttonRect
    button.buttonComp = buttonComp
    button.buttonImage = buttonImage
    button.label = label
    button.onClick = buttonComp.GetField("onClick")

    return button
end

GUITool.CreateButton = CreateButtonInternal

function GUITool.CreateFoldout(parentGO, options)
    options = options or {}

    local foldoutWidth = Opt(options.width, 780)
    local headerHeight = Opt(options.headerHeight, 38)
    local rowSpacing = Opt(options.rowSpacing, 0)

    local foldoutGO, foldoutRect = CreateRectTransform(parentGO, "Foldout", {
        width = foldoutWidth,
        height = headerHeight,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local foldoutLayout = foldoutGO.AddComponent("UnityEngine.UI.VerticalLayoutGroup")
    ApplyLayoutGroupSettings(foldoutLayout, {
        spacing = 0,
        childAlignment = Opt(options.childAlignment, "UpperLeft"),
        childControlWidth = true,
        childControlHeight = false,
        childForceExpandWidth = true,
        childForceExpandHeight = false,
        paddingLeft = 0,
        paddingRight = 0,
        paddingTop = 0,
        paddingBottom = 0
    })

    local foldoutLayoutElement = CreateLayoutElement(foldoutGO, {
        minHeight = headerHeight,
        preferredHeight = headerHeight,
        flexibleHeight = 0
    })

    local foldoutHeaderTheme = GUITool.GetThemeColor("Theme.Components.Foldout.Header", { r = 0.13, g = 0.19, b = 0.28, a = 1 })

    local headerButton = CreateButtonInternal(foldoutGO, {
        text = "▼ " .. Opt(options.title, "Foldout"),
        width = foldoutWidth,
        height = headerHeight,
        alignment = Opt(options.headerAlignment, "Center"),
        fontSize = Opt(options.headerFontSize, Opt(options.fontSize, 19)),
        r = Opt(options.headerR, Opt(options.r, foldoutHeaderTheme.r)),
        g = Opt(options.headerG, Opt(options.g, foldoutHeaderTheme.g)),
        b = Opt(options.headerB, Opt(options.b, foldoutHeaderTheme.b)),
        a = Opt(options.headerA, Opt(options.a, foldoutHeaderTheme.a))
    })

    CreateLayoutElement(headerButton.buttonGO, {
        minHeight = headerHeight,
        preferredHeight = headerHeight,
        flexibleHeight = 0
    })

    local itemsContainerGO, itemsContainerRect = CreateRectTransform(foldoutGO, "FoldoutItems", {
        width = foldoutWidth,
        height = 0,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local itemsContainerLayoutElement = CreateLayoutElement(itemsContainerGO, {
        minHeight = 0,
        preferredHeight = 0,
        flexibleHeight = 0
    })

    local itemsLayoutGroup = itemsContainerGO.AddComponent("UnityEngine.UI.VerticalLayoutGroup")
    ApplyLayoutGroupSettings(itemsLayoutGroup, {
        spacing = rowSpacing,
        childAlignment = Opt(options.itemsAlignment, "UpperLeft"),
        childControlWidth = true,
        childControlHeight = false,
        childForceExpandWidth = true,
        childForceExpandHeight = false,
        paddingLeft = Opt(options.itemsPaddingLeft, 0),
        paddingRight = Opt(options.itemsPaddingRight, 0),
        paddingTop = Opt(options.itemsPaddingTop, 0),
        paddingBottom = Opt(options.itemsPaddingBottom, 0)
    })

    local itemsSizeFitter = CreateContentSizeFitter(itemsContainerGO, {
        horizontalFit = "Unconstrained",
        verticalFit = "PreferredSize"
    })

    local foldout = LuaGUI.GUI_Foldout.New()
    foldout.foldoutGO = foldoutGO
    foldout.foldoutRect = foldoutRect
    foldout.layoutElement = foldoutLayoutElement
    foldout.headerButton = headerButton
    foldout.itemsContainerGO = itemsContainerGO
    foldout.itemsContainerRect = itemsContainerRect
    foldout.itemsContainerLayoutElement = itemsContainerLayoutElement
    foldout.itemsLayoutGroup = itemsLayoutGroup
    foldout.itemsSizeFitter = itemsSizeFitter
    foldout.headerHeight = headerHeight
    foldout.itemSpacing = rowSpacing
    foldout.title = Opt(options.title, "Foldout")

    headerButton.onClick:AddListener(function()
        foldout.Toggle()
    end)

    local startExpanded = Opt(options.expanded, true)
    foldout.SetExpanded(startExpanded)

    return foldout
end

function GUITool.CreateScrollView(parentGO, options)
    return GUITool.CreateScrollRect(parentGO, options)
end

function GUITool.CreateScrollRect(parentGO, options)
    options = options or {}

    local scrollGO, scrollRect = CreateRectTransform(parentGO, "ScrollRect", options, {
        width = 400,
        height = 250
    })

    local backgroundImage = scrollGO.AddComponent("UnityEngine.UI.Image")
    local scrollBg = ResolveColorFromOptions(options, { r = "bgR", g = "bgG", b = "bgB", a = "bgA" }, "Theme.Components.ScrollRect.Background", {
        r = 0,
        g = 0,
        b = 0,
        a = 0.35
    })
    backgroundImage.SetField("color", Vector4.New(scrollBg.r, scrollBg.g, scrollBg.b, scrollBg.a))

    local scrollComp = scrollGO.AddComponent("UnityEngine.UI.ScrollRect")

    local viewportGO, viewportRect = CreateRectTransform(scrollGO, "Viewport", {
        width = Opt(options.width, 400),
        height = Opt(options.height, 250),
        x = 0,
        y = 0,
        anchorMinX = 0,
        anchorMinY = 0,
        anchorMaxX = 1,
        anchorMaxY = 1,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local viewportImage = viewportGO.AddComponent("UnityEngine.UI.Image")
    local viewportColor = GUITool.GetThemeColor("Theme.Components.ScrollRect.Viewport", { r = 1, g = 1, b = 1, a = 0.01 })
    viewportImage.SetField("color", Vector4.New(viewportColor.r, viewportColor.g, viewportColor.b, viewportColor.a))
    local viewportMask = viewportGO.AddComponent("UnityEngine.UI.Mask")
    viewportMask.SetField("showMaskGraphic", false)

    local contentGO, contentRect = CreateRectTransform(viewportGO, "Content", {
        width = Opt(options.contentWidth, Opt(options.width, 400)),
        height = Opt(options.contentHeight, 600),
        x = 0,
        y = 0,
        anchorMinX = 0,
        anchorMinY = 1,
        anchorMaxX = 1,
        anchorMaxY = 1,
        pivotX = 0.5,
        pivotY = 1
    })

    contentRect.SetField("offsetMin", Vector2.New(0, 0))
    contentRect.SetField("offsetMax", Vector2.New(0, 0))
    contentRect.SetField("anchoredPosition", Vector2.New(0, 0))

    local contentLayoutOptions = Opt(options.contentLayoutGroup, options.contentLayout)
    if contentLayoutOptions == nil then
        contentLayoutOptions = {
            type = "Vertical",
            spacing = Opt(options.itemSpacing, 6),
            childAlignment = Opt(options.childAlignment, "UpperLeft"),
            childControlWidth = true,
            childControlHeight = false,
            childForceExpandWidth = true,
            childForceExpandHeight = false,
            paddingLeft = Opt(options.contentPaddingLeft, 0),
            paddingRight = Opt(options.contentPaddingRight, 0),
            paddingTop = Opt(options.contentPaddingTop, 0),
            paddingBottom = Opt(options.contentPaddingBottom, 0)
        }
    end

    local contentLayoutGroupComp = nil
    if contentLayoutOptions ~= false then
        contentLayoutGroupComp = CreateContentLayoutGroup(contentGO, contentLayoutOptions)
    end

    local contentSizeFitterOptions = Opt(options.contentSizeFitter, {
        horizontalFit = Opt(options.contentHorizontalFit, "Unconstrained"),
        verticalFit = Opt(options.contentVerticalFit, "PreferredSize")
    })

    local contentSizeFitterComp = nil
    if contentSizeFitterOptions ~= false then
        contentSizeFitterComp = CreateContentSizeFitter(contentGO, contentSizeFitterOptions)
    end

    local verticalScrollbarGO, verticalScrollbarRect = CreateRectTransform(scrollGO, "VerticalScrollbar", {
        x = Opt(options.width, 400) * 0.5 - 8,
        y = 0,
        width = 14,
        height = Opt(options.height, 250) - 6,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local vTrackImage = verticalScrollbarGO.AddComponent("UnityEngine.UI.Image")
    local scrollbarBg = ResolveColorFromOptions(options, { r = "scrollbarBgR", g = "scrollbarBgG", b = "scrollbarBgB", a = "scrollbarBgA" }, "Theme.Components.ScrollRect.Scrollbar.Background", {
        r = 0.08,
        g = 0.08,
        b = 0.08,
        a = 0.8
    })
    vTrackImage.SetField("color", Vector4.New(scrollbarBg.r, scrollbarBg.g, scrollbarBg.b, scrollbarBg.a))

    local vHandleGO, vHandleRect = CreateRectTransform(verticalScrollbarGO, "Handle", {
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        anchorMinX = 0,
        anchorMinY = 0,
        anchorMaxX = 1,
        anchorMaxY = 1,
        pivotX = 0.5,
        pivotY = 0.5
    })

    vHandleRect.SetField("offsetMin", Vector2.New(0, 0))
    vHandleRect.SetField("offsetMax", Vector2.New(0, 0))

    local vHandleImage = vHandleGO.AddComponent("UnityEngine.UI.Image")
    local scrollbarHandle = ResolveColorFromOptions(options, { r = "scrollbarHandleR", g = "scrollbarHandleG", b = "scrollbarHandleB", a = "scrollbarHandleA" }, "Theme.Components.ScrollRect.Scrollbar.Handle", {
        r = 0.6,
        g = 0.6,
        b = 0.65,
        a = 0.95
    })
    vHandleImage.SetField("color", Vector4.New(scrollbarHandle.r, scrollbarHandle.g, scrollbarHandle.b, scrollbarHandle.a))

    local vScrollbarComp = verticalScrollbarGO.AddComponent("UnityEngine.UI.Scrollbar")
    vScrollbarComp.SetField("handleRect", vHandleRect)
    vScrollbarComp.SetField("targetGraphic", vHandleImage)
    vScrollbarComp.SetField("direction", "BottomToTop")

    scrollComp.SetField("viewport", viewportRect)
    scrollComp.SetField("content", contentRect)
    scrollComp.SetField("horizontal", Opt(options.horizontal, false))
    scrollComp.SetField("vertical", Opt(options.vertical, true))
    scrollComp.SetField("movementType", Opt(options.movementType, "Clamped"))
    scrollComp.SetField("inertia", Opt(options.inertia, true))
    scrollComp.SetField("scrollSensitivity", Opt(options.scrollSensitivity, 24))
    scrollComp.SetField("elasticity", Opt(options.elasticity, 0.1))
    scrollComp.SetField("decelerationRate", Opt(options.decelerationRate, 0.135))
    scrollComp.SetField("verticalNormalizedPosition", 1)
    scrollComp.SetField("verticalScrollbar", vScrollbarComp)
    scrollComp.SetField("verticalScrollbarVisibility", "AutoHideAndExpandViewport")
    scrollComp.SetField("verticalScrollbarSpacing", -2)
    scrollComp.SetField("viewport", viewportRect)

    local scroll = LuaGUI.GUI_ScrollView.New()
    scroll.scrollGO = scrollGO
    scroll.scrollRect = scrollRect
    scroll.scrollComp = scrollComp
    scroll.viewportGO = viewportGO
    scroll.viewportRect = viewportRect
    scroll.contentGO = contentGO
    scroll.contentRect = contentRect
    scroll.contentLayoutGroup = contentLayoutGroupComp
    scroll.contentSizeFitter = contentSizeFitterComp
    scroll.verticalScrollbarGO = verticalScrollbarGO
    scroll.verticalScrollbarRect = verticalScrollbarRect
    scroll.verticalScrollbarComp = vScrollbarComp

    return scroll
end

function GUITool.CreateToggle(parentGO, options)
    options = options or {}

    local toggleGO, toggleRect = CreateRectTransform(parentGO, "Toggle", options, {
        width = 240,
        height = 36
    })

    local toggleComp = toggleGO.AddComponent("UnityEngine.UI.Toggle")

    local backgroundGO, backgroundRect = CreateRectTransform(toggleGO, "Background", {
        x = Opt(options.indicatorX, -100),
        y = 0,
        width = 24,
        height = 24,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local backgroundImage = backgroundGO.AddComponent("UnityEngine.UI.Image")
    local toggleBg = ResolveColorFromOptions(options, { r = "bgR", g = "bgG", b = "bgB", a = "bgA" }, "Theme.Components.Toggle.Background", {
        r = 0.18,
        g = 0.18,
        b = 0.18,
        a = 1
    })
    backgroundImage.SetField("color", Vector4.New(toggleBg.r, toggleBg.g, toggleBg.b, toggleBg.a))

    local checkmarkGO, checkmarkRect = CreateRectTransform(backgroundGO, "Checkmark", {
        x = 0,
        y = 0,
        width = 16,
        height = 16,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local checkmarkImage = checkmarkGO.AddComponent("UnityEngine.UI.Image")
    local toggleCheck = ResolveColorFromOptions(options, { r = "checkR", g = "checkG", b = "checkB", a = "checkA" }, "Theme.Components.Toggle.Checkmark", {
        r = 0.2,
        g = 0.85,
        b = 0.35,
        a = 1
    })
    checkmarkImage.SetField("color", Vector4.New(toggleCheck.r, toggleCheck.g, toggleCheck.b, toggleCheck.a))

    local toggleTextTheme = GUITool.GetThemeColor("Theme.Components.Toggle.Text", { r = 1, g = 1, b = 1, a = 1 })

    local label = nil
    if Opt(options.showLabel, true) == true then
        label = GUITool.CreateText(toggleGO, {
            text = Opt(options.text, "Toggle"),
            fontSize = Opt(options.fontSize, 20),
            alignment = Opt(options.alignment, "Left"),
            stretch = true,
            paddingLeft = Opt(options.textPaddingLeft, 0),
            paddingRight = Opt(options.textPaddingRight, 0),
            paddingTop = Opt(options.textPaddingTop, 0),
            paddingBottom = Opt(options.textPaddingBottom, 0),
            r = Opt(options.textR, toggleTextTheme.r),
            g = Opt(options.textG, toggleTextTheme.g),
            b = Opt(options.textB, toggleTextTheme.b),
            a = Opt(options.textA, toggleTextTheme.a)
        })
    end

    toggleComp.SetField("targetGraphic", backgroundImage)
    toggleComp.SetField("graphic", checkmarkImage)
    toggleComp.SetField("isOn", Opt(options.isOn, false))

    local toggle = LuaGUI.GUI_Toggle.New()
    toggle.toggleGO = toggleGO
    toggle.toggleRect = toggleRect
    toggle.toggleComp = toggleComp
    toggle.backgroundGO = backgroundGO
    toggle.backgroundRect = backgroundRect
    toggle.checkmarkGO = checkmarkGO
    toggle.checkmarkRect = checkmarkRect
    toggle.label = label
    toggle._lastIsOn = toggleComp.GetField("isOn")

    return toggle
end

function GUITool.CreateInputField(parentGO, options)
    options = options or {}

    local resolvedLineType = options.lineType
    if resolvedLineType == nil then
        if Opt(options.multiLine, false) == true then
            resolvedLineType = "MultiLineNewline"
        else
            resolvedLineType = "SingleLine"
        end
    end

    local resolvedAlignment = options.alignment
    if resolvedAlignment == nil then
        if resolvedLineType == "SingleLine" then
            resolvedAlignment = "Center"
        else
            resolvedAlignment = "UpperLeft"
        end
    end

    local resolvedWordWrap = options.wordWrap
    if resolvedWordWrap == nil then
        resolvedWordWrap = (resolvedLineType ~= "SingleLine")
    end

    local inputGO, inputRect = CreateRectTransform(parentGO, "InputField", options, {
        width = 320,
        height = 42
    })

    local backgroundImage = inputGO.AddComponent("UnityEngine.UI.Image")
    local inputBg = ResolveColorFromOptions(options, { r = "r", g = "g", b = "b", a = "a" }, "Theme.Components.InputField.Background", {
        r = 0.07,
        g = 0.09,
        b = 0.13,
        a = 1
    })
    backgroundImage.SetField("color", Vector4.New(inputBg.r, inputBg.g, inputBg.b, inputBg.a))

    local inputPlaceholderTheme = GUITool.GetThemeColor("Theme.Components.InputField.Placeholder", {
        r = 0.62,
        g = 0.68,
        b = 0.77,
        a = 0.85
    })

    local inputTextTheme = GUITool.GetThemeColor("Theme.Components.InputField.Text", {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    })

    local textAreaGO, textAreaRect = CreateRectTransform(inputGO, "TextArea", {
        x = 0,
        y = 0,
        width = Opt(options.width, 320),
        height = Opt(options.height, 42)
    })
    StretchRect(textAreaRect, Opt(options.paddingLeft, 8), Opt(options.paddingRight, 8), Opt(options.paddingTop, 6),
        Opt(options.paddingBottom, 6))

    local placeholder = GUITool.CreateText(textAreaGO, {
        text = Opt(options.placeholder, "Input..."),
        fontSize = Opt(options.fontSize, 18),
        alignment = resolvedAlignment,
        wordWrap = resolvedWordWrap,
        stretch = true,
        r = Opt(options.placeholderR, inputPlaceholderTheme.r),
        g = Opt(options.placeholderG, inputPlaceholderTheme.g),
        b = Opt(options.placeholderB, inputPlaceholderTheme.b),
        a = Opt(options.placeholderA, inputPlaceholderTheme.a)
    })

    local text = GUITool.CreateText(textAreaGO, {
        text = Opt(options.text, ""),
        fontSize = Opt(options.fontSize, 18),
        alignment = resolvedAlignment,
        wordWrap = resolvedWordWrap,
        stretch = true,
        r = Opt(options.textR, inputTextTheme.r),
        g = Opt(options.textG, inputTextTheme.g),
        b = Opt(options.textB, inputTextTheme.b),
        a = Opt(options.textA, inputTextTheme.a)
    })

    local inputComp = inputGO.AddComponent("TMPro.TMP_InputField")
    inputComp.SetField("targetGraphic", backgroundImage)
    inputComp.SetField("textViewport", textAreaRect)
    inputComp.SetField("textComponent", text.textComp)
    inputComp.SetField("placeholder", placeholder.textComp)
    inputComp.SetField("lineType", ResolveInputLineTypeValue(resolvedLineType))
    inputComp.SetField("lineLimit", Opt(options.lineLimit, 0))
    inputComp.SetField("readOnly", Opt(options.readOnly, false))
    if options.contentType ~= nil then
        inputComp.SetField("contentType", options.contentType)
    end
    inputComp.SetField("characterLimit", Opt(options.characterLimit, 0))
    inputComp.SetField("text", Opt(options.text, ""))

    local inputField = LuaGUI.GUI_InputField.New()
    inputField.inputGO = inputGO
    inputField.inputRect = inputRect
    inputField.inputComp = inputComp
    inputField.backgroundImage = backgroundImage
    inputField.textAreaGO = textAreaGO
    inputField.textRect = textAreaRect
    inputField.textComp = text.textComp
    inputField.placeholderComp = placeholder.textComp
    inputField.onTextChanged = inputComp.GetField("onValueChanged")
    inputField.onValueChanged = inputComp.GetField("onValueChanged")
    inputField.onEndEdit = inputComp.GetField("onEndEdit")
    inputField._lastText = inputComp.GetField("text")

    return inputField
end

function GUITool.CreateSlider(parentGO, options)
    options = options or {}

    local function FormatSliderValue(value)
        if Opt(options.wholeNumbers, false) == true then
            return basicModule.tostring(math.floor(value + 0.5))
        end

        local decimals = Opt(options.showValueDecimals, 2)
        local format = "%0." .. basicModule.tostring(decimals) .. "f"
        if(value == nil) then
            return ""
        end
        return string.format(format, value)
    end

    local sliderGO, sliderRect = CreateRectTransform(parentGO, "Slider", options, {
        width = 320,
        height = 32
    })

    local backgroundGO, backgroundRect = CreateRectTransform(sliderGO, "Background", {
        x = 0,
        y = 0,
        width = Opt(options.width, 320),
        height = 8,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })
    local backgroundImage = backgroundGO.AddComponent("UnityEngine.UI.Image")
    local sliderBg = ResolveColorFromOptions(options, { r = "bgR", g = "bgG", b = "bgB", a = "bgA" }, "Theme.Components.Slider.Background", {
        r = 0.12,
        g = 0.12,
        b = 0.12,
        a = 1
    })
    backgroundImage.SetField("color", Vector4.New(sliderBg.r, sliderBg.g, sliderBg.b, sliderBg.a))

    local fillAreaGO, fillAreaRect = CreateRectTransform(sliderGO, "FillArea", {
        x = 0,
        y = 0,
        width = Opt(options.width, 320),
        height = 8,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local fillGO, fillRect = CreateRectTransform(fillAreaGO, "Fill", {
        x = 0,
        y = 0,
        width = 0,
        height = 8,
        anchorMinX = 0,
        anchorMinY = 0,
        anchorMaxX = 0,
        anchorMaxY = 1,
        pivotX = 0,
        pivotY = 0.5
    })
    local fillImage = fillGO.AddComponent("UnityEngine.UI.Image")
    local sliderFill = ResolveColorFromOptions(options, { r = "fillR", g = "fillG", b = "fillB", a = "fillA" }, "Theme.Components.Slider.Fill", {
        r = 0.25,
        g = 0.65,
        b = 1,
        a = 1
    })
    fillImage.SetField("color", Vector4.New(sliderFill.r, sliderFill.g, sliderFill.b, sliderFill.a))

    local handleAreaGO, handleAreaRect = CreateRectTransform(sliderGO, "HandleSlideArea", {
        x = 0,
        y = 0,
        width = Opt(options.width, 320),
        height = 22,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })

    local handleGO, handleRect = CreateRectTransform(handleAreaGO, "Handle", {
        x = 0,
        y = 0,
        width = 10,
        height = 3,
        anchorMinX = 0.5,
        anchorMinY = 0.5,
        anchorMaxX = 0.5,
        anchorMaxY = 0.5,
        pivotX = 0.5,
        pivotY = 0.5
    })
    local handleImage = handleGO.AddComponent("UnityEngine.UI.Image")
    local sliderHandle = ResolveColorFromOptions(options, { r = "handleR", g = "handleG", b = "handleB", a = "handleA" }, "Theme.Components.Slider.Handle", {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    })
    handleImage.SetField("color", Vector4.New(sliderHandle.r, sliderHandle.g, sliderHandle.b, sliderHandle.a))

    local sliderComp = sliderGO.AddComponent("UnityEngine.UI.Slider")
    sliderComp.SetField("targetGraphic", handleImage)
    sliderComp.SetField("fillRect", fillRect)
    sliderComp.SetField("handleRect", handleRect)
    sliderComp.SetField("direction", Opt(options.direction, "LeftToRight"))
    sliderComp.SetField("minValue", Opt(options.minValue, 0))
    sliderComp.SetField("maxValue", Opt(options.maxValue, 1))
    sliderComp.SetField("wholeNumbers", Opt(options.wholeNumbers, false))
    sliderComp.SetField("value", Opt(options.value, 0.5))

    local showValueEnabled = Opt(options.ShowValue, Opt(options.showValue, false))
    local valueLabel = nil

    local function UpdateShowValue(value)
        if valueLabel ~= nil then
            valueLabel.SetValue(FormatSliderValue(value))
        end
    end

    if showValueEnabled == true then
        local valueLabelTheme = GUITool.GetThemeColor("Theme.Components.Slider.ValueLabel", {
            r = 0.9,
            g = 0.95,
            b = 1,
            a = 1
        })

        valueLabel = GUITool.CreateText(sliderGO, {
            text = FormatSliderValue(Opt(options.value, 0.5)),
            x = Opt(options.showValueX, Opt(options.width, 320) * 0.5 + 52),
            y = Opt(options.showValueY, 0),
            width = Opt(options.showValueWidth, 96),
            height = Opt(options.showValueHeight, 28),
            alignment = Opt(options.showValueAlignment, "Left"),
            fontSize = Opt(options.showValueFontSize, 16),
            r = Opt(options.showValueR, valueLabelTheme.r),
            g = Opt(options.showValueG, valueLabelTheme.g),
            b = Opt(options.showValueB, valueLabelTheme.b),
            a = Opt(options.showValueA, valueLabelTheme.a)
        })
    end

    local slider = LuaGUI.GUI_Slider.New()
    slider.sliderGO = sliderGO
    slider.sliderRect = sliderRect
    slider.sliderComp = sliderComp
    slider.backgroundGO = backgroundGO
    slider.backgroundRect = backgroundRect
    slider.fillAreaGO = fillAreaGO
    slider.fillAreaRect = fillAreaRect
    slider.fillGO = fillGO
    slider.fillRect = fillRect
    slider.handleAreaGO = handleAreaGO
    slider.handleAreaRect = handleAreaRect
    slider.handleGO = handleGO
    slider.handleRect = handleRect
    slider.valueLabel = valueLabel
    slider.UpdateShowValue = UpdateShowValue
    slider._lastValue = sliderComp.GetField("value")

    if showValueEnabled == true and LuaGUI.GUIValueUpdater ~= nil and basicModule.type(LuaGUI.GUIValueUpdater.AddListener) == "function" then
        slider.showValueListener = LuaGUI.GUIValueUpdater.AddListener(slider, function(value)
            slider.UpdateShowValue(value)
        end)
    end

    return slider
end

return GUITool
