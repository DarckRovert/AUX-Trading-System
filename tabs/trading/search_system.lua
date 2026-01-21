-- ============================================================================
-- Sistema de Búsqueda Avanzada
-- ============================================================================
-- Proporciona búsqueda rápida, autocompletado y filtrado de items
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local info = require('aux.util.info')
local money = require('aux.util.money')
local M = getfenv()

-- Variables globales del módulo
local search_frame = nil
local search_input = nil
local search_results_frame = nil
local search_results = {}
local search_history = {}
local max_history = 20
local autocomplete_frame = nil
local autocomplete_items = {}

-- ============================================================================
-- Funciones de Búsqueda
-- ============================================================================

-- Buscar items por nombre
local function buscar_items(query)
    if not query or query == "" then
        return {}
    end
    
    query = string.lower(query)
    local resultados = {}
    
    -- Buscar en oportunidades actuales
    if aux.trading and aux.trading.oportunidades then
        for _, opp in ipairs(aux.trading.oportunidades) do
            local item_name = string.lower(opp.item_name or "")
            if string.find(item_name, query, 1, true) then
                table.insert(resultados, {
                    type = "oportunidad",
                    item_name = opp.item_name,
                    item_key = opp.item_key,
                    profit = opp.profit_estimado,
                    roi = opp.roi,
                    precio = opp.precio_compra,
                    data = opp
                })
            end
        end
    end
    
    -- Buscar en historial de trades
    if aux.trading and aux.trading.historial then
        for _, trade in ipairs(aux.trading.historial) do
            local item_name = string.lower(trade.item_name or "")
            if string.find(item_name, query, 1, true) then
                local found = false
                for _, r in ipairs(resultados) do
                    if r.item_key == trade.item_key then
                        found = true
                        break
                    end
                end
                
                if not found then
                    table.insert(resultados, {
                        type = "historial",
                        item_name = trade.item_name,
                        item_key = trade.item_key,
                        profit = trade.profit,
                        precio = trade.precio_compra,
                        data = trade
                    })
                end
            end
        end
    end
    
    -- Limitar resultados
    local max_results = 50
    if table.getn(resultados) > max_results then
        local temp = {}
        for i = 1, max_results do
            table.insert(temp, resultados[i])
        end
        resultados = temp
    end
    
    return resultados
end

-- Buscar por categoría
local function buscar_por_categoria(categoria)
    local resultados = {}
    
    if aux.trading and aux.trading.oportunidades then
        for _, opp in ipairs(aux.trading.oportunidades) do
            if opp.categoria == categoria then
                table.insert(resultados, {
                    type = "oportunidad",
                    item_name = opp.item_name,
                    item_key = opp.item_key,
                    profit = opp.profit_estimado,
                    roi = opp.roi,
                    precio = opp.precio_compra,
                    data = opp
                })
            end
        end
    end
    
    return resultados
end

-- Buscar por rango de precio
local function buscar_por_precio(min_precio, max_precio)
    local resultados = {}
    
    if aux.trading and aux.trading.oportunidades then
        for _, opp in ipairs(aux.trading.oportunidades) do
            local precio = opp.precio_compra or 0
            if precio >= min_precio and precio <= max_precio then
                table.insert(resultados, {
                    type = "oportunidad",
                    item_name = opp.item_name,
                    item_key = opp.item_key,
                    profit = opp.profit_estimado,
                    roi = opp.roi,
                    precio = precio,
                    data = opp
                })
            end
        end
    end
    
    return resultados
end

-- Buscar por profit mínimo
local function buscar_por_profit(min_profit)
    local resultados = {}
    
    if aux.trading and aux.trading.oportunidades then
        for _, opp in ipairs(aux.trading.oportunidades) do
            local profit = opp.profit_estimado or 0
            if profit >= min_profit then
                table.insert(resultados, {
                    type = "oportunidad",
                    item_name = opp.item_name,
                    item_key = opp.item_key,
                    profit = profit,
                    roi = opp.roi,
                    precio = opp.precio_compra,
                    data = opp
                })
            end
        end
    end
    
    return resultados
end

-- ============================================================================
-- Sistema de Autocompletado
-- ============================================================================

