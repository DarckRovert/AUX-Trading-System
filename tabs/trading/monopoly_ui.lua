module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- MONOPOLY UI - Interfaz Visual para Sistema de Monopolios
-- Creado por: Elnazzareno (DarckRovert)
-- Clan: El Séquito del Terror
-- ============================================================================

aux.print('|cFFFFD700[MONOPOLY_UI]|r Interfaz de monopolios cargada')

-- ============================================================================
-- Variables
-- ============================================================================

local monopoly_frame = nil
local monopoly_candidates = {}
local selected_candidate = nil
local current_view = 'candidates'  -- 'candidates', 'active', 'watchlist', 'history'

-- Colores
local COLORS = {
    gold = {1.0, 0.82, 0.0, 1},
    green = {0.2, 0.8, 0.2, 1},
    red = {0.8, 0.2, 0.2, 1},
    yellow = {1.0, 0.8, 0.0, 1},
    white = {1, 1, 1, 1},
    gray = {0.6, 0.6, 0.6, 1},
    bg_dark = {0.05, 0.05, 0.08, 0.95},
    bg_medium = {0.1, 0.1, 0.12, 0.9},
    border = {0.3, 0.3, 0.35, 1},
}

-- ============================================================================
-- Funciones de Utilidad (Local - frame.lua no cargado aún)
-- ============================================================================

local function create_backdrop(frame, bg, border, edge)
    edge = edge or 1
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = edge,
        insets = {left = edge, right = edge, top = edge, bottom = edge}
    })
    if bg then frame:SetBackdropColor(unpack(bg)) end
    if border then frame:SetBackdropBorderColor(unpack(border)) end
end

local function create_text(parent, text, size, color, anchor, rel, relp, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12)
    if color then fs:SetTextColor(unpack(color)) end
    fs:SetText(text or "")
    if anchor then fs:SetPoint(anchor, rel or parent, relp or anchor, x or 0, y or 0) end
    return fs
end

local function create_button(parent, text, width, height, color)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width)
    btn:SetHeight(height)
    create_backdrop(btn, color or COLORS.bg_medium, COLORS.border, 1)
    btn.btn_color = color or COLORS.bg_medium
    local txt = create_text(btn, text, 10, COLORS.white, "CENTER")
    btn.label = txt
    btn:SetScript("OnEnter", function()
        local c = this.btn_color
        create_backdrop(this, {c[1]+0.1, c[2]+0.1, c[3]+0.1, 1}, COLORS.border, 1)
    end)
    btn:SetScript("OnLeave", function()
        create_backdrop(this, this.btn_color, COLORS.border, 1)
    end)
    return btn
end

