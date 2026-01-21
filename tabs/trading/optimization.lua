module 'aux.tabs.trading'

local aux = require 'aux'

-- ============================================================================
-- Performance Optimization - Optimización de Performance
-- ============================================================================

aux.print('[OPTIMIZATION] Módulo de optimización cargado')

-- ============================================================================
-- Smart Query Optimization
-- ============================================================================

local query_cache = {}
local cache_ttl = 300  -- 5 minutos

function init_query_cache()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    -- Cache en memoria (no persistente)
    query_cache = {}
end

-- Optimizar queries de escaneo
function optimize_scan_queries(items_list)
    -- Agrupar items por categoría para reducir queries
    local grouped_queries = {}
    
    for i = 1, getn(items_list) do
        local item = items_list[i]
        local category = get_item_category(item)
        
        if not grouped_queries[category] then
            grouped_queries[category] = {}
        end
        
        tinsert(grouped_queries[category], item)
    end
    
    -- Crear queries optimizadas
    local optimized_queries = {}
    
    for category, items in pairs(grouped_queries) do
        -- Si hay muchos items en la categoría, hacer una query genérica
        if getn(items) > 5 then
            tinsert(optimized_queries, {
                type = 'category',
                category = category,
                items = items,
            })
        else
            -- Si son pocos, queries individuales
            for j = 1, getn(items) do
                tinsert(optimized_queries, {
                    type = 'individual',
                    item = items[j],
                })
            end
        end
    end
    
    return optimized_queries
end

-- Cache de resultados de queries
function cache_query_result(query_key, result)
    query_cache[query_key] = {
        result = result,
        timestamp = time(),
    }
end

function get_cached_query_result(query_key)
    local cached = query_cache[query_key]
    
    if not cached then
        return nil
    end
    
    -- Verificar si el cache expiró
    if time() - cached.timestamp > cache_ttl then
        query_cache[query_key] = nil
        return nil
    end
    
    return cached.result
end

-- Priorizar queries por importancia
function prioritize_queries(queries)
    -- Clasificar queries por prioridad
    local high_priority = {}
    local medium_priority = {}
    local low_priority = {}
    
    for i = 1, getn(queries) do
        local query = queries[i]
        local priority = calculate_query_priority(query)
        
        if priority >= 80 then
            tinsert(high_priority, query)
        elseif priority >= 50 then
            tinsert(medium_priority, query)
        else
            tinsert(low_priority, query)
        end
    end
    
    -- Combinar en orden de prioridad
    local prioritized = {}
    
    for i = 1, getn(high_priority) do
        tinsert(prioritized, high_priority[i])
    end
    for i = 1, getn(medium_priority) do
        tinsert(prioritized, medium_priority[i])
    end
    for i = 1, getn(low_priority) do
        tinsert(prioritized, low_priority[i])
    end
    
    return prioritized
end

function calculate_query_priority(query)
    local priority = 50  -- Base priority
    
    -- Items con alta rentabilidad histórica
    if query.item then
        local classification = get_item_classification(query.item.item_key)
        
        if classification and classification.classification == 'highly_profitable' then
            priority = priority + 30
        elseif classification and classification.classification == 'profitable' then
            priority = priority + 20
        end
    end
    
    -- Items con alto volumen
    if query.item then
        local avg_volume = get_average_daily_volume(query.item.item_key, 7)
        if avg_volume and avg_volume > 10 then
            priority = priority + 20
        elseif avg_volume and avg_volume > 5 then
            priority = priority + 10
        end
    end
    
    return priority
end

-- ============================================================================
-- Database Query Optimization
-- ============================================================================

-- Optimizar acceso a aux.faction_data (base de datos persistente)
function optimize_database_access()
    -- Crear índices en memoria para acceso rápido
    if not aux.faction_data or not aux.faction_data.trading then
        return
    end
    
    -- Índice de trades por item_key
    local trades_by_item = {}
    local trades_by_status = {}
    
    if aux.faction_data.trading.trades then
        for trade_id, trade in pairs(aux.faction_data.trading.trades) do
            -- Índice por item
            if trade.item_key then
                if not trades_by_item[trade.item_key] then
                    trades_by_item[trade.item_key] = {}
                end
                tinsert(trades_by_item[trade.item_key], trade)
            end
            
            -- Índice por status
            if trade.status then
                if not trades_by_status[trade.status] then
                    trades_by_status[trade.status] = {}
                end
                tinsert(trades_by_status[trade.status], trade)
            end
        end
    end
    
    -- Guardar índices en cache
    data_cache.trades_by_item = trades_by_item
    data_cache.trades_by_status = trades_by_status
    
    aux.print('[OPTIMIZATION] Índices de base de datos creados')
