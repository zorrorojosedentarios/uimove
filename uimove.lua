local addonName, addon = ...

UIMoveDB = UIMoveDB or {}

local isUnlocked = false
local isSettingPoint = false
local overlays = {}
local gridFrame
local controlPanel

local framesToMove = {
    { name = "PlayerFrame", label = "Marco de Jugador" },
    { name = "TargetFrame", label = "Marco de Objetivo" },
    { name = "TargetFrameToT", label = "Objetivo de Objetivo" },
    { name = "FocusFrame", label = "Marco de Foco" },
    { name = "FocusFrameToT", label = "Objetivo de Foco" },
    { name = "MinimapCluster", label = "Minimapa" },
    { name = "MainMenuBar", label = "Barras de Acción" },
    { name = "VehicleMenuBar", label = "Barra de Vehículo" },
    { name = "CastingBarFrame", label = "Barra de Lanzamiento" },
    { name = "BuffFrame", label = "Marco de Beneficios" },
    { name = "PartyMemberFrame1", label = "Grupo 1" },
    { name = "PartyMemberFrame2", label = "Grupo 2" },
    { name = "PartyMemberFrame3", label = "Grupo 3" },
    { name = "PartyMemberFrame4", label = "Grupo 4" },
    { name = "ChatFrame1", label = "Chat Principal" },
    { name = "WatchFrame", label = "Objetivos / Misiones" },
    { name = "DurabilityFrame", label = "Durabilidad" },
    { name = "GhostFrame", label = "Liberar Espíritu" },
    { name = "VehicleSeatIndicator", label = "Asientos Vehículo" },
    { name = "UIMoveTooltipAnchor", label = "Tooltip / Información" },
    { name = "UIErrorsFrame", label = "Mensajes de Error" },
    { name = "RaidWarningFrame", label = "Avisos de Banda" },
    { name = "LootFrame", label = "Objetos / Botín" },
    { name = "MirrorTimer1", label = "Barra de Respiración" },
    { name = "PetFrame", label = "Marco de Mascota" },
    { name = "Boss1TargetFrame", label = "Jefe 1" },
    { name = "Boss2TargetFrame", label = "Jefe 2" },
    { name = "Boss3TargetFrame", label = "Jefe 3" },
    { name = "Boss4TargetFrame", label = "Jefe 4" },
    { name = "PetActionBarFrame", label = "Barra de Mascota" },
    { name = "ShapeshiftBarFrame", label = "Barra de Estados" },
    { name = "RuneFrame", label = "Runas (DK)" },
    { name = "MainMenuExpBar", label = "Barra de Experiencia" },
    { name = "ReputationWatchBar", label = "Barra de Reputación" },
}

-- Crear un ancla para el Tooltip (ya que este cambia de tamaño constantemente)
local tooltipAnchor = CreateFrame("Frame", "UIMoveTooltipAnchor", UIParent)
tooltipAnchor:SetSize(200, 100)
tooltipAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -15, 100)

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    if UIMoveDB["UIMoveTooltipAnchor"] then
        local pos = UIMoveDB["UIMoveTooltipAnchor"]
        if pos.hidden then
            tooltip:Hide()
            return
        end
        tooltip:SetOwner(parent, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIMoveTooltipAnchor, "BOTTOMRIGHT", 0, 0)
    end
end)

local function SavePosition(frameName)
    local frame = _G[frameName]
    if not frame then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    local relativeToName = "UIParent"
    if relativeTo and relativeTo.GetName and relativeTo:GetName() then
        relativeToName = relativeTo:GetName()
    end
    
    local current = UIMoveDB[frameName] or {}
    current[1] = point
    current[2] = relativeToName
    current[3] = relativePoint
    current[4] = xOfs
    current[5] = yOfs
    -- Mantener el estado 'hidden' si ya existía
    UIMoveDB[frameName] = current
end