local function format_gold(copper)
    if not copper or copper == 0 then return "|cFF8888880c|r" end
    copper = math.floor(copper)
    local negative = copper < 0
    copper = math.abs(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    local result = ""
    if negative then result = "-" end
    if gold > 0 then result = result .. "|cFFFFD700" .. gold .. "g|r " end
    if silver > 0 or gold > 0 then result = result .. "|cFFC0C0C0" .. silver .. "s|r " end
    if cop > 0 or (gold == 0 and silver == 0) then result = result .. "|cFFB87333" .. cop .. "c|r" end
    return result
end

local function get_score_color(score)
    if score >= 70 then return "|cFF00FF00"
    elseif score >= 50 then return "|cFF88FF00"
    elseif score >= 35 then return "|cFFFFFF00"
    else return "|cFFFF4444" end
end

local function get_score_stars(score)
    if score >= 70 then return "⭐⭐⭐⭐"
    elseif score >= 50 then return "⭐⭐⭐"
    elseif score >= 35 then return "⭐⭐"
    else return "⭐" end
end

-- ============================================================================
-- Construir UI del Panel de Monopolio
-- ============================================================================

function M.build_monopoly_panel(parent)
    if monopoly_frame then return monopoly_frame end
    
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    
    -- Barra de navegación superior
    local nav_bar = CreateFrame("Frame", nil, panel)
    nav_bar:SetPoint("TOPLEFT", 10, -10)
    nav_bar:SetPoint("TOPRIGHT", -10, -10)
    nav_bar:SetHeight(35)
    create_backdrop(nav_bar, COLORS.bg_medium, COLORS.border, 1)
    
    -- Botones de navegación
    local btn_candidates = create_button(nav_bar, "Candidatos", 90, 25, {0.2, 0.5, 0.3, 0.9})
    btn_candidates:SetPoint("LEFT", 5, 0)
    btn_candidates:SetScript("OnClick", function()
        current_view = 'candidates'
        M.refresh_monopoly_ui()
    end)
    panel.btn_candidates = btn_candidates
    
    local btn_active = create_button(nav_bar, "Activos", 70, 25, {0.3, 0.4, 0.5, 0.9})
    btn_active:SetPoint("LEFT", btn_candidates, "RIGHT", 5, 0)
    btn_active:SetScript("OnClick", function()
        current_view = 'active'
        M.refresh_monopoly_ui()
    end)
    panel.btn_active = btn_active
    
    local btn_watchlist = create_button(nav_bar, "Watchlist", 80, 25, {0.3, 0.4, 0.5, 0.9})
    btn_watchlist:SetPoint("LEFT", btn_active, "RIGHT", 5, 0)
    btn_watchlist:SetScript("OnClick", function()
        current_view = 'watchlist'
        M.refresh_monopoly_ui()
    end)
    panel.btn_watchlist = btn_watchlist
    
    local btn_history = create_button(nav_bar, "Historial", 70, 25, {0.3, 0.4, 0.5, 0.9})
    btn_history:SetPoint("LEFT", btn_watchlist, "RIGHT", 5, 0)
    btn_history:SetScript("OnClick", function()
        current_view = 'history'
        M.refresh_monopoly_ui()
    end)
    panel.btn_history = btn_history
    
    -- Botón de escanear
    local btn_scan = create_button(nav_bar, "Buscar Oportunidades", 130, 25, {0.6, 0.4, 0.1, 0.9})
    btn_scan:SetPoint("RIGHT", -5, 0)
    btn_scan:SetScript("OnClick", function()
        M.scan_for_monopoly_candidates()
    end)
    panel.btn_scan = btn_scan
    
    -- Panel de estadísticas
    local stats_panel = CreateFrame("Frame", nil, panel)
    stats_panel:SetPoint("TOPLEFT", 10, -55)
    stats_panel:SetWidth(180)
    stats_panel:SetHeight(100)
    create_backdrop(stats_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(stats_panel, "|cFFFFD700Estadísticas|r", 11, nil, "TOP", stats_panel, "TOP", 0, -8)
    
    panel.stats_total = create_text(stats_panel, "Monopolios: 0", 10, COLORS.white, "TOPLEFT", stats_panel, "TOPLEFT", 10, -28)
    panel.stats_success = create_text(stats_panel, "Exitosos: 0", 10, COLORS.green, "TOPLEFT", stats_panel, "TOPLEFT", 10, -43)
    panel.stats_profit = create_text(stats_panel, "Profit Total: 0g", 10, COLORS.gold, "TOPLEFT", stats_panel, "TOPLEFT", 10, -58)
    panel.stats_roi = create_text(stats_panel, "ROI Promedio: 0%", 10, COLORS.yellow, "TOPLEFT", stats_panel, "TOPLEFT", 10, -73)
    
    panel.stats_panel = stats_panel
    
    -- Panel de detalle (lado derecho arriba)
    local detail_panel = CreateFrame("Frame", nil, panel)
    detail_panel:SetPoint("TOPLEFT", stats_panel, "TOPRIGHT", 10, 0)
    detail_panel:SetPoint("TOPRIGHT", -10, -55)
    detail_panel:SetHeight(100)
    create_backdrop(detail_panel, COLORS.bg_medium, COLORS.border, 1)
    
    panel.detail_title = create_text(detail_panel, "|cFFFFD700Selecciona un item|r", 11, nil, "TOP", detail_panel, "TOP", 0, -8)
    panel.detail_score = create_text(detail_panel, "", 10, COLORS.white, "TOPLEFT", detail_panel, "TOPLEFT", 10, -28)
    panel.detail_sellers = create_text(detail_panel, "", 10, COLORS.white, "TOPLEFT", detail_panel, "TOPLEFT", 10, -43)
    panel.detail_cost = create_text(detail_panel, "", 10, COLORS.white, "TOPLEFT", detail_panel, "TOPLEFT", 10, -58)
    panel.detail_profit = create_text(detail_panel, "", 10, COLORS.white, "TOPLEFT", detail_panel, "TOPLEFT", 10, -73)
    
    -- Botones de acción en detalle
    local btn_start = create_button(detail_panel, "Iniciar Monopolio", 110, 22, {0.2, 0.6, 0.2, 0.9})
    btn_start:SetPoint("TOPRIGHT", detail_panel, "TOPRIGHT", -10, -28)
    btn_start:SetScript("OnClick", function()
        if selected_candidate then
            M.start_monopoly_from_ui(selected_candidate)
        else
            aux.print("|cFFFF0000[MONOPOLY]|r Selecciona un candidato primero")
        end
    end)
    panel.btn_start = btn_start
    
    local btn_watch = create_button(detail_panel, "+ Watchlist", 80, 22, {0.4, 0.4, 0.5, 0.9})
    btn_watch:SetPoint("TOP", btn_start, "BOTTOM", 0, -5)
    btn_watch:SetScript("OnClick", function()
        if selected_candidate then
            M.add_to_watchlist(selected_candidate.item_key, selected_candidate.item_name)
            M.refresh_monopoly_ui()
        end
    end)
    panel.btn_watch = btn_watch
    
    panel.detail_panel = detail_panel
    
    -- Lista de candidatos/items
    local list_header = CreateFrame("Frame", nil, panel)
    list_header:SetPoint("TOPLEFT", 10, -165)
    list_header:SetPoint("TOPRIGHT", -10, -165)
    list_header:SetHeight(22)
    create_backdrop(list_header, {0.12, 0.12, 0.15, 1}, COLORS.border, 1)
    
    create_text(list_header, "Item", 10, COLORS.gray, "LEFT", list_header, "LEFT", 10, 0)
    create_text(list_header, "Score", 10, COLORS.gray, "LEFT", list_header, "LEFT", 180, 0)
    create_text(list_header, "Sellers", 10, COLORS.gray, "LEFT", list_header, "LEFT", 240, 0)
    create_text(list_header, "Stock", 10, COLORS.gray, "LEFT", list_header, "LEFT", 300, 0)
    create_text(list_header, "Costo Total", 10, COLORS.gray, "LEFT", list_header, "LEFT", 360, 0)
    create_text(list_header, "Profit Est.", 10, COLORS.gray, "LEFT", list_header, "LEFT", 450, 0)
    
    -- Container de lista con scroll
    local list_container = CreateFrame("Frame", nil, panel)
    list_container:SetPoint("TOPLEFT", 10, -190)
    list_container:SetPoint("BOTTOMRIGHT", -28, 10) -- Espacio para scrollbar
    create_backdrop(list_container, COLORS.bg_medium, COLORS.border, 1)

    -- Constantes de layout
    local ROW_HEIGHT = 24
    local VISIBLE_ROWS = 13 -- Ajustado a 13 según petición
    
    -- ScrollFrame
    panel.scroll_frame = CreateFrame("ScrollFrame", "AuxMonopolyScrollFrame", list_container, "FauxScrollFrameTemplate")
    panel.scroll_frame:SetPoint("TOPLEFT", 0, 0)
    panel.scroll_frame:SetPoint("BOTTOMRIGHT", -26, 0)
    panel.scroll_frame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, M.refresh_monopoly_ui)
    end)
    
    -- Crear filas
    panel.rows = {}
    
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, list_container)
        row:SetPoint("TOPLEFT", 5, -5 - (i-1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -5, -5 - (i-1) * ROW_HEIGHT)
        row:SetHeight(ROW_HEIGHT)
        row.index = i
        
        -- Fondo alternado
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        -- Fondo de selección
        local select_bg = row:CreateTexture(nil, "BACKGROUND")
        select_bg:SetAllPoints()
        select_bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
        row.select_bg = select_bg
        
        -- Icono
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        -- Textos
        row.name = create_text(row, "", 10, COLORS.white, "LEFT", icon, "RIGHT", 5, 0)
        row.name:SetWidth(130)
        row.score = create_text(row, "", 10, COLORS.white, "LEFT", row, "LEFT", 180, 0)
        row.sellers = create_text(row, "", 10, COLORS.white, "LEFT", row, "LEFT", 240, 0)
        row.stock = create_text(row, "", 10, COLORS.white, "LEFT", row, "LEFT", 300, 0)
        row.cost = create_text(row, "", 10, COLORS.gold, "LEFT", row, "LEFT", 360, 0)
        row.profit = create_text(row, "", 10, COLORS.green, "LEFT", row, "LEFT", 450, 0)
        
        -- Eventos
        row:SetScript("OnClick", function()
            M.select_candidate(this.data)
        end)
        row:SetScript("OnEnter", function()
            this.select_bg:SetVertexColor(0.2, 0.3, 0.4, 0.5)
        end)
        row:SetScript("OnLeave", function()
            if selected_candidate and this.data and this.data.item_key == selected_candidate.item_key then
                this.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0.6)
            else
                this.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
            end
        end)
        
        row:Hide()
        panel.rows[i] = row
    end
    
    panel.no_items = create_text(list_container, "Haz clic en 'Buscar Oportunidades' después de un Full Scan", 11, COLORS.gray, "CENTER")
    
    monopoly_frame = panel
    return panel