local function obtener_sugerencias(query)
    if not query or query == "" then
        return {}
    end
    
    query = string.lower(query)
    local sugerencias = {}
    local items_vistos = {}
    
    -- Obtener items únicos
    if aux.trading and aux.trading.oportunidades then
        for _, opp in ipairs(aux.trading.oportunidades) do
            local item_name = opp.item_name or ""
            local item_lower = string.lower(item_name)
            
            if string.find(item_lower, query, 1, true) and not items_vistos[item_name] then
                table.insert(sugerencias, item_name)
                items_vistos[item_name] = true
            end
        end
    end
    
    -- Limitar sugerencias
    local max_sugerencias = 10
    if table.getn(sugerencias) > max_sugerencias then
        local temp = {}
        for i = 1, max_sugerencias do
            table.insert(temp, sugerencias[i])
        end
        sugerencias = temp
    end
    
    return sugerencias
end

local function mostrar_autocompletado(sugerencias)
    if not autocomplete_frame then
        return
    end
    
    -- Limpiar sugerencias anteriores
    if autocomplete_items then
        for _, item in ipairs(autocomplete_items) do
            if item.frame then
                item.frame:Hide()
            end
        end
    end
    autocomplete_items = {}
    
    if table.getn(sugerencias) == 0 then
        autocomplete_frame:Hide()
        return
    end
    
    -- Mostrar frame
    autocomplete_frame:Show()
    
    -- Crear items de sugerencia
    local y_offset = -5
    for i, sugerencia in ipairs(sugerencias) do
        local item_frame = CreateFrame("Button", nil, autocomplete_frame)
        item_frame:SetSize(280, 20)
        item_frame:SetPoint("TOPLEFT", 5, y_offset)
        
        -- Fondo
        local bg = item_frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        item_frame.bg = bg
        
        -- Texto
        local text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 5, 0)
        text:SetText(sugerencia)
        text:SetTextColor(1, 1, 1)
        
        -- Hover
        item_frame:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.2, 0.4, 0.6, 0.8)
        end)
        
        item_frame:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        end)
        
        -- Click
        item_frame:SetScript("OnClick", function(self)
            if search_input then
                search_input:SetText(sugerencia)
                ejecutar_busqueda(sugerencia)
            end
            autocomplete_frame:Hide()
        end)
        
        table.insert(autocomplete_items, {frame = item_frame, text = sugerencia})
        y_offset = y_offset - 22
    end
    
    -- Ajustar tamaño del frame
    local height = math.min(table.getn(sugerencias) * 22 + 10, 200)
    autocomplete_frame:SetHeight(height)
end

-- ============================================================================
-- Historial de Búsquedas
-- ============================================================================

local function agregar_a_historial(query)
    if not query or query == "" then
        return
    end
    
    -- Evitar duplicados
    for i, item in ipairs(search_history) do
        if item == query then
            table.remove(search_history, i)
            break
        end
    end
    
    -- Agregar al inicio
    table.insert(search_history, 1, query)
    
    -- Limitar tamaño
    if table.getn(search_history) > max_history then
        table.remove(search_history, table.getn(search_history))
    end
end

local function obtener_historial()
    return search_history
end

local function limpiar_historial()
    search_history = {}
end

-- ============================================================================
-- Interfaz de Usuario
-- ============================================================================