local function HookVisibility(frame)
    if frame.uimove_hooked then return end
    frame.uimove_hooked = true
    hooksecurefunc(frame, "Show", function(self)
        local name = self:GetName()
        if not isUnlocked and UIMoveDB[name] and UIMoveDB[name].hidden then
            self:Hide()
        end
    end)
end

local function RestoreFramePosition(frameName)
    if isSettingPoint or not UIMoveDB[frameName] then return end
    local frame = _G[frameName]
    if not frame then return end
    
    local pos = UIMoveDB[frameName]
    isSettingPoint = true
    frame:ClearAllPoints()
    local relativeTo = _G[pos[2]] or UIParent
    frame:SetPoint(pos[1], relativeTo, pos[3], pos[4], pos[5])
    isSettingPoint = false
end

local function ApplySavedPositions()
    -- Limpiar Arte Barra Principal por si se guardó por error y asegurar que siga a MainMenuBar
    UIMoveDB["MainMenuBarArtFrame"] = nil
    if MainMenuBarArtFrame and MainMenuBar then
        MainMenuBarArtFrame:ClearAllPoints()
        MainMenuBarArtFrame:SetAllPoints(MainMenuBar)
    end

    for frameName, pos in pairs(UIMoveDB) do
        local frame = _G[frameName]
        if frame then
            frame:SetMovable(true)
            frame:SetUserPlaced(true)
            
            RestoreFramePosition(frameName)
            HookVisibility(frame)
            
            if pos.hidden then
                frame:Hide()
            end
            
            -- Bloquear el reposicionamiento automático de Blizzard
            if not frame.uimove_point_hooked then
                frame.uimove_point_hooked = true
                hooksecurefunc(frame, "SetPoint", function(self)
                    if not isUnlocked and not isSettingPoint and UIMoveDB[frameName] then
                        RestoreFramePosition(frameName)
                    end
                end)
            end
        end
    end
end

local function DisableBlizzardManagement()
    if not UIPARENT_MANAGED_FRAME_POSITIONS then return end
    for _, info in ipairs(framesToMove) do
        if UIPARENT_MANAGED_FRAME_POSITIONS[info.name] then
            UIPARENT_MANAGED_FRAME_POSITIONS[info.name] = nil
        end
    end
end

local gridLines = {}
local function CreateGrid()
    if not gridFrame then
        gridFrame = CreateFrame("Frame", "UIMoveGrid", UIParent)
        gridFrame:SetAllPoints(UIParent)
        gridFrame:SetFrameStrata("BACKGROUND")
    end
    
    for _, line in ipairs(gridLines) do
        line:Hide()
    end
    
    local size = UIMoveDB.gridSize or 32
    local width = GetScreenWidth() * UIParent:GetEffectiveScale()
    local height = GetScreenHeight() * UIParent:GetEffectiveScale()
    
    local lineIdx = 1
    local function GetLine()
        if not gridLines[lineIdx] then
            local line = gridFrame:CreateTexture(nil, "BACKGROUND")
            gridLines[lineIdx] = line
        end
        local line = gridLines[lineIdx]
        line:ClearAllPoints()
        line:SetTexture(0, 0, 0, 0.5) -- Reset texture in case it was red
        line:Show()
        lineIdx = lineIdx + 1
        return line
    end
    
    for i = 0, width, size do
        local line = GetLine()
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", i, 0)
        line:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", i, 0)
        line:SetWidth(1)
    end
    for i = 0, height, size do
        local line = GetLine()
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -i)
        line:SetPoint("TOPRIGHT", gridFrame, "TOPRIGHT", 0, -i)
        line:SetHeight(1)
    end
    
    local centerV = GetLine()
    centerV:SetTexture(1, 0, 0, 0.8)
    centerV:SetPoint("TOP", gridFrame, "TOP", 0, 0)
    centerV:SetPoint("BOTTOM", gridFrame, "BOTTOM", 0, 0)
    centerV:SetWidth(1)
    
    local centerH = GetLine()
    centerH:SetTexture(1, 0, 0, 0.8)
    centerH:SetPoint("LEFT", gridFrame, "LEFT", 0, 0)
    centerH:SetPoint("RIGHT", gridFrame, "RIGHT", 0, 0)
    centerH:SetHeight(1)
    
    gridFrame:Hide()
