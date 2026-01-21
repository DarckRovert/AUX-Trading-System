--[[
    AUX-ADDON Trading System - Accounting Module
    Sistema de contabilidad para registrar compras/ventas
    Inspirado en TradeSkillMaster_Accounting
]]

module 'aux.tabs.trading.accounting'

local aux = require 'aux'
local info = require 'aux.util.info'

local M = getfenv()

-- ============================================
-- CONSTANTES
-- ============================================
local SECONDS_PER_DAY = 24 * 60 * 60

-- ============================================
-- DATOS PERSISTENTES
-- ============================================
-- Se guardan en SavedVariables: AuxTradingAccounting
local function get_data()
    if not AuxTradingAccounting then
        AuxTradingAccounting = {
            sales = {},      -- Ventas: {itemKey = {records}}
            purchases = {},  -- Compras: {itemKey = {records}}
            lastUpdate = 0
        }
    end
    return AuxTradingAccounting
end

-- ============================================
-- FUNCIONES DE REGISTRO
-- ============================================

-- Registrar una venta
function M.record_sale(item_key, price, quantity, buyer)
    local data = get_data()
    if not data.sales[item_key] then
        data.sales[item_key] = {}
    end
    
    local record = {
        price = price,
        quantity = quantity or 1,
        buyer = buyer or "Unknown",
        time = time(),
        player = UnitName("player")
    }
    
    table.insert(data.sales[item_key], record)
    data.lastUpdate = time()
    
    aux.print(string.format("[ACCOUNTING] Venta registrada: %s x%d por %s", 
        item_key, quantity or 1, M.format_money(price)))
end

-- Registrar una compra
function M.record_purchase(item_key, price, quantity, seller)
    local data = get_data()
    if not data.purchases[item_key] then
        data.purchases[item_key] = {}
    end
    
    local record = {
        price = price,
        quantity = quantity or 1,
        seller = seller or "Unknown",
        time = time(),
        player = UnitName("player")
    }
    
    table.insert(data.purchases[item_key], record)
    data.lastUpdate = time()
    
    aux.print(string.format("[ACCOUNTING] Compra registrada: %s x%d por %s", 
        item_key, quantity or 1, M.format_money(price)))
end

-- ============================================
-- FUNCIONES DE CONSULTA
-- ============================================

-- Obtener precio promedio de venta
function M.get_average_sell_price(item_key, max_days)
    local data = get_data()
    local records = data.sales[item_key]
    if not records or table.getn(records) == 0 then
        return nil
    end
    
    max_days = max_days or 30
    local cutoff_time = time() - (max_days * SECONDS_PER_DAY)
    
    local total_price = 0
    local total_quantity = 0
    
    for _, record in ipairs(records) do
        if record.time >= cutoff_time then
            total_price = total_price + (record.price * record.quantity)
            total_quantity = total_quantity + record.quantity
        end
    end
    
    if total_quantity == 0 then
        return nil
    end
    
    return math.floor(total_price / total_quantity + 0.5)
end

-- Obtener precio promedio de compra
function M.get_average_buy_price(item_key, max_days)
    local data = get_data()
    local records = data.purchases[item_key]
    if not records or table.getn(records) == 0 then
        return nil
    end
    
    max_days = max_days or 30
    local cutoff_time = time() - (max_days * SECONDS_PER_DAY)
    
    local total_price = 0
    local total_quantity = 0
    
    for _, record in ipairs(records) do
        if record.time >= cutoff_time then
            total_price = total_price + (record.price * record.quantity)
            total_quantity = total_quantity + record.quantity
        end
    end
    
    if total_quantity == 0 then
        return nil
    end
    
    return math.floor(total_price / total_quantity + 0.5)
end

-- Obtener ganancia por reventa de un item
function M.get_resale_profit(item_key, max_days)
    local avg_sell = M.get_average_sell_price(item_key, max_days)
    local avg_buy = M.get_average_buy_price(item_key, max_days)
    
    if not avg_sell or not avg_buy then
        return nil, nil
    end
    
    local profit = avg_sell - avg_buy
    local profit_percent = 0
    if avg_buy > 0 then
        profit_percent = math.floor((profit / avg_buy) * 100 + 0.5)
    end
    
    return profit, profit_percent
end

-- ============================================
-- ESTADISTICAS GLOBALES
-- ============================================