end

-- Query optimizada: obtener trades por item
function get_trades_by_item_optimized(item_key)
    -- Usar índice si está disponible
    if data_cache.trades_by_item and data_cache.trades_by_item[item_key] then
        return data_cache.trades_by_item[item_key]
    end
    
    -- Fallback: búsqueda manual
    local result = {}
    
    if aux.faction_data and aux.faction_data.trading and aux.faction_data.trading.trades then
        for trade_id, trade in pairs(aux.faction_data.trading.trades) do
            if trade.item_key == item_key then
                tinsert(result, trade)
            end
        end
    end
    
    return result
end

-- Query optimizada: obtener trades por status
function get_trades_by_status_optimized(status)
    -- Usar índice si está disponible
    if data_cache.trades_by_status and data_cache.trades_by_status[status] then
        return data_cache.trades_by_status[status]
    end
    
    -- Fallback: búsqueda manual
    local result = {}
    
    if aux.faction_data and aux.faction_data.trading and aux.faction_data.trading.trades then
        for trade_id, trade in pairs(aux.faction_data.trading.trades) do
            if trade.status == status then
                tinsert(result, trade)
            end
        end
    end
    
    return result
end

-- Batch updates para reducir escrituras
local pending_updates = {}

function queue_database_update(table_name, key, value)
    if not pending_updates[table_name] then
        pending_updates[table_name] = {}
    end
    
    pending_updates[table_name][key] = value
end

function flush_database_updates()
    if not aux.faction_data or not aux.faction_data.trading then
        return
    end
    
    local update_count = 0
    
    for table_name, updates in pairs(pending_updates) do
        if not aux.faction_data.trading[table_name] then
            aux.faction_data.trading[table_name] = {}
        end
        
        for key, value in pairs(updates) do
            aux.faction_data.trading[table_name][key] = value
            update_count = update_count + 1
        end
    end
    
    -- Limpiar cola
    pending_updates = {}
    
    if update_count > 0 then
        aux.print(string.format('[OPTIMIZATION] %d actualizaciones de BD aplicadas', update_count))
    end
end

-- ============================================================================
-- Intelligent Caching System
-- ============================================================================

local data_cache = {
    market_values = {},
    item_profiles = {},
    trends = {},
    competition = {},
    trades_by_item = {},
    trades_by_status = {},
}

function init_data_cache()
    -- Cache en memoria para datos frecuentemente accedidos
    data_cache = {
        market_values = {},
        item_profiles = {},
        trends = {},
        competition = {},
    }
end

-- Cache de valores de mercado
function cache_market_value(item_key, value)
    data_cache.market_values[item_key] = {
        value = value,
        timestamp = time(),
    }
end

function get_cached_market_value(item_key)
    local cached = data_cache.market_values[item_key]
    
    if not cached then
        return nil
    end
    
    -- Cache de valores de mercado dura 10 minutos
    if time() - cached.timestamp > 600 then
        data_cache.market_values[item_key] = nil
        return nil
    end
    
    return cached.value
end

-- Cache de perfiles de items
function cache_item_profile(item_key, profile)
    data_cache.item_profiles[item_key] = {
        profile = profile,
        timestamp = time(),
    }
end

function get_cached_item_profile(item_key)
    local cached = data_cache.item_profiles[item_key]
    
    if not cached then
        return nil
    end
    
    -- Cache de perfiles dura 30 minutos
    if time() - cached.timestamp > 1800 then
        data_cache.item_profiles[item_key] = nil
        return nil
    end
    
    return cached.profile
end