end

local function CreateControlPanel()
    if controlPanel then return end
    
    controlPanel = CreateFrame("Frame", "UIMoveControlPanel", UIParent)
    controlPanel:SetSize(400, 170)
    controlPanel:SetPoint("TOP", 0, -100)
    controlPanel:SetFrameStrata("DIALOG")
    
    controlPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    controlPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    controlPanel:SetBackdropBorderColor(1, 0.5, 0, 1)
    
    local title = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("UIMove")
    title:SetTextColor(1, 0.5, 0)
    
    local desc = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", 0, -40)
    desc:SetWidth(380)
    desc:SetJustifyH("CENTER")
    desc:SetText("Fijadores desbloqueados. Muévelos ahora y haz clic en Bloquear cuando termines.\nClic Derecho para Ocultar/Mostrar un recuadro.")
    
    -- Checkbox Imán
    local snapCheck = CreateFrame("CheckButton", "UIMoveSnapCheck", controlPanel, "UICheckButtonTemplate")
    snapCheck:SetPoint("TOPLEFT", 15, -75)
    snapCheck:SetSize(26, 26)
    _G[snapCheck:GetName().."Text"]:SetText(" Imán a cuadrícula")
    if UIMoveDB.snapToGrid == nil then UIMoveDB.snapToGrid = false end
    snapCheck:SetChecked(UIMoveDB.snapToGrid)
    snapCheck:SetScript("OnClick", function(self)
        UIMoveDB.snapToGrid = self:GetChecked()
    end)
    
    -- Checkbox Ventanas Libres
    local freeMoveCheck = CreateFrame("CheckButton", "UIMoveFreeMoveCheck", controlPanel, "UICheckButtonTemplate")
    freeMoveCheck:SetPoint("TOPLEFT", 15, -100)
    freeMoveCheck:SetSize(26, 26)
    _G[freeMoveCheck:GetName().."Text"]:SetText(" Ventanas Libres (Bolsas, etc.)")
    if UIMoveDB.freeMoveWindows == nil then UIMoveDB.freeMoveWindows = true end
    freeMoveCheck:SetChecked(UIMoveDB.freeMoveWindows)
    freeMoveCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            UIMoveDB.freeMoveWindows = true
        else
            UIMoveDB.freeMoveWindows = false
        end
    end)
    
    -- Grid Size
    local gridSizeText = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gridSizeText:SetPoint("TOPRIGHT", -75, -80)
    gridSizeText:SetText("Rejilla: " .. (UIMoveDB.gridSize or 32))
    
    local gridMinus = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    gridMinus:SetSize(20, 20)
    gridMinus:SetPoint("RIGHT", gridSizeText, "LEFT", -5, 0)
    gridMinus:SetText("-")
    gridMinus:SetScript("OnClick", function()
        local size = (UIMoveDB.gridSize or 32) - 4
        if size < 8 then size = 8 end
        UIMoveDB.gridSize = size
        gridSizeText:SetText("Rejilla: " .. size)
        CreateGrid()
        if isUnlocked then gridFrame:Show() end
    end)
    
    local gridPlus = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    gridPlus:SetSize(20, 20)
    gridPlus:SetPoint("LEFT", gridSizeText, "RIGHT", 5, 0)
    gridPlus:SetText("+")
    gridPlus:SetScript("OnClick", function()
        local size = (UIMoveDB.gridSize or 32) + 4
        if size > 128 then size = 128 end
        UIMoveDB.gridSize = size
        gridSizeText:SetText("Rejilla: " .. size)
        CreateGrid()
        if isUnlocked then gridFrame:Show() end
    end)
    
    local lockBtn = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    lockBtn:SetSize(120, 25)
    lockBtn:SetPoint("BOTTOMRIGHT", controlPanel, "BOTTOM", -5, 15)
    lockBtn:SetText("Bloquear")
    lockBtn:SetScript("OnClick", function()
        UIMove_ToggleLock()
    end)
    
    local resetBtn = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("BOTTOMLEFT", controlPanel, "BOTTOM", 5, 15)
    resetBtn:SetText("Resetear")
    resetBtn:SetScript("OnClick", function()
        UIMoveDB = {}
        ReloadUI()
    end)
    
    controlPanel:SetMovable(true)
    controlPanel:EnableMouse(true)
    controlPanel:RegisterForDrag("LeftButton")
    controlPanel:SetScript("OnDragStart", controlPanel.StartMoving)
    controlPanel:SetScript("OnDragStop", controlPanel.StopMovingOrSizing)
    
    controlPanel:Hide()
