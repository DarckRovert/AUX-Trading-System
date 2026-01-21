module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- Professional Dashboard - Dashboard Profesional con Analytics
-- ============================================================================

aux.print('[DASHBOARD] Módulo de dashboard cargado')

-- ============================================================================
-- Statistics Tracking
-- ============================================================================

local stats = {
    daily = {},
    weekly = {},
    monthly = {},
    all_time = {
        total_profit = 0,
        total_loss = 0,
        total_trades = 0,
        successful_trades = 0,
        failed_trades = 0,
        total_invested = 0,
        total_revenue = 0,
        best_trade = nil,
        worst_trade = nil,
    },
}

function init_stats()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.stats then
        aux.faction_data.trading.stats = stats
    else
        stats = aux.faction_data.trading.stats
    end
end

-- ============================================================================
-- Legacy Data Integration (AuxTradingAccounting)
-- ============================================================================

-- Function to migrate or read from AuxTradingAccounting if needed
local function get_legacy_data()
    if not AuxTradingAccounting then return nil end
    
    local legacy_stats = {
        profit = 0,
        revenue = 0,
        expenses = 0,
        count = 0
    }
    
    -- Process sales
    if AuxTradingAccounting.sales then
        for item_key, records in pairs(AuxTradingAccounting.sales) do
            for _, record in ipairs(records) do
                local amount = (record.price or 0) * (record.quantity or 1)
                legacy_stats.revenue = legacy_stats.revenue + amount
                legacy_stats.profit = legacy_stats.profit + amount
                legacy_stats.count = legacy_stats.count + 1
            end
        end
    end
    
    -- Process purchases
    if AuxTradingAccounting.purchases then
        for item_key, records in pairs(AuxTradingAccounting.purchases) do
            for _, record in ipairs(records) do
                local amount = (record.price or 0) * (record.quantity or 1)
                legacy_stats.expenses = legacy_stats.expenses + amount
                legacy_stats.profit = legacy_stats.profit - amount
                legacy_stats.count = legacy_stats.count + 1
            end
        end
    end
    
    return legacy_stats
end

-- ============================================================================
-- Estructuras de Datos
-- ============================================================================

-- Asegurar que M.modules existe
if not M.modules then M.modules = {} end

-- ============================================================================
-- Actualización de Estadísticas
-- ============================================================================

-- Actualizar estadísticas cuando se completa un trade
function update_stats_on_trade(trade)
    if not trade or trade.status ~= 'sold' then
        return
    end
    
    local profit = trade.profit or 0
    local timestamp = trade.sold_at or time()
    
    -- Actualizar all-time stats
    stats.all_time.total_trades = stats.all_time.total_trades + 1
    
    if profit > 0 then
        stats.all_time.successful_trades = stats.all_time.successful_trades + 1
        stats.all_time.total_profit = stats.all_time.total_profit + profit
    else
        stats.all_time.failed_trades = stats.all_time.failed_trades + 1
        stats.all_time.total_loss = stats.all_time.total_loss + math.abs(profit)
    end
    
    stats.all_time.total_invested = stats.all_time.total_invested + (trade.buy_price or 0)
    stats.all_time.total_revenue = stats.all_time.total_revenue + (trade.sell_price or 0)
    
    -- Mejor y peor trade
    if not stats.all_time.best_trade or profit > stats.all_time.best_trade.profit then
        stats.all_time.best_trade = {
            item_name = trade.item_name,
            profit = profit,
            timestamp = timestamp,
        }
    end
    
    if not stats.all_time.worst_trade or profit < stats.all_time.worst_trade.profit then
        stats.all_time.worst_trade = {
            item_name = trade.item_name,
            profit = profit,
            timestamp = timestamp,
        }
    end
    
    -- Actualizar stats diarias
    local day_key = get_day_key(timestamp)
    update_period_stats(stats.daily, day_key, trade, profit)
    
    -- Actualizar stats semanales
    local week_key = get_week_key(timestamp)
    update_period_stats(stats.weekly, week_key, trade, profit)
    
    -- Actualizar stats mensuales
    local month_key = get_month_key(timestamp)
    update_period_stats(stats.monthly, month_key, trade, profit)
end