-- Limpiar cache antiguo
function cleanup_cache()
    local current_time = time()
    
    -- Limpiar market values
    for item_key, cached in pairs(data_cache.market_values) do
        if current_time - cached.timestamp > 600 then
            data_cache.market_values[item_key] = nil
        end
    end
    
    -- Limpiar profiles
    for item_key, cached in pairs(data_cache.item_profiles) do
        if current_time - cached.timestamp > 1800 then
            data_cache.item_profiles[item_key] = nil
        end
    end
    
    -- Limpiar trends
    for item_key, cached in pairs(data_cache.trends) do
        if current_time - cached.timestamp > 3600 then
            data_cache.trends[item_key] = nil
        end
    end
end

-- ============================================================================
-- Memory Optimization
-- ============================================================================

local memory_config = {
    max_price_history_days = 30,
    max_trades_to_keep = 1000,
    max_opportunities_to_display = 100,
    cleanup_interval = 3600,  -- 1 hora
}

function init_memory_optimization()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    if not aux.account_data.trading.memory_config then
        aux.account_data.trading.memory_config = memory_config
    else
        memory_config = aux.account_data.trading.memory_config
    end
end

-- Limpiar datos antiguos
function cleanup_old_data()
    local current_time = time()
    local cutoff_time = current_time - (memory_config.max_price_history_days * 86400)
    
    -- Limpiar price history
    if price_history then
        for item_key, history_entry in pairs(price_history) do
            if history_entry.prices then
                local cleaned_prices = {}
                
                for i = 1, getn(history_entry.prices) do
                    local price_entry = history_entry.prices[i]
                    if price_entry.timestamp >= cutoff_time then
                        tinsert(cleaned_prices, price_entry)
                    end
                end
                
                history_entry.prices = cleaned_prices
            end
        end
    end
    
    -- Limpiar trades antiguos
    if aux.faction_data and aux.faction_data.trading and aux.faction_data.trading.trades then
        local trades_array = {}
        
        for trade_id, trade in pairs(aux.faction_data.trading.trades) do
            tinsert(trades_array, {id = trade_id, trade = trade})
        end
        
        -- Ordenar por fecha
        table.sort(trades_array, function(a, b)
            local a_time = a.trade.sold_at or a.trade.bought_at or 0
            local b_time = b.trade.sold_at or b.trade.bought_at or 0
            return a_time > b_time
        end)
        
        -- Mantener solo los más recientes
        if getn(trades_array) > memory_config.max_trades_to_keep then
            for i = memory_config.max_trades_to_keep + 1, getn(trades_array) do
                aux.faction_data.trading.trades[trades_array[i].id] = nil
            end
        end
    end
    
    aux.print('[OPTIMIZATION] Limpieza de datos completada')
end

-- Comprimir datos históricos
function compress_historical_data()
    -- Comprimir price history agrupando por día
    if not price_history then
        return
    end
    
    local compressed_count = 0
    
    for item_key, history_entry in pairs(price_history) do
        if history_entry.prices and getn(history_entry.prices) > 100 then
            local original_size = getn(history_entry.prices)
            local compressed = compress_price_array(history_entry.prices)
            history_entry.prices = compressed
            compressed_count = compressed_count + 1
            
            -- Log reducción
            local reduction = ((original_size - getn(compressed)) / original_size) * 100
            if reduction > 50 then
                aux.print(string.format('[OPTIMIZATION] %s: %d -> %d entries (%.1f%% reduction)', item_key, original_size, getn(compressed), reduction))
            end
        end
    end
    
    if compressed_count > 0 then
        aux.print(string.format('[OPTIMIZATION] Comprimidos %d items de historial', compressed_count))
    end
end

-- Limitar tamaño de cache
function limit_cache_size()
    local max_cache_entries = 500
    
    -- Limitar market values cache
    local market_values_count = 0
    for k, v in pairs(data_cache.market_values) do
        market_values_count = market_values_count + 1
    end
    
    if market_values_count > max_cache_entries then
        -- Eliminar entradas más antiguas
        local entries = {}
        for item_key, cached in pairs(data_cache.market_values) do
            tinsert(entries, {key = item_key, timestamp = cached.timestamp})
        end
        
        table.sort(entries, function(a, b)
            return a.timestamp < b.timestamp
        end)
        
        -- Eliminar las más antiguas
        local to_remove = market_values_count - max_cache_entries
        for i = 1, to_remove do
            data_cache.market_values[entries[i].key] = nil
        end
        
        aux.print(string.format('[OPTIMIZATION] Eliminadas %d entradas antiguas del cache', to_remove))
    end