local function mostrar_resultados(resultados)
    if not search_results_frame then
        return
    end
    
    search_results = resultados
    
    -- Limpiar resultados anteriores
    if search_results_frame.items then
        for _, item in ipairs(search_results_frame.items) do
            if item.frame then
                item.frame:Hide()
            end
        end
    end
    search_results_frame.items = {}
    
    if table.getn(resultados) == 0 then
        -- Mostrar mensaje de no resultados
        local no_results = search_results_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        no_results:SetPoint("CENTER", 0, 0)
        no_results:SetText("No se encontraron resultados")
        no_results:SetTextColor(0.7, 0.7, 0.7)
        search_results_frame.no_results = no_results
        return
    end
    
    -- Ocultar mensaje de no resultados
    if search_results_frame.no_results then
        search_results_frame.no_results:Hide()
    end
    
    -- Crear items de resultado
    local y_offset = -10
    for i, resultado in ipairs(resultados) do
        local item_frame = CreateFrame("Button", nil, search_results_frame)
        item_frame:SetSize(560, 40)
        item_frame:SetPoint("TOPLEFT", 10, y_offset)
        
        -- Fondo
        local bg = item_frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if math.mod(i, 2) == 0 then
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        else
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        end
        item_frame.bg = bg
        
        -- Nombre del item
        local name_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name_text:SetPoint("LEFT", 10, 0)
        name_text:SetText(resultado.item_name)
        name_text:SetTextColor(1, 0.82, 0)
        
        -- Profit
        local profit_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        profit_text:SetPoint("LEFT", 250, 0)
        if resultado.profit and resultado.profit > 0 then
            profit_text:SetText("+" .. money.to_string(resultado.profit, true))
            profit_text:SetTextColor(0, 1, 0)
        else
            profit_text:SetText(money.to_string(resultado.profit or 0, true))
            profit_text:SetTextColor(1, 0, 0)
        end
        
        -- ROI
        if resultado.roi then
            local roi_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            roi_text:SetPoint("LEFT", 380, 0)
            roi_text:SetText(string.format("ROI: %.1f%%", resultado.roi))
            if resultado.roi > 50 then
                roi_text:SetTextColor(0, 1, 0)
            elseif resultado.roi > 20 then
                roi_text:SetTextColor(1, 1, 0)
            else
                roi_text:SetTextColor(1, 0.5, 0)
            end
        end
        
        -- Tipo
        local type_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        type_text:SetPoint("RIGHT", -10, 0)
        if resultado.type == "oportunidad" then
            type_text:SetText("Oportunidad")
            type_text:SetTextColor(0, 1, 0)
        else
            type_text:SetText("Historial")
            type_text:SetTextColor(0.7, 0.7, 0.7)
        end
        
        -- Hover
        item_frame:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.2, 0.4, 0.6, 0.8)
            
            -- Mostrar tooltip
            if resultado.data and aux.trading and aux.trading.tooltips_advanced then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                aux.trading.tooltips_advanced.mostrar_tooltip_oportunidad(resultado.data)
                GameTooltip:Show()
            end
        end)
        
        item_frame:SetScript("OnLeave", function(self)
            if math.mod(i, 2) == 0 then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            else
                self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            end
            GameTooltip:Hide()
        end)
        
        -- Click
        item_frame:SetScript("OnClick", function(self)
            if resultado.data then
                -- Acción al hacer click (por ejemplo, abrir detalles)
                print("Seleccionado: " .. resultado.item_name)
            end
        end)
        
        table.insert(search_results_frame.items, {frame = item_frame, data = resultado})
        y_offset = y_offset - 42
    end
end

function ejecutar_busqueda(query)
    if not query or query == "" then
        mostrar_resultados({})
        return
    end
    
    -- Agregar a historial
    agregar_a_historial(query)
    
    -- Buscar
    local resultados = buscar_items(query)
    
    -- Mostrar resultados
    mostrar_resultados(resultados)
    
    -- Ocultar autocompletado
    if autocomplete_frame then
        autocomplete_frame:Hide()
    end
end

