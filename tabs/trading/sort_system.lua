-- ============================================================================
-- Sistema de Ordenamiento
-- ============================================================================
-- Proporciona ordenamiento de listas por múltiples criterios
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local M = getfenv()

-- Variables globales
local orden_actual = {
    campo = "profit",
    direccion = "desc" -- "asc" o "desc"
}

-- ============================================================================
-- Funciones de Ordenamiento
-- ============================================================================

local function comparar_valores(a, b, campo, direccion)
    local valor_a = a[campo]
    local valor_b = b[campo]
    
    -- Manejar valores nil
    if valor_a == nil and valor_b == nil then
        return false
    elseif valor_a == nil then
        return direccion == "desc"
    elseif valor_b == nil then
        return direccion == "asc"
    end
    
    -- Comparar según tipo
    if type(valor_a) == "string" and type(valor_b) == "string" then
        valor_a = string.lower(valor_a)
        valor_b = string.lower(valor_b)
    end
    
    if direccion == "asc" then
        return valor_a < valor_b
    else
        return valor_a > valor_b
    end
end

local function ordenar_lista(lista, campo, direccion)
    if not lista or table.getn(lista) == 0 then
        return lista
    end
    
    campo = campo or "profit"
    direccion = direccion or "desc"
    
    -- Guardar orden actual
    orden_actual.campo = campo
    orden_actual.direccion = direccion
    
    -- Crear copia de la lista
    local lista_ordenada = {}
    for i, item in ipairs(lista) do
        table.insert(lista_ordenada, item)
    end
    
    -- Ordenar
    table.sort(lista_ordenada, function(a, b)
        return comparar_valores(a, b, campo, direccion)
    end)
    
    return lista_ordenada
end

local function ordenar_por_profit(lista, direccion)
    return ordenar_lista(lista, "profit", direccion or "desc")
end

local function ordenar_por_roi(lista, direccion)
    return ordenar_lista(lista, "roi", direccion or "desc")
end

local function ordenar_por_precio(lista, direccion)
    return ordenar_lista(lista, "precio_compra", direccion or "asc")
end

local function ordenar_por_nombre(lista, direccion)
    return ordenar_lista(lista, "item_name", direccion or "asc")
end

local function ordenar_por_fecha(lista, direccion)
    return ordenar_lista(lista, "fecha", direccion or "desc")
end

local function ordenar_por_estrategia(lista, direccion)
    return ordenar_lista(lista, "estrategia", direccion or "asc")
end

local function ordenar_por_rareza(lista, direccion)
    -- Orden de rareza: Legendario > Épico > Raro > Poco común > Común
    local rareza_valores = {
        ["Legendario"] = 5,
        ["Épico"] = 4,
        ["Raro"] = 3,
        ["Poco común"] = 2,
        ["Común"] = 1
    }
    
    local lista_ordenada = {}
    for i, item in ipairs(lista) do
        local copia = {}
        for k, v in pairs(item) do
            copia[k] = v
        end
        copia.rareza_valor = rareza_valores[item.rareza] or 0
        table.insert(lista_ordenada, copia)
    end
    
    return ordenar_lista(lista_ordenada, "rareza_valor", direccion or "desc")
end

local function invertir_orden(lista)
    local lista_invertida = {}
    for i = table.getn(lista), 1, -1 do
        table.insert(lista_invertida, lista[i])
    end
    return lista_invertida
end

local function obtener_orden_actual()
    return orden_actual.campo, orden_actual.direccion
end

local function alternar_direccion()
    if orden_actual.direccion == "asc" then
        orden_actual.direccion = "desc"
    else
        orden_actual.direccion = "asc"
    end
    return orden_actual.direccion
end

-- ============================================================================
-- Ordenamiento Múltiple
-- ============================================================================

local function ordenar_multiple(lista, criterios)
    -- criterios = {{campo = "profit", direccion = "desc"}, {campo = "roi", direccion = "desc"}}
    if not lista or table.getn(lista) == 0 or not criterios or table.getn(criterios) == 0 then
        return lista
    end
    
    local lista_ordenada = {}
    for i, item in ipairs(lista) do
        table.insert(lista_ordenada, item)
    end
    
    table.sort(lista_ordenada, function(a, b)
        for _, criterio in ipairs(criterios) do
            local campo = criterio.campo
            local direccion = criterio.direccion or "desc"
            
            local valor_a = a[campo]
            local valor_b = b[campo]
            
            if valor_a ~= valor_b then
                return comparar_valores(a, b, campo, direccion)
            end
        end
        return false
    end)
    
    return lista_ordenada
end

-- ============================================================================
-- Interfaz de Usuario - Cabeceras de Columnas
-- ============================================================================

