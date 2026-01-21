module 'aux.tabs.trading'

local aux = require 'aux'
local full_scan = require 'aux.tabs.trading.full_scan'
local groups = require 'aux.tabs.trading.groups'
local auctioning = require 'aux.tabs.trading.auctioning'
local sniper = require 'aux.tabs.trading.sniper'
require 'aux.tabs.trading.vendor' 
require 'aux.tabs.trading.vendor_ui'

-- UI Modules
local dashboard_ui = require 'aux.tabs.trading.dashboard_ui'
local crafting = require 'aux.tabs.trading.crafting' -- Logic
local crafting_ui = require 'aux.tabs.trading.crafting_ui' -- UI
local item_tracker = require 'aux.tabs.trading.item_tracker' -- Logic
local item_tracker_ui = require 'aux.tabs.trading.item_tracker_ui' -- UI

local M = getfenv()

--[[
    AUX TRADING SYSTEM - UI PROFESIONAL v5.0
    Sistema de Trading con funcionalidad completa
    Creado por: Elnazzareno (DarckRovert)
    Clan: El Sequito del Terror
]]

-- HELPER: Extract item_id from item key (Lua 5.0 compatible)
local function extract_item_id(str)
    if not str then return 0 end
    local _, _, id = string.find(str, "item:(%d+)")
    return tonumber(id) or tonumber(str) or 0
end

-- COLORES
local COLORS = {
    primary = {0.2, 0.6, 1.0, 1},
    success = {0.2, 0.8, 0.2, 1},
    warning = {1.0, 0.6, 0.0, 1},
    danger = {0.9, 0.2, 0.2, 1},
    gold = {1.0, 0.82, 0.0, 1},
    bg_dark = {0.05, 0.05, 0.08, 0.95},
    bg_medium = {0.1, 0.1, 0.12, 0.9},
    bg_light = {0.15, 0.15, 0.18, 0.85},
    border = {0.3, 0.3, 0.35, 1},
    text = {0.9, 0.9, 0.9, 1},
    text_dim = {0.6, 0.6, 0.6, 1},
}

local SIZES = {
    sidebar_width = 160,
    header_height = 45,
    tab_height = 32,
    row_height = 28,
    padding = 8,
}

-- ESTADO
local current_tab = "dashboard"
local content_panels = {}
local sniper_running = false
local selected_group = nil
local panel_refs = {}

-- FUNCIONES AUXILIARES
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

local function format_gold(copper)
    return require('aux.util.money').to_string(copper or 0, nil, nil, nil, true)
end

local function format_time_ago(timestamp)
    if not timestamp then return "Nunca" end
    local diff = time() - timestamp
    if diff < 60 then return "Hace " .. diff .. "s"
    elseif diff < 3600 then return "Hace " .. math.floor(diff/60) .. "m"
    elseif diff < 86400 then return "Hace " .. math.floor(diff/3600) .. "h"
    else return "Hace " .. math.floor(diff/86400) .. "d" end
end

local function create_button(parent, text, width, height, color)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width)
    btn:SetHeight(height)
    create_backdrop(btn, color or COLORS.bg_medium, COLORS.border, 1)
    btn.btn_color = color or COLORS.bg_medium
    local txt = create_text(btn, text, 11, COLORS.text, "CENTER")
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

-- EXPORTAR COLORES Y HELPERS
M.COLORS = COLORS
M.SIZES = SIZES
M.create_backdrop = create_backdrop
M.create_text = create_text
M.create_button = create_button
M.format_gold = format_gold

-- UI PRINCIPAL
function aux.handle.INIT_UI()
    M.frame = CreateFrame('Frame', 'AuxTradingFrame', aux.frame)
    local f = M.frame
    f:SetAllPoints()
    f:Hide()
    create_backdrop(f, COLORS.bg_dark, COLORS.border, 2)
    
    -- HEADER
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(SIZES.header_height)
    create_backdrop(header, {0.08, 0.08, 0.1, 1}, COLORS.border, 1)
    
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetPoint("LEFT", header, "LEFT", 12, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    
    f.titulo = create_text(header, "|cFFFFD700AUX Trading System|r", 16, nil, "LEFT", icon, "RIGHT", 10, 0)
    f.gold_display = create_text(header, format_gold(GetMoney()), 14, COLORS.gold, "RIGHT", header, "RIGHT", -15, 0)
    
    -- SIDEBAR
    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", 0, -SIZES.header_height)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIZES.sidebar_width)
    create_backdrop(sidebar, COLORS.bg_medium, COLORS.border, 1)
    f.sidebar = sidebar
    
    local tabs = {
        {id = "dashboard", name = "Dashboard", icon = "Interface\\Icons\\INV_Misc_Note_01"},
        {id = "grupos", name = "Grupos", icon = "Interface\\Icons\\INV_Box_01"},
        {id = "oportunidades", name = "Oportunidades", icon = "Interface\\Icons\\INV_Misc_Coin_02"},
        {id = "sniper", name = "Sniper", icon = "Interface\\Icons\\Ability_Hunter_SniperShot"},
        {id = "vendor", name = "Vendor Shuffle", icon = "Interface\\Icons\\INV_Misc_Coin_03"}, -- Nuevo Tab
        {id = "monopoly", name = "Monopolio", icon = "Interface\\Icons\\INV_Misc_Coin_01"},
        {id = "auctioning", name = "Subastas", icon = "Interface\\Icons\\INV_Misc_Coin_04"},
        {id = "crafting", name = "Crafting", icon = "Interface\\Icons\\Trade_BlackSmithing"},
        {id = "item_tracker", name = "Inventario", icon = "Interface\\Icons\\INV_Misc_Bag_08"}, -- Nuevo Tab
        {id = "historial", name = "Historial", icon = "Interface\\Icons\\INV_Scroll_03"},
        {id = "config", name = "Configuracion", icon = "Interface\\Icons\\Trade_Engineering"},
    }
    
    f.tab_buttons = {}
    local yoff = -10
    
    for i, t in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetWidth(SIZES.sidebar_width - 10)
        btn:SetHeight(SIZES.tab_height)
        btn:SetPoint("TOP", sidebar, "TOP", 0, yoff)
        
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.15, 0.15, 0.18, 0)
        btn.bg = bg
        
        local indicator = btn:CreateTexture(nil, "ARTWORK")
        indicator:SetWidth(3)
        indicator:SetHeight(SIZES.tab_height - 8)
        indicator:SetPoint("LEFT", btn, "LEFT", 0, 0)
        indicator:SetTexture("Interface\\Buttons\\WHITE8X8")
        indicator:SetVertexColor(unpack(COLORS.primary))
        indicator:Hide()
        btn.indicator = indicator
        
        local ic = btn:CreateTexture(nil, "ARTWORK")
        ic:SetWidth(18)
        ic:SetHeight(18)
        ic:SetPoint("LEFT", btn, "LEFT", 12, 0)
        ic:SetTexture(t.icon)
        btn.icon = ic
        
        local txt = create_text(btn, t.name, 11, COLORS.text, "LEFT", ic, "RIGHT", 8, 0)
        btn.text = txt
        btn.tab_id = t.id
        
        btn:SetScript("OnEnter", function()
            if current_tab ~= this.tab_id then
                this.bg:SetVertexColor(0.2, 0.25, 0.3, 0.8)
            end
        end)
        btn:SetScript("OnLeave", function()
            if current_tab ~= this.tab_id then
                this.bg:SetVertexColor(0.15, 0.15, 0.18, 0)
            end
        end)
        btn:SetScript("OnClick", function()
            M.switch_tab(this.tab_id)
        end)
        
        f.tab_buttons[t.id] = btn
        yoff = yoff - SIZES.tab_height - 2
    end
    
    -- CONTENIDO
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    create_backdrop(content, COLORS.bg_light, nil, 0)
    f.content = content
    
    M.create_panels(content)
    M.switch_tab("dashboard")
    
    aux.print("|cFFFFD700[Trading]|r UI v5.0 cargada - Por Elnazzareno")
end