end

local function CreateOverlay(frameInfo)
    local frameName = frameInfo.name
    local frame = _G[frameName]
    if not frame then return end
    
    local overlay = CreateFrame("Frame", "UIMoveOverlay_" .. frameName, UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    
    if frameName == "MainMenuBar" then
        -- MainMenuBar occupies 1024 width
        overlay:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
        overlay:SetSize(1024, 53)
    elseif frameName == "VehicleMenuBar" then
        overlay:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
        overlay:SetSize(900, 100)
    elseif frameName == "MainMenuExpBar" or frameName == "ReputationWatchBar" then
        overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
        overlay:SetSize(1024, 12)
    elseif frameName == "MinimapCluster" then
        overlay:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        overlay:SetSize(140, 140)
    elseif frameName == "UIErrorsFrame" or frameName == "RaidWarningFrame" then
        overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
        overlay:SetSize(300, 60)
    elseif frameName == "LootFrame" then
        overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        overlay:SetSize(170, 240)
    elseif frameName == "MirrorTimer1" then
        overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
        overlay:SetSize(206, 26)
    elseif frameName == "WatchFrame" then
        overlay:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        overlay:SetSize(230, 200)
    elseif frameName == "UIMoveTooltipAnchor" then
        overlay:SetAllPoints(frame)
    else
        overlay:SetAllPoints(frame)
    end
    
    overlay:EnableMouse(true)
    overlay:SetMovable(true)
    overlay:RegisterForDrag("LeftButton")
    
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    overlay:SetBackdropColor(0, 0.8, 0, 0.3)
    overlay:SetBackdropBorderColor(1, 0.5, 0, 1)

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(frameInfo.label)
    text:SetTextColor(1, 1, 1)
    overlay.text = text
    
    -- Inicializar estado visual si ya está oculto
    if UIMoveDB[frameName] and UIMoveDB[frameName].hidden then
        overlay:SetBackdropColor(0.8, 0, 0, 0.5)
        text:SetText(frameInfo.label .. " (Oculto)")
    end
    
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            local db = UIMoveDB[frameName]
            if not db then
                SavePosition(frameName)
                db = UIMoveDB[frameName]
            end
            db.hidden = not db.hidden
            if db.hidden then
                self:SetBackdropColor(0.8, 0, 0, 0.5)
                self.text:SetText(frameInfo.label .. " (Oculto)")
            else
                self:SetBackdropColor(0, 0.8, 0, 0.3)
                self.text:SetText(frameInfo.label)
            end
        end
    end)

    overlay:SetScript("OnDragStart", function(self)
        frame:SetMovable(true)
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self.dragStartX = cx / scale
        self.dragStartY = cy / scale
        
        -- Usar fallbacks para evitar errores si GetLeft/GetTop devuelven nil
        local left = frame:GetLeft() or 0
        local top = frame:GetTop() or 0
        
        -- Si es 0, intentar obtenerlo de los puntos de anclaje
        if left == 0 and top == 0 then
            local _, _, _, x, y = frame:GetPoint()
            left = x or 0
            top = y or 0
        end
        
        self.frameStartX = left
        self.frameStartY = top
        
        self:SetScript("OnUpdate", function()
            if not self.frameStartX or not self.frameStartY then return end
            
            local nx, ny = GetCursorPosition()
            local newX = self.frameStartX + ((nx / scale) - self.dragStartX)
            local newY = self.frameStartY + ((ny / scale) - self.dragStartY)
            
            if UIMoveDB.snapToGrid then
                local grid = UIMoveDB.gridSize or 32
                newX = math.floor(newX / grid + 0.5) * grid
                newY = math.floor(newY / grid + 0.5) * grid
            end
            
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newX, newY)
        end)
    end)
    
    overlay:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        frame:StopMovingOrSizing()
        SavePosition(frameName)
    end)
    
    overlay:Hide()
    return overlay