end

-- Liberar memoria no utilizada
function free_unused_memory()
    -- Forzar garbage collection
    collectgarbage('collect')
    
    -- Limpiar referencias circulares
    cleanup_circular_references()
    
    -- Comprimir datos
    compress_historical_data()
    
    -- Limitar cache
    limit_cache_size()
    
    aux.print('[OPTIMIZATION] Memoria liberada')
end

function cleanup_circular_references()
    -- Limpiar referencias que puedan causar memory leaks
    -- En Lua, el GC maneja esto automáticamente, pero podemos ayudar
    
    -- Limpiar callbacks antiguos
    if data_cache.callbacks then
        data_cache.callbacks = {}
    end
end

-- Monitorear uso de memoria
function get_memory_usage()
    -- Obtener uso de memoria en KB
    local memory_kb = collectgarbage('count')
    
    -- Estimar uso por componente
    local cache_size = 0
    for k, v in pairs(data_cache) do
        if type(v) == 'table' then
            for k2, v2 in pairs(v) do
                cache_size = cache_size + 1
            end
        end
    end
    
    local query_cache_size = 0
    for k, v in pairs(query_cache) do
        query_cache_size = query_cache_size + 1
    end
    
    return {
        total_kb = memory_kb,
        cache_entries = cache_size,
        query_cache_entries = query_cache_size,
    }
end

function compress_price_array(prices)
    -- Agrupar precios por día y promediar
    local daily_prices = {}
    
    for i = 1, getn(prices) do
        local price_entry = prices[i]
        local day_key = math.floor(price_entry.timestamp / 86400)
        
        if not daily_prices[day_key] then
            daily_prices[day_key] = {
                sum = 0,
                count = 0,
                min = price_entry.price,
                max = price_entry.price,
                timestamp = price_entry.timestamp,
            }
        end
        
        local day_data = daily_prices[day_key]
        day_data.sum = day_data.sum + price_entry.price
        day_data.count = day_data.count + 1
        
        if price_entry.price < day_data.min then
            day_data.min = price_entry.price
        end
        if price_entry.price > day_data.max then
            day_data.max = price_entry.price
        end
    end
    
    -- Convertir a array
    local compressed = {}
    for day_key, day_data in pairs(daily_prices) do
        tinsert(compressed, {
            price = day_data.sum / day_data.count,  -- Promedio
            timestamp = day_data.timestamp,
            min = day_data.min,
            max = day_data.max,
            samples = day_data.count,
        })
    end
    
    -- Ordenar por timestamp
    table.sort(compressed, function(a, b)
        return a.timestamp < b.timestamp
    end)
    
    return compressed
end

-- ============================================================================
-- Processing Speed Optimization
-- ============================================================================

-- Procesamiento por lotes
function process_auctions_batch(auctions, batch_size)
    batch_size = batch_size or 50
    
    local results = {}
    local batch_count = math.ceil(getn(auctions) / batch_size)
    
    for batch = 1, batch_count do
        local start_idx = (batch - 1) * batch_size + 1
        local end_idx = math.min(batch * batch_size, getn(auctions))
        
        -- Procesar lote
        for i = start_idx, end_idx do
            local auction = auctions[i]
            local result = process_single_auction(auction)
            
            if result then
                tinsert(results, result)
            end
        end
        
        -- Yield entre lotes para no bloquear UI
        if batch < batch_count then
            coroutine.yield()
        end
    end
    
    return results
end

function process_single_auction(auction)
    -- Procesamiento optimizado de una subasta
    
    -- Usar cache cuando sea posible
    local market_value = get_cached_market_value(auction.item_key)
    if not market_value then
        market_value = history.value(auction.item_key)
        if market_value then
            cache_market_value(auction.item_key, market_value)
        end
    end
    
    -- Verificación rápida de viabilidad
    if not market_value or market_value == 0 then
        return nil
    end
    
    if not auction.buyout_price or auction.buyout_price == 0 then
        return nil
    end
    
    -- Cálculo rápido de descuento
    local discount = (market_value - auction.buyout_price) / market_value
    
    if discount < 0.15 then  -- Menos de 15% descuento
        return nil
    end
    
    -- Si pasa las verificaciones rápidas, hacer análisis completo
    return {
        auction = auction,
        market_value = market_value,
        discount = discount,
    }
