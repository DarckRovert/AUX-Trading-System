module 'aux.tabs.trading'

local M = getfenv()
local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local scan = require 'aux.core.scan'
local filter_util = require 'aux.util.filter'
local history = require 'aux.core.history'

-- ============================================================================
-- Scan Integration - Integración REAL con el sistema de scan de aux
-- ============================================================================

aux.print('[SCAN_INTEGRATION] Módulo de integración de scan cargado')

-- ============================================================================
-- Cache Global de Resultados de Scan
-- ============================================================================

local scan_results_cache = {}
local scan_cache_timestamps = {}
local SCAN_CACHE_TTL = 120  -- 2 minutos

-- Helper function para verificar si un item está en una lista
local function contains(tbl, value)
    for i = 1, getn(tbl) do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Funciones de Scan Mejoradas
-- ============================================================================

-- Escanear item específico y actualizar cache
function M.scan_item_for_trading(item_key, on_progress, on_complete)
    -- Parse item_key (formato: "item_id:suffix_id")
    local colon_pos = string.find(item_key, ':')
    local item_id, suffix_id
    if colon_pos then
        item_id = tonumber(string.sub(item_key, 1, colon_pos - 1))
        suffix_id = tonumber(string.sub(item_key, colon_pos + 1)) or 0
    else
        item_id = tonumber(item_key)
        suffix_id = 0
    end
    
    if not item_id then
        if on_complete then
            on_complete({success = false, reason = 'invalid_item_key'})
        end
        return
    end
    
    -- Obtener información del item
    local item_info = info.item(item_id, suffix_id)
    if not item_info then
        if on_complete then
            on_complete({success = false, reason = 'item_not_found'})
        end
        return
    end
    
    -- Crear query para el item
    local query = filter_util.query(item_info.name .. '/exact')
    if not query or not query.blizzard_query then
        if on_complete then
            on_complete({success = false, reason = 'query_creation_failed'})
        end
        return
    end
    
    -- Almacenar resultados del scan
    local scan_results = T.acquire()
    
    -- Iniciar scan
    local scan_id = scan.start{
        type = 'list',
        queries = {query},
        on_scan_start = function()
            if on_progress then
                on_progress({status = 'starting', progress = 0})
            end
        end,
        on_page_loaded = function(page, total_pages)
            if on_progress then
                on_progress({
                    status = 'scanning',
                    progress = page / total_pages,
                    page = page,
                    total_pages = total_pages
                })
            end
        end,
        on_auction = function(auction_record)
            -- Convertir auction_record al formato que necesitamos
            local auction_data = {
                item_key = auction_record.item_key,
                item_id = auction_record.item_id,
                suffix_id = auction_record.suffix_id,
                name = auction_record.name,
                texture = auction_record.texture,
                count = auction_record.count,
                quality = auction_record.quality,
                level = auction_record.level,
                bid_price = auction_record.bid_price,
                buyout_price = auction_record.buyout_price,
                unit_bid_price = auction_record.unit_bid_price,
                unit_buyout_price = auction_record.unit_buyout_price,
                owner = auction_record.owner,
                time_left = auction_record.time_left,
                high_bidder = auction_record.high_bidder,
                page = auction_record.page,
                index = auction_record.index,
            }
            tinsert(scan_results, auction_data)
        end,
        on_complete = function()
            -- Actualizar cache
            scan_results_cache[item_key] = scan_results
            scan_cache_timestamps[item_key] = time()
            
            -- Actualizar cache en helpers.lua
            if M.update_auction_cache then
                M.update_auction_cache(item_key, scan_results)
            end
            
            -- Registrar en el sistema de trading para análisis
            if M.record_scan_data then
                M.record_scan_data(item_key, scan_results)
            end
            
            if on_complete then
                on_complete({
                    success = true,
                    item_key = item_key,
                    auctions = scan_results,
                    count = getn(scan_results)
                })
            end
        end,
        on_abort = function()
            if on_complete then
                on_complete({
                    success = false,
                    reason = 'scan_aborted',
                    partial_results = scan_results
                })
            end
        end,
    }
    
    return scan_id
end