end

-- ============================================================================
-- Seleccionar Candidato
-- ============================================================================

function M.select_candidate(candidate)
    if not candidate then return end
    
    selected_candidate = candidate
    
    -- Actualizar panel de detalle
    if monopoly_frame then
        monopoly_frame.detail_title:SetText("|cFFFFD700" .. (candidate.item_name or candidate.item_key) .. "|r")
        monopoly_frame.detail_score:SetText(string.format("Score: %s%d|r %s", 
            get_score_color(candidate.score), candidate.score, get_score_stars(candidate.score)))
        monopoly_frame.detail_sellers:SetText(string.format("Vendedores: |cFFFFFFFF%d|r | Stock: |cFFFFFFFF%d|r", 
            candidate.unique_sellers, candidate.total_stock))
        monopoly_frame.detail_cost:SetText(string.format("Costo total: %s", format_gold(candidate.total_buyout_cost)))
        monopoly_frame.detail_profit:SetText(string.format("Profit potencial: %s (+%.0f%%)", 
            format_gold(candidate.potential_profit), candidate.profit_margin * 100))
    end
    
    -- Actualizar selección visual en filas
    if monopoly_frame and monopoly_frame.rows then
        for i = 1, 13 do
            local row = monopoly_frame.rows[i]
            if row.data and row.data.item_key == candidate.item_key then
                row.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0.6)
            else
                row.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
            end
        end
    end
