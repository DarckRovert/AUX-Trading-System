-- ============================================================================
-- Sistema de Filtros Avanzados
-- ============================================================================
-- Proporciona filtrado avanzado de oportunidades por múltiples criterios
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local money = require('aux.util.money')
local M = getfenv()

-- Variables globales del módulo
local filter_frame = nil
local filtros_activos = {
    profit_min = 0,
    profit_max = 999999,
    roi_min = 0,
    roi_max = 1000,
    precio_min = 0,
    precio_max = 999999,
    categorias = {},
    rarezas = {},
    estrategias = {},
    solo_ml_recomendado = false,
    solo_sin_competencia = false,
    solo_tendencia_alcista = false
}

local filtros_guardados = {}
local max_filtros_guardados = 10

-- ============================================================================
-- Funciones de Filtrado
-- ============================================================================

local function aplicar_filtros(oportunidades)
    if not oportunidades then
        return {}
    end
    
    local resultados = {}
    
    for _, opp in ipairs(oportunidades) do
        local cumple = true
        
        -- Filtro de profit
        local profit = opp.profit_estimado or 0
        if profit < filtros_activos.profit_min or profit > filtros_activos.profit_max then
            cumple = false
        end
        
        -- Filtro de ROI
        local roi = opp.roi or 0
        if roi < filtros_activos.roi_min or roi > filtros_activos.roi_max then
            cumple = false
        end
        
        -- Filtro de precio
        local precio = opp.precio_compra or 0
        if precio < filtros_activos.precio_min or precio > filtros_activos.precio_max then
            cumple = false
        end
        
        -- Filtro de categorías
        if next(filtros_activos.categorias) then
            local categoria = opp.categoria or "Otro"
            if not filtros_activos.categorias[categoria] then
                cumple = false
            end
        end
        
        -- Filtro de rarezas
        if next(filtros_activos.rarezas) then
            local rareza = opp.rareza or "Común"
            if not filtros_activos.rarezas[rareza] then
                cumple = false
            end
        end
        
        -- Filtro de estrategias
        if next(filtros_activos.estrategias) then
            local tiene_estrategia = false
            if opp.estrategias then
                for _, estrategia in ipairs(opp.estrategias) do
                    if filtros_activos.estrategias[estrategia] then
                        tiene_estrategia = true
                        break
                    end
                end
            end
            if not tiene_estrategia then
                cumple = false
            end
        end
        
        -- Filtro ML recomendado
        if filtros_activos.solo_ml_recomendado then
            if not opp.ml_recomendado or opp.ml_score < 0.7 then
                cumple = false
            end
        end
        
        -- Filtro sin competencia
        if filtros_activos.solo_sin_competencia then
            if opp.competidores and opp.competidores > 2 then
                cumple = false
            end
        end
        
        -- Filtro tendencia alcista
        if filtros_activos.solo_tendencia_alcista then
            if opp.tendencia ~= "subiendo" then
                cumple = false
            end
        end
        
        if cumple then
            table.insert(resultados, opp)
        end
    end
    
    return resultados
end

local function resetear_filtros()
    filtros_activos = {
        profit_min = 0,
        profit_max = 999999,
        roi_min = 0,
        roi_max = 1000,
        precio_min = 0,
        precio_max = 999999,
        categorias = {},
        rarezas = {},
        estrategias = {},
        solo_ml_recomendado = false,
        solo_sin_competencia = false,
        solo_tendencia_alcista = false
    }
end

local function obtener_filtros_activos()
    return filtros_activos
end

local function establecer_filtro(nombre, valor)
    if filtros_activos[nombre] ~= nil then
        filtros_activos[nombre] = valor
        return true
    end
    return false
end

-- ============================================================================
-- Filtros Guardados
-- ============================================================================