function update_period_stats(period_table, key, trade, profit)
    if not period_table[key] then
        period_table[key] = {
            total_profit = 0,
            total_loss = 0,
            total_trades = 0,
            successful_trades = 0,
            failed_trades = 0,
            total_invested = 0,
            total_revenue = 0,
        }
    end
    
    local period = period_table[key]
    period.total_trades = period.total_trades + 1
    
    if profit > 0 then
        period.successful_trades = period.successful_trades + 1
        period.total_profit = period.total_profit + profit
    else
        period.failed_trades = period.failed_trades + 1
        period.total_loss = period.total_loss + math.abs(profit)
    end
    
    period.total_invested = period.total_invested + (trade.buy_price or 0)
    period.total_revenue = period.total_revenue + (trade.sell_price or 0)
end

-- ============================================================================
-- Time Period Helpers
-- ============================================================================

function get_day_key(timestamp)
    local date_table = date('*t', timestamp)
    return string.format('%04d-%02d-%02d', date_table.year, date_table.month, date_table.day)
end

function get_week_key(timestamp)
    local date_table = date('*t', timestamp)
    local week = math.floor(date_table.yday / 7)
    return string.format('%04d-W%02d', date_table.year, week)
end

function get_month_key(timestamp)
    local date_table = date('*t', timestamp)
    return string.format('%04d-%02d', date_table.year, date_table.month)
end

-- ============================================================================
-- Dashboard Data Generation
-- ============================================================================

function get_dashboard_data()
    local current_time = time()
    
    -- Intentar usar datos legacy si stats está vacío
    if stats.all_time.total_trades == 0 and AuxTradingAccounting then
        local legacy = get_legacy_data()
        if legacy and legacy.count > 0 then
            stats.all_time.net_profit = legacy.profit -- Esto es net directamente
            stats.all_time.total_profit = legacy.revenue -- Aproximación
            stats.all_time.total_loss = legacy.expenses -- Aproximación
            stats.all_time.total_trades = legacy.count
            
            -- Para gráficos, necesitamos procesar el historial real (TODO)
        end
    end
    
    -- Stats de hoy
    local today_key = get_day_key(current_time)
    local today_stats = stats.daily[today_key] or {
        total_profit = 0,
        total_loss = 0,
        total_trades = 0,
        successful_trades = 0,
    }
    
    -- Stats de esta semana
    local week_key = get_week_key(current_time)
    local week_stats = stats.weekly[week_key] or {
        total_profit = 0,
        total_loss = 0,
        total_trades = 0,
        successful_trades = 0,
    }
    
    -- Stats de este mes
    local month_key = get_month_key(current_time)
    local month_stats = stats.monthly[month_key] or {
        total_profit = 0,
        total_loss = 0,
        total_trades = 0,
        successful_trades = 0,
    }
    
    -- Calcular ROI
    local all_time_roi = 0
    if stats.all_time.total_invested > 0 then
        all_time_roi = ((stats.all_time.total_revenue - stats.all_time.total_invested) / stats.all_time.total_invested) * 100
    end
    
    -- Calcular tasa de éxito
    local success_rate = 0
    if stats.all_time.total_trades > 0 then
        success_rate = (stats.all_time.successful_trades / stats.all_time.total_trades) * 100
    end
    
    -- Net profit
    local net_profit = stats.all_time.total_profit - stats.all_time.total_loss
    -- Override si usamos legacy
    if stats.all_time.total_trades > 0 and stats.all_time.net_profit then
         net_profit = stats.all_time.net_profit
    end
    
    return {
        today = today_stats,
        week = week_stats,
        month = month_stats,
        all_time = {
            net_profit = net_profit,
            total_profit = stats.all_time.total_profit,
            total_loss = stats.all_time.total_loss,
            total_trades = stats.all_time.total_trades,
            successful_trades = stats.all_time.successful_trades,
            failed_trades = stats.all_time.failed_trades,
            success_rate = success_rate,
            roi = all_time_roi,
            avg_profit_per_trade = stats.all_time.total_trades > 0 and (net_profit / stats.all_time.total_trades) or 0,
            best_trade = stats.all_time.best_trade,
            worst_trade = stats.all_time.worst_trade,
        },
    }
end

-- ============================================================================
-- Profit/Loss Chart Data
-- ============================================================================

