module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

--[[
    MARKET DATA SYSTEM - Inspirado en TSM
    
    Características:
    - Historial de precios de 14 días
    - Cálculo de valor de mercado con pesos por día
    - Estadísticas con desviación estándar
    - Filtrado de outliers
]]

-- Pesos por día (igual que TSM)
local PESOS_DIA = {
    [0] = 132,  -- Hoy
    [1] = 125,  -- Ayer
    [2] = 100,
    [3] = 75,
    [4] = 45,
    [5] = 34,
    [6] = 33,
    [7] = 38,
    [8] = 28,
    [9] = 21,
    [10] = 15,
    [11] = 10,
    [12] = 7,
    [13] = 5,
    [14] = 4   -- Hace 14 días
}

-- Base de datos de mercado (se guarda en SavedVariables)
-- Estructura: AuxTradingMarketData[itemKey] = {scans={[dia]=precio}, minBuyout=X, seen=X, lastScan=X}
AuxTradingMarketData = AuxTradingMarketData or {}

-- Obtener día actual (número de días desde epoch)
function M.obtener_dia(tiempo)
    tiempo = tiempo or time()
    return math.floor(tiempo / (60 * 60 * 24))
end

-- Calcular promedio de una lista
function M.calcular_promedio(datos)
    if not datos or table.getn(datos) == 0 then return 0 end
    
    local total = 0
    local num = 0
    for _, valor in ipairs(datos) do
        if valor and valor > 0 then
            total = total + valor
            num = num + 1
        end
    end
    
    if num == 0 then return 0 end
    return math.floor(total / num + 0.5)
end

-- Calcular desviación estándar
function M.calcular_desviacion(datos, media)
    if not datos or table.getn(datos) < 2 then return 0 end
    
    local suma_cuadrados = 0
    local num = 0
    
    for _, valor in ipairs(datos) do
        if valor and valor > 0 then
            suma_cuadrados = suma_cuadrados + (valor - media) * (valor - media)
            num = num + 1
        end
    end
    
    if num < 2 then return 0 end
    return math.sqrt(suma_cuadrados / num)
end

-- Calcular valor de mercado con pesos por día (como TSM)
function M.calcular_valor_mercado(item_key)
    local data = AuxTradingMarketData[item_key]
    if not data or not data.scans then return 0 end
    
    local dia_actual = M.obtener_dia()
    local total_valor = 0
    local total_peso = 0
    
    for i = 0, 14 do
        local dia = dia_actual - i
        local scan_dia = data.scans[dia]
        
        if scan_dia then
            local valor_dia
            if type(scan_dia) == "table" then
                valor_dia = M.calcular_promedio(scan_dia)
            else
                valor_dia = scan_dia
            end
            
            if valor_dia and valor_dia > 0 then
                local peso = PESOS_DIA[i] or 1
                total_valor = total_valor + (peso * valor_dia)
                total_peso = total_peso + peso
            end
        end
    end
    
    if total_peso == 0 then return data.minBuyout or 0 end
    return math.floor(total_valor / total_peso + 0.5)
end

-- Calcular precio de mercado inteligente (con estadísticas como TSM)
function M.calcular_precio_inteligente(records, cantidad_total)
    if not records or table.getn(records) == 0 then return 0 end
    
    -- Ordenar por precio (menor a mayor)
    table.sort(records, function(a, b)
        return (a.buyout or 0) < (b.buyout or 0)
    end)
    
    -- Paso 1: Tomar solo el 30-50% más bajo
    local total_num = 0
    local total_buyout = 0
    local precios_filtrados = {}
    
    for i = 1, table.getn(records) do
        local record = records[i]
        local count = record.count or 1
        
        for j = 1, count do
            local gi = total_num + 1
            -- Solo incluir si es el primero, o está en el 30% más bajo,
            -- o está en el 50% y el precio no sube más del 20%
            local incluir = (gi == 1) or 
                           (gi < cantidad_total * 0.3) or 
                           (gi < cantidad_total * 0.5 and record.buyout < 1.2 * (records[math.max(i-1, 1)].buyout or record.buyout))
            
            if not incluir then break end
            
            total_buyout = total_buyout + record.buyout
            total_num = total_num + 1
            table.insert(precios_filtrados, record.buyout)
        end
    end
    
    if total_num == 0 then return 0 end
    
    -- Paso 2: Calcular media sin corregir
    local media_sin_corregir = total_buyout / total_num
    
    -- Paso 3: Calcular desviación estándar
    local desviacion = M.calcular_desviacion(precios_filtrados, media_sin_corregir)
    
    -- Paso 4: Calcular media corregida (solo precios dentro de 1.5 * stdDev)
    local total_corregido = media_sin_corregir  -- Empezar con la media
    local num_corregido = 1
    
    for _, precio in ipairs(precios_filtrados) do
        if math.abs(media_sin_corregir - precio) < 1.5 * desviacion then
            total_corregido = total_corregido + precio
            num_corregido = num_corregido + 1
        end
    end
    
    return math.floor(total_corregido / num_corregido + 0.5)