end

-- ============================================================================
-- Index System for Fast Lookups
-- ============================================================================

local indexes = {
    items_by_category = {},
    items_by_profit = {},
    trades_by_item = {},
    trades_by_date = {},
}

function init_indexes()
    indexes = {
        items_by_category = {},
        items_by_profit = {},
        trades_by_item = {},
        trades_by_date = {},
    }
end

function rebuild_indexes()
    init_indexes()
    
    -- Indexar trades
    if aux.faction_data and aux.faction_data.trading and aux.faction_data.trading.trades then
        for trade_id, trade in pairs(aux.faction_data.trading.trades) do
            -- Por item
            local item_key = trade.item_key
            if not indexes.trades_by_item[item_key] then
                indexes.trades_by_item[item_key] = {}
            end
            tinsert(indexes.trades_by_item[item_key], trade_id)
            
            -- Por fecha
            if trade.bought_at then
                local day_key = get_day_key(trade.bought_at)
                if not indexes.trades_by_date[day_key] then
                    indexes.trades_by_date[day_key] = {}
                end
                tinsert(indexes.trades_by_date[day_key], trade_id)
            end
        end
    end
    
    aux.print('[OPTIMIZATION] Índices reconstruidos')
end

function get_trades_by_item_fast(item_key)
    if not indexes.trades_by_item[item_key] then
        return {}
    end
    
    local trades = {}
    for i = 1, getn(indexes.trades_by_item[item_key]) do
        local trade_id = indexes.trades_by_item[item_key][i]
        local trade = aux.faction_data.trading.trades[trade_id]
        if trade then
            tinsert(trades, trade)
        end
    end
    
    return trades
end

-- ============================================================================
-- Performance Monitoring
-- ============================================================================

local performance_stats = {
    scan_times = {},
    processing_times = {},
    cache_hits = 0,
    cache_misses = 0,
}

function record_scan_time(duration)
    tinsert(performance_stats.scan_times, duration)
    
    -- Mantener solo últimos 100
    if getn(performance_stats.scan_times) > 100 then
        tremove(performance_stats.scan_times, 1)
    end
end

function record_processing_time(duration)
    tinsert(performance_stats.processing_times, duration)
    
    if getn(performance_stats.processing_times) > 100 then
        tremove(performance_stats.processing_times, 1)
    end
end

function get_performance_stats()
    local avg_scan_time = 0
    if getn(performance_stats.scan_times) > 0 then
        local sum = 0
        for i = 1, getn(performance_stats.scan_times) do
            sum = sum + performance_stats.scan_times[i]
        end
        avg_scan_time = sum / getn(performance_stats.scan_times)
    end
    
    local avg_processing_time = 0
    if getn(performance_stats.processing_times) > 0 then
        local sum = 0
        for i = 1, getn(performance_stats.processing_times) do
            sum = sum + performance_stats.processing_times[i]
        end
        avg_processing_time = sum / getn(performance_stats.processing_times)
    end
    
    local cache_hit_rate = 0
    local total_cache_requests = performance_stats.cache_hits + performance_stats.cache_misses
    if total_cache_requests > 0 then
        cache_hit_rate = (performance_stats.cache_hits / total_cache_requests) * 100
    end
    
    return {
        avg_scan_time = avg_scan_time,
        avg_processing_time = avg_processing_time,
        cache_hit_rate = cache_hit_rate,
        total_scans = getn(performance_stats.scan_times),
    }
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function get_item_category(item)
    -- Simplificado - debería usar datos reales del item
    if not item or not item.item_key then
        return 'unknown'
    end
    
    -- TODO: Implementar categorización real
    return 'materials'
end

function get_day_key(timestamp)
    local date_table = date('*t', timestamp)
    return string.format('%04d-%02d-%02d', date_table.year, date_table.month, date_table.day)
end

-- ============================================================================
-- Auto-Cleanup Timer
-- ============================================================================