-- Escanear múltiples items (para buscar oportunidades)
function M.scan_multiple_items(item_keys, on_item_complete, on_all_complete)
    aux.print('[SCAN_MULTIPLE] INICIANDO con ' .. getn(item_keys) .. ' items')
    local results = {}
    local completed = 0
    local total = getn(item_keys)
    
    if total == 0 then
        aux.print('[SCAN_MULTIPLE] ERROR: total es 0')
        if on_all_complete then
            on_all_complete({success = true, results = {}})
        end
        return
    end
    
    aux.print('[SCAN_MULTIPLE] Total validado: ' .. total .. ' items')
    
    local function scan_next_item(index)
        aux.print('[SCAN_NEXT] Llamada con index=' .. index .. ', total=' .. total)
        if index > total then
            aux.print('[SCAN_NEXT] Completado todos los items')
            if on_all_complete then
                on_all_complete({success = true, results = results})
            end
            return
        end
        
        local item_key = item_keys[index]
        aux.print('[SCAN_NEXT] Escaneando item: ' .. tostring(item_key))
        
        M.scan_item_for_trading(
            item_key,
            nil,  -- no progress callback
            function(result)
                results[item_key] = result
                completed = completed + 1
                
                if on_item_complete then
                    on_item_complete(item_key, result, completed, total)
                end
                
                -- Escanear siguiente item
                scan_next_item(index + 1)
            end
        )
    end
    
    -- Iniciar con el primer item
    aux.print('[SCAN_MULTIPLE] Iniciando scan_next_item(1)')
    scan_next_item(1)
end

-- Obtener resultados de scan desde cache
function M.get_cached_scan_results(item_key)
    local now = time()
    
    if scan_results_cache[item_key] and scan_cache_timestamps[item_key] then
        local age = now - scan_cache_timestamps[item_key]
        if age < SCAN_CACHE_TTL then
            return {
                success = true,
                cached = true,
                age = age,
                auctions = scan_results_cache[item_key]
            }
        end
    end
    
    return {success = false, reason = 'no_cache'}
end

-- Limpiar cache antiguo
function M.cleanup_scan_cache()
    local now = time()
    local cleaned = 0
    
    for item_key, timestamp in pairs(scan_cache_timestamps) do
        if (now - timestamp) > SCAN_CACHE_TTL then
            scan_results_cache[item_key] = nil
            scan_cache_timestamps[item_key] = nil
            cleaned = cleaned + 1
        end
    end
    
    return cleaned
end

-- ============================================================================
-- Integración con Sistema de Análisis de Mercado
-- ============================================================================

-- Registrar datos de scan para análisis
function M.record_scan_data(item_key, auctions)
    if not auctions or getn(auctions) == 0 then
        return
    end
    
    -- Calcular estadísticas del scan
    local lowest_buyout = nil
    local total_quantity = 0
    local prices = {}
    
    for i = 1, getn(auctions) do
        local auction = auctions[i]
        
        if auction.buyout_price and auction.buyout_price > 0 then
            if not lowest_buyout or auction.buyout_price < lowest_buyout then
                lowest_buyout = auction.buyout_price
            end
            tinsert(prices, auction.buyout_price)
        end
        
        total_quantity = total_quantity + (auction.count or 1)
    end
    
    -- Registrar en el sistema de ML patterns si existe
    if M.record_price_with_time and lowest_buyout then
        M.record_price_with_time(item_key, lowest_buyout, time())
    end
    
    -- Actualizar volumen si existe la función
    if M.record_volume_data then
        M.record_volume_data(item_key, total_quantity, time())
    end
end

-- ============================================================================
-- Scan de Oportunidades Automático
-- ============================================================================

-- Obtener lista de items para escanear
function M.get_items_to_scan(config)
    local items = {}
    
    -- Opción 1: Items de nuestro inventario
    if config.scan_inventory then
        if M.get_bag_items then
            local bag_items = M.get_bag_items()
            if bag_items then
                for i = 1, getn(bag_items) do
                    local item_key = bag_items[i].item_key
                    if item_key and not contains(items, item_key) then
                        tinsert(items, item_key)
                    end
                end
            end
        end
    end
    
    -- Opción 2: Items de shopping lists
    if config.shopping_lists then
        for i = 1, getn(config.shopping_lists) do
            local list = config.shopping_lists[i]
            if list.items then
                for j = 1, getn(list.items) do
                    local item_key = list.items[j]
                    if item_key and not contains(items, item_key) then
                        tinsert(items, item_key)
                    end
                end
            end
        end
    end
    
    -- Opción 3: Items populares (lista hardcodeada si no hay función)
    if config.scan_popular then
        -- Lista de items populares para tradear
        local popular_items = {
            "14047:0",  -- Runecloth
            "4338:0",   -- Mageweave Cloth
            "4306:0",   -- Silk Cloth
            "7078:0",   -- Essence of Fire
            "7080:0",   -- Essence of Water
            "7082:0",   -- Essence of Air
            "12808:0",  -- Essence of Undeath
            "12364:0",  -- Huge Emerald
            "12799:0",  -- Large Opal
            "12800:0",  -- Azerothian Diamond
        }
        
        for i = 1, getn(popular_items) do
            local item_key = popular_items[i]
            if not contains(items, item_key) then
                tinsert(items, item_key)
            end
        end
    end
    
    -- Si no hay items, usar lista por defecto
    if getn(items) == 0 then
        aux.print('[SCAN_INTEGRATION] No hay items para escanear, usando lista por defecto')
        items = {
            "14047:0",  -- Runecloth
            "4338:0",   -- Mageweave Cloth
            "7078:0",   -- Essence of Fire
        }
    end
    
    return items
