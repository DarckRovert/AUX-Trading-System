--[[
    AUX-ADDON Trading System - Log Module
    Sistema de registro de operaciones
    Inspirado en TradeSkillMaster_Auctioning Log
]]

module 'aux.tabs.trading.log'

local aux = require 'aux'

local M = getfenv()

-- ============================================
-- COLORES
-- ============================================
M.colors = {
    RED = "|cffff2211",
    ORANGE = "|cffff8811",
    GREEN = "|cff22ff22",
    CYAN = "|cff99ffff",
    YELLOW = "|cffffff00",
    WHITE = "|cffffffff",
    GRAY = "|cff999999",
    GOLD = "|cffffd700"
}

-- ============================================
-- RAZONES Y MENSAJES
-- ============================================
M.reasons = {
    -- Razones de escaneo
    scan = {
        started = {"Escaneo iniciado", M.colors.CYAN},
        completed = {"Escaneo completado", M.colors.GREEN},
        stopped = {"Escaneo detenido", M.colors.ORANGE},
        error = {"Error en escaneo", M.colors.RED},
        no_results = {"Sin resultados", M.colors.ORANGE},
        found_opportunity = {"Oportunidad encontrada!", M.colors.GREEN}
    },
    
    -- Razones de evaluacion
    evaluate = {
        no_market_data = {"Sin datos de mercado", M.colors.ORANGE},
        low_profit_margin = {"Margen de ganancia bajo", M.colors.ORANGE},
        invalid_price = {"Precio invalido", M.colors.RED},
        below_threshold = {"Bajo el umbral minimo", M.colors.ORANGE},
        good_deal = {"Buena oportunidad!", M.colors.GREEN},
        excellent_deal = {"Excelente oportunidad!", M.colors.GOLD},
        vendor_profit = {"Ganancia por vendor", M.colors.CYAN}
    },
    
    -- Razones de compra
    buy = {
        success = {"Compra exitosa", M.colors.GREEN},
        failed = {"Compra fallida", M.colors.RED},
        not_enough_gold = {"Oro insuficiente", M.colors.RED},
        auction_gone = {"Subasta ya no existe", M.colors.ORANGE},
        outbid = {"Superado por otra oferta", M.colors.ORANGE}
    },
    
    -- Razones de post
    post = {
        success = {"Posteado exitosamente", M.colors.GREEN},
        failed = {"Error al postear", M.colors.RED},
        not_enough_items = {"Items insuficientes", M.colors.ORANGE},
        below_threshold = {"Precio bajo umbral", M.colors.ORANGE},
        undercut = {"Haciendo undercut", M.colors.CYAN},
        at_market = {"A precio de mercado", M.colors.GREEN}
    },
    
    -- Razones de cancel
    cancel = {
        undercut = {"Te han hecho undercut", M.colors.RED},
        repost_higher = {"Cancelando para repostear mas alto", M.colors.CYAN},
        has_bid = {"Tiene oferta activa", M.colors.ORANGE},
        expired = {"Subasta expirada", M.colors.GRAY}
    }
}

-- ============================================
-- ALMACENAMIENTO DE LOGS
-- ============================================
local log_records = {}
local MAX_RECORDS = 500

-- ============================================
-- FUNCIONES PRINCIPALES
-- ============================================

-- Agregar registro al log
function M.add(category, reason, item_key, extra_data)
    local reason_info = M.reasons[category] and M.reasons[category][reason]
    if not reason_info then
        reason_info = {reason, M.colors.WHITE}
    end
    
    local record = {
        time = time(),
        category = category,
        reason = reason,
        message = reason_info[1],
        color = reason_info[2],
        item_key = item_key,
        data = extra_data
    }
    
    table.insert(log_records, 1, record)  -- Insertar al inicio
    
    -- Limitar cantidad de registros
    while table.getn(log_records) > MAX_RECORDS do
        table.remove(log_records)
    end
    
    return record
end

-- Agregar y mostrar en chat
function M.add_and_print(category, reason, item_key, extra_data)
    local record = M.add(category, reason, item_key, extra_data)
    
    local msg = record.color .. "[" .. string.upper(category) .. "] " .. record.message .. "|r"
    if item_key then
        msg = msg .. " - " .. tostring(item_key)
    end
    if extra_data then
        if type(extra_data) == "table" then
            if extra_data.price then
                msg = msg .. " (" .. M.format_money(extra_data.price) .. ")"
            end
            if extra_data.score then
                msg = msg .. " Score: " .. extra_data.score
            end
        else
            msg = msg .. " (" .. tostring(extra_data) .. ")"
        end
    end
    
    aux.print(msg)
    return record