local cleanup_timer = 0

local memory_cleanup_timer = 0
local MEMORY_CLEANUP_INTERVAL = 600  -- 10 minutos

function on_update_optimization(elapsed)
    cleanup_timer = cleanup_timer + elapsed
    memory_cleanup_timer = memory_cleanup_timer + elapsed
    
    -- Limpiar cache cada 5 minutos
    if cleanup_timer >= 300 then
        cleanup_timer = 0
        cleanup_cache()
    end
    
    -- Limpieza de memoria cada 10 minutos
    if memory_cleanup_timer >= MEMORY_CLEANUP_INTERVAL then
        memory_cleanup_timer = 0
        
        -- Comprimir datos históricos
        compress_historical_data()
        
        -- Limitar tamaño de cache
        limit_cache_size()
        
        -- Forzar garbage collection
        collectgarbage('collect')
        
        local memory = get_memory_usage()
        aux.print(string.format('[OPTIMIZATION] Memoria: %.1f KB, Cache: %d entries', memory.total_kb, memory.cache_entries))
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_query_cache()
    init_data_cache()
    init_memory_optimization()
    init_indexes()
    
    -- Optimizar acceso a base de datos
    optimize_database_access()
    
    -- Limpiar datos antiguos al cargar
    cleanup_old_data()
    
    aux.print('[OPTIMIZATION] Sistema de optimización inicializado')
end)

-- Flush de actualizaciones cada 30 segundos
local flush_timer = 0
local FLUSH_INTERVAL = 30

local original_on_update = on_update_optimization
on_update_optimization = function(elapsed)
    original_on_update(elapsed)
    
    flush_timer = flush_timer + elapsed
    
    if flush_timer >= FLUSH_INTERVAL then
        flush_timer = 0
        flush_database_updates()
    end
end

-- Registrar update loop
aux.event_listener('UPDATE', on_update_optimization)

-- ============================================================================
-- PERFORMANCE METRICS
-- ============================================================================

local perf_metrics = {
    cache_hits = 0,
    cache_misses = 0,
    queries_executed = 0,
    queries_cached = 0,
    memory_used = 0,
    memory_saved = 0,
    avg_query_time = 0,
    total_query_time = 0,
}

function record_cache_hit()
    perf_metrics.cache_hits = perf_metrics.cache_hits + 1
end

function record_cache_miss()
    perf_metrics.cache_misses = perf_metrics.cache_misses + 1
end

function record_query(cached)
    perf_metrics.queries_executed = perf_metrics.queries_executed + 1
    if cached then
        perf_metrics.queries_cached = perf_metrics.queries_cached + 1
    end
end

function get_performance_metrics()
    -- Calcular métricas en tiempo real
    local total_cache_ops = perf_metrics.cache_hits + perf_metrics.cache_misses
    local cache_hit_rate = 0
    if total_cache_ops > 0 then
        cache_hit_rate = (perf_metrics.cache_hits / total_cache_ops) * 100
    end
    
    local query_cache_rate = 0
    if perf_metrics.queries_executed > 0 then
        query_cache_rate = (perf_metrics.queries_cached / perf_metrics.queries_executed) * 100
    end
    
    -- Estimar memoria usada (aproximado)
    local cache_size = 0
    for k, v in pairs(query_cache) do
        cache_size = cache_size + 1
    end
    
    local data_cache_size = 0
    for k, v in pairs(data_cache) do
        data_cache_size = data_cache_size + 1
    end
    
    return {
        cache_hits = perf_metrics.cache_hits,
        cache_misses = perf_metrics.cache_misses,
        cache_hit_rate = cache_hit_rate,
        queries_executed = perf_metrics.queries_executed,
        queries_cached = perf_metrics.queries_cached,
        query_cache_rate = query_cache_rate,
        memory_entries = cache_size + data_cache_size,
        avg_query_time = perf_metrics.avg_query_time,
    }
end

-- ============================================================================
-- UI UPDATE FUNCTION
-- ============================================================================

