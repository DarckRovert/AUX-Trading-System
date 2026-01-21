module 'aux.tabs.trading'

local aux = require 'aux'
local money = require 'aux.util.money'

local M = getfenv()

-- Acceso al modulo lógic (vendor.lua ya cargó aquí)
-- local Logic = aux.tabs.trading 

-- Debug Removed

-- Referencias
local vendor_frame = nil

-- ============================================================================
-- Colores y Estilos (Local - frame.lua no cargado aún)
-- ============================================================================

local COLORS = {
    gold = {1.0, 0.82, 0.0, 1},
    green = {0.2, 0.8, 0.2, 1},
    red = {0.8, 0.2, 0.2, 1},
    text = {0.9, 0.9, 0.9, 1},
    text_dim = {0.6, 0.6, 0.6, 1},
    primary = {0.2, 0.5, 0.3, 0.9},
    bar_bg = {0.15, 0.15, 0.15, 1},
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
    create_backdrop(btn, color or {0.2, 0.2, 0.25, 0.9}, {0.4, 0.4, 0.45, 1}, 1)
    btn.btn_color = color or {0.2, 0.2, 0.25, 0.9}
    local txt = create_text(btn, text, 11, COLORS.text, "CENTER")
    btn.label = txt
    btn:SetScript("OnEnter", function()
        local c = this.btn_color
        create_backdrop(this, {c[1]+0.1, c[2]+0.1, c[3]+0.1, 1}, {0.4, 0.4, 0.45, 1}, 1)
    end)
    btn:SetScript("OnLeave", function()
        create_backdrop(this, this.btn_color, {0.4, 0.4, 0.45, 1}, 1)
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

    function M.build_vendor_panel(parent)
    if vendor_frame then vendor_frame:Show(); return end
        
    vendor_frame = CreateFrame("Frame", nil, parent)
    vendor_frame:SetAllPoints()
    
    -- Cabecera
    local header = CreateFrame("Frame", nil, vendor_frame)
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetPoint("TOPRIGHT", -10, -10)
    header:SetHeight(60)
    
    local title = create_text(header, "Vendor Shuffle - Dinero Gratis", 16, COLORS.gold, "TOPLEFT", header, "TOPLEFT", 0, 0)
    local subtitle = create_text(header, "Encuentra items que venden al NPC mas caro que su precio en subasta.", 10, COLORS.text, "TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    
    -- Botón Scan
    local scan_btn = create_button(header, "Iniciar Busqueda", 120, 25, COLORS.primary)
    scan_btn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -15, -10)
    scan_btn:SetScript("OnClick", function()
        M.start_vendor_search()
    end)
    
    -- Botón Buy All
    local buy_all_btn = create_button(header, "Comprar Todo", 100, 25)
    buy_all_btn:SetPoint("RIGHT", scan_btn, "LEFT", -10, 0)
    buy_all_btn:SetScript("OnClick", function()
        if M.buy_all_candidates then
            M.buy_all_candidates()
        else
            aux.print("Función buy_all_candidates no disponible")
        end
    end)
    
    -- Stats
    local stats_text = create_text(header, "Profit Potencial: |cFF00FF000c|r", 12, COLORS.text, "RIGHT", buy_all_btn, "LEFT", -20, 0)
    vendor_frame.stats_text = stats_text
    
    -- Container Lista
    local list_container = CreateFrame("Frame", nil, vendor_frame)
    list_container:SetPoint("TOPLEFT", 10, -80)
    list_container:SetPoint("BOTTOMRIGHT", -28, 10)
    
    -- Backdrops (simulado en vanilla si no usas librerias complejas, usaremos frames planos)
    -- Fondo oscuro real
    local bg = list_container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, 0.3)
    
    -- Mensaje de ayuda inicial
    vendor_frame.help_text = create_text(list_container, "Dale click a 'Iniciar Busqueda' para encontrar dinero gratis.", 12, COLORS.text_dim, "CENTER", list_container, "CENTER", 0, 0)
    
    -- Scroll
    vendor_frame.scroll_frame = CreateFrame("ScrollFrame", "AuxVendorScrollFrame", list_container, "FauxScrollFrameTemplate")
    vendor_frame.scroll_frame:SetPoint("TOPLEFT", 0, 0)
    vendor_frame.scroll_frame:SetPoint("BOTTOMRIGHT", -26, 0)
    vendor_frame.scroll_frame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(24, M.refresh_vendor_ui)
    end)
    
    -- Filas
    vendor_frame.rows = {}
    for i = 1, 15 do
        local row = CreateFrame("Button", nil, list_container)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 0, -(i-1)*24)
        row:SetPoint("TOPRIGHT", 0, -(i-1)*24)
        
        -- Fondo alternado
        local row_bg = row:CreateTexture(nil, "BACKGROUND")
        row_bg:SetAllPoints()
        if math.mod(i, 2) == 0 then row_bg:SetTexture(1,1,1,0.05) else row_bg:SetTexture(1,1,1,0) end
        
        -- Icono
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", 2, 0)
        row.icon = icon
        
        -- Nombre
        local name = create_text(row, "", 12, COLORS.text, "LEFT", icon, "RIGHT", 5, 0)
        row.name = name
        
        -- Profit Text
        local profit = create_text(row, "", 12, COLORS.green, "RIGHT", row, "RIGHT", -150, 0)
        row.profit_text = profit
        
        -- BARRA GRAFICA DE PROFIT
        -- Fondo barra
        local bar_bg = row:CreateTexture(nil, "ARTWORK")
        bar_bg:SetHeight(8)
        bar_bg:SetWidth(100)
        bar_bg:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        bar_bg:SetTexture(unpack(COLORS.bar_bg))
        
        -- Barra relleno
        local bar_fill = row:CreateTexture(nil, "OVERLAY")
        bar_fill:SetHeight(8)
        bar_fill:SetPoint("LEFT", bar_bg, "LEFT", 0, 0)
        bar_fill:SetTexture(unpack(COLORS.green))
        bar_fill:SetWidth(0) -- Start empty
        row.bar_fill = bar_fill
        row.bar_bg = bar_bg
        
        -- Click para comprar (simple hook)
        row:SetScript("OnClick", function()
            if this.data then
                aux.place_bid(this.data.auction_record.type, this.data.auction_record.index, this.data.buyout, function()
                    aux.print("Comprado: " .. this.data.name)
                    -- Forzar refresh simple
                    -- M.refresh_vendor_ui()
                end)
            end
        end)
        
        vendor_frame.rows[i] = row
    end