end

-- Obtener todos los registros
function M.get_all()
    return log_records
end

-- Obtener registros filtrados
function M.get_filtered(category, limit)
    limit = limit or 50
    local filtered = {}
    
    for _, record in ipairs(log_records) do
        if not category or record.category == category then
            table.insert(filtered, record)
            if table.getn(filtered) >= limit then
                break
            end
        end
    end
    
    return filtered
end

-- Obtener registros de un item especifico
function M.get_for_item(item_key, limit)
    limit = limit or 20
    local filtered = {}
    
    for _, record in ipairs(log_records) do
        if record.item_key == item_key then
            table.insert(filtered, record)
            if table.getn(filtered) >= limit then
                break
            end
        end
    end
    
    return filtered
end

-- Limpiar logs
function M.clear()
    log_records = {}
    aux.print(M.colors.CYAN .. "[LOG] Registros limpiados|r")
end

-- Obtener ultimo registro
function M.get_last()
    return log_records[1]
end

-- Contar registros por categoria
function M.count_by_category()
    local counts = {}
    for _, record in ipairs(log_records) do
        counts[record.category] = (counts[record.category] or 0) + 1
    end
    return counts
end

-- ============================================
-- UTILIDADES
-- ============================================

-- Formatear dinero
function M.format_money(copper)
    if not copper or copper == 0 then
        return "0c"
    end
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

-- Formatear tiempo
function M.format_time(timestamp)
    local diff = time() - timestamp
    
    if diff < 60 then
        return "ahora"
    elseif diff < 3600 then
        return string.format("%dm", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%dh", math.floor(diff / 3600))
    else
        return string.format("%dd", math.floor(diff / 86400))
    end
end

-- Obtener color por categoria
function M.get_category_color(category)
    local category_colors = {
        scan = M.colors.CYAN,
        evaluate = M.colors.YELLOW,
        buy = M.colors.GREEN,
        post = M.colors.GOLD,
        cancel = M.colors.ORANGE
    }
    return category_colors[category] or M.colors.WHITE
end

-- Formatear registro para mostrar
function M.format_record(record)
    local time_str = M.format_time(record.time)
    local cat_color = M.get_category_color(record.category)
    
    local text = string.format("%s[%s]|r %s%s|r",
        M.colors.GRAY, time_str,
        record.color, record.message)
    
    if record.item_key then
        text = text .. " - " .. M.colors.WHITE .. tostring(record.item_key) .. "|r"
    end
    
    return text
end

-- Exportar logs a string
function M.export_to_string(limit)
    limit = limit or 100
    local lines = {}
    
    for i, record in ipairs(log_records) do
        if i > limit then break end
        
        local line = string.format("%s | %s | %s | %s",
            date("%Y-%m-%d %H:%M", record.time),
            record.category,
            record.message,
            record.item_key or "")
        table.insert(lines, line)
    end
    
    return table.concat(lines, "\n")
end

-- ============================================
-- FUNCIONES DE CONVENIENCIA
-- ============================================

-- Log de escaneo
function M.scan_started()
    return M.add("scan", "started")
end

function M.scan_completed(count)
    return M.add("scan", "completed", nil, {count = count})
end

function M.scan_error(error_msg)
    return M.add_and_print("scan", "error", nil, error_msg)
end

function M.opportunity_found(item_key, score, price)
    return M.add("scan", "found_opportunity", item_key, {score = score, price = price})
end

-- Log de evaluacion
function M.evaluate_rejected(item_key, reason)
    return M.add("evaluate", reason, item_key)
end

function M.evaluate_accepted(item_key, score)
    return M.add("evaluate", "good_deal", item_key, {score = score})
end

-- Log de compra
function M.buy_success(item_key, price, quantity)
    return M.add_and_print("buy", "success", item_key, {price = price, quantity = quantity})
end

function M.buy_failed(item_key, reason)
    return M.add_and_print("buy", reason or "failed", item_key)
end

aux.print('[TRADING] Modulo Log cargado')