function get_profit_chart_data(days)
    days = days or 30
    
    local chart_data = {}
    local current_time = time()
    
    for i = days - 1, 0, -1 do
        local day_timestamp = current_time - (i * 86400)
        local day_key = get_day_key(day_timestamp)
        
        local day_stats = stats.daily[day_key]
        
        if day_stats then
            local net_profit = day_stats.total_profit - day_stats.total_loss
            
            tinsert(chart_data, {
                date = day_key,
                timestamp = day_timestamp,
                profit = day_stats.total_profit,
                loss = day_stats.total_loss,
                net = net_profit,
                trades = day_stats.total_trades,
            })
        else
            tinsert(chart_data, {
                date = day_key,
                timestamp = day_timestamp,
                profit = 0,
                loss = 0,
                net = 0,
                trades = 0,
            })
        end
    end
    
    return chart_data
end

-- ============================================================================
-- Top Items Analysis
-- ============================================================================

function get_top_items_by_profit(limit)
    limit = limit or 10
    
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return {}
    end
    
    -- Agrupar trades por item
    local item_stats = {}
    
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        if trade.status == 'sold' then
            local item_key = trade.item_key
            
            if not item_stats[item_key] then
                item_stats[item_key] = {
                    item_key = item_key,
                    item_name = trade.item_name,
                    total_profit = 0,
                    total_trades = 0,
                    successful_trades = 0,
                    avg_profit = 0,
                }
            end
            
            local stats_entry = item_stats[item_key]
            stats_entry.total_trades = stats_entry.total_trades + 1
            
            if trade.profit and trade.profit > 0 then
                stats_entry.total_profit = stats_entry.total_profit + trade.profit
                stats_entry.successful_trades = stats_entry.successful_trades + 1
            end
        end
    end
    
    -- Calcular promedio y convertir a array
    local items_array = {}
    for item_key, stats_entry in pairs(item_stats) do
        if stats_entry.total_trades > 0 then
            stats_entry.avg_profit = stats_entry.total_profit / stats_entry.total_trades
        end
        tinsert(items_array, stats_entry)
    end
    
    -- Ordenar por profit total
    table.sort(items_array, function(a, b)
        return a.total_profit > b.total_profit
    end)
    
    -- Retornar top N
    local result = {}
    for i = 1, math.min(limit, table.getn(items_array)) do
        tinsert(result, items_array[i])
    end
    
    return result
end

function get_top_items_by_volume(limit)
    limit = limit or 10
    
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return {}
    end
    
    -- Agrupar trades por item
    local item_stats = {}
    
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        if trade.status == 'sold' then
            local item_key = trade.item_key
            
            if not item_stats[item_key] then
                item_stats[item_key] = {
                    item_key = item_key,
                    item_name = trade.item_name,
                    total_trades = 0,
                    total_quantity = 0,
                }
            end
            
            local stats_entry = item_stats[item_key]
            stats_entry.total_trades = stats_entry.total_trades + 1
            stats_entry.total_quantity = stats_entry.total_quantity + (trade.count or 1)
        end
    end
    
    -- Convertir a array
    local items_array = {}
    for item_key, stats_entry in pairs(item_stats) do
        tinsert(items_array, stats_entry)
    end
    
    -- Ordenar por cantidad de trades
    table.sort(items_array, function(a, b)
        return a.total_trades > b.total_trades
    end)
    
    -- Retornar top N
    local result = {}
    for i = 1, math.min(limit, table.getn(items_array)) do
        tinsert(result, items_array[i])
    end
    
    return result
end

-- ============================================================================
-- Trade History with Filters
-- ============================================================================

function get_trade_history(filters)
    filters = filters or {}
    
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return {}
    end
    
    local history = {}
    
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        local include = true
        
        -- Filtro por status
        if filters.status and trade.status ~= filters.status then
            include = false
        end
        
        -- Filtro por item
        if filters.item_key and trade.item_key ~= filters.item_key then
            include = false
        end
        
        -- Filtro por fecha
        if filters.start_date and trade.bought_at < filters.start_date then
            include = false
        end
        
        if filters.end_date and trade.bought_at > filters.end_date then
            include = false
        end
        
        -- Filtro por profit mínimo
        if filters.min_profit and (not trade.profit or trade.profit < filters.min_profit) then
            include = false
        end
        
        if include then
            tinsert(history, trade)
        end
    end
    
    -- Ordenar por fecha (más reciente primero)
    table.sort(history, function(a, b)
        return (a.sold_at or a.bought_at or 0) > (b.sold_at or b.bought_at or 0)
    end)
    
    return history