local function guardar_filtro_actual(nombre)
    if not nombre or nombre == "" then
        return false
    end
    
    -- Copiar filtros actuales
    local filtro_copia = {
        nombre = nombre,
        profit_min = filtros_activos.profit_min,
        profit_max = filtros_activos.profit_max,
        roi_min = filtros_activos.roi_min,
        roi_max = filtros_activos.roi_max,
        precio_min = filtros_activos.precio_min,
        precio_max = filtros_activos.precio_max,
        categorias = {},
        rarezas = {},
        estrategias = {},
        solo_ml_recomendado = filtros_activos.solo_ml_recomendado,
        solo_sin_competencia = filtros_activos.solo_sin_competencia,
        solo_tendencia_alcista = filtros_activos.solo_tendencia_alcista
    }
    
    -- Copiar tablas
    for k, v in pairs(filtros_activos.categorias) do
        filtro_copia.categorias[k] = v
    end
    for k, v in pairs(filtros_activos.rarezas) do
        filtro_copia.rarezas[k] = v
    end
    for k, v in pairs(filtros_activos.estrategias) do
        filtro_copia.estrategias[k] = v
    end
    
    -- Guardar
    filtros_guardados[nombre] = filtro_copia
    
    -- Limitar cantidad
    local count = 0
    for _ in pairs(filtros_guardados) do
        count = count + 1
    end
    
    if count > max_filtros_guardados then
        -- Eliminar el más antiguo (simplificado)
        local primera_key = next(filtros_guardados)
        filtros_guardados[primera_key] = nil
    end
    
    return true
end

local function cargar_filtro_guardado(nombre)
    local filtro = filtros_guardados[nombre]
    if not filtro then
        return false
    end
    
    -- Cargar filtros
    filtros_activos.profit_min = filtro.profit_min
    filtros_activos.profit_max = filtro.profit_max
    filtros_activos.roi_min = filtro.roi_min
    filtros_activos.roi_max = filtro.roi_max
    filtros_activos.precio_min = filtro.precio_min
    filtros_activos.precio_max = filtro.precio_max
    filtros_activos.solo_ml_recomendado = filtro.solo_ml_recomendado
    filtros_activos.solo_sin_competencia = filtro.solo_sin_competencia
    filtros_activos.solo_tendencia_alcista = filtro.solo_tendencia_alcista
    
    -- Limpiar y copiar tablas
    filtros_activos.categorias = {}
    filtros_activos.rarezas = {}
    filtros_activos.estrategias = {}
    
    for k, v in pairs(filtro.categorias) do
        filtros_activos.categorias[k] = v
    end
    for k, v in pairs(filtro.rarezas) do
        filtros_activos.rarezas[k] = v
    end
    for k, v in pairs(filtro.estrategias) do
        filtros_activos.estrategias[k] = v
    end
    
    return true
end

local function eliminar_filtro_guardado(nombre)
    if filtros_guardados[nombre] then
        filtros_guardados[nombre] = nil
        return true
    end
    return false
end

local function obtener_filtros_guardados()
    local lista = {}
    for nombre, _ in pairs(filtros_guardados) do
        table.insert(lista, nombre)
    end
    return lista
end

-- ============================================================================
-- Filtros Predefinidos
-- ============================================================================

local function aplicar_filtro_predefinido(tipo)
    resetear_filtros()
    
    if tipo == "alto_profit" then
        filtros_activos.profit_min = 50000 -- 5g
        filtros_activos.roi_min = 30
        
    elseif tipo == "bajo_riesgo" then
        filtros_activos.roi_min = 20
        filtros_activos.precio_max = 100000 -- 10g
        filtros_activos.solo_sin_competencia = true
        
    elseif tipo == "flipping_rapido" then
        filtros_activos.roi_min = 15
        filtros_activos.estrategias["Flipping"] = true
        filtros_activos.solo_tendencia_alcista = true
        
    elseif tipo == "sniping" then
        filtros_activos.roi_min = 50
        filtros_activos.estrategias["Sniping"] = true
        
    elseif tipo == "ml_recomendado" then
        filtros_activos.solo_ml_recomendado = true
        filtros_activos.roi_min = 25
        
    elseif tipo == "items_raros" then
        filtros_activos.rarezas["Raro"] = true
        filtros_activos.rarezas["Épico"] = true
        filtros_activos.rarezas["Legendario"] = true
        
    elseif tipo == "inversion_grande" then
        filtros_activos.precio_min = 100000 -- 10g
        filtros_activos.profit_min = 100000 -- 10g
        filtros_activos.roi_min = 20
    end
end

-- ============================================================================
-- Interfaz de Usuario
-- ============================================================================