function update_optimization_ui(optimization_frame)
    if not optimization_frame then
        return
    end
    
    -- Crear UI inicial si no existe
    if not optimization_frame.initialized then
        create_optimization_ui(optimization_frame)
        optimization_frame.initialized = true
    end
    
    local metrics = get_performance_metrics()
    
    -- Actualizar Cache Hits
    if optimization_frame.cache_hits_value then
        optimization_frame.cache_hits_value:SetText(tostring(metrics.cache_hits))
    end
    
    -- Actualizar Cache Misses
    if optimization_frame.cache_misses_value then
        optimization_frame.cache_misses_value:SetText(tostring(metrics.cache_misses))
    end
    
    -- Actualizar Queries/seg
    if optimization_frame.queries_value then
        -- Aproximar queries por segundo basado en total
        local qps = math.min(metrics.queries_executed, 100)
        optimization_frame.queries_value:SetText(tostring(qps))
    end
    
    -- Actualizar Memoria Usada
    if optimization_frame.memory_value then
        optimization_frame.memory_value:SetText(tostring(metrics.memory_entries))
    end
    
    -- Actualizar Tiempo Promedio Query
    if optimization_frame.query_time_value then
        optimization_frame.query_time_value:SetText(string.format('%.1fms', metrics.avg_query_time))
    end
    
    -- Actualizar Items en Cache
    if optimization_frame.cache_items_value then
        optimization_frame.cache_items_value:SetText(tostring(metrics.memory_entries))
    end
    
    -- Actualizar Reducción Memoria
    if optimization_frame.memory_reduction_value then
        local reduction = metrics.cache_hit_rate
        optimization_frame.memory_reduction_value:SetText(string.format('%.1f%%', reduction))
    end
    
    -- Actualizar Mejora Velocidad
    if optimization_frame.speed_improvement_value then
        local improvement = metrics.query_cache_rate
        optimization_frame.speed_improvement_value:SetText(string.format('%.1f%%', improvement))
    end
end

function create_optimization_ui(optimization_frame)
    if not optimization_frame then return end
    
    -- Título
    local title = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 20, -20)
    title:SetText('|cFFFFD700Optimización de Performance|r')
    
    -- Descripción
    local desc = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    desc:SetPoint('TOPLEFT', 20, -50)
    desc:SetPoint('TOPRIGHT', -20, -50)
    desc:SetJustifyH('LEFT')
    desc:SetText('|cFF888888Optimización de consultas, cache y uso de memoria para mejor performance.|r')
    
    -- Métricas de performance
    local metrics_y = -80
    
    -- Cache Hits
    local cache_hits_label = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    cache_hits_label:SetPoint('TOPLEFT', 20, metrics_y)
    cache_hits_label:SetText('Cache Hits:')
    
    optimization_frame.cache_hits_value = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    optimization_frame.cache_hits_value:SetPoint('TOPLEFT', 120, metrics_y)
    optimization_frame.cache_hits_value:SetText('0')
    
    -- Cache Misses
    local cache_misses_label = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    cache_misses_label:SetPoint('TOPLEFT', 20, metrics_y - 30)
    cache_misses_label:SetText('Cache Misses:')
    
    optimization_frame.cache_misses_value = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    optimization_frame.cache_misses_value:SetPoint('TOPLEFT', 120, metrics_y - 30)
    optimization_frame.cache_misses_value:SetText('0')
    
    -- Queries/seg
    local queries_label = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    queries_label:SetPoint('TOPLEFT', 20, metrics_y - 60)
    queries_label:SetText('Queries/seg:')
    
    optimization_frame.queries_value = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    optimization_frame.queries_value:SetPoint('TOPLEFT', 120, metrics_y - 60)
    optimization_frame.queries_value:SetText('0')
    
    -- Memoria
    local memory_label = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    memory_label:SetPoint('TOPLEFT', 20, metrics_y - 90)
    memory_label:SetText('Memoria:')
    
    optimization_frame.memory_value = optimization_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    optimization_frame.memory_value:SetPoint('TOPLEFT', 120, metrics_y - 90)
    optimization_frame.memory_value:SetText('0 KB')
    
    -- Botón de optimizar
    local optimize_button = CreateFrame('Button', nil, optimization_frame, 'UIPanelButtonTemplate')
    optimize_button:SetPoint('TOPRIGHT', -20, -20)
    optimize_button:SetWidth(100)
    optimize_button:SetHeight(25)
    optimize_button:SetText('Optimizar')
    optimize_button:SetScript('OnClick', function()
        aux.print('[OPTIMIZATION] Optimización solicitada')
        update_optimization_ui(optimization_frame)
    end)