end

-- Escanear el AH buscando oportunidades de trading
function M.scan_for_opportunities(config, on_progress, on_complete)
    aux.print('[SCAN_FOR_OPP] INICIANDO scan_for_opportunities')
    config = config or {}
    
    aux.print('[SCAN_FOR_OPP] Config recibida: min_score=' .. tostring(config.min_score))
    local min_score = config.min_score or 20  -- REDUCIDO de 70 a 20 para testing
    local max_items = config.max_items or 20
    
    aux.print('[SCAN_FOR_OPP] Min score configurado: ' .. min_score)
    
    -- Determinar estrategias activas
    local active_strategies = {}
    if M.modules and M.modules.strategies then
        if M.modules.strategies.is_flipping_active and M.modules.strategies.is_flipping_active() then
            tinsert(active_strategies, 'flipping')
        end
        if M.modules.strategies.is_sniping_active and M.modules.strategies.is_sniping_active() then
            tinsert(active_strategies, 'sniping')
        end
        if M.modules.strategies.is_market_reset_active and M.modules.strategies.is_market_reset_active() then
            tinsert(active_strategies, 'market_reset')
        end
        if M.modules.strategies.is_arbitrage_active and M.modules.strategies.is_arbitrage_active() then
            tinsert(active_strategies, 'arbitrage')
        end
    end
    
    -- Usar estrategias activas o las del config como fallback
    local strategies = config.strategies or active_strategies
    if getn(strategies) == 0 then
        strategies = {'flipping', 'sniping'}  -- Default fallback
    end
    
    -- Obtener lista de items a escanear
    aux.print('[SCAN_FOR_OPP] Llamando a get_items_to_scan...')
    local items_to_scan = M.get_items_to_scan(config)
    aux.print('[SCAN_FOR_OPP] Items obtenidos: ' .. getn(items_to_scan))
    
    if getn(items_to_scan) == 0 then
        if on_complete then
            on_complete({success = false, reason = 'no_items_to_scan'})
        end
        return
    end
    
    local opportunities = {}
    
    aux.print('[SCAN_FOR_OPP] Llamando a scan_multiple_items con ' .. getn(items_to_scan) .. ' items')
    M.scan_multiple_items(
        items_to_scan,
        function(item_key, result, completed, total)
            if on_progress then
                on_progress({
                    item_key = item_key,
                    completed = completed,
                    total = total,
                    progress = completed / total
                })
            end
            
            -- Analizar resultados para encontrar oportunidades
            if result.success and result.auctions then
                local item_opportunities = M.analyze_auctions_for_opportunities(
                    item_key,
                    result.auctions,
                    strategies,
                    min_score
                )
                
                for i = 1, getn(item_opportunities) do
                    tinsert(opportunities, item_opportunities[i])
                end
            end
        end,
        function(all_results)
            -- Ordenar oportunidades por score
            table.sort(opportunities, function(a, b)
                return (a.score or 0) > (b.score or 0)
            end)
            
            -- Limitar a max_items
            while getn(opportunities) > max_items do
                tremove(opportunities)
            end
            
            if on_complete then
                on_complete({
                    success = true,
                    opportunities = opportunities,
                    scanned_items = getn(items_to_scan)
                })
            end
        end
    )
end