local function crear_slider(parent, label, min, max, step, x, y, callback)
    local slider_frame = CreateFrame("Frame", nil, parent)
    slider_frame:SetSize(250, 50)
    slider_frame:SetPoint("TOPLEFT", x, y)
    
    -- Label
    local label_text = slider_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label_text:SetPoint("TOPLEFT", 0, 0)
    label_text:SetText(label)
    
    -- Slider
    local slider = CreateFrame("Slider", nil, slider_frame, "OptionsSliderTemplate")
    slider:SetSize(200, 15)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetValue(min)
    slider:SetObeyStepOnDrag(true)
    
    -- Value text
    local value_text = slider_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value_text:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    value_text:SetText(tostring(min))
    
    slider:SetScript("OnValueChanged", function(self, value)
        value_text:SetText(tostring(math.floor(value)))
        if callback then
            callback(value)
        end
    end)
    
    slider_frame.slider = slider
    slider_frame.value_text = value_text
    
    return slider_frame
end

local function crear_checkbox(parent, label, x, y, callback)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", x, y)
    
    local text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    text:SetText(label)
    
    checkbox:SetScript("OnClick", function(self)
        if callback then
            callback(self:GetChecked())
        end
    end)
    
    checkbox.text = text
    return checkbox
end

local function crear_filter_ui(parent)
    -- Frame principal
    filter_frame = CreateFrame("Frame", nil, parent)
    filter_frame:SetAllPoints()
    filter_frame:Hide()
    
    -- Scroll frame
    local scroll_frame = CreateFrame("ScrollFrame", nil, filter_frame, "UIPanelScrollFrameTemplate")
    scroll_frame:SetSize(580, 420)
    scroll_frame:SetPoint("TOP", 0, -40)
    
    local content = CreateFrame("Frame", nil, scroll_frame)
    content:SetSize(560, 1200)
    scroll_frame:SetScrollChild(content)
    
    -- Fondo
    local bg = scroll_frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    -- Título
    local title = filter_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Filtros Avanzados")
    title:SetTextColor(1, 0.82, 0)
    
    local y_offset = -10
    
    -- ========================================================================
    -- Sección: Filtros Predefinidos
    -- ========================================================================
    
    local predefined_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    predefined_title:SetPoint("TOPLEFT", 10, y_offset)
    predefined_title:SetText("Filtros Predefinidos:")
    predefined_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 25
    
    local predefinidos = {
        {id = "alto_profit", label = "Alto Profit (>5g, ROI>30%)"},
        {id = "bajo_riesgo", label = "Bajo Riesgo (<10g, sin competencia)"},
        {id = "flipping_rapido", label = "Flipping Rápido (tendencia alcista)"},
        {id = "sniping", label = "Sniping (ROI>50%)"},
        {id = "ml_recomendado", label = "ML Recomendado (score>0.7)"},
        {id = "items_raros", label = "Items Raros/Épicos"},
        {id = "inversion_grande", label = "Inversión Grande (>10g)"}
    }
    
    for i, pred in ipairs(predefinidos) do
        local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btn:SetSize(260, 25)
        if math.mod(i, 2) == 1 then
            btn:SetPoint("TOPLEFT", 10, y_offset)
        else
            btn:SetPoint("TOPLEFT", 280, y_offset + 27)
        end
        btn:SetText(pred.label)
        btn:SetScript("OnClick", function()
            aplicar_filtro_predefinido(pred.id)
            actualizar_filter_ui()
        end)
        
        if math.mod(i, 2) == 0 then
            y_offset = y_offset - 30
        end
    end
    
    if math.mod(table.getn(predefinidos), 2) == 1 then
        y_offset = y_offset - 30
    end
    
    y_offset = y_offset - 20
    
    -- ========================================================================
    -- Sección: Rangos Numéricos
    -- ========================================================================
    
    local ranges_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ranges_title:SetPoint("TOPLEFT", 10, y_offset)
    ranges_title:SetText("Rangos de Valores:")
    ranges_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    -- Profit mínimo
    local profit_min_slider = crear_slider(content, "Profit Mínimo (copper):", 0, 1000000, 10000, 10, y_offset, function(value)
        filtros_activos.profit_min = value
    end)
    y_offset = y_offset - 60
    
    -- Profit máximo
    local profit_max_slider = crear_slider(content, "Profit Máximo (copper):", 0, 10000000, 100000, 10, y_offset, function(value)
        filtros_activos.profit_max = value
    end)
    profit_max_slider.slider:SetValue(999999)
    y_offset = y_offset - 60
    
    -- ROI mínimo
    local roi_min_slider = crear_slider(content, "ROI Mínimo (%):", 0, 500, 5, 10, y_offset, function(value)
        filtros_activos.roi_min = value
    end)
    y_offset = y_offset - 60
    
    -- ROI máximo
    local roi_max_slider = crear_slider(content, "ROI Máximo (%):", 0, 1000, 10, 10, y_offset, function(value)
        filtros_activos.roi_max = value
    end)
    roi_max_slider.slider:SetValue(1000)
    y_offset = y_offset - 60
    
    -- Precio mínimo
    local precio_min_slider = crear_slider(content, "Precio Mínimo (copper):", 0, 1000000, 10000, 10, y_offset, function(value)
        filtros_activos.precio_min = value
    end)
    y_offset = y_offset - 60
    
    -- Precio máximo
    local precio_max_slider = crear_slider(content, "Precio Máximo (copper):", 0, 10000000, 100000, 10, y_offset, function(value)
        filtros_activos.precio_max = value
    end)
    precio_max_slider.slider:SetValue(999999)
    y_offset = y_offset - 80
    
    -- ========================================================================
    -- Sección: Categorías
    -- ========================================================================
    
    local cat_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cat_title:SetPoint("TOPLEFT", 10, y_offset)
    cat_title:SetText("Categorías:")
    cat_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 25
    
    local categorias = {"Armas", "Armadura", "Consumibles", "Materiales", "Recetas", "Otro"}
    for i, cat in ipairs(categorias) do
        local cb = crear_checkbox(content, cat, 10 + math.mod(i-1, 3) * 180, y_offset - math.floor((i-1) / 3) * 30, function(checked)
            filtros_activos.categorias[cat] = checked or nil
        end)
    end
    y_offset = y_offset - 80
    
    -- ========================================================================
    -- Sección: Rarezas
    -- ========================================================================
    
    local rarity_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rarity_title:SetPoint("TOPLEFT", 10, y_offset)
    rarity_title:SetText("Rarezas:")
    rarity_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 25
    
    local rarezas = {"Común", "Poco común", "Raro", "Épico", "Legendario"}
    for i, rar in ipairs(rarezas) do
        local cb = crear_checkbox(content, rar, 10 + math.mod(i-1, 3) * 180, y_offset - math.floor((i-1) / 3) * 30, function(checked)
            filtros_activos.rarezas[rar] = checked or nil
        end)
    end
    y_offset = y_offset - 80
    
    -- ========================================================================
    -- Sección: Estrategias
    -- ========================================================================
    
    local strat_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    strat_title:SetPoint("TOPLEFT", 10, y_offset)
    strat_title:SetText("Estrategias:")
    strat_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 25
    
    local estrategias = {"Flipping", "Sniping", "Market Reset", "Arbitraje"}
    for i, est in ipairs(estrategias) do
        local cb = crear_checkbox(content, est, 10 + math.mod(i-1, 2) * 270, y_offset - math.floor((i-1) / 2) * 30, function(checked)
            filtros_activos.estrategias[est] = checked or nil
        end)
    end
    y_offset = y_offset - 80
    
    -- ========================================================================
    -- Sección: Opciones Especiales
    -- ========================================================================
    
    local special_title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    special_title:SetPoint("TOPLEFT", 10, y_offset)
    special_title:SetText("Opciones Especiales:")
    special_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 25
    
    local ml_cb = crear_checkbox(content, "Solo ML Recomendado (score > 0.7)", 10, y_offset, function(checked)
        filtros_activos.solo_ml_recomendado = checked
    end)
    y_offset = y_offset - 30
    
    local comp_cb = crear_checkbox(content, "Solo Sin Competencia (< 3 competidores)", 10, y_offset, function(checked)
        filtros_activos.solo_sin_competencia = checked
    end)
    y_offset = y_offset - 30
    
    local trend_cb = crear_checkbox(content, "Solo Tendencia Alcista", 10, y_offset, function(checked)
        filtros_activos.solo_tendencia_alcista = checked
    end)
    y_offset = y_offset - 50
    
    -- ========================================================================
    -- Botones de Acción
    -- ========================================================================
    
    local apply_btn = CreateFrame("Button", nil, filter_frame, "UIPanelButtonTemplate")
    apply_btn:SetSize(120, 30)
    apply_btn:SetPoint("BOTTOMLEFT", 20, 10)
    apply_btn:SetText("Aplicar Filtros")
    apply_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.oportunidades then
            local filtradas = aplicar_filtros(aux.trading.oportunidades)
            print(string.format("Filtros aplicados: %d oportunidades encontradas", table.getn(filtradas)))
            -- Actualizar lista de oportunidades
            if aux.trading.actualizar_lista_oportunidades then
                aux.trading.actualizar_lista_oportunidades(filtradas)
            end
        end
    end)
    
    local reset_btn = CreateFrame("Button", nil, filter_frame, "UIPanelButtonTemplate")
    reset_btn:SetSize(120, 30)
    reset_btn:SetPoint("LEFT", apply_btn, "RIGHT", 10, 0)
    reset_btn:SetText("Resetear")
    reset_btn:SetScript("OnClick", function()
        resetear_filtros()
        actualizar_filter_ui()
        print("Filtros reseteados")
    end)
    
    local save_btn = CreateFrame("Button", nil, filter_frame, "UIPanelButtonTemplate")
    save_btn:SetSize(120, 30)
    save_btn:SetPoint("LEFT", reset_btn, "RIGHT", 10, 0)
    save_btn:SetText("Guardar Filtro")
    save_btn:SetScript("OnClick", function()
        StaticPopup_Show("SAVE_FILTER_POPUP")
    end)
    
    local load_btn = CreateFrame("Button", nil, filter_frame, "UIPanelButtonTemplate")
    load_btn:SetSize(120, 30)
    load_btn:SetPoint("LEFT", save_btn, "RIGHT", 10, 0)
    load_btn:SetText("Cargar Filtro")
    load_btn:SetScript("OnClick", function()
        -- Mostrar lista de filtros guardados
        local filtros = obtener_filtros_guardados()
        if table.getn(filtros) == 0 then
            print("No hay filtros guardados")
        else
            print("Filtros guardados:")
            for i, nombre in ipairs(filtros) do
                print(string.format("%d. %s", i, nombre))
            end
        end
    end)
    
    -- Guardar referencias
    filter_frame.sliders = {
        profit_min = profit_min_slider,
        profit_max = profit_max_slider,
        roi_min = roi_min_slider,
        roi_max = roi_max_slider,
        precio_min = precio_min_slider,
        precio_max = precio_max_slider
    }
    
    return filter_frame