-- Obtener resumen de oro
function M.get_gold_summary()
    local data = get_data()
    local now = time()
    
    local summary = {
        -- Ventas
        total_sales = 0,
        week_sales = 0,
        month_sales = 0,
        total_sales_count = 0,
        
        -- Compras
        total_purchases = 0,
        week_purchases = 0,
        month_purchases = 0,
        total_purchases_count = 0,
        
        -- Ganancias
        total_profit = 0,
        week_profit = 0,
        month_profit = 0,
        
        -- Top items
        top_selling_item = nil,
        top_selling_gold = 0,
        top_bought_item = nil,
        top_bought_gold = 0
    }
    
    local week_cutoff = now - (7 * SECONDS_PER_DAY)
    local month_cutoff = now - (30 * SECONDS_PER_DAY)
    
    -- Procesar ventas
    local item_sales = {}
    for item_key, records in pairs(data.sales) do
        item_sales[item_key] = 0
        for _, record in ipairs(records) do
            local amount = record.price * record.quantity
            summary.total_sales = summary.total_sales + amount
            summary.total_sales_count = summary.total_sales_count + record.quantity
            item_sales[item_key] = item_sales[item_key] + amount
            
            if record.time >= month_cutoff then
                summary.month_sales = summary.month_sales + amount
                if record.time >= week_cutoff then
                    summary.week_sales = summary.week_sales + amount
                end
            end
        end
        
        if item_sales[item_key] > summary.top_selling_gold then
            summary.top_selling_gold = item_sales[item_key]
            summary.top_selling_item = item_key
        end
    end
    
    -- Procesar compras
    local item_purchases = {}
    for item_key, records in pairs(data.purchases) do
        item_purchases[item_key] = 0
        for _, record in ipairs(records) do
            local amount = record.price * record.quantity
            summary.total_purchases = summary.total_purchases + amount
            summary.total_purchases_count = summary.total_purchases_count + record.quantity
            item_purchases[item_key] = item_purchases[item_key] + amount
            
            if record.time >= month_cutoff then
                summary.month_purchases = summary.month_purchases + amount
                if record.time >= week_cutoff then
                    summary.week_purchases = summary.week_purchases + amount
                end
            end
        end
        
        if item_purchases[item_key] > summary.top_bought_gold then
            summary.top_bought_gold = item_purchases[item_key]
            summary.top_bought_item = item_key
        end
    end
    
    -- Calcular ganancias
    summary.total_profit = summary.total_sales - summary.total_purchases
    summary.week_profit = summary.week_sales - summary.week_purchases
    summary.month_profit = summary.month_sales - summary.month_purchases
    
    return summary
end

-- Obtener items mas rentables
function M.get_most_profitable_items(limit)
    limit = limit or 10
    local data = get_data()
    local profits = {}
    
    -- Encontrar items que se han comprado Y vendido
    for item_key in pairs(data.sales) do
        if data.purchases[item_key] then
            local profit, percent = M.get_resale_profit(item_key, 30)
            if profit and profit > 0 then
                table.insert(profits, {
                    item_key = item_key,
                    profit = profit,
                    percent = percent
                })
            end
        end
    end
    
    -- Ordenar por ganancia
    table.sort(profits, function(a, b)
        return a.profit > b.profit
    end)
    
    -- Limitar resultados
    local result = {}
    for i = 1, math.min(limit, table.getn(profits)) do
        table.insert(result, profits[i])
    end
    
    return result
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
        return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

-- Formatear tiempo relativo
function M.format_time_ago(timestamp)
    local diff = time() - timestamp
    
    if diff < 60 then
        return "hace menos de 1 min"
    elseif diff < 3600 then
        return string.format("hace %d min", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("hace %d horas", math.floor(diff / 3600))
    else
        return string.format("hace %d dias", math.floor(diff / 86400))
    end
end

-- Limpiar datos antiguos
function M.cleanup_old_data(days_to_keep)
    days_to_keep = days_to_keep or 60
    local data = get_data()
    local cutoff = time() - (days_to_keep * SECONDS_PER_DAY)
    local removed_count = 0
    
    -- Limpiar ventas
    for item_key, records in pairs(data.sales) do
        local new_records = {}
        for _, record in ipairs(records) do
            if record.time >= cutoff then
                table.insert(new_records, record)
            else
                removed_count = removed_count + 1
            end
        end
        if table.getn(new_records) > 0 then
            data.sales[item_key] = new_records
        else
            data.sales[item_key] = nil
        end
    end
    
    -- Limpiar compras
    for item_key, records in pairs(data.purchases) do
        local new_records = {}
        for _, record in ipairs(records) do
            if record.time >= cutoff then
                table.insert(new_records, record)
            else
                removed_count = removed_count + 1
            end
        end
        if table.getn(new_records) > 0 then
            data.purchases[item_key] = new_records
        else
            data.purchases[item_key] = nil
        end
    end
    
    aux.print(string.format("[ACCOUNTING] Limpieza completada: %d registros eliminados", removed_count))
    return removed_count
end

-- Obtener historial de un item
function M.get_item_history(item_key)
    local data = get_data()
    local history = {
        sales = data.sales[item_key] or {},
        purchases = data.purchases[item_key] or {},
        avg_sell = M.get_average_sell_price(item_key, 30),
        avg_buy = M.get_average_buy_price(item_key, 30)
    }
    
    local profit, percent = M.get_resale_profit(item_key, 30)
    history.profit = profit
    history.profit_percent = percent
    
    return history
end

-- Contar registros totales
function M.get_record_count()
    local data = get_data()
    local sales_count = 0
    local purchases_count = 0
    
    for _, records in pairs(data.sales) do
        sales_count = sales_count + table.getn(records)
    end
    
    for _, records in pairs(data.purchases) do
        purchases_count = purchases_count + table.getn(records)
    end
    
    return sales_count, purchases_count
end

aux.print('[TRADING] Modulo Accounting cargado')