-- Analizar auctions para encontrar oportunidades
function M.analyze_auctions_for_opportunities(item_key, auctions, strategies, min_score)
    local opportunities = {}
    
    aux.print('[ANALYZE] Analizando ' .. tostring(item_key) .. ' con ' .. getn(auctions) .. ' auctions')
    
    if not auctions or getn(auctions) == 0 then
        aux.print('[ANALYZE] No hay auctions para ' .. tostring(item_key))
        return opportunities
    end
    
    -- Obtener precio de mercado
    local market_value = history.value(item_key) or 0
    aux.print('[ANALYZE] Market value para ' .. tostring(item_key) .. ': ' .. tostring(market_value))
    
    if market_value == 0 then
        -- No hay datos históricos, no podemos evaluar
        aux.print('[ANALYZE] RECHAZADO - Sin datos históricos para ' .. tostring(item_key))
        return opportunities
    end
    
    -- Evaluar cada auction
    for i = 1, getn(auctions) do
        local auction = auctions[i]
        
        if auction.buyout_price and auction.buyout_price > 0 then
            local auction_info = {
                item_key = item_key,
                item_name = auction.name,
                buyout_price = auction.buyout_price,
                unit_buyout_price = auction.unit_buyout_price or (auction.buyout_price / auction.count),
                count = auction.count,
                market_value = market_value,
                time_left = auction.time_left,
                owner = auction.owner,
                page = auction.page,
                index = auction.index,
                auction_data = auction,
            }
            
            -- Evaluar con cada estrategia
            for j = 1, getn(strategies) do
                local strategy = strategies[j]
                local evaluation = nil
                
                if strategy == 'flipping' and M.evaluate_flipping_opportunity then
                    evaluation = M.evaluate_flipping_opportunity(auction_info)
                elseif strategy == 'sniping' and M.evaluate_sniping_opportunity then
                    evaluation = M.evaluate_sniping_opportunity(auction_info)
                elseif strategy == 'market_reset' and M.evaluate_reset_opportunity then
                    evaluation = M.evaluate_reset_opportunity(item_key)
                elseif strategy == 'arbitrage' and M.evaluate_arbitrage_opportunity then
                    -- Para arbitrage necesitamos precios de diferentes facciones/servidores
                    -- Por ahora, usamos precios históricos como aproximación
                    local market_value = history.value(item_key) or 0
                    evaluation = M.evaluate_arbitrage_opportunity(item_key, auction_info.buyout_price, market_value)
                end
                
                if evaluation and evaluation.viable and evaluation.score >= min_score then
                    aux.print('[ANALYZE] OPORTUNIDAD ENCONTRADA! Item: ' .. tostring(item_key) .. ' Score: ' .. tostring(evaluation.score))
                    tinsert(opportunities, {
                        item_key = item_key,
                        item_name = auction.name,
                        strategy = strategy,
                        score = evaluation.score,
                        buyout_price = auction.buyout_price,
                        market_value = market_value,
                        expected_profit = evaluation.expected_profit,
                        discount_percent = evaluation.discount_percent,
                        auction_data = auction,
                        evaluation = evaluation,
                    })
                elseif evaluation then
                    aux.print('[ANALYZE] Rechazado - viable: ' .. tostring(evaluation.viable) .. ' score: ' .. tostring(evaluation.score) .. ' reason: ' .. tostring(evaluation.reason))
                end
            end
        end
    end
    
    return opportunities
end

-- ============================================================================
-- Integración con Auctions Tab (nuestras subastas)
-- ============================================================================

-- Escanear nuestras subastas activas
function M.scan_our_auctions(on_complete)
    local our_auctions = T.acquire()
    
    scan.start{
        type = 'owner',
        queries = {{blizzard_query = T.acquire()}},
        on_auction = function(auction_record)
            tinsert(our_auctions, {
                item_key = auction_record.item_key,
                item_id = auction_record.item_id,
                suffix_id = auction_record.suffix_id,
                name = auction_record.name,
                count = auction_record.count,
                bid_price = auction_record.bid_price,
                buyout_price = auction_record.buyout_price,
                time_left = auction_record.time_left,
                high_bidder = auction_record.high_bidder,
                sale_status = auction_record.sale_status,
                index = auction_record.index,
            })
        end,
        on_complete = function()
            -- Actualizar cache en helpers
            if M.player_auctions_cache then
                M.player_auctions_cache = our_auctions
                M.player_auctions_timestamp = time()
            end
            
            if on_complete then
                on_complete({
                    success = true,
                    auctions = our_auctions,
                    count = getn(our_auctions)
                })
            end
        end,
        on_abort = function()
            if on_complete then
                on_complete({success = false, reason = 'scan_aborted'})
            end
        end,
    }