end

-- ============================================================================
-- Performance Metrics
-- ============================================================================

function calculate_performance_metrics()
    local dashboard_data = get_dashboard_data()
    local all_time = dashboard_data.all_time
    
    -- Calcular métricas avanzadas
    local metrics = {
        -- Rentabilidad
        roi = all_time.roi,
        profit_factor = 0,
        
        -- Eficiencia
        success_rate = all_time.success_rate,
        avg_profit_per_trade = all_time.avg_profit_per_trade,
        
        -- Riesgo
        max_drawdown = calculate_max_drawdown(),
        volatility = calculate_profit_volatility(),
        
        -- Actividad
        total_trades = all_time.total_trades,
        trades_per_day = calculate_trades_per_day(),
        
        -- Comparación temporal
        week_vs_month = compare_periods('week', 'month'),
        month_vs_all_time = compare_periods('month', 'all_time'),
    }
    
    -- Profit factor (total profit / total loss)
    if all_time.total_loss > 0 then
        metrics.profit_factor = all_time.total_profit / all_time.total_loss
    else
        metrics.profit_factor = all_time.total_profit > 0 and 999 or 0
    end
    
    return metrics
end

function calculate_max_drawdown()
    local chart_data = get_profit_chart_data(90)  -- Últimos 90 días
    
    if table.getn(chart_data) == 0 then
        return 0
    end
    
    local peak = 0
    local max_drawdown = 0
    local cumulative = 0
    
    for i = 1, table.getn(chart_data) do
        cumulative = cumulative + chart_data[i].net
        
        if cumulative > peak then
            peak = cumulative
        end
        
        local drawdown = peak - cumulative
        if drawdown > max_drawdown then
            max_drawdown = drawdown
        end
    end
    
    return max_drawdown
end

function calculate_profit_volatility()
    local chart_data = get_profit_chart_data(30)  -- Últimos 30 días
    
    if table.getn(chart_data) < 2 then
        return 0
    end
    
    -- Calcular promedio
    local sum = 0
    for i = 1, table.getn(chart_data) do
        sum = sum + chart_data[i].net
    end
    local avg = sum / table.getn(chart_data)
    
    -- Calcular desviación estándar
    local variance_sum = 0
    for i = 1, table.getn(chart_data) do
        local diff = chart_data[i].net - avg
        variance_sum = variance_sum + (diff * diff)
    end
    
    local std_dev = math.sqrt(variance_sum / table.getn(chart_data))
    
    -- Coeficiente de variación
    if avg ~= 0 then
        return std_dev / math.abs(avg)
    end
    
    return 0
end

function calculate_trades_per_day()
    local chart_data = get_profit_chart_data(30)
    
    if table.getn(chart_data) == 0 then
        return 0
    end
    
    local total_trades = 0
    local days_with_trades = 0
    
    for i = 1, table.getn(chart_data) do
        if chart_data[i].trades > 0 then
            total_trades = total_trades + chart_data[i].trades
            days_with_trades = days_with_trades + 1
        end
    end
    
    if days_with_trades > 0 then
        return total_trades / days_with_trades
    end
    
    return 0
end

function compare_periods(period1, period2)
    local dashboard_data = get_dashboard_data()
    
    local p1_data = dashboard_data[period1]
    local p2_data = dashboard_data[period2]
    
    if not p1_data or not p2_data then
        return {
            profit_change = 0,
            trades_change = 0,
            success_rate_change = 0,
        }
    end
    
    local p1_net = p1_data.total_profit - p1_data.total_loss
    local p2_net = p2_data.total_profit - p2_data.total_loss
    
    local profit_change = 0
    if p2_net ~= 0 then
        profit_change = ((p1_net - p2_net) / math.abs(p2_net)) * 100
    end
    
    local trades_change = 0
    if p2_data.total_trades > 0 then
        trades_change = ((p1_data.total_trades - p2_data.total_trades) / p2_data.total_trades) * 100
    end
    
    local p1_success_rate = p1_data.total_trades > 0 and (p1_data.successful_trades / p1_data.total_trades) or 0
    local p2_success_rate = p2_data.total_trades > 0 and (p2_data.successful_trades / p2_data.total_trades) or 0
    local success_rate_change = (p1_success_rate - p2_success_rate) * 100
    
    return {
        profit_change = profit_change,
        trades_change = trades_change,
        success_rate_change = success_rate_change,
    }