end

-- Procesar datos de escaneo
function M.procesar_scan(scan_data)
    local dia = M.obtener_dia()
    local items_procesados = 0
    
    for item_key, data in pairs(scan_data) do
        -- Inicializar si no existe
        AuxTradingMarketData[item_key] = AuxTradingMarketData[item_key] or {scans = {}, seen = 0}
        local item_data = AuxTradingMarketData[item_key]
        
        -- Calcular valor de mercado inteligente
        local market_value = M.calcular_precio_inteligente(data.records, data.cantidad or 1)
        
        -- Guardar en historial del día
        if type(item_data.scans[dia]) == "number" then
            item_data.scans[dia] = {item_data.scans[dia]}
        end
        item_data.scans[dia] = item_data.scans[dia] or {}
        table.insert(item_data.scans[dia], market_value)
        
        -- Actualizar estadísticas
        item_data.seen = (item_data.seen or 0) + (data.cantidad or 1)
        item_data.currentQuantity = data.cantidad or 0
        item_data.lastScan = time()
        item_data.minBuyout = data.minBuyout and data.minBuyout > 0 and data.minBuyout or nil
        
        -- Limpiar scans antiguos (más de 14 días)
        for scan_dia in pairs(item_data.scans) do
            if scan_dia < dia - 14 then
                item_data.scans[scan_dia] = nil
            end
        end
        
        items_procesados = items_procesados + 1
    end
    
    return items_procesados
end

-- Obtener datos de un item
function M.obtener_datos_item(item_key)
    local data = AuxTradingMarketData[item_key]
    if not data then return nil end
    
    return {
        marketValue = M.calcular_valor_mercado(item_key),
        minBuyout = data.minBuyout or 0,
        seen = data.seen or 0,
        lastScan = data.lastScan or 0,
        currentQuantity = data.currentQuantity or 0
    }
end

-- Obtener valor de mercado de un item
function M.obtener_valor_mercado(item_key)
    if not item_key then return 0 end
    
    -- Primero intentar con nuestros datos
    local valor = M.calcular_valor_mercado(item_key)
    if valor and valor > 0 then return valor end
    
    -- Fallback a aux.history si existe
    local history = require 'aux.core.history'
    if history and history.value then
        return history.value(item_key) or 0
    end
    
    return 0
end

-- Limpiar datos antiguos
function M.limpiar_datos_antiguos()
    local dia = M.obtener_dia()
    local items_limpiados = 0
    
    for item_key, data in pairs(AuxTradingMarketData) do
        if data.scans then
            for scan_dia in pairs(data.scans) do
                if scan_dia < dia - 14 then
                    data.scans[scan_dia] = nil
                end
            end
        end
        
        -- Si no tiene scans recientes, eliminar
        local tiene_scans = false
        if data.scans then
            for _ in pairs(data.scans) do
                tiene_scans = true
                break
            end
        end
        
        if not tiene_scans then
            AuxTradingMarketData[item_key] = nil
            items_limpiados = items_limpiados + 1
        end
    end
    
    return items_limpiados
end

-- Estadísticas de la base de datos
function M.obtener_estadisticas_db()
    local total_items = 0
    local items_con_datos = 0
    
    for item_key, data in pairs(AuxTradingMarketData) do
        total_items = total_items + 1
        if data.minBuyout and data.minBuyout > 0 then
            items_con_datos = items_con_datos + 1
        end
    end
    
    return {
        total_items = total_items,
        items_con_datos = items_con_datos
    }
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.market_data = M

aux.print('|cFFFFD700[Trading]|r Sistema de datos de mercado cargado')