end

-- Detectar undercuts en nuestras subastas
function M.check_for_undercuts(on_complete)
    M.scan_our_auctions(function(our_result)
        if not our_result.success then
            if on_complete then
                on_complete({success = false, reason = 'failed_to_scan_our_auctions'})
            end
            return
        end
        
        local undercuts = {}
        local items_to_check = {}
        
        -- Agrupar nuestras subastas por item
        local our_auctions_by_item = {}
        for i = 1, getn(our_result.auctions) do
            local auction = our_result.auctions[i]
            local item_key = auction.item_key
            
            if not our_auctions_by_item[item_key] then
                our_auctions_by_item[item_key] = {}
                tinsert(items_to_check, item_key)
            end
            
            tinsert(our_auctions_by_item[item_key], auction)
        end
        
        -- Escanear cada item para ver si hay undercuts
        M.scan_multiple_items(
            items_to_check,
            nil,
            function(scan_results)
                for item_key, our_auctions in pairs(our_auctions_by_item) do
                    local market_auctions = scan_results[item_key]
                    
                    if market_auctions and market_auctions.success then
                        -- Encontrar el precio más bajo del mercado (que no sea nuestro)
                        local lowest_competitor_price = nil
                        
                        for i = 1, getn(market_auctions.auctions) do
                            local auction = market_auctions.auctions[i]
                            
                            -- Verificar que no sea nuestra subasta
                            local is_ours = false
                            for j = 1, getn(our_auctions) do
                                if our_auctions[j].index == auction.index then
                                    is_ours = true
                                    break
                                end
                            end
                            
                            if not is_ours and auction.buyout_price and auction.buyout_price > 0 then
                                if not lowest_competitor_price or auction.buyout_price < lowest_competitor_price then
                                    lowest_competitor_price = auction.buyout_price
                                end
                            end
                        end
                        
                        -- Verificar si nos hicieron undercut
                        if lowest_competitor_price then
                            for i = 1, getn(our_auctions) do
                                local our_auction = our_auctions[i]
                                
                                if our_auction.buyout_price and our_auction.buyout_price > lowest_competitor_price then
                                    tinsert(undercuts, {
                                        item_key = item_key,
                                        item_name = our_auction.name,
                                        our_price = our_auction.buyout_price,
                                        competitor_price = lowest_competitor_price,
                                        difference = our_auction.buyout_price - lowest_competitor_price,
                                        our_auction = our_auction,
                                    })
                                end
                            end
                        end
                    end
                end
                
                if on_complete then
                    on_complete({
                        success = true,
                        undercuts = undercuts,
                        count = getn(undercuts)
                    })
                end
            end
        )
    end)
end

-- ============================================================================
-- Cleanup Timer
-- ============================================================================

-- Limpiar cache cada 5 minutos
local cleanup_timer = 0
aux.event_listener('UPDATE', function()
    cleanup_timer = cleanup_timer + 1
    if cleanup_timer >= 300 then  -- 5 minutos (asumiendo 1 update/segundo)
        M.cleanup_scan_cache()
        cleanup_timer = 0
    end
end)

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    aux.print('[SCAN_INTEGRATION] Sistema de integración de scan inicializado')
end)

-- ============================================================================
-- EXPORTAR FUNCIONES AL MÓDULO
-- ============================================================================
-- Todas las funciones M.* ya están disponibles en el módulo porque usamos M = getfenv()
-- Pero vamos a asegurarnos de que las funciones principales estén accesibles

-- Verificar que las funciones están disponibles
aux.print('[SCAN_INTEGRATION] Verificando funciones exportadas...')
aux.print('[SCAN_INTEGRATION] - scan_item_for_trading: ' .. tostring(M.scan_item_for_trading ~= nil))
aux.print('[SCAN_INTEGRATION] - scan_multiple_items: ' .. tostring(M.scan_multiple_items ~= nil))
aux.print('[SCAN_INTEGRATION] - scan_for_opportunities: ' .. tostring(M.scan_for_opportunities ~= nil))
aux.print('[SCAN_INTEGRATION] - check_for_undercuts: ' .. tostring(M.check_for_undercuts ~= nil))
aux.print('[SCAN_INTEGRATION] - get_cached_scan_results: ' .. tostring(M.get_cached_scan_results ~= nil))

aux.print('[SCAN_INTEGRATION] Módulo cargado correctamente')