end

-- ============================================================================
-- Export Reports
-- ============================================================================

function generate_text_report(period)
    period = period or 'all_time'
    
    local dashboard_data = get_dashboard_data()
    local metrics = calculate_performance_metrics()
    
    local report = {}
    
    tinsert(report, '=========================================')
    tinsert(report, '   REPORTE DE TRADING - AUX ADDON')
    tinsert(report, '=========================================')
    tinsert(report, '')
    tinsert(report, 'Fecha: ' .. date('%Y-%m-%d %H:%M:%S', time()))
    tinsert(report, '')
    
    -- Estadísticas generales
    tinsert(report, '--- ESTADÍSTICAS GENERALES ---')
    local all_time = dashboard_data.all_time
    tinsert(report, string.format('Total Trades: %d', all_time.total_trades))
    tinsert(report, string.format('Trades Exitosos: %d (%.1f%%)', all_time.successful_trades, all_time.success_rate))
    tinsert(report, string.format('Trades Fallidos: %d', all_time.failed_trades))
    tinsert(report, '')
    
    -- Profit/Loss
    tinsert(report, '--- PROFIT/LOSS ---')
    tinsert(report, string.format('Profit Total: %s', format_money(all_time.total_profit)))
    tinsert(report, string.format('Loss Total: %s', format_money(all_time.total_loss)))
    tinsert(report, string.format('Net Profit: %s', format_money(all_time.net_profit)))
    tinsert(report, string.format('ROI: %.2f%%', all_time.roi))
    tinsert(report, string.format('Profit por Trade: %s', format_money(all_time.avg_profit_per_trade)))
    tinsert(report, '')
    
    -- Métricas de performance
    tinsert(report, '--- MÉTRICAS DE PERFORMANCE ---')
    tinsert(report, string.format('Profit Factor: %.2f', metrics.profit_factor))
    tinsert(report, string.format('Max Drawdown: %s', format_money(metrics.max_drawdown)))
    tinsert(report, string.format('Volatilidad: %.2f', metrics.volatility))
    tinsert(report, string.format('Trades por Día: %.1f', metrics.trades_per_day))
    tinsert(report, '')
    
    -- Mejores trades
    if all_time.best_trade then
        tinsert(report, '--- MEJOR TRADE ---')
        tinsert(report, string.format('Item: %s', all_time.best_trade.item_name or 'Unknown'))
        tinsert(report, string.format('Profit: %s', format_money(all_time.best_trade.profit)))
        tinsert(report, '')
    end
    
    -- Top items
    tinsert(report, '--- TOP 5 ITEMS POR PROFIT ---')
    local top_items = get_top_items_by_profit(5)
    for i = 1, table.getn(top_items) do
        local item = top_items[i]
        tinsert(report, string.format('%d. %s - %s (%d trades)', 
            i, 
            item.item_name or 'Unknown',
            format_money(item.total_profit),
            item.total_trades
        ))
    end
    tinsert(report, '')
    
    tinsert(report, '=========================================')
    
    return table.concat(report, '\n')
end

function export_report_to_chat()
    local report = generate_text_report()
    local lines = {}
    
    -- Lua 5.0 compatible: use string.gfind instead of string.gmatch
    for line in string.gfind(report, '[^\n]+') do
        tinsert(lines, line)
    end
    
    for i = 1, table.getn(lines) do
        aux.print(lines[i])
    end
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function format_money(copper)
    if not copper or copper == 0 then
        return '0c'
    end
    
    local is_negative = copper < 0
    copper = math.abs(copper)
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local copper_left = math.mod(copper, 100)
    
    local result = ''
    if gold > 0 then
        result = result .. gold .. 'g '
    end
    if silver > 0 then
        result = result .. silver .. 's '
    end
    if copper_left > 0 or result == '' then
        result = result .. copper_left .. 'c'
    end
    
    if is_negative then
        result = '-' .. result
    end
    
    return result
end

-- ============================================================================
-- ENHANCED: Real Data Integration
-- ============================================================================