end

-- Popup para guardar filtro
StaticPopupDialogs["SAVE_FILTER_POPUP"] = {
    text = "Nombre del filtro:",
    button1 = "Guardar",
    button2 = "Cancelar",
    hasEditBox = true,
    OnAccept = function(self)
        local nombre = self.editBox:GetText()
        if guardar_filtro_actual(nombre) then
            print("Filtro guardado: " .. nombre)
        else
            print("Error al guardar filtro")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- ============================================================================
-- Funciones Públicas
-- ============================================================================

function actualizar_filter_ui()
    if not filter_frame or not filter_frame.sliders then
        return
    end
    
    -- Actualizar sliders
    filter_frame.sliders.profit_min.slider:SetValue(filtros_activos.profit_min)
    filter_frame.sliders.profit_max.slider:SetValue(filtros_activos.profit_max)
    filter_frame.sliders.roi_min.slider:SetValue(filtros_activos.roi_min)
    filter_frame.sliders.roi_max.slider:SetValue(filtros_activos.roi_max)
    filter_frame.sliders.precio_min.slider:SetValue(filtros_activos.precio_min)
    filter_frame.sliders.precio_max.slider:SetValue(filtros_activos.precio_max)
end

local function mostrar_filter()
    if filter_frame then
        filter_frame:Show()
    end
end

local function ocultar_filter()
    if filter_frame then
        filter_frame:Hide()
    end
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.filter_system = {
    crear_filter_ui = crear_filter_ui,
    mostrar_filter = mostrar_filter,
    ocultar_filter = ocultar_filter,
    actualizar_filter_ui = actualizar_filter_ui,
    aplicar_filtros = aplicar_filtros,
    resetear_filtros = resetear_filtros,
    obtener_filtros_activos = obtener_filtros_activos,
    establecer_filtro = establecer_filtro,
    guardar_filtro_actual = guardar_filtro_actual,
    cargar_filtro_guardado = cargar_filtro_guardado,
    eliminar_filtro_guardado = eliminar_filtro_guardado,
    obtener_filtros_guardados = obtener_filtros_guardados,
    aplicar_filtro_predefinido = aplicar_filtro_predefinido
}

aux.print('[TRADING] filter_system.lua cargado')