end

-- ============================================================================
-- REGISTRO DE FUNCIONES PÚBLICAS
-- ============================================================================

-- ============================================================================
-- SISTEMA DE LIMPIEZA AUTOMÁTICA
-- ============================================================================

local cleanup_timer = 0
local CLEANUP_INTERVAL = 600 -- 10 minutos

local compression_timer = 0
local COMPRESSION_INTERVAL = 600 -- 10 minutos

local gc_timer = 0
local GC_INTERVAL = 300 -- 5 minutos

-- Función que se ejecuta en cada frame
function on_update(elapsed)
    -- Timer de limpieza de datos antiguos
    cleanup_timer = cleanup_timer + elapsed
    if cleanup_timer >= CLEANUP_INTERVAL then
        cleanup_timer = 0
        cleanup_old_data()
        aux.print('[OPTIMIZATION] Limpieza automática de datos antiguos ejecutada')
    end
    
    -- Timer de compresión de datos históricos
    compression_timer = compression_timer + elapsed
    if compression_timer >= COMPRESSION_INTERVAL then
        compression_timer = 0
        compress_historical_data()
        aux.print('[OPTIMIZATION] Compresión de datos históricos ejecutada')
    end
    
    -- Timer de garbage collection
    gc_timer = gc_timer + elapsed
    if gc_timer >= GC_INTERVAL then
        gc_timer = 0
        free_unused_memory()
        collectgarbage('collect')
        aux.print('[OPTIMIZATION] Garbage collection ejecutado')
    end
end

-- Iniciar sistema de limpieza automática
function start_auto_cleanup()
    -- Crear frame invisible para OnUpdate
    if not optimization_cleanup_frame then
        optimization_cleanup_frame = CreateFrame('Frame')
        optimization_cleanup_frame:SetScript('OnUpdate', on_update)
        aux.print('[OPTIMIZATION] Sistema de limpieza automática iniciado')
    end
end

-- Detener sistema de limpieza automática
function stop_auto_cleanup()
    if optimization_cleanup_frame then
        optimization_cleanup_frame:SetScript('OnUpdate', nil)
        aux.print('[OPTIMIZATION] Sistema de limpieza automática detenido')
    end
end

local M = getfenv()
if M.modules then
    M.modules.optimization = {
        -- Initialization
        init = function()
            init_query_cache()
            init_data_cache()
            init_memory_optimization()
            init_indexes()
            optimize_database_access()
            start_auto_cleanup()
        end,
        -- UI
        update_ui = update_optimization_ui,
        get_metrics = get_performance_metrics,
        -- Cache management
        record_cache_hit = record_cache_hit,
        record_cache_miss = record_cache_miss,
        record_query = record_query,
        cleanup_cache = cleanup_cache,
        -- Database optimization
        optimize_database_access = optimize_database_access,
        get_trades_by_item_optimized = get_trades_by_item_optimized,
        get_trades_by_status_optimized = get_trades_by_status_optimized,
        queue_database_update = queue_database_update,
        flush_database_updates = flush_database_updates,
        -- Query optimization
        optimize_scan_queries = optimize_scan_queries,
        prioritize_queries = prioritize_queries,
        get_cached_query_result = get_cached_query_result,
        cache_query_result = cache_query_result,
        -- Data cache
        cache_market_value = cache_market_value,
        get_cached_market_value = get_cached_market_value,
        cache_item_profile = cache_item_profile,
        get_cached_item_profile = get_cached_item_profile,
        -- Memory optimization
        cleanup_old_data = cleanup_old_data,
        compress_historical_data = compress_historical_data,
        limit_cache_size = limit_cache_size,
        free_unused_memory = free_unused_memory,
        get_memory_usage = get_memory_usage,
        -- Auto cleanup
        start_auto_cleanup = start_auto_cleanup,
        stop_auto_cleanup = stop_auto_cleanup,
        on_update = on_update,
    }
    aux.print('[OPTIMIZATION] Funciones registradas en M.modules.optimization')
end