end

-- ============================================================================
-- Escanear Candidatos
-- ============================================================================

function M.scan_for_monopoly_candidates()
    -- Obtener resultados del último scan
    local scan_results = nil
    
    if M.get_last_scan_results then
        scan_results = M.get_last_scan_results()
    end
    
    if not scan_results or getn(scan_results) == 0 then
        aux.print("|cFFFF0000[MONOPOLY]|r No hay resultados de scan. Haz un Full Scan primero.")
        return
    end
    
    -- Buscar candidatos
    if M.find_monopoly_candidates then
        monopoly_candidates = M.find_monopoly_candidates(scan_results, 30)
        M.refresh_monopoly_ui()
    else
        aux.print("|cFFFF0000[MONOPOLY]|r Función find_monopoly_candidates no disponible")
    end
end

-- ============================================================================
-- Iniciar Monopolio desde UI
-- ============================================================================

function M.start_monopoly_from_ui(candidate)
    if not candidate then return end
    
    if M.start_monopoly then
        M.start_monopoly(
            candidate.item_key,
            candidate.item_name,
            candidate.total_buyout_cost,
            candidate.total_stock,
            candidate.suggested_resale_price
        )
        
        aux.print("|cFF00FF00[MONOPOLY]|r ¡Monopolio iniciado!")
        aux.print(string.format("  Item: %s", candidate.item_name or candidate.item_key))
        aux.print(string.format("  Inversión: %s", format_gold(candidate.total_buyout_cost)))
        aux.print(string.format("  Precio objetivo: %s", format_gold(candidate.suggested_resale_price)))
        
        M.refresh_monopoly_ui()
    end
end

-- ============================================================================
-- Refrescar UI
-- ============================================================================