-- CREAR PANELES
function M.create_panels(parent)
    local ids = {"dashboard", "grupos", "oportunidades", "sniper", "vendor", "monopoly", "auctioning", "crafting", "item_tracker", "historial", "config"}
    
    for _, id in ipairs(ids) do
        local panel = CreateFrame("Frame", nil, parent)
        panel:SetAllPoints()
        panel:Hide()
        
        local panel_header = CreateFrame("Frame", nil, panel)
        panel_header:SetPoint("TOPLEFT", 0, 0)
        panel_header:SetPoint("TOPRIGHT", 0, 0)
        panel_header:SetHeight(40)
        create_backdrop(panel_header, {0.1, 0.1, 0.12, 1}, COLORS.border, 1)
        
        local titles = {
            dashboard = "Dashboard - Resumen de Trading",
            grupos = "Gestion de Grupos",
            oportunidades = "Oportunidades de Mercado",
            sniper = "Sniper - Ofertas en Tiempo Real",
            vendor = "Vendor Shuffle - Dinero Gratis", -- Titulo
            monopoly = "Monopolio - Domina el Mercado",
            auctioning = "Gestion de Subastas",
            crafting = "Crafting y Profesiones",
            item_tracker = "Tracker de Inventario",
            historial = "Historial de Transacciones",
            config = "Configuracion del Sistema",
        }
        
        create_text(panel_header, titles[id] or id, 14, COLORS.gold, "LEFT", panel_header, "LEFT", 15, 0)
        
        local panel_content = CreateFrame("Frame", nil, panel)
        panel_content:SetPoint("TOPLEFT", panel_header, "BOTTOMLEFT", 0, 0)
        panel_content:SetPoint("BOTTOMRIGHT", 0, 0)
        panel.content = panel_content
        
        if id == "dashboard" then M.build_dashboard(panel_content)
        elseif id == "oportunidades" then M.build_oportunidades(panel_content)
        elseif id == "grupos" then M.build_grupos(panel_content)
        elseif id == "sniper" then M.build_sniper(panel_content)
        elseif id == "vendor" then 
            M.build_vendor_panel(panel_content)
        elseif id == "monopoly" then M.build_monopoly_panel(panel_content)
        elseif id == "auctioning" then M.build_auctioning(panel_content)
        elseif id == "crafting" then M.build_crafting(panel_content)
        elseif id == "item_tracker" then M.build_item_tracker(panel_content)
        elseif id == "historial" then M.build_historial(panel_content)
        elseif id == "config" then 
            if M.modules.config_ui and M.modules.config_ui.crear_config_ui then
                M.modules.config_ui.crear_config_ui(panel_content)
            end
        end
        
        content_panels[id] = panel
    end
end

-- CAMBIO DE TABS
function M.switch_tab(tab_id)
    current_tab = tab_id
    local f = M.frame
    
    if f and f.tab_buttons then
        for id, btn in pairs(f.tab_buttons) do
            if id == tab_id then
                btn.bg:SetVertexColor(0.15, 0.25, 0.4, 0.9)
                btn.indicator:Show()
                btn.text:SetTextColor(1, 1, 1, 1)
            else
                btn.bg:SetVertexColor(0.15, 0.15, 0.18, 0)
                btn.indicator:Hide()
                btn.text:SetTextColor(0.8, 0.8, 0.8, 1)
            end
        end
    end
    
    for id, panel in pairs(content_panels) do
        if id == tab_id then panel:Show() else panel:Hide() end
    end
    
    -- Actualizar panel al cambiar
    if tab_id == "dashboard" then M.refresh_dashboard()
    elseif tab_id == "historial" then M.refresh_historial()
    elseif tab_id == "grupos" then M.refresh_grupos()
    elseif tab_id == "crafting" then M.refresh_crafting_ui()
    elseif tab_id == "item_tracker" then M.refresh_item_tracker()
    elseif tab_id == "vendor" then 
        M.refresh_vendor_ui()
    elseif tab_id == "monopoly" then M.refresh_monopoly_ui()
    end
end

-- ACTUALIZAR ORO
function M.update_gold()
    local f = M.frame
    if f and f.gold_display then
        f.gold_display:SetText(format_gold(GetMoney()))
    end
end

local gold_frame = CreateFrame("Frame")
gold_frame:RegisterEvent("PLAYER_MONEY")
gold_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
gold_frame:SetScript("OnEvent", function() M.update_gold() end)

-- ============================================
-- PANEL DASHBOARD - FUNCIONAL
-- ============================================
function M.build_dashboard(parent)
    if M.modules.dashboard_ui and M.modules.dashboard_ui.crear_dashboard_ui then
        local f = M.modules.dashboard_ui.crear_dashboard_ui(parent)
        if f then f:Show() end
        return f
    end
end

function M.refresh_dashboard()
    if M.modules.dashboard_ui and M.modules.dashboard_ui.actualizar_dashboard_ui then
        M.modules.dashboard_ui.actualizar_dashboard_ui()
    end
end

function M.refresh_dashboard()
    local refs = panel_refs.dashboard
    if not refs or not refs.cards then return end
    
    -- Obtener datos de accounting
    local accounting = nil
    if AuxTradingAccounting then
        -- Calcular ganancias
        local now = time()
        local day_ago = now - 86400
        local week_ago = now - 604800
        
        local profit_today = 0
        local profit_week = 0
        local item_totals = {}
        
        -- Procesar ventas
        if AuxTradingAccounting.sales then
            for item_key, records in pairs(AuxTradingAccounting.sales) do
                item_totals[item_key] = item_totals[item_key] or 0
                for _, record in ipairs(records) do
                    local amount = (record.price or 0) * (record.quantity or 1)
                    item_totals[item_key] = item_totals[item_key] + amount
                    if record.time and record.time >= day_ago then
                        profit_today = profit_today + amount
                    end
                    if record.time and record.time >= week_ago then
                        profit_week = profit_week + amount
                    end
                end
            end
        end
        
        -- Restar compras
        if AuxTradingAccounting.purchases then
            for item_key, records in pairs(AuxTradingAccounting.purchases) do
                for _, record in ipairs(records) do
                    local amount = (record.price or 0) * (record.quantity or 1)
                    if record.time and record.time >= day_ago then
                        profit_today = profit_today - amount
                    end
                    if record.time and record.time >= week_ago then
                        profit_week = profit_week - amount
                    end
                end
            end
        end
        
        -- Actualizar tarjetas
        if refs.cards.profit_today then
            refs.cards.profit_today:SetText(format_gold(profit_today))
        end
        if refs.cards.profit_week then
            refs.cards.profit_week:SetText(format_gold(profit_week))
        end
        
        -- Top items
        local sorted_items = {}
        for item_key, total in pairs(item_totals) do
            table.insert(sorted_items, {key = item_key, total = total})
        end
        table.sort(sorted_items, function(a, b) return a.total > b.total end)
        
        for i = 1, 6 do
            local row = refs.top_items[i]
            if row then
                if sorted_items[i] then
                    local item = sorted_items[i]
                    local item_id = extract_item_id(item.key)
                    local name = item.key
                    if item_id > 0 then
                        local item_name = GetItemInfo(item_id)
                        if item_name then name = item_name end
                    end
                    row.name:SetText(name)
                    row.gold:SetText(format_gold(item.total))
                    row:Show()
                else
                    row:Hide()
                end
            end
        end
    end
    
    -- Subastas activas
    if refs.cards.active_auctions then
        local num_auctions = 0
        
        -- Verificar si podemos obtener datos de subastas
        if GetNumAuctionItems then
             -- Solo funciona si se ha visitado la AH, pero podemos intentar obtener 'owner' items
             -- Nota: GetNumAuctionItems("owner") devuelve 2 valores: batch y total
             local _, total = GetNumAuctionItems("owner")
             num_auctions = total or 0
        end
        
        refs.cards.active_auctions:SetText(tostring(num_auctions))
    end
end