end

function UIMove_ToggleLock()
    isUnlocked = not isUnlocked
    
    CreateGrid()
    CreateControlPanel()
    
    if isUnlocked then
        gridFrame:Show()
        controlPanel:Show()
        
        for _, info in ipairs(framesToMove) do
            local frameName = info.name
            local frame = _G[frameName]
            if frame then
                frame:SetMovable(true)
                if not overlays[frameName] then
                    overlays[frameName] = CreateOverlay(info)
                end
                if overlays[frameName] then
                    overlays[frameName]:Show()
                end
            end
        end
    else
        gridFrame:Hide()
        controlPanel:Hide()
        for _, overlay in pairs(overlays) do
            overlay:Hide()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", function(self, event)
    DisableBlizzardManagement()
    ApplySavedPositions()
end)

local function UIMove_SlashHandler(msg)
    msg = msg and msg:match("^%s*(.-)%s*$"):lower() or ""
    if msg == "h" or msg == "help" or msg == "ayuda" then
        print("|cFFFF7D0AUIMove (Guía Rápida)|r")
        print("  |cFF00FF00/uimove|r - Desbloquea la interfaz. Arrastra los recuadros verdes para fijarlos donde quieras.")
        print("    - |cFF00FFFFClic Izquierdo|r sobre el recuadro: Arrastra.")
        print("    - |cFF00FFFFClic Derecho|r sobre el recuadro: Oculta o muestra ese elemento permanentemente.")
        print("  |cFF00FF00/uimove ver|r - Muestra la versión actual del addon.")
        print("  |cFF00FF00Funciones Integradas:|r")
        print("    - Desvinculación de paneles: Tus cuadros son ahora totalmente independientes.")
        print("    - Movimiento Libre: Ahora puedes arrastrar bolsas, mercaderes o tu panel de personaje mientras juegas (como si fueran ventanas de PC).")
        print("  |cFF888888Para más detalles e información avanzada, por favor lee el archivo README.md incluido en la carpeta del addon.|r")
    elseif msg == "ver" or msg == "version" then
        local version = GetAddOnMetadata("uimove", "Version") or "Desconocida"
        print("|cFFFF7D0AUIMove|r: Versión " .. version)
    else
        UIMove_ToggleLock()
    end
end

SLASH_UIMOVE1 = "/uimove"
SlashCmdList["UIMOVE"] = UIMove_SlashHandler

-- Refuerzo especial para MainMenuBar y otros marcos persistentes
if MainMenuBar then
    MainMenuBar:SetMovable(true)
    MainMenuBar:SetUserPlaced(true)
end