function M.refresh_monopoly_ui()
    if not monopoly_frame then return end
    
    -- Actualizar estadísticas
    local stats = M.get_monopoly_stats and M.get_monopoly_stats() or {}
    monopoly_frame.stats_total:SetText(string.format("Monopolios: |cFFFFFFFF%d|r", stats.total_monopolies or 0))
    monopoly_frame.stats_success:SetText(string.format("Exitosos: |cFF00FF00%d|r", stats.successful or 0))
    monopoly_frame.stats_profit:SetText(string.format("Profit Total: %s", format_gold(stats.total_profit or 0)))
    
    local avg_roi = 0
    if stats.total_invested and stats.total_invested > 0 then
        avg_roi = ((stats.total_profit or 0) / stats.total_invested) * 100
    end
    monopoly_frame.stats_roi:SetText(string.format("ROI Promedio: |cFFFFFF00%.1f%%|r", avg_roi))
    
    -- Actualizar lista según vista actual
    local items = {}
    
    if current_view == 'candidates' then
        items = monopoly_candidates or {}
    elseif current_view == 'active' then
        local active = M.get_active_monopolies and M.get_active_monopolies() or {}
        for item_key, monopoly in pairs(active) do
            tinsert(items, {
                item_key = item_key,
                item_name = monopoly.item_name,
                score = 0,
                unique_sellers = 0,
                total_stock = monopoly.quantity_bought - monopoly.quantity_sold,
                total_buyout_cost = monopoly.investment,
                potential_profit = (monopoly.target_price * monopoly.quantity_bought) - monopoly.investment,
                profit_margin = 0,
                status = 'active',
            })
        end
    elseif current_view == 'watchlist' then
        local watchlist = M.get_watchlist and M.get_watchlist() or {}
        for item_key, item in pairs(watchlist) do
            tinsert(items, {
                item_key = item_key,
                item_name = item.item_name,
                score = 0,
                unique_sellers = 0,
                total_stock = 0,
                total_buyout_cost = 0,
                potential_profit = 0,
                profit_margin = 0,
                notes = item.notes,
            })
        end
    elseif current_view == 'history' then
        local history = M.get_monopoly_history and M.get_monopoly_history() or {}
        for i = 1, getn(history) do
            local h = history[i]
            tinsert(items, {
                item_key = h.item_key,
                item_name = h.item_name,
                score = 0,
                unique_sellers = 0,
                total_stock = h.quantity_bought,
                total_buyout_cost = h.investment,
                potential_profit = h.profit,
                profit_margin = h.roi or 0,
                status = h.status,
            })
        end
    end
    
    -- Mostrar/ocultar mensaje de "no items"
    if getn(items) == 0 then
        monopoly_frame.no_items:Show()
        monopoly_frame.scroll_frame:Hide()
        for i = 1, 13 do
            monopoly_frame.rows[i]:Hide()
        end
        return
    else
        monopoly_frame.no_items:Hide()
        monopoly_frame.scroll_frame:Show()
    end
    
    -- Actualizar barra de scroll
    FauxScrollFrame_Update(monopoly_frame.scroll_frame, getn(items), 13, 24)
    local offset = FauxScrollFrame_GetOffset(monopoly_frame.scroll_frame)
    
    -- Actualizar filas
    for i = 1, 13 do
        local row = monopoly_frame.rows[i]
        local item_index = offset + i
        local item = items[item_index]
        
        if item and item_index <= getn(items) then
            row.data = item
            
            -- Icono
            if item.texture then
                row.icon:SetTexture(item.texture)
            elseif item.item_key then
                -- Corrección: strsplit no existe en Lua 5.0 / WoW 1.12
                -- item_key formato: "item_id:suffix"
                local _, _, item_id = string.find(item.item_key, "^(%d+)")
                local texture = nil
                if item_id then
                    _, _, _, _, _, _, _, _, _, texture = GetItemInfo(tonumber(item_id))
                end
                
                if texture then
                    row.icon:SetTexture(texture)
                else
                    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row.name:SetText(item.item_name or item.item_key or "Unknown")
            row.score:SetText(string.format("%s%d|r", get_score_color(item.score or 0), item.score or 0))
            row.sellers:SetText(tostring(item.unique_sellers or 0))
            row.stock:SetText(tostring(item.total_stock or 0))
            row.cost:SetText(format_gold(item.total_buyout_cost or 0))
            row.profit:SetText(format_gold(item.potential_profit or 0))
            
            -- Actualizar selección visual
            if selected_candidate and item.item_key == selected_candidate.item_key then
                row.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0.6)
            else
                row.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
            end
            
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================================
-- Registrar módulo
-- ============================================================================

if not M.modules then M.modules = {} end
M.modules.monopoly_ui = {
    build_panel = M.build_monopoly_panel,
    refresh = M.refresh_monopoly_ui,
    scan = M.scan_for_monopoly_candidates,
    select = M.select_candidate,
}

aux.print('|cFF00FF00[MONOPOLY_UI]|r Interfaz registrada correctamente')