-- Get real profit data from AuxTradingAccounting
function M.get_real_profit_data(days)
    days = days or 7
    
    local data = {}
    local now = time()
    
    -- Initialize days
    for i = days - 1, 0, -1 do
        local day_ts = now - (i * 86400)
        local day_key = get_day_key(day_ts)
        data[day_key] = {
            sales = 0,
            purchases = 0,
            profit = 0,
            count = 0,
        }
    end
    
    -- Process AuxTradingAccounting sales
    if AuxTradingAccounting and AuxTradingAccounting.sales then
        for item_key, records in pairs(AuxTradingAccounting.sales) do
            for _, record in ipairs(records) do
                local ts = record.time or 0
                local day_key = get_day_key(ts)
                
                if data[day_key] then
                    local amount = (record.price or 0) * (record.quantity or 1)
                    data[day_key].sales = data[day_key].sales + amount
                    data[day_key].profit = data[day_key].profit + amount
                    data[day_key].count = data[day_key].count + 1
                end
            end
        end
    end
    
    -- Process AuxTradingAccounting purchases
    if AuxTradingAccounting and AuxTradingAccounting.purchases then
        for item_key, records in pairs(AuxTradingAccounting.purchases) do
            for _, record in ipairs(records) do
                local ts = record.time or 0
                local day_key = get_day_key(ts)
                
                if data[day_key] then
                    local amount = (record.price or 0) * (record.quantity or 1)
                    data[day_key].purchases = data[day_key].purchases + amount
                    data[day_key].profit = data[day_key].profit - amount
                end
            end
        end
    end
    
    -- Convert to array sorted by date
    local result = {}
    for day_key, values in pairs(data) do
        table.insert(result, {
            date = day_key,
            sales = values.sales,
            purchases = values.purchases,
            profit = values.profit,
            count = values.count,
        })
    end
    
    table.sort(result, function(a, b) return a.date < b.date end)
    
    return result
end

-- Get top profitable items from accounting
function M.get_top_profitable_items(limit)
    limit = limit or 10
    
    local items = {}
    
    if AuxTradingAccounting and AuxTradingAccounting.sales then
        for item_key, records in pairs(AuxTradingAccounting.sales) do
            local total_revenue = 0
            local total_quantity = 0
            local item_name = nil
            
            for _, record in ipairs(records) do
                total_revenue = total_revenue + ((record.price or 0) * (record.quantity or 1))
                total_quantity = total_quantity + (record.quantity or 1)
                item_name = item_name or record.name or item_key
            end
            
            if total_revenue > 0 then
                table.insert(items, {
                    item_key = item_key,
                    name = item_name,
                    revenue = total_revenue,
                    quantity = total_quantity,
                    avg_price = total_quantity > 0 and (total_revenue / total_quantity) or 0,
                })
            end
        end
    end
    
    -- Sort by revenue
    table.sort(items, function(a, b) return a.revenue > b.revenue end)
    
    -- Return top N
    local result = {}
    for i = 1, math.min(limit, table.getn(items)) do
        table.insert(result, items[i])
    end
    
    return result
end

-- Get price history stats
function M.get_price_history_summary()
    if M.price_history and M.price_history.get_stats then
        return M.price_history.get_stats()
    end
    return { items = 0, samples = 0 }
end

-- Get graph bar heights (normalized 0-100)
function M.get_graph_bars(days)
    local data = M.get_real_profit_data(days)
    local max_val = 0
    
    -- Find max for normalization
    for _, entry in ipairs(data) do
        local abs_profit = math.abs(entry.profit)
        if abs_profit > max_val then max_val = abs_profit end
    end
    
    local bars = {}
    for _, entry in ipairs(data) do
        local height = 0
        if max_val > 0 then
            height = math.floor((math.abs(entry.profit) / max_val) * 100)
        end
        table.insert(bars, {
            date = entry.date,
            height = height,
            profit = entry.profit,
            is_positive = entry.profit >= 0,
        })
    end
    
    return bars
end

-- Register module
M.modules.dashboard = {
    export_report_to_chat = export_report_to_chat,
    get_dashboard_data = get_dashboard_data,
    get_real_profit_data = M.get_real_profit_data,
    get_top_profitable_items = M.get_top_profitable_items,
    get_price_history_summary = M.get_price_history_summary,
    get_graph_bars = M.get_graph_bars,
}