local function crear_cabecera_ordenable(parent, texto, campo, x, y, width, callback)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(width or 100, 25)
    header:SetPoint("TOPLEFT", x, y)
    
    -- Fondo
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
    
    -- Texto
    local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 5, 0)
    text:SetText(texto)
    text:SetTextColor(1, 0.82, 0)
    
    -- Indicador de orden
    local indicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    indicator:SetPoint("RIGHT", -5, 0)
    indicator:SetText("")
    indicator:SetTextColor(0.5, 1, 0.5)
    
    -- Actualizar indicador
    local function actualizar_indicador()
        if orden_actual.campo == campo then
            if orden_actual.direccion == "asc" then
                indicator:SetText("▲") -- Flecha arriba
            else
                indicator:SetText("▼") -- Flecha abajo
            end
        else
            indicator:SetText("")
        end
    end
    
    -- Click
    header:SetScript("OnClick", function(self)
        if orden_actual.campo == campo then
            alternar_direccion()
        else
            orden_actual.campo = campo
            orden_actual.direccion = "desc"
        end
        
        actualizar_indicador()
        
        if callback then
            callback(campo, orden_actual.direccion)
        end
    end)
    
    -- Hover
    header:SetScript("OnEnter", function(self)
        bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)
    end)
    
    header:SetScript("OnLeave", function(self)
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
    end)
    
    header.actualizar_indicador = actualizar_indicador
    header.bg = bg
    header.text = text
    header.indicator = indicator
    
    return header
end

local function crear_barra_cabeceras(parent, columnas, y_offset, callback)
    -- columnas = {{texto = "Item", campo = "item_name", width = 200}, ...}
    local cabeceras = {}
    local x_offset = 10
    
    for i, col in ipairs(columnas) do
        local header = crear_cabecera_ordenable(
            parent,
            col.texto,
            col.campo,
            x_offset,
            y_offset,
            col.width,
            callback
        )
        
        table.insert(cabeceras, header)
        x_offset = x_offset + col.width + 5
    end
    
    return cabeceras
end

local function actualizar_indicadores_cabeceras(cabeceras)
    if not cabeceras then
        return
    end
    
    for _, header in ipairs(cabeceras) do
        if header.actualizar_indicador then
            header.actualizar_indicador()
        end
    end
end

-- ============================================================================
-- Ordenamiento Rápido (Quick Sort)
-- ============================================================================

local function quicksort(lista, campo, direccion, inicio, fin)
    if inicio >= fin then
        return
    end
    
    local pivot = lista[fin]
    local i = inicio - 1
    
    for j = inicio, fin - 1 do
        if comparar_valores(lista[j], pivot, campo, direccion) then
            i = i + 1
            lista[i], lista[j] = lista[j], lista[i]
        end
    end
    
    lista[i + 1], lista[fin] = lista[fin], lista[i + 1]
    
    local pivot_index = i + 1
    quicksort(lista, campo, direccion, inicio, pivot_index - 1)
    quicksort(lista, campo, direccion, pivot_index + 1, fin)
end

local function ordenar_rapido(lista, campo, direccion)
    if not lista or table.getn(lista) <= 1 then
        return lista
    end
    
    -- Crear copia
    local lista_ordenada = {}
    for i, item in ipairs(lista) do
        table.insert(lista_ordenada, item)
    end
    
    quicksort(lista_ordenada, campo or "profit", direccion or "desc", 1, table.getn(lista_ordenada))
    
    return lista_ordenada
end

-- ============================================================================
-- Funciones de Búsqueda en Lista Ordenada
-- ============================================================================

local function busqueda_binaria(lista, campo, valor)
    if not lista or table.getn(lista) == 0 then
        return nil
    end
    
    local inicio = 1
    local fin = table.getn(lista)
    
    while inicio <= fin do
        local medio = math.floor((inicio + fin) / 2)
        local valor_medio = lista[medio][campo]
        
        if valor_medio == valor then
            return medio, lista[medio]
        elseif valor_medio < valor then
            inicio = medio + 1
        else
            fin = medio - 1
        end
    end
    
    return nil
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.sort_system = {
    ordenar_lista = ordenar_lista,
    ordenar_por_profit = ordenar_por_profit,
    ordenar_por_roi = ordenar_por_roi,
    ordenar_por_precio = ordenar_por_precio,
    ordenar_por_nombre = ordenar_por_nombre,
    ordenar_por_fecha = ordenar_por_fecha,
    ordenar_por_estrategia = ordenar_por_estrategia,
    ordenar_por_rareza = ordenar_por_rareza,
    invertir_orden = invertir_orden,
    obtener_orden_actual = obtener_orden_actual,
    alternar_direccion = alternar_direccion,
    ordenar_multiple = ordenar_multiple,
    ordenar_rapido = ordenar_rapido,
    crear_cabecera_ordenable = crear_cabecera_ordenable,
    crear_barra_cabeceras = crear_barra_cabeceras,
    actualizar_indicadores_cabeceras = actualizar_indicadores_cabeceras,
    busqueda_binaria = busqueda_binaria
}

aux.print('[TRADING] sort_system.lua cargado')