end

function M.refresh_vendor_ui()
    if not vendor_frame then return end
    
    local items = M.get_vendor_items() or {}
    local num_items = table.getn(items)
    
    -- Toggle ayuda
    if vendor_frame.help_text then
        if num_items == 0 then vendor_frame.help_text:Show() else vendor_frame.help_text:Hide() end
    end
    
    -- Ordenar por profit mayor a menor
    table.sort(items, function(a,b) return a.profit > b.profit end)
    
    local max_profit = 0
    local total_profit = 0
    if num_items > 0 then max_profit = items[1].profit end
    for _, item in ipairs(items) do total_profit = total_profit + item.profit end
    
    if vendor_frame.stats_text then
        vendor_frame.stats_text:SetText("Profit Potencial: " .. format_gold(total_profit))
    end
    
    FauxScrollFrame_Update(vendor_frame.scroll_frame, num_items or 0, 15, 24)
    local offset = FauxScrollFrame_GetOffset(vendor_frame.scroll_frame)
    
    for i=1, 15 do
        local row = vendor_frame.rows[i]
        local idx = offset + i
        if idx <= num_items then
            local item = items[idx]
            row.data = item
            
            row.name:SetText(item.name)
            row.icon:SetTexture(item.texture)
            
            local p_text = format_gold(item.profit)
            row.profit_text:SetText("+"..p_text)
            
            -- Grafica: Ancho relativo al maximo profit
            if max_profit > 0 then
                local pct = item.profit / max_profit
                row.bar_fill:SetWidth(100 * pct)
            else
                row.bar_fill:SetWidth(0)
            end
            
            row:Show()
        else
            row:Hide()
        end
    end
end