-- ============================================
-- PANEL GRUPOS - FUNCIONAL
-- ============================================
function M.build_grupos(parent)
    panel_refs.grupos = {}
    local refs = panel_refs.grupos
    
    -- Panel izquierdo: Lista de grupos
    local left_panel = CreateFrame("Frame", nil, parent)
    left_panel:SetPoint("TOPLEFT", 10, -10)
    left_panel:SetWidth(200)
    left_panel:SetPoint("BOTTOM", 0, 10)
    create_backdrop(left_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(left_panel, "Grupos", 12, COLORS.gold, "TOP", left_panel, "TOP", 0, -10)
    
    -- Botones de accion grupos
    local btn_new = create_button(left_panel, "+ Nuevo", 60, 22, {0.2, 0.5, 0.3, 0.9})
    btn_new:SetPoint("TOPLEFT", 5, -35)
    btn_new:SetScript("OnClick", function()
        -- Mostrar dialogo para crear grupo
        StaticPopupDialogs["AUX_CREATE_GROUP"] = {
            text = "Nombre del nuevo grupo:",
            button1 = "Crear",
            button2 = "Cancelar",
            hasEditBox = 1,
            maxLetters = 50,
            OnAccept = function()
                local nombre = getglobal(this:GetParent():GetName().."EditBox"):GetText()
                if nombre and nombre ~= "" then
                    if groups.crear_grupo(nombre) then
                        M.refresh_grupos()
                    end
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        StaticPopup_Show("AUX_CREATE_GROUP")
    end)
    
    local btn_del = create_button(left_panel, "Eliminar", 60, 22, {0.5, 0.2, 0.2, 0.9})
    btn_del:SetPoint("LEFT", btn_new, "RIGHT", 5, 0)
    btn_del:SetScript("OnClick", function()
        if selected_group then
            StaticPopupDialogs["AUX_DELETE_GROUP"] = {
                text = "¿Eliminar grupo '" .. selected_group .. "'?",
                button1 = "Eliminar",
                button2 = "Cancelar",
                OnAccept = function()
                    if groups.eliminar_grupo(selected_group) then
                        selected_group = nil
                        M.refresh_grupos()
                    end
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
            }
            StaticPopup_Show("AUX_DELETE_GROUP")
        else
            aux.print("|cFFFF0000[Error]|r Selecciona un grupo primero")
        end
    end)
    
    local btn_import = create_button(left_panel, "Importar", 60, 22, {0.3, 0.4, 0.5, 0.9})
    btn_import:SetPoint("LEFT", btn_del, "RIGHT", 5, 0)
    
    -- Lista de grupos
    refs.group_list = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, left_panel)
        row:SetPoint("TOPLEFT", 5, -65 - (i-1) * 26)
        row:SetWidth(188)
        row:SetHeight(24)
        row.index = i
        
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.15, 0.15, 0.18, 0)
        row.bg = bg
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(18)
        icon:SetHeight(18)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Box_01")
        row.icon = icon
        
        row.name = create_text(row, "", 10, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.count = create_text(row, "", 9, COLORS.text_dim, "RIGHT", row, "RIGHT", -5, 0)
        
        row:SetScript("OnEnter", function()
            this.bg:SetVertexColor(0.2, 0.25, 0.3, 0.8)
        end)
        row:SetScript("OnLeave", function()
            if selected_group ~= this.group_name then
                this.bg:SetVertexColor(0.15, 0.15, 0.18, 0)
            end
        end)
        row:SetScript("OnClick", function()
            selected_group = this.group_name
            M.refresh_grupos()
            M.show_group_items(this.group_name)
        end)
        
        row:Hide()
        refs.group_list[i] = row
    end
    
    -- Panel derecho: Items del grupo
    local right_panel = CreateFrame("Frame", nil, parent)
    right_panel:SetPoint("TOPLEFT", left_panel, "TOPRIGHT", 10, 0)
    right_panel:SetPoint("BOTTOMRIGHT", -10, 10)
    create_backdrop(right_panel, COLORS.bg_medium, COLORS.border, 1)
    
    refs.group_title = create_text(right_panel, "Selecciona un grupo", 12, COLORS.gold, "TOP", right_panel, "TOP", 0, -10)
    refs.group_desc = create_text(right_panel, "", 10, COLORS.text_dim, "TOP", right_panel, "TOP", 0, -28)
    
    -- Botones de items
    local btn_add = create_button(right_panel, "+ Agregar Item", 100, 22, {0.2, 0.5, 0.3, 0.9})
    btn_add:SetPoint("TOPLEFT", 10, -50)
    btn_add:SetScript("OnClick", function()
        if not selected_group then
            aux.print("|cFFFF0000[Error]|r Selecciona un grupo primero")
            return
        end
        
        -- Mostrar dialogo para agregar item
        StaticPopupDialogs["AUX_ADD_ITEM_TO_GROUP"] = {
            text = "Item ID o link del item:",
            button1 = "Agregar",
            button2 = "Cancelar",
            hasEditBox = 1,
            maxLetters = 100,
            OnAccept = function()
                local input = getglobal(this:GetParent():GetName().."EditBox"):GetText()
                if input and input ~= "" then
                    -- Parsear item link o ID
                    local item_id = extract_item_id(input)
                    if item_id and item_id > 0 then
                        local item_key = "item:" .. item_id .. ":0:0:0"
                        if groups.agregar_item_a_grupo(selected_group, item_key) then
                            M.show_group_items(selected_group)
                        end
                    else
                        aux.print("|cFFFF0000[Error]|r Item ID inv\195\161lido")
                    end
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        StaticPopup_Show("AUX_ADD_ITEM_TO_GROUP")
    end)
    
    local btn_remove = create_button(right_panel, "Quitar Item", 90, 22, {0.5, 0.2, 0.2, 0.9})
    btn_remove:SetPoint("LEFT", btn_add, "RIGHT", 5, 0)
    btn_remove:SetScript("OnClick", function()
        if not selected_group then
            aux.print("|cFFFF0000[Error]|r Selecciona un grupo primero")
            return
        end
        
        local selected_item = refs.selected_item
        if selected_item then
            if groups.eliminar_item_de_grupo(selected_group, selected_item) then
                refs.selected_item = nil
                M.show_group_items(selected_group)
            end
        else
            aux.print("|cFFFF0000[Error]|r Selecciona un item primero")
        end
    end)
    
    refs.selected_item = nil
    
    -- Lista de items del grupo
    refs.item_list = {}
    for i = 1, 10 do
        local row = CreateFrame("Button", nil, right_panel)
        row:SetPoint("TOPLEFT", 10, -80 - (i-1) * 26)
        row:SetPoint("TOPRIGHT", -10, -80 - (i-1) * 26)
        row:SetHeight(24)
        
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        row.name = create_text(row, "", 10, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.name:SetWidth(200)
        row.market = create_text(row, "", 10, COLORS.gold, "RIGHT", row, "RIGHT", -5, 0)
        
        -- Agregar fondo para selección
        local select_bg = row:CreateTexture(nil, "BACKGROUND")
        select_bg:SetAllPoints()
        select_bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
        row.select_bg = select_bg
        
        row:SetScript("OnClick", function()
            -- Seleccionar este item
            refs.selected_item = this.item_key
            
            -- Resaltar la fila seleccionada
            for j = 1, 10 do
                if refs.item_list[j].select_bg then
                    if refs.item_list[j] == this then
                        refs.item_list[j].select_bg:SetVertexColor(0.3, 0.5, 0.3, 0.6)
                    else
                        refs.item_list[j].select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
                    end
                end
            end
        end)
        
        row:Hide()
        refs.item_list[i] = row
    end
end

function M.refresh_grupos()
    local refs = panel_refs.grupos
    if not refs or not refs.group_list then return end
    
    -- Obtener grupos reales de groups.lua usando la referencia correcta
    local todos_grupos = {}
    if groups.obtener_todos_grupos then
        todos_grupos = groups.obtener_todos_grupos()
    end
    
    local grupos_array = {}
    for nombre, grupo in pairs(todos_grupos) do
        local count = 0
        if groups.contar_items_en_grupo then
            count = groups.contar_items_en_grupo(nombre)
        elseif grupo.items then
            count = table.getn(grupo.items)
        end
        
        table.insert(grupos_array, {
            name = nombre,
            icon = grupo.icono or 'Interface\\Icons\\INV_Misc_QuestionMark',
            count = count,
            grupo = grupo
        })
    end
    
    -- Ordenar por nombre
    table.sort(grupos_array, function(a, b) return a.name < b.name end)
    
    for i, row in ipairs(refs.group_list) do
        if grupos_array[i] then
            local g = grupos_array[i]
            row.icon:SetTexture(g.icon)
            row.name:SetText(g.name)
            row.count:SetText("(" .. g.count .. ")")
            row.group_name = g.name
            
            if selected_group == g.name then
                row.bg:SetVertexColor(0.15, 0.25, 0.4, 0.9)
            else
                row.bg:SetVertexColor(0.15, 0.15, 0.18, 0)
            end
            
            row:Show()
        else
            row:Hide()
        end
    end
end

function M.show_group_items(group_name)
    local refs = panel_refs.grupos
    if not refs then return end
    
    local grupo = groups.obtener_grupo(group_name)
    if not grupo then return end
    
    refs.group_title:SetText(group_name)
    refs.group_desc:SetText(grupo.descripcion or "Items en este grupo")
    
    -- Obtener items reales del grupo
    local item_keys = groups.obtener_items_de_grupo(group_name)
    
    -- Resetear selección
    refs.selected_item = nil
    
    for i, row in ipairs(refs.item_list) do
        if item_keys[i] then
            local item_key = item_keys[i]
            local item_id = extract_item_id(item_key)
            
            -- Obtener info del item
            local item_name = "Item " .. item_id
            local item_texture = "Interface\\Icons\\INV_Misc_QuestionMark"
            
            if item_id > 0 then
                local name, _, _, _, _, _, _, _, texture = GetItemInfo(item_id)
                if name then
                    item_name = name
                    item_texture = texture
                end
            end
            
            -- Obtener precio de mercado
            local history = require 'aux.core.history'
            local market_value = history.value(item_key)
            local price_text = ""
            if market_value and market_value > 0 then
                price_text = format_gold(market_value)
            else
                price_text = "|cFF888888Sin datos|r"
            end
            
            row.icon:SetTexture(item_texture)
            row.name:SetText(item_name)
            row.market:SetText(price_text)
            row.item_key = item_key
            row.select_bg:SetVertexColor(0.3, 0.5, 0.3, 0)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================
-- PANEL SNIPER - FUNCIONAL
-- ============================================
function M.build_sniper(parent)
    panel_refs.sniper = {}
    local refs = panel_refs.sniper
    
    -- Barra de control
    local control_bar = CreateFrame("Frame", nil, parent)
    control_bar:SetPoint("TOPLEFT", 10, -10)
    control_bar:SetPoint("TOPRIGHT", -10, -10)
    control_bar:SetHeight(40)
    create_backdrop(control_bar, COLORS.bg_medium, COLORS.border, 1)
    
    refs.btn_start = create_button(control_bar, "Iniciar Sniper", 110, 28, {0.2, 0.6, 0.3, 0.9})
    refs.btn_start:SetPoint("LEFT", control_bar, "LEFT", 10, 0)
    refs.btn_start:SetScript("OnClick", function()
        if M.toggle_sniper then
            M.toggle_sniper()
            
            -- Actualizar UI del botón
            if M.is_sniper_running and M.is_sniper_running() then
                this.label:SetText("Detener")
                create_backdrop(this, {0.6, 0.2, 0.2, 0.9}, COLORS.border, 1)
                this.btn_color = {0.6, 0.2, 0.2, 0.9}
            else
                this.label:SetText("Iniciar Sniper")
                create_backdrop(this, {0.2, 0.6, 0.3, 0.9}, COLORS.border, 1)
                this.btn_color = {0.2, 0.6, 0.3, 0.9}
            end
        else
            aux.print("|cFFFF0000[Error]|r La función toggle_sniper no existe")
        end
    end)
    
    refs.status = create_text(control_bar, "|cFF888888Detenido|r", 11, nil, "LEFT", refs.btn_start, "RIGHT", 15, 0)
    refs.stats = create_text(control_bar, "Escaneados: 0 | Ofertas: 0", 10, COLORS.text_dim, "RIGHT", control_bar, "RIGHT", -10, 0)
    
    -- Configuracion sniper
    local config_frame = CreateFrame("Frame", nil, parent)
    config_frame:SetPoint("TOPLEFT", 10, -60)
    config_frame:SetWidth(200)
    config_frame:SetHeight(120)
    create_backdrop(config_frame, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(config_frame, "Configuracion", 11, COLORS.gold, "TOP", config_frame, "TOP", 0, -8)
    create_text(config_frame, "Min. Ganancia %:", 10, COLORS.text, "TOPLEFT", config_frame, "TOPLEFT", 10, -30)
    refs.config_min_profit = create_text(config_frame, "5%", 10, COLORS.success, "TOPRIGHT", config_frame, "TOPRIGHT", -10, -30)
    create_text(config_frame, "Max. Precio:", 10, COLORS.text, "TOPLEFT", config_frame, "TOPLEFT", 10, -50)
    refs.config_max_price = create_text(config_frame, "1000g", 10, COLORS.gold, "TOPRIGHT", config_frame, "TOPRIGHT", -10, -50)
    create_text(config_frame, "Intervalo Scan:", 10, COLORS.text, "TOPLEFT", config_frame, "TOPLEFT", 10, -70)
    refs.config_interval = create_text(config_frame, "0.5s", 10, COLORS.primary, "TOPRIGHT", config_frame, "TOPRIGHT", -10, -70)
    create_text(config_frame, "Sonido Alerta:", 10, COLORS.text, "TOPLEFT", config_frame, "TOPLEFT", 10, -90)
    refs.config_sound = create_text(config_frame, "|cFF00FF00SI|r", 10, nil, "TOPRIGHT", config_frame, "TOPRIGHT", -10, -90)
    
    -- Actualizar valores de configuracion desde el modulo sniper
    local function update_config_display()
        local config = M.get_sniper_config and M.get_sniper_config() or {}
        if refs.config_min_profit then
            refs.config_min_profit:SetText(string.format("%d%%", config.min_profit_percent or 5))
        end
        if refs.config_max_price then
            refs.config_max_price:SetText(string.format("%dg", config.max_price_gold or 1000))
        end
        if refs.config_interval then
            refs.config_interval:SetText(string.format("%.1fs", config.scan_interval or 0.5))
        end
        if refs.config_sound then
            refs.config_sound:SetText(config.sound_alert and "|cFF00FF00SI|r" or "|cFFFF0000NO|r")
        end
    end
    update_config_display()
    
    -- Lista de ofertas encontradas
    create_text(parent, "Ofertas Encontradas", 12, COLORS.gold, "TOPLEFT", parent, "TOPLEFT", 220, -60)
    
    local list_container = CreateFrame("Frame", nil, parent)
    list_container:SetPoint("TOPLEFT", 220, -80)
    list_container:SetPoint("BOTTOMRIGHT", -10, 10)
    create_backdrop(list_container, COLORS.bg_medium, COLORS.border, 1)
    
    -- Header
    local header = CreateFrame("Frame", nil, list_container)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", -18, 0)  -- Espacio para scrollbar
    header:SetHeight(22)
    create_backdrop(header, {0.12, 0.12, 0.15, 1}, COLORS.border, 1)
    
    create_text(header, "Item", 10, COLORS.text_dim, "LEFT", header, "LEFT", 10, 0)
    create_text(header, "Precio", 10, COLORS.text_dim, "LEFT", header, "LEFT", 180, 0)
    create_text(header, "Mercado", 10, COLORS.text_dim, "LEFT", header, "LEFT", 260, 0)
    create_text(header, "Ganancia", 10, COLORS.text_dim, "LEFT", header, "LEFT", 340, 0)
    create_text(header, "Accion", 10, COLORS.text_dim, "RIGHT", header, "RIGHT", -10, 0)
    
    -- ScrollFrame para la lista
    local VISIBLE_ROWS = 15
    local ROW_HEIGHT = 24  -- Filas mas compactas para mostrar mas
    refs.sniper_visible_rows = VISIBLE_ROWS
    refs.sniper_row_height = ROW_HEIGHT
    
    local scroll_frame = CreateFrame("ScrollFrame", "AuxTradingSniperScrollFrame", list_container, "FauxScrollFrameTemplate")
    scroll_frame:SetPoint("TOPLEFT", 0, -24)
    scroll_frame:SetPoint("BOTTOMRIGHT", -26, 4) -- Reduced width to ensure scrollbar is visible
    refs.sniper_scroll_frame = scroll_frame
    refs.sniper_total_deals = 0
    
    refs.snipe_rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, list_container)
        row:SetPoint("TOPLEFT", 5, -25 - (i-1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -26, -25 - (i-1) * ROW_HEIGHT)  -- Adjusted for scrollbar
        row:SetHeight(ROW_HEIGHT)
        
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        row.name = create_text(row, "", 9, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.name:SetWidth(130)
        row.price = create_text(row, "", 9, COLORS.text, "LEFT", row, "LEFT", 180, 0)
        row.market = create_text(row, "", 9, COLORS.text, "LEFT", row, "LEFT", 260, 0)
        row.profit = create_text(row, "", 9, COLORS.success, "LEFT", row, "LEFT", 340, 0)
        
        local btn_buy = create_button(row, "Comprar", 55, 18, {0.2, 0.5, 0.3, 0.9})
        btn_buy:SetPoint("RIGHT", -5, 0)
        btn_buy.row_index = i
        btn_buy:SetScript("OnClick", function()
            if row.deal and M.buy_sniper_deal then
                M.buy_sniper_deal(row.deal)
            else
                aux.print("|cFFFF0000[Error]|r No hay deal seleccionado")
            end
        end)
        row.btn_buy = btn_buy
        
        row:Hide()
        refs.snipe_rows[i] = row
    end
    
    -- Configurar scroll
    scroll_frame:SetScript("OnVerticalScroll", function()
        -- Ensure FauxScrollFrame_OnVerticalScroll is called if standard template logic is needed, or custom:
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, function()
             M.update_sniper_ui()
        end)
        -- The previous logic just calculated offset manually, standard FauxScrollFrame_OnVerticalScroll is safer
    end)
    
    -- Mouse wheel scroll
    list_container:EnableMouseWheel(true)
    list_container:SetScript("OnMouseWheel", function()
        local current = FauxScrollFrame_GetOffset(scroll_frame)
        local max_scroll = refs.sniper_total_deals and (refs.sniper_total_deals - VISIBLE_ROWS) or 0
        if max_scroll < 0 then max_scroll = 0 end
        
        if arg1 > 0 then
            if current > 0 then
                FauxScrollFrame_SetOffset(scroll_frame, current - 1)
                -- Also update the scrollbar position
                getglobal(scroll_frame:GetName().."ScrollBar"):SetValue((current - 1) * ROW_HEIGHT)
                M.update_sniper_ui()
            end
        else
            if current < max_scroll then
                FauxScrollFrame_SetOffset(scroll_frame, current + 1)
                getglobal(scroll_frame:GetName().."ScrollBar"):SetValue((current + 1) * ROW_HEIGHT)
                M.update_sniper_ui()
            end
        end
    end)
    
    -- Mensaje cuando no hay ofertas
    refs.no_deals = create_text(list_container, "No hay ofertas. Inicia el sniper para buscar.", 11, COLORS.text_dim, "CENTER")
end

-- Actualizar UI del sniper
function M.update_sniper_ui()
    local refs = panel_refs.sniper
    if not refs or not refs.snipe_rows then return end
    
    local deals = M.get_sniper_deals and M.get_sniper_deals() or {}
    local state = M.get_sniper_state and M.get_sniper_state() or {}
    
    -- Contar deals
    local deal_count = 0
    if deals then
        deal_count = getn(deals)
    end
    refs.sniper_total_deals = deal_count
    
    -- Actualizar stats
    if refs.stats then
        refs.stats:SetText(string.format("Escaneados: %d | Ofertas: %d", 
            state.items_scanned or 0, 
            deal_count))
    end
    
    -- Actualizar status
    if refs.status then
        if state.running then
            refs.status:SetText("|cFF00FF00Activo|r")
        else
            refs.status:SetText("|cFF888888Detenido|r")
        end
    end
    
    -- Actualizar FauxScrollFrame
    local VISIBLE_ROWS = refs.sniper_visible_rows or 10
    local ROW_HEIGHT = refs.sniper_row_height or 24
    
    if refs.sniper_scroll_frame then
        FauxScrollFrame_Update(refs.sniper_scroll_frame, deal_count, VISIBLE_ROWS, ROW_HEIGHT)
    end
    
    -- Obtener offset del scroll
    local offset = 0
    if refs.sniper_scroll_frame then
        offset = FauxScrollFrame_GetOffset(refs.sniper_scroll_frame) or 0
    end
    
    -- Actualizar filas con offset
    local visible_count = 0
    for i = 1, VISIBLE_ROWS do
        local row = refs.snipe_rows[i]
        local data_index = i + offset
        local deal = deals[data_index]
        
        if deal then
            -- Obtener info del item
            local item_name = deal.item_name or "Unknown"
            local item_texture = "Interface\\Icons\\INV_Misc_QuestionMark"
            
            -- FIX: Usar texture del auction_record (obtenido directamente del scan)
            if deal.auction_record and deal.auction_record.texture then
                item_texture = deal.auction_record.texture
            elseif deal.item_id then
                -- Backup: Usar GetItemInfo sin cache
                local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(deal.item_id)
                if texture then
                    item_texture = texture
                end
                if name then
                    item_name = name
                end
            end
            
            row.icon:SetTexture(item_texture)
            row.name:SetText(item_name)
            row.price:SetText(format_gold(deal.buyout_price))
            row.market:SetText(format_gold(deal.market_value))
            row.profit:SetText(string.format("+%s (-%d%%)", format_gold(deal.profit), deal.percent_below))
            row.deal = deal
            row:Show()
            visible_count = visible_count + 1
        else
            row:Hide()
        end
    end
    
    -- Mostrar/ocultar mensaje de "no hay ofertas"
    if refs.no_deals then
        if visible_count == 0 then
            refs.no_deals:Show()
        else
            refs.no_deals:Hide()
        end
    end
end

-- ============================================
-- PANEL SUBASTAS - FUNCIONAL
-- ============================================
function M.build_auctioning(parent)
    panel_refs.auctioning = {}
    local refs = panel_refs.auctioning
    
    -- Barra de acciones
    local action_bar = CreateFrame("Frame", nil, parent)
    action_bar:SetPoint("TOPLEFT", 10, -10)
    action_bar:SetPoint("TOPRIGHT", -10, -10)
    action_bar:SetHeight(40)
    create_backdrop(action_bar, COLORS.bg_medium, COLORS.border, 1)
    
    local btn_post = create_button(action_bar, "Publicar Todo", 100, 28, {0.2, 0.5, 0.3, 0.9})
    btn_post:SetPoint("LEFT", action_bar, "LEFT", 10, 0)
    btn_post:SetScript("OnClick", function()
        if M.post_all_items then
            M.post_all_items()
        else
            aux.print("|cFFFF0000[Error]|r La función post_all_items no existe")
        end
    end)
    
    local btn_cancel = create_button(action_bar, "Cancelar Undercut", 120, 28, {0.5, 0.3, 0.2, 0.9})
    btn_cancel:SetPoint("LEFT", btn_post, "RIGHT", 10, 0)
    btn_cancel:SetScript("OnClick", function()
        if M.cancel_undercut_auctions then
            M.cancel_undercut_auctions()
        else
            aux.print("|cFFFF0000[Error]|r La función cancel_undercut_auctions no existe")
        end
    end)
    
    local btn_scan = create_button(action_bar, "Escanear Precios", 110, 28, {0.3, 0.4, 0.5, 0.9})
    btn_scan:SetPoint("LEFT", btn_cancel, "RIGHT", 10, 0)
    btn_scan:SetScript("OnClick", function()
        if M.scan_prices then
            M.scan_prices()
        else
            aux.print("|cFFFF0000[Error]|r La función scan_prices no existe")
        end
    end)
    
    local btn_refresh = create_button(action_bar, "Actualizar", 80, 28, {0.4, 0.4, 0.5, 0.9})
    btn_refresh:SetPoint("LEFT", btn_scan, "RIGHT", 10, 0)
    btn_refresh:SetScript("OnClick", function()
        M.refresh_auctioning()
        aux.print("|cFF00FF00Subastas actualizadas|r")
    end)
    
    refs.status = create_text(action_bar, "|cFF00FF00Listo|r", 10, nil, "RIGHT", action_bar, "RIGHT", -10, 0)
    
    -- Resumen
    local summary = CreateFrame("Frame", nil, parent)
    summary:SetPoint("TOPLEFT", 10, -60)
    summary:SetPoint("TOPRIGHT", -10, -60)
    summary:SetHeight(50)
    create_backdrop(summary, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(summary, "Subastas Activas:", 10, COLORS.text, "LEFT", summary, "LEFT", 15, 8)
    refs.active_count = create_text(summary, "0", 14, COLORS.primary, "LEFT", summary, "LEFT", 130, 8)
    
    create_text(summary, "Valor Total:", 10, COLORS.text, "LEFT", summary, "LEFT", 200, 8)
    refs.total_value = create_text(summary, "0g", 14, COLORS.gold, "LEFT", summary, "LEFT", 280, 8)
    
    create_text(summary, "Vendidas Hoy:", 10, COLORS.text, "LEFT", summary, "LEFT", 400, 8)
    refs.sold_today = create_text(summary, "0", 14, COLORS.success, "LEFT", summary, "LEFT", 500, 8)
    
    -- Header de lista
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 10, -120)
    header:SetPoint("TOPRIGHT", -10, -120)
    header:SetHeight(22)
    create_backdrop(header, {0.12, 0.12, 0.15, 1}, COLORS.border, 1)
    
    create_text(header, "Item", 10, COLORS.text_dim, "LEFT", header, "LEFT", 10, 0)
    create_text(header, "Cantidad", 10, COLORS.text_dim, "LEFT", header, "LEFT", 200, 0)
    create_text(header, "Precio Unit.", 10, COLORS.text_dim, "LEFT", header, "LEFT", 280, 0)
    create_text(header, "Tiempo", 10, COLORS.text_dim, "LEFT", header, "LEFT", 380, 0)
    create_text(header, "Estado", 10, COLORS.text_dim, "LEFT", header, "LEFT", 460, 0)
    
    -- Lista de subastas
    local list_frame = CreateFrame("Frame", nil, parent)
    list_frame:SetPoint("TOPLEFT", 10, -145)
    list_frame:SetPoint("BOTTOMRIGHT", -10, 10)
    create_backdrop(list_frame, COLORS.bg_medium, COLORS.border, 1)
    
    refs.auction_rows = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, list_frame)
        row:SetPoint("TOPLEFT", 5, -5 - (i-1) * SIZES.row_height)
        row:SetPoint("TOPRIGHT", -5, -5 - (i-1) * SIZES.row_height)
        row:SetHeight(SIZES.row_height)
        
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(22)
        icon:SetHeight(22)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        row.name = create_text(row, "", 10, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.name:SetWidth(150)
        row.quantity = create_text(row, "", 10, COLORS.text, "LEFT", row, "LEFT", 200, 0)
        row.price = create_text(row, "", 10, COLORS.gold, "LEFT", row, "LEFT", 280, 0)
        row.time_left = create_text(row, "", 10, COLORS.text, "LEFT", row, "LEFT", 380, 0)
        row.status = create_text(row, "", 10, COLORS.success, "LEFT", row, "LEFT", 460, 0)
        
        row:Hide()
        refs.auction_rows[i] = row
    end
    
    refs.no_auctions = create_text(list_frame, "No tienes subastas activas", 11, COLORS.text_dim, "CENTER")
    
    -- Actualizar al mostrar
    M.refresh_auctioning()
end

-- Actualizar lista de subastas del jugador
function M.refresh_auctioning()
    local refs = panel_refs.auctioning
    if not refs or not refs.auction_rows then return end
    
    -- Obtener subastas del jugador
    local num_auctions = 0
    local total_value = 0
    local auctions = {}
    
    -- Verificar si la AH esta abierta
    if AuctionFrame and AuctionFrame:IsVisible() then
        -- Solicitar lista de subastas propias
        GetOwnerAuctionItems(0)
        
        local batch, total = GetNumAuctionItems('owner')
        num_auctions = batch or 0
        
        for i = 1, num_auctions do
            local name, texture, count, quality, canUse, level, levelColHeader, 
                  minBid, minIncrement, buyoutPrice, bidAmount, highBidder, 
                  bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo('owner', i)
            
            if name then
                local time_left = GetAuctionItemTimeLeft('owner', i)
                local time_text = "Corto"
                if time_left == 1 then time_text = "Corto"
                elseif time_left == 2 then time_text = "Medio"
                elseif time_left == 3 then time_text = "Largo"
                elseif time_left == 4 then time_text = "Muy Largo"
                end
                
                local status = "|cFF00FF00Activa|r"
                if bidAmount and bidAmount > 0 then
                    status = "|cFFFFFF00Con Puja|r"
                end
                if saleStatus == 1 then
                    status = "|cFF00FF00Vendida!|r"
                end
                
                table.insert(auctions, {
                    name = name,
                    texture = texture,
                    count = count or 1,
                    buyout = buyoutPrice or 0,
                    bid = minBid or 0,
                    time_left = time_text,
                    status = status,
                    has_bid = bidAmount and bidAmount > 0,
                    sold = saleStatus == 1,
                    index = i
                })
                
                total_value = total_value + (buyoutPrice or minBid or 0)
            end
        end
    end
    
    -- Actualizar contadores
    if refs.active_count then
        refs.active_count:SetText(tostring(num_auctions))
    end
    if refs.total_value then
        refs.total_value:SetText(format_gold(total_value))
    end
    
    -- Actualizar filas
    for i, row in ipairs(refs.auction_rows) do
        local auction = auctions[i]
        if auction then
            if auction.texture then
                row.icon:SetTexture(auction.texture)
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row.name:SetText(auction.name)
            row.quantity:SetText("x" .. auction.count)
            row.price:SetText(format_gold(auction.buyout))
            row.time_left:SetText(auction.time_left)
            row.status:SetText(auction.status)
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Mostrar mensaje si no hay subastas
    if refs.no_auctions then
        if num_auctions == 0 then
            refs.no_auctions:Show()
        else
            refs.no_auctions:Hide()
        end
    end
end

-- ============================================
-- PANEL CRAFTING - FUNCIONAL
-- ============================================
function M.build_crafting(parent)
    if M.modules.crafting_ui and M.modules.crafting_ui.crear_crafting_ui then
        local f = M.modules.crafting_ui.crear_crafting_ui(parent)
        if f then f:Show() end
        return f
    end
end

function M.refresh_crafting_ui()
    if M.modules.crafting_ui and M.modules.crafting_ui.actualizar_crafting_ui then
        M.modules.crafting_ui.actualizar_crafting_ui()
    end
end

function M.build_item_tracker(parent)
    if M.modules.item_tracker_ui and M.modules.item_tracker_ui.crear_item_tracker_ui then
        local f = M.modules.item_tracker_ui.crear_item_tracker_ui(parent)
        if f then f:Show() end
        return f
    end
end

function M.refresh_item_tracker()
    if M.modules.item_tracker_ui and M.modules.item_tracker_ui.actualizar_item_tracker_ui then
        M.modules.item_tracker_ui.actualizar_item_tracker_ui()
    end
end

function M.refresh_crafting_ui()
    local refs = panel_refs.crafting
    if not refs then return end
    
    if not (M.modules and M.modules.crafting) then return end
    
    -- Obtener datos
    local rentables = M.modules.crafting.obtener_rentables() or {}
    local stats = M.modules.crafting.obtener_stats()
    
    -- Actualizar resumen
    if stats then
        refs.profitable_count:SetText(stats.total_rentables)
        refs.potential_profit:SetText(format_gold(stats.total_potential_profit or 0)) -- backend needs to provide this or we sum it here
        -- refs.missing_mats:SetText(stats.missing_mats_count or 0) 
    end
    
    -- Calcular total profit visual (si el backend no lo da directo)
    local total_profit = 0
    for _, r in ipairs(rentables) do
        if r.profit_info then total_profit = total_profit + r.profit_info.profit end
    end
    refs.potential_profit:SetText(format_gold(total_profit))
    
    -- Actualizar lista
    local has_recipes = false
    for i, row in ipairs(refs.recipe_rows) do
        if rentables[i] then
            has_recipes = true
            local recipe = rentables[i]
            local info = recipe.profit_info
            
            -- Icon (Item Result)
            -- recipe.item_link or recipe.icon
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(recipe.item_id)
            if itemTexture then
                row.icon:SetTexture(itemTexture)
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            row.name:SetText(recipe.name)
            row.cost:SetText(format_gold(info.material_cost))
            row.sell:SetText(format_gold(info.net_value)) -- net value (after cut)
            row.profit:SetText(format_gold(info.profit))
            
            -- Tooltip
            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(recipe.item_link)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Materiales Requeridos:", 1, 0.8, 0)
                for _, mat in ipairs(recipe.reagents) do
                    local color = "|cFFFF0000" -- red if missing
                    if mat.have >= mat.count then color = "|cFF00FF00" end -- green if have
                    GameTooltip:AddLine(string.format("%s%dx %s (%d/%d)|r", color, mat.count, mat.name, mat.have, mat.count))
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            row:Show()
        else
            row:Hide()
        end
    end
    
    if refs.no_recipes then
        if has_recipes then refs.no_recipes:Hide() else refs.no_recipes:Show() end
    end
end

-- ============================================
-- PANEL HISTORIAL - FUNCIONAL
-- ============================================
-- ============================================
-- PANEL HISTORIAL - FUNCIONAL
-- ============================================

local active_filter_type = "all" -- all, sales, purchases
local active_filter_period = 30 -- 7, 30

function M.filter_historial(filter_type, period)
    if filter_type then active_filter_type = filter_type end
    if period then active_filter_period = period end
    
    -- Actualizar visual de botones
    local refs = panel_refs.historial
    if refs then
        if refs.btn_all then 
            if active_filter_type == "all" then refs.btn_all:LockHighlight() else refs.btn_all:UnlockHighlight() end
        end
        if refs.btn_sales then 
            if active_filter_type == "sales" then refs.btn_sales:LockHighlight() else refs.btn_sales:UnlockHighlight() end
        end
        if refs.btn_purchases then 
            if active_filter_type == "purchases" then refs.btn_purchases:LockHighlight() else refs.btn_purchases:UnlockHighlight() end
        end
        
        if refs.btn_7d then
            if active_filter_period == 7 then refs.btn_7d:LockHighlight() else refs.btn_7d:UnlockHighlight() end
        end
        if refs.btn_30d then
            if active_filter_period == 30 then refs.btn_30d:LockHighlight() else refs.btn_30d:UnlockHighlight() end
        end
    end

    M.refresh_historial()
end

function M.build_historial(parent)
    panel_refs.historial = {}
    local refs = panel_refs.historial
    
    -- Filtros
    local filter_bar = CreateFrame("Frame", nil, parent)
    filter_bar:SetPoint("TOPLEFT", 10, -10)
    filter_bar:SetPoint("TOPRIGHT", -10, -10)
    filter_bar:SetHeight(40)
    create_backdrop(filter_bar, COLORS.bg_medium, COLORS.border, 1)
    
    local btn_all = create_button(filter_bar, "Todo", 60, 26, {0.3, 0.4, 0.5, 0.9})
    btn_all:SetPoint("LEFT", filter_bar, "LEFT", 10, 0)
    btn_all:SetScript("OnClick", function() M.filter_historial("all") end)
    refs.btn_all = btn_all
    
    local btn_sales = create_button(filter_bar, "Ventas", 70, 26, {0.2, 0.5, 0.3, 0.9})
    btn_sales:SetPoint("LEFT", btn_all, "RIGHT", 5, 0)
    btn_sales:SetScript("OnClick", function() M.filter_historial("sales") end)
    refs.btn_sales = btn_sales
    
    local btn_purchases = create_button(filter_bar, "Compras", 70, 26, {0.5, 0.3, 0.2, 0.9})
    btn_purchases:SetPoint("LEFT", btn_sales, "RIGHT", 5, 0)
    btn_purchases:SetScript("OnClick", function() M.filter_historial("purchases") end)
    refs.btn_purchases = btn_purchases
    
    create_text(filter_bar, "Periodo:", 10, COLORS.text, "LEFT", btn_purchases, "RIGHT", 20, 0)
    
    local btn_7d = create_button(filter_bar, "7 dias", 60, 26, {0.25, 0.35, 0.45, 0.9})
    btn_7d:SetPoint("LEFT", btn_purchases, "RIGHT", 70, 0)
    btn_7d:SetScript("OnClick", function() M.filter_historial(nil, 7) end)
    refs.btn_7d = btn_7d
    
    local btn_30d = create_button(filter_bar, "30 dias", 60, 26, {0.25, 0.35, 0.45, 0.9})
    btn_30d:SetPoint("LEFT", btn_7d, "RIGHT", 5, 0)
    btn_30d:SetScript("OnClick", function() M.filter_historial(nil, 30) end)
    refs.btn_30d = btn_30d
    
    -- Init state
    M.filter_historial("all", 30)
    
    refs.total_label = create_text(filter_bar, "Total: 0g", 11, COLORS.gold, "RIGHT", filter_bar, "RIGHT", -10, 0)
    
    -- Header
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 10, -60)
    header:SetPoint("TOPRIGHT", -10, -60)
    header:SetHeight(22)
    create_backdrop(header, {0.12, 0.12, 0.15, 1}, COLORS.border, 1)
    
    create_text(header, "Tipo", 10, COLORS.text_dim, "LEFT", header, "LEFT", 10, 0)
    create_text(header, "Item", 10, COLORS.text_dim, "LEFT", header, "LEFT", 70, 0)
    create_text(header, "Cantidad", 10, COLORS.text_dim, "LEFT", header, "LEFT", 250, 0)
    create_text(header, "Precio", 10, COLORS.text_dim, "LEFT", header, "LEFT", 330, 0)
    create_text(header, "Jugador", 10, COLORS.text_dim, "LEFT", header, "LEFT", 420, 0)
    create_text(header, "Fecha", 10, COLORS.text_dim, "RIGHT", header, "RIGHT", -10, 0)
    
    -- Lista
    local list_frame = CreateFrame("Frame", nil, parent)
    list_frame:SetPoint("TOPLEFT", 10, -85)
    list_frame:SetPoint("BOTTOMRIGHT", -10, 10)
    create_backdrop(list_frame, COLORS.bg_medium, COLORS.border, 1)
    
    refs.history_rows = {}
    for i = 1, 12 do
        local row = CreateFrame("Frame", nil, list_frame)
        row:SetPoint("TOPLEFT", 5, -5 - (i-1) * SIZES.row_height)
        row:SetPoint("TOPRIGHT", -5, -5 - (i-1) * SIZES.row_height)
        row:SetHeight(SIZES.row_height)
        
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        row.type_text = create_text(row, "", 10, COLORS.success, "LEFT", row, "LEFT", 10, 0)
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 60, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        row.name = create_text(row, "", 10, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.name:SetWidth(140)
        row.quantity = create_text(row, "", 10, COLORS.text, "LEFT", row, "LEFT", 250, 0)
        row.price = create_text(row, "", 10, COLORS.gold, "LEFT", row, "LEFT", 330, 0)
        row.player = create_text(row, "", 10, COLORS.text_dim, "LEFT", row, "LEFT", 420, 0)
        row.date = create_text(row, "", 9, COLORS.text_dim, "RIGHT", row, "RIGHT", -5, 0)
        
        row:Hide()
        refs.history_rows[i] = row
    end
    
    refs.no_history = create_text(list_frame, "No hay transacciones registradas", 11, COLORS.text_dim, "CENTER")
end

function M.refresh_historial()
    local refs = panel_refs.historial
    if not refs or not refs.history_rows then return end
    
    local records = {}
    local total = 0
    
    -- Obtener datos de accounting
    -- Obtener datos de accounting
    local cutoff_time = time() - (active_filter_period * 24 * 60 * 60)
    
    if AuxTradingAccounting then
        -- Ventas
        if (active_filter_type == "all" or active_filter_type == "sales") and AuxTradingAccounting.sales then
            for item_key, item_records in pairs(AuxTradingAccounting.sales) do
                for _, record in ipairs(item_records) do
                    if record.time >= cutoff_time then
                        table.insert(records, {
                            type = "Venta",
                            type_color = COLORS.success,
                            item_key = item_key,
                            quantity = record.quantity or 1,
                            price = record.price or 0,
                            player = record.buyer or "Desconocido",
                            time = record.time or 0
                        })
                        total = total + ((record.price or 0) * (record.quantity or 1))
                    end
                end
            end
        end
        
        -- Compras
        if (active_filter_type == "all" or active_filter_type == "purchases") and AuxTradingAccounting.purchases then
            for item_key, item_records in pairs(AuxTradingAccounting.purchases) do
                for _, record in ipairs(item_records) do
                    if record.time >= cutoff_time then
                        table.insert(records, {
                            type = "Compra",
                            type_color = COLORS.danger,
                            item_key = item_key,
                            quantity = record.quantity or 1,
                            price = record.price or 0,
                            player = record.seller or "Desconocido",
                            time = record.time or 0
                        })
                        total = total - ((record.price or 0) * (record.quantity or 1))
                    end
                end
            end
        end
    end
    
    -- Ordenar por tiempo
    table.sort(records, function(a, b) return a.time > b.time end)
    
    -- Actualizar total
    if refs.total_label then
        refs.total_label:SetText("Total: " .. format_gold(total))
    end
    
    -- Mostrar registros
    local has_records = false
    for i, row in ipairs(refs.history_rows) do
        if records[i] then
            has_records = true
            local r = records[i]
            row.type_text:SetText(r.type)
            row.type_text:SetTextColor(unpack(r.type_color))
            
            local item_id = extract_item_id(r.item_key)
            local name = r.item_key
            if item_id > 0 then
                local item_name = GetItemInfo(item_id)
                if item_name then name = item_name end
            end
            
            row.name:SetText(name)
            row.quantity:SetText("x" .. r.quantity)
            row.price:SetText(format_gold(r.price * r.quantity))
            row.player:SetText(r.player)
            row.date:SetText(format_time_ago(r.time))
            row:Show()
        else
            row:Hide()
        end
    end
    
    if refs.no_history then
        if has_records then refs.no_history:Hide() else refs.no_history:Show() end
    end
end



-- ============================================
-- PANEL CONFIG - FUNCIONAL
-- ============================================
-- ============================================
-- PANEL CONFIG - REEMPLAZADO POR MODULO EXTERNO
-- ============================================
-- La función M.build_config ha sido eliminada en favor de aux.tabs.trading.config_ui


-- ============================================
-- PANEL OPORTUNIDADES - FUNCIONAL CON SCROLL
-- ============================================
function M.build_oportunidades(parent)
    panel_refs.oportunidades = {}
    local refs = panel_refs.oportunidades
    
    -- Barra de acciones
    local action_bar = CreateFrame("Frame", nil, parent)
    action_bar:SetPoint("TOPLEFT", 10, -10)
    action_bar:SetPoint("TOPRIGHT", -10, -10)
    action_bar:SetHeight(35)
    
    local btn_scan = create_button(action_bar, "Full Scan", 80, 26, {0.2, 0.5, 0.3, 0.9})
    btn_scan:SetPoint("LEFT", 0, 0)
    btn_scan:SetScript("OnClick", function()
        if M.start_scan then
            M.start_scan()
        else
            aux.print("|cFFFF0000[Error]|r La función start_scan no existe en el módulo")
        end
    end)
    refs.btn_scan = btn_scan
    
    local btn_quick = create_button(action_bar, "Scan Rapido", 90, 26, {0.3, 0.4, 0.5, 0.9})
    btn_quick:SetPoint("LEFT", btn_scan, "RIGHT", 5, 0)
    btn_quick:SetScript("OnClick", function()
        if M.start_quick_scan then
            M.start_quick_scan()
        else
            aux.print("|cFFFF0000[Error]|r La función start_quick_scan no existe en el módulo")
        end
    end)
    refs.btn_quick = btn_quick
    
    local btn_stop = create_button(action_bar, "Detener", 70, 26, {0.5, 0.3, 0.2, 0.9})
    btn_stop:SetPoint("LEFT", btn_quick, "RIGHT", 5, 0)
    btn_stop:SetScript("OnClick", function()
        if M.stop_scan then
            M.stop_scan()
        end
    end)
    refs.btn_stop = btn_stop
    
    local btn_buy = create_button(action_bar, "Comprar", 70, 26, {0.2, 0.4, 0.6, 0.9})
    btn_buy:SetPoint("LEFT", btn_stop, "RIGHT", 5, 0)
    btn_buy:SetScript("OnClick", function()
        local selected_opp = refs.selected_opportunity
        if selected_opp and M.buy_opportunity then
            M.buy_opportunity(selected_opp)
        else
            aux.print("|cFFFF0000[Error]|r Selecciona una oportunidad primero")
        end
    end)
    refs.btn_buy = btn_buy
    
    refs.status = create_text(action_bar, "|cFF00FF00Listo|r", 10, nil, "RIGHT", action_bar, "RIGHT", -10, 0)
    
    -- Header de columnas
    local col_header = CreateFrame("Frame", nil, parent)
    col_header:SetPoint("TOPLEFT", 10, -55)
    col_header:SetPoint("TOPRIGHT", -25, -55)  -- Espacio para scrollbar
    col_header:SetHeight(22)
    create_backdrop(col_header, {0.12, 0.12, 0.15, 1}, COLORS.border, 1)
    
    create_text(col_header, "Item", 10, COLORS.text_dim, "LEFT", col_header, "LEFT", 10, 0)
    create_text(col_header, "Precio", 10, COLORS.text_dim, "LEFT", col_header, "LEFT", 200, 0)
    create_text(col_header, "Mercado", 10, COLORS.text_dim, "LEFT", col_header, "LEFT", 280, 0)
    create_text(col_header, "Ganancia", 10, COLORS.text_dim, "LEFT", col_header, "LEFT", 360, 0)
    create_text(col_header, "%", 10, COLORS.text_dim, "LEFT", col_header, "LEFT", 440, 0)
    
    -- Container para scroll
    local list_container = CreateFrame("Frame", nil, parent)
    list_container:SetPoint("TOPLEFT", 10, -80)
    list_container:SetPoint("BOTTOMRIGHT", -10, 10)
    create_backdrop(list_container, COLORS.bg_medium, COLORS.border, 1)
    
    -- ScrollFrame
    local scroll_frame = CreateFrame("ScrollFrame", "TradingOpportunitiesScroll", list_container, "FauxScrollFrameTemplate")
    scroll_frame:SetPoint("TOPLEFT", 5, -5)
    scroll_frame:SetPoint("BOTTOMRIGHT", -25, 5)
    refs.scroll_frame = scroll_frame
    
    -- Content frame para las filas
    local content = CreateFrame("Frame", nil, scroll_frame)
    content:SetWidth(scroll_frame:GetWidth())
    content:SetHeight(1)  -- Se ajustara dinamicamente
    scroll_frame:SetScrollChild(content)
    refs.content = content
    
    -- Numero de filas visibles (basado en altura disponible)
    local VISIBLE_ROWS = 15
    local ROW_HEIGHT = SIZES.row_height or 24
    refs.visible_rows = VISIBLE_ROWS
    refs.row_height = ROW_HEIGHT
    
    -- Crear filas visibles
    refs.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, list_container)
        row:SetPoint("TOPLEFT", 5, -5 - (i-1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -25, -5 - (i-1) * ROW_HEIGHT)
        row:SetHeight(ROW_HEIGHT)
        
        if math.mod(i, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            bg:SetVertexColor(0.1, 0.1, 0.12, 0.5)
        end
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(22)
        icon:SetHeight(22)
        icon:SetPoint("LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon = icon
        
        row.name = create_text(row, "", 11, COLORS.text, "LEFT", icon, "RIGHT", 8, 0)
        row.name:SetWidth(150)
        row.price = create_text(row, "", 10, COLORS.text, "LEFT", row, "LEFT", 200, 0)
        row.market = create_text(row, "", 10, COLORS.text, "LEFT", row, "LEFT", 280, 0)
        row.profit = create_text(row, "", 10, COLORS.success, "LEFT", row, "LEFT", 360, 0)
        row.pct = create_text(row, "", 10, COLORS.gold, "LEFT", row, "LEFT", 440, 0)
        
        row:SetScript("OnEnter", function()
            this:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            this:SetBackdropColor(0.2, 0.3, 0.4, 0.5)
        end)
        row:SetScript("OnLeave", function()
            -- Mantener seleccion si esta seleccionada
            if refs.selected_opportunity and this.opportunity == refs.selected_opportunity then
                this:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                this:SetBackdropColor(0.3, 0.5, 0.3, 0.6)
            else
                this:SetBackdrop(nil)
            end
        end)
        row:SetScript("OnClick", function()
            refs.selected_opportunity = this.opportunity
            for j = 1, VISIBLE_ROWS do
                if refs.rows[j] == this then
                    this:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                    this:SetBackdropColor(0.3, 0.5, 0.3, 0.6)
                else
                    refs.rows[j]:SetBackdrop(nil)
                end
            end
        end)
        
        row:Hide()
        refs.rows[i] = row
    end
    
    -- Configurar scroll - En WoW 1.12, usamos arg1 para el offset
    scroll_frame:SetScript("OnVerticalScroll", function()
        local offset = math.floor((arg1 or 0) / ROW_HEIGHT + 0.5)
        FauxScrollFrame_SetOffset(this, offset)
        M.update_opportunities()
    end)
    
    -- Habilitar scroll con rueda del mouse
    list_container:EnableMouseWheel(true)
    list_container:SetScript("OnMouseWheel", function()
        local current = FauxScrollFrame_GetOffset(scroll_frame)
        local max_scroll = refs.total_items and (refs.total_items - VISIBLE_ROWS) or 0
        if max_scroll < 0 then max_scroll = 0 end
        
        if arg1 > 0 then
            -- Scroll up
            if current > 0 then
                FauxScrollFrame_SetOffset(scroll_frame, current - 1)
                M.update_opportunities()
            end
        else
            -- Scroll down
            if current < max_scroll then
                FauxScrollFrame_SetOffset(scroll_frame, current + 1)
                M.update_opportunities()
            end
        end
    end)
    
    refs.no_items = create_text(list_container, "Haz un Full Scan para encontrar oportunidades", 11, COLORS.text_dim, "CENTER")
    refs.total_items = 0
end

-- Actualizar lista de oportunidades con soporte de scroll
function M.update_opportunities()
    local refs = panel_refs.oportunidades
    if not refs or not refs.rows then return end
    
    -- Obtener oportunidades de core.lua
    local opportunities = {}
    if M.get_opportunities then
        opportunities = M.get_opportunities()
    end
    
    -- Usar getn para Lua 5.0
    local opp_count = 0
    if opportunities then
        opp_count = getn(opportunities)
    end
    
    refs.total_items = opp_count
    
    -- Actualizar FauxScrollFrame
    local VISIBLE_ROWS = refs.visible_rows or 15
    local ROW_HEIGHT = refs.row_height or 24
    
    if refs.scroll_frame then
        FauxScrollFrame_Update(refs.scroll_frame, opp_count, VISIBLE_ROWS, ROW_HEIGHT)
    end
    
    if opp_count == 0 then
        if refs.no_items then refs.no_items:Show() end
        for i = 1, VISIBLE_ROWS do
            if refs.rows[i] then refs.rows[i]:Hide() end
        end
        if refs.status then
            refs.status:SetText("|cFF00FF00Listo|r")
        end
        return
    end
    
    if refs.no_items then refs.no_items:Hide() end
    
    -- Obtener offset del scroll
    local offset = 0
    if refs.scroll_frame then
        offset = FauxScrollFrame_GetOffset(refs.scroll_frame) or 0
    end
    
    for i = 1, VISIBLE_ROWS do
        local row = refs.rows[i]
        local data_index = i + offset
        
        if opportunities[data_index] then
            local opp = opportunities[data_index]
            row.opportunity = opp
            
            local auction_info = opp.auction_info or {}
            local item_name = auction_info.name or "Item Desconocido"
            local buyout_price = auction_info.buyout_price or 0
            local market_price = opp.avg_price or 0
            local profit = opp.profit or 0
            local discount = opp.discount or 0
            local discount_pct = math.floor(discount * 100)
            
            -- Obtener icono del item
            local item_texture = "Interface\\Icons\\INV_Misc_QuestionMark"
            local item_id = nil
            
            -- 1. Intentar con texture directa si existe (mas rapido)
            if auction_info.texture then
                item_texture = auction_info.texture
            else
                -- 2. Extraer item_id del item_key
                -- aux usa formato "12345:0:0:0" o "item:12345:0:0"
                if auction_info.item_key then
                    -- Primero intentar formato "item:12345"
                    local _, _, id = string.find(auction_info.item_key, "item:(%d+)")
                    if id then 
                        item_id = tonumber(id) 
                    else
                        -- Intentar formato "12345:0:0" (solo numeros al inicio)
                        local _, _, id2 = string.find(auction_info.item_key, "^(%d+)")
                        if id2 then item_id = tonumber(id2) end
                    end
                end
                
                -- 3. Usar GetItemInfo para obtener la textura
                if item_id then
                    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(item_id)
                    if texture then
                        item_texture = texture
                    end
                end
            end
            
            row.icon:SetTexture(item_texture)
            row.name:SetText(item_name)
            row.price:SetText(format_gold(buyout_price))
            row.market:SetText(format_gold(market_price))
            row.profit:SetText(format_gold(profit))
            row.pct:SetText(string.format("+%d%%", discount_pct))
            
            -- Mantener seleccion visual
            if refs.selected_opportunity and row.opportunity == refs.selected_opportunity then
                row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                row:SetBackdropColor(0.3, 0.5, 0.3, 0.6)
            else
                row:SetBackdrop(nil)
            end
            
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Actualizar status
    if refs.status then
        refs.status:SetText(string.format("|cFF00FF00%d oportunidades|r", opp_count))
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:SetScript("OnEvent", function()
    -- Initialize Item Tracker
    if M.modules.item_tracker and M.modules.item_tracker.inicializar then
        M.modules.item_tracker.inicializar()
    end
end)