local function crear_search_ui(parent)
    -- Frame principal
    search_frame = CreateFrame("Frame", nil, parent)
    search_frame:SetAllPoints()
    search_frame:Hide()
    
    -- Título
    local title = search_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Búsqueda Avanzada de Items")
    title:SetTextColor(1, 0.82, 0)
    
    -- Input de búsqueda
    local search_bg = CreateFrame("Frame", nil, search_frame)
    search_bg:SetSize(300, 30)
    search_bg:SetPoint("TOP", 0, -40)
    search_bg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    search_input = CreateFrame("EditBox", nil, search_bg)
    search_input:SetSize(280, 20)
    search_input:SetPoint("CENTER", 0, 0)
    search_input:SetFontObject("GameFontNormal")
    search_input:SetAutoFocus(false)
    search_input:SetMaxLetters(50)
    
    -- Placeholder
    local placeholder = search_input:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("LEFT", 5, 0)
    placeholder:SetText("Buscar item...")
    placeholder:SetTextColor(0.5, 0.5, 0.5)
    
    search_input:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        
        -- Mostrar/ocultar placeholder
        if text == "" then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        
        -- Autocompletado
        if string.len(text) >= 2 then
            local sugerencias = obtener_sugerencias(text)
            mostrar_autocompletado(sugerencias)
        else
            if autocomplete_frame then
                autocomplete_frame:Hide()
            end
        end
    end)
    
    search_input:SetScript("OnEnterPressed", function(self)
        ejecutar_busqueda(self:GetText())
        self:ClearFocus()
    end)
    
    search_input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Frame de autocompletado
    autocomplete_frame = CreateFrame("Frame", nil, search_frame)
    autocomplete_frame:SetSize(290, 200)
    autocomplete_frame:SetPoint("TOP", search_bg, "BOTTOM", 0, -2)
    autocomplete_frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    autocomplete_frame:Hide()
    autocomplete_frame:SetFrameStrata("DIALOG")
    
    -- Botón de búsqueda
    local search_button = CreateFrame("Button", nil, search_frame, "UIPanelButtonTemplate")
    search_button:SetSize(100, 25)
    search_button:SetPoint("LEFT", search_bg, "RIGHT", 10, 0)
    search_button:SetText("Buscar")
    search_button:SetScript("OnClick", function()
        ejecutar_busqueda(search_input:GetText())
    end)
    
    -- Botón de limpiar
    local clear_button = CreateFrame("Button", nil, search_frame, "UIPanelButtonTemplate")
    clear_button:SetSize(80, 25)
    clear_button:SetPoint("LEFT", search_button, "RIGHT", 5, 0)
    clear_button:SetText("Limpiar")
    clear_button:SetScript("OnClick", function()
        search_input:SetText("")
        mostrar_resultados({})
    end)
    
    -- Frame de resultados
    search_results_frame = CreateFrame("ScrollFrame", nil, search_frame, "UIPanelScrollFrameTemplate")
    search_results_frame:SetSize(580, 350)
    search_results_frame:SetPoint("TOP", search_bg, "BOTTOM", 0, -40)
    
    local results_content = CreateFrame("Frame", nil, search_results_frame)
    results_content:SetSize(560, 1000)
    search_results_frame:SetScrollChild(results_content)
    search_results_frame.content = results_content
    
    -- Fondo de resultados
    local results_bg = search_results_frame:CreateTexture(nil, "BACKGROUND")
    results_bg:SetAllPoints()
    results_bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    -- Estadísticas de búsqueda
    local stats_text = search_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats_text:SetPoint("TOPLEFT", search_results_frame, "BOTTOMLEFT", 5, -5)
    stats_text:SetText("0 resultados encontrados")
    stats_text:SetTextColor(0.7, 0.7, 0.7)
    search_frame.stats_text = stats_text
    
    return search_frame
end

-- ============================================================================
-- Funciones Públicas
-- ============================================================================

local function mostrar_search()
    if search_frame then
        search_frame:Show()
    end
end

local function ocultar_search()
    if search_frame then
        search_frame:Hide()
    end
    if autocomplete_frame then
        autocomplete_frame:Hide()
    end
end

local function actualizar_search()
    -- Actualizar estadísticas
    if search_frame and search_frame.stats_text then
        local count = table.getn(search_results)
        if count == 0 then
            search_frame.stats_text:SetText("0 resultados encontrados")
        elseif count == 1 then
            search_frame.stats_text:SetText("1 resultado encontrado")
        else
            search_frame.stats_text:SetText(count .. " resultados encontrados")
        end
    end
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.search_system = {
    crear_search_ui = crear_search_ui,
    mostrar_search = mostrar_search,
    ocultar_search = ocultar_search,
    actualizar_search = actualizar_search,
    buscar_items = buscar_items,
    buscar_por_categoria = buscar_por_categoria,
    buscar_por_precio = buscar_por_precio,
    buscar_por_profit = buscar_por_profit,
    ejecutar_busqueda = ejecutar_busqueda,
    obtener_historial = obtener_historial,
    limpiar_historial = limpiar_historial
}

aux.print('[TRADING] search_system.lua cargado - VERSION 2.0 - SIN ICONOS')