-- ==============================================
-- MOVIMIENTO LIBRE (VENTANAS ESTÁNDAR)
-- ==============================================
local function MakeDraggable(frame, moveFrame)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame or frame.uimove_draggable then return end
    
    moveFrame = moveFrame or frame
    if type(moveFrame) == "string" then moveFrame = _G[moveFrame] end
    if not moveFrame then return end

    frame.uimove_draggable = true
    
    moveFrame:SetMovable(true)
    moveFrame:SetClampedToScreen(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    local origDragStart = frame:GetScript("OnDragStart")
    frame:SetScript("OnDragStart", function(self, button)
        if UIMoveDB.freeMoveWindows == false then return end
        moveFrame:StartMoving()
        if origDragStart then origDragStart(self, button) end
    end)

    local origDragStop = frame:GetScript("OnDragStop")
    frame:SetScript("OnDragStop", function(self, button)
        moveFrame:StopMovingOrSizing()
        if origDragStop then origDragStop(self, button) end
    end)
end

local draggableFrames = {
    {"CharacterFrame", nil},
    {"PaperDollFrame", "CharacterFrame"},
    {"ReputationFrame", "CharacterFrame"},
    {"SkillFrame", "CharacterFrame"},
    {"TokenFrame", "CharacterFrame"},
    {"PetPaperDollFrame", "CharacterFrame"},
    {"CompanionFrame", "CharacterFrame"},

    {"SpellBookFrame", nil},
    
    {"QuestLogFrame", nil},
    {"QuestLogDetailScrollFrame", "QuestLogFrame"},
    {"QuestLogScrollFrame", "QuestLogFrame"},

    {"FriendsFrame", nil},
    {"FriendsListFrame", "FriendsFrame"},
    {"IgnoreListFrame", "FriendsFrame"},
    {"WhoFrame", "FriendsFrame"},
    {"GuildFrame", "FriendsFrame"},
    {"ChannelFrame", "FriendsFrame"},

    {"MerchantFrame", nil},
    {"BankFrame", nil},
    {"TradeFrame", nil},
    {"MailFrame", nil},
    {"GossipFrame", nil},
    {"DressUpFrame", nil},
    {"MacroFrame", nil},
    {"TaxiFrame", nil},
    
    {"AuctionFrame", nil},
    {"AuctionFrameBrowse", "AuctionFrame"},
    {"AuctionFrameBid", "AuctionFrame"},
    {"AuctionFrameAuctions", "AuctionFrame"},
    
    {"PlayerTalentFrame", nil},
    {"PlayerTalentFrameTalents", "PlayerTalentFrame"},
    {"PlayerTalentFramePets", "PlayerTalentFrame"},
}

local dragEvent = CreateFrame("Frame")
dragEvent:RegisterEvent("PLAYER_LOGIN")
dragEvent:RegisterEvent("ADDON_LOADED")
dragEvent:SetScript("OnEvent", function()
    -- Ventanas estándar y sub-pestañas
    for _, info in ipairs(draggableFrames) do
        MakeDraggable(info[1], info[2])
    end
    -- Bolsas
    for i = 1, 13 do
        MakeDraggable("ContainerFrame"..i)
    end
end)

-- ==============================================
-- MINIMAP BUTTON (UIMOVE)
-- ==============================================
local minimapButton = CreateFrame("Button", "UIMoveMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexture("Interface\\AddOns\\uimove\\uimove.tga")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
minimapButton.icon = icon

minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapButtonPos(angle)
    local radius = 80
    -- math.cos and math.sin take radians
    local x = 52 - (radius * math.cos(angle))
    local y = (radius * math.sin(angle)) - 52
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", x, y)
end

minimapButton:RegisterForDrag("RightButton", "LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    self.isDragging = false
end)

minimapButton:SetScript("OnUpdate", function(self)
    if self.isDragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        
        local angle = math.atan2(py - my, px - mx)
        UpdateMinimapButtonPos(angle)
        
        UIMoveDB = UIMoveDB or {}
        UIMoveDB.MinimapAngle = angle
    end
end)

minimapButton:SetScript("OnClick", function(self, button)
    UIMove_ToggleLock()
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFFFF7D0AUIMove|r")
    GameTooltip:AddLine("Clic izquierdo para bloquear/desbloquear los marcos.", 1, 1, 1)
    GameTooltip:AddLine("Arrastra para mover este icono por el minimapa.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

local mEvent = CreateFrame("Frame")
mEvent:RegisterEvent("PLAYER_LOGIN")
mEvent:SetScript("OnEvent", function()
    local angle = (UIMoveDB and UIMoveDB.MinimapAngle) or math.rad(225)
    UpdateMinimapButtonPos(angle)
end)

