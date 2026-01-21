module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'
local money = require 'aux.util.money'
local T = require 'T'
local M = getfenv()

-- ============================================================================
-- MONOPOLY SYSTEM - Sistema de Análisis y Gestión de Monopolios
-- Creado por: Elnazzareno (DarckRovert)
-- Clan: El Séquito del Terror
-- ============================================================================

aux.print('|cFFFFD700[MONOPOLY]|r Sistema de monopolios cargado')

-- ============================================================================
-- Configuración
-- ============================================================================

local MONOPOLY_CONFIG = {
    -- Umbrales para considerar monopolizable
    max_sellers_for_monopoly = 5,        -- Máximo de vendedores para considerar
    max_stock_for_easy_monopoly = 50,    -- Stock máximo para monopolio "fácil"
    min_profit_margin = 0.30,            -- Margen mínimo de ganancia (30%)
    min_demand_score = 0.5,              -- Demanda mínima (0-1)
    
    -- Pesos para el score de monopolio
    weights = {
        low_sellers = 25,      -- Pocos vendedores
        low_stock = 20,        -- Poco stock
        high_demand = 25,      -- Alta demanda
        good_margin = 15,      -- Buen margen
        low_restock = 15,      -- Baja reposición
    },
    
    -- Multiplicadores de precio de reventa sugerido
    resale_multipliers = {
        conservative = 1.30,   -- +30%
        moderate = 1.50,       -- +50%
        aggressive = 2.00,     -- +100%
        extreme = 3.00,        -- +200%
    },
    
    -- Categorías de riesgo de reposición (items por día)
    restock_risk = {
        low = 2,       -- 0-2 items/día = bajo riesgo
        medium = 5,    -- 3-5 items/día = medio riesgo
        high = 10,     -- 6-10 items/día = alto riesgo
        -- >10 = muy alto riesgo
    },
}

-- ============================================================================
-- Base de datos de monopolios activos
-- ============================================================================

-- Se guarda en SavedVariables via aux.account_data
local active_monopolies = {}
local monopoly_history = {}
local watchlist = {}
local last_scan_results = {} 
local scan_signatures = {} -- Para evitar duplicados

-- ============================================================================
-- Data Ingestion (Bridge from Scanner)
-- ============================================================================

function M.clear_scan_data()
    last_scan_results = {}
    scan_signatures = {}
end

function M.ingest_auction_record(record)
    if not record then return end
    
    -- Generar firma única para evitar duplicados en la sesión
    -- item_key + bid + buyout + count + owner + duration
    local signature = string.format("%s_%d_%d_%d_%s_%d", 
        record.item_key or "x",
        record.bid_price or 0,
        record.buyout_price or 0,
        record.count or 1,
        record.owner or "?",
        record.duration or 0
    )
    
    if scan_signatures[signature] then return end
    scan_signatures[signature] = true
    
    local entry = {
        item_key = record.item_key,
        name = record.name,
        buyout_price = record.buyout_price or record.unit_buyout_price or 0,
        count = record.count or record.aux_quantity or 1,
        owner = record.owner,
        texture = record.texture,
        quality = record.quality,
    }
    
    if entry.buyout_price > 0 then
        tinsert(last_scan_results, entry)
    end
end

function M.get_last_scan_results()
    return last_scan_results
end


function init_monopoly_data()
    if not aux.account_data then return end
    
    if not aux.account_data.monopoly then
        aux.account_data.monopoly = {
            active = {},
            history = {},
            watchlist = {},
            stats = {
                total_monopolies = 0,
                successful = 0,
                failed = 0,
                total_profit = 0,
                total_invested = 0,
            },
        }
    end
    
    active_monopolies = aux.account_data.monopoly.active
    monopoly_history = aux.account_data.monopoly.history
    watchlist = aux.account_data.monopoly.watchlist
end

-- ============================================================================
-- Funciones de Análisis de Mercado
-- ============================================================================

-- Obtener datos actuales del mercado para un item
function M.get_market_snapshot(item_key)
    local snapshot = {
        item_key = item_key,
        timestamp = time(),
        sellers = {},
        unique_sellers = 0,
        total_stock = 0,
        total_cost = 0,
        min_price = nil,
        max_price = nil,
        avg_price = 0,
        market_value = 0,
        auctions = {},
    }
    
    -- Obtener valor de mercado histórico
    if history and history.value then
        snapshot.market_value = history.value(item_key) or 0
    end
    
    -- Obtener datos de AuxTradingMarketData si existe
    if AuxTradingMarketData and AuxTradingMarketData[item_key] then
        local data = AuxTradingMarketData[item_key]
        snapshot.market_value = snapshot.market_value or data.minBuyout or 0
        snapshot.last_seen = data.lastScan
        snapshot.times_seen = data.seen or 0
    end
    
    return snapshot
end

-- Analizar oportunidad de monopolio
function M.analyze_monopoly_opportunity(item_key, auctions)
    local analysis = {
        item_key = item_key,
        timestamp = time(),
        is_monopolizable = false,
        score = 0,
        
        -- Datos del mercado
        unique_sellers = 0,
        total_stock = 0,
        total_buyout_cost = 0,
        avg_price = 0,
        min_price = 0,
        max_price = 0,
        market_value = 0,
        
        -- Análisis
        suggested_resale_price = 0,
        potential_profit = 0,
        profit_margin = 0,
        restock_risk = 'unknown',
        demand_score = 0,
        
        -- Desglose del score
        score_breakdown = {
            low_sellers = 0,
            low_stock = 0,
            high_demand = 0,
            good_margin = 0,
            low_restock = 0,
        },
        
        -- Recomendación
        recommendation = '',
        warnings = {},
    }
    
    -- Si no hay auctions, usar datos del snapshot
    if not auctions or getn(auctions) == 0 then
        analysis.recommendation = 'Sin datos de subastas. Haz un scan primero.'
        return analysis
    end
    
    -- Procesar auctions
    local sellers = T.acquire()
    local total_cost = 0
    local total_quantity = 0
    local prices = T.acquire()
    
    for i = 1, getn(auctions) do
        local auction = auctions[i]
        local seller = auction.owner or 'unknown'
        local buyout = auction.buyout_price or auction.buyout or 0
        local quantity = auction.aux_quantity or auction.count or 1
        
        if buyout > 0 then
            -- Contar vendedores únicos
            if not sellers[seller] then
                sellers[seller] = true
                analysis.unique_sellers = analysis.unique_sellers + 1
            end
            
            -- Acumular stock y costo
            total_quantity = total_quantity + quantity
            total_cost = total_cost + buyout
            
            -- Precio por unidad
            local unit_price = buyout / quantity
            tinsert(prices, unit_price)
            
            -- Min/Max
            if not analysis.min_price or unit_price < analysis.min_price then
                analysis.min_price = unit_price
            end
            if not analysis.max_price or unit_price > analysis.max_price then
                analysis.max_price = unit_price
            end
        end
    end
    
    analysis.total_stock = total_quantity
    analysis.total_buyout_cost = total_cost
    
    -- Calcular precio promedio
    if getn(prices) > 0 then
        local sum = 0
        for i = 1, getn(prices) do
            sum = sum + prices[i]
        end
        analysis.avg_price = sum / getn(prices)
    end
    
    T.release(sellers)
    T.release(prices)
    
    -- Obtener valor de mercado histórico
    if history and history.value then
        analysis.market_value = history.value(item_key) or analysis.avg_price
    else
        analysis.market_value = analysis.avg_price
    end
    
    -- ========================================
    -- CALCULAR SCORES
    -- ========================================
    
    local weights = MONOPOLY_CONFIG.weights
    local total_score = 0
    
    -- 1. Score por pocos vendedores (0-25 puntos)
    if analysis.unique_sellers <= 1 then
        analysis.score_breakdown.low_sellers = weights.low_sellers
    elseif analysis.unique_sellers <= 3 then
        analysis.score_breakdown.low_sellers = weights.low_sellers * 0.8
    elseif analysis.unique_sellers <= 5 then
        analysis.score_breakdown.low_sellers = weights.low_sellers * 0.5
    elseif analysis.unique_sellers <= 10 then
        analysis.score_breakdown.low_sellers = weights.low_sellers * 0.2
    else
        analysis.score_breakdown.low_sellers = 0
    end
    total_score = total_score + analysis.score_breakdown.low_sellers
    
    -- 2. Score por poco stock (0-20 puntos)
    if analysis.total_stock <= 5 then
        analysis.score_breakdown.low_stock = weights.low_stock
    elseif analysis.total_stock <= 20 then
        analysis.score_breakdown.low_stock = weights.low_stock * 0.7
    elseif analysis.total_stock <= 50 then
        analysis.score_breakdown.low_stock = weights.low_stock * 0.4
    else
        analysis.score_breakdown.low_stock = weights.low_stock * 0.1
    end
    total_score = total_score + analysis.score_breakdown.low_stock
    
    -- 3. Score por demanda (0-25 puntos)
    -- Basado en datos históricos de ventas
    local demand_score = 0
    if AuxTradingMarketData and AuxTradingMarketData[item_key] then
        local data = AuxTradingMarketData[item_key]
        local times_seen = data.seen or 0
        
        -- Más veces visto = más demanda
        if times_seen > 100 then
            demand_score = 1.0
        elseif times_seen > 50 then
            demand_score = 0.8
        elseif times_seen > 20 then
            demand_score = 0.6
        elseif times_seen > 10 then
            demand_score = 0.4
        else
            demand_score = 0.2
        end
    else
        demand_score = 0.5  -- Valor por defecto
    end
    analysis.demand_score = demand_score
    analysis.score_breakdown.high_demand = weights.high_demand * demand_score
    total_score = total_score + analysis.score_breakdown.high_demand
    
    -- 4. Score por margen de ganancia (0-15 puntos)
    -- Calcular precio de reventa sugerido
    local resale_multiplier = MONOPOLY_CONFIG.resale_multipliers.moderate
    analysis.suggested_resale_price = analysis.avg_price * resale_multiplier
    
    -- Si el market value es mayor, usar ese como referencia
    if analysis.market_value > analysis.avg_price * 1.2 then
        analysis.suggested_resale_price = analysis.market_value * 0.95
    end
    
    -- Calcular ganancia potencial
    analysis.potential_profit = (analysis.suggested_resale_price * analysis.total_stock) - analysis.total_buyout_cost
    
    if analysis.total_buyout_cost > 0 then
        analysis.profit_margin = analysis.potential_profit / analysis.total_buyout_cost
    end
    
    if analysis.profit_margin >= 1.0 then
        analysis.score_breakdown.good_margin = weights.good_margin
    elseif analysis.profit_margin >= 0.5 then
        analysis.score_breakdown.good_margin = weights.good_margin * 0.7
    elseif analysis.profit_margin >= 0.3 then
        analysis.score_breakdown.good_margin = weights.good_margin * 0.4
    else
        analysis.score_breakdown.good_margin = 0
    end
    total_score = total_score + analysis.score_breakdown.good_margin
    
    -- 5. Score por riesgo de reposición (0-15 puntos)
    -- Estimar basado en frecuencia de aparición
    local restock_rate = 5  -- Por defecto medio
    if AuxTradingMarketData and AuxTradingMarketData[item_key] then
        local data = AuxTradingMarketData[item_key]
        if data.lastScan and data.seen then
            -- Calcular tasa aproximada
            local days_tracked = math.max(1, (time() - (data.lastScan - 86400 * 14)) / 86400)
            restock_rate = (data.seen or 0) / days_tracked
        end
    end
    
    if restock_rate <= MONOPOLY_CONFIG.restock_risk.low then
        analysis.restock_risk = 'BAJO'
        analysis.score_breakdown.low_restock = weights.low_restock
    elseif restock_rate <= MONOPOLY_CONFIG.restock_risk.medium then
        analysis.restock_risk = 'MEDIO'
        analysis.score_breakdown.low_restock = weights.low_restock * 0.6
    elseif restock_rate <= MONOPOLY_CONFIG.restock_risk.high then
        analysis.restock_risk = 'ALTO'
        analysis.score_breakdown.low_restock = weights.low_restock * 0.3
    else
        analysis.restock_risk = 'MUY ALTO'
        analysis.score_breakdown.low_restock = 0
    end
    total_score = total_score + analysis.score_breakdown.low_restock
    
    -- ========================================
    -- SCORE FINAL Y RECOMENDACIÓN
    -- ========================================
    
    analysis.score = math.floor(total_score)
    
    -- Determinar si es monopolizable
    if analysis.score >= 70 then
        analysis.is_monopolizable = true
        analysis.recommendation = '|cFF00FF00EXCELENTE|r - Oportunidad de monopolio ideal'
    elseif analysis.score >= 50 then
        analysis.is_monopolizable = true
        analysis.recommendation = '|cFF88FF00BUENO|r - Buena oportunidad, proceder con cuidado'
    elseif analysis.score >= 35 then
        analysis.is_monopolizable = false
        analysis.recommendation = '|cFFFFFF00REGULAR|r - Riesgo moderado, evaluar bien'
    else
        analysis.is_monopolizable = false
        analysis.recommendation = '|cFFFF4444NO RECOMENDADO|r - Alto riesgo o bajo potencial'
    end
    
    -- Agregar warnings
    if analysis.unique_sellers > 5 then
        tinsert(analysis.warnings, 'Muchos vendedores - difícil mantener monopolio')
    end
    if analysis.total_stock > 50 then
        tinsert(analysis.warnings, 'Stock alto - requiere mucha inversión')
    end
    if analysis.restock_risk == 'ALTO' or analysis.restock_risk == 'MUY ALTO' then
        tinsert(analysis.warnings, 'Alta reposición - monopolio difícil de mantener')
    end
    if analysis.profit_margin < 0.3 then
        tinsert(analysis.warnings, 'Margen bajo - ganancia limitada')
    end
    
    return analysis
end

-- ============================================================================
-- Buscar Candidatos para Monopolio
-- ============================================================================

function M.find_monopoly_candidates(scan_results, min_score)
    min_score = min_score or 50
    local candidates = {}
    
    if not scan_results then
        aux.print('|cFFFF0000[MONOPOLY]|r No hay resultados de scan. Haz un Full Scan primero.')
        return candidates
    end
    
    -- Agrupar auctions por item_key
    local items = {}
    for i = 1, getn(scan_results) do
        local auction = scan_results[i]
        local item_key = auction.item_key
        
        if item_key then
            if not items[item_key] then
                items[item_key] = {
                    auctions = {},
                    name = auction.name or 'Unknown',
                    texture = auction.texture, -- Capturar textura
                }
            end
            -- Si no teníamos textura pero ahora sí (e.g. primer registro corrupto), actualizar
            if not items[item_key].texture and auction.texture then
                items[item_key].texture = auction.texture
            end
            tinsert(items[item_key].auctions, auction)
        end
    end
    
    -- Analizar cada item
    for item_key, item_data in pairs(items) do
        local analysis = M.analyze_monopoly_opportunity(item_key, item_data.auctions)
        analysis.item_name = item_data.name
        analysis.texture = item_data.texture -- Pasar textura al análisis
        
        if analysis.score >= min_score then
            tinsert(candidates, analysis)
        end
    end
    
    -- Ordenar por score (mayor primero)
    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)
    
    aux.print(string.format('|cFFFFD700[MONOPOLY]|r Encontrados %d candidatos con score >= %d', getn(candidates), min_score))
    
    return candidates
end

-- ============================================================================
-- Gestión de Monopolios Activos
-- ============================================================================

-- Iniciar tracking de un monopolio
function M.start_monopoly(item_key, item_name, investment, quantity, target_price)
    init_monopoly_data()
    
    local monopoly = {
        item_key = item_key,
        item_name = item_name or 'Unknown',
        started_at = time(),
        investment = investment or 0,
        quantity_bought = quantity or 0,
        target_price = target_price or 0,
        quantity_sold = 0,
        revenue = 0,
        status = 'active',
        notes = {},
    }
    
    active_monopolies[item_key] = monopoly
    
    aux.print(string.format('|cFF00FF00[MONOPOLY]|r Iniciado monopolio de %s', item_name or item_key))
    aux.print(string.format('  Inversión: %s | Cantidad: %d | Precio objetivo: %s', 
        M.format_gold(investment), quantity, M.format_gold(target_price)))
    
    return monopoly
end

-- Registrar venta de monopolio
function M.record_monopoly_sale(item_key, quantity, price)
    init_monopoly_data()
    
    local monopoly = active_monopolies[item_key]
    if not monopoly then
        aux.print('|cFFFF0000[MONOPOLY]|r No hay monopolio activo para este item')
        return false
    end
    
    monopoly.quantity_sold = monopoly.quantity_sold + quantity
    monopoly.revenue = monopoly.revenue + price
    
    -- Verificar si se completó
    if monopoly.quantity_sold >= monopoly.quantity_bought then
        M.complete_monopoly(item_key, true)
    end
    
    return true
end

-- Completar/Cerrar monopolio
function M.complete_monopoly(item_key, success)
    init_monopoly_data()
    
    local monopoly = active_monopolies[item_key]
    if not monopoly then return false end
    
    monopoly.ended_at = time()
    monopoly.status = success and 'completed' or 'failed'
    monopoly.profit = monopoly.revenue - monopoly.investment
    monopoly.roi = monopoly.investment > 0 and (monopoly.profit / monopoly.investment) or 0
    
    -- Mover a historial
    tinsert(monopoly_history, monopoly)
    active_monopolies[item_key] = nil
    
    -- Actualizar stats
    local stats = aux.account_data.monopoly.stats
    stats.total_monopolies = stats.total_monopolies + 1
    if success then
        stats.successful = stats.successful + 1
    else
        stats.failed = stats.failed + 1
    end
    stats.total_profit = stats.total_profit + monopoly.profit
    stats.total_invested = stats.total_invested + monopoly.investment
    
    local status_text = success and '|cFF00FF00COMPLETADO|r' or '|cFFFF4444FALLIDO|r'
    aux.print(string.format('|cFFFFD700[MONOPOLY]|r %s - %s', monopoly.item_name, status_text))
    aux.print(string.format('  Profit: %s | ROI: %.1f%%', M.format_gold(monopoly.profit), monopoly.roi * 100))
    
    return true
end

-- ============================================================================
-- Watchlist
-- ============================================================================

function M.add_to_watchlist(item_key, item_name, notes)
    init_monopoly_data()
    
    watchlist[item_key] = {
        item_key = item_key,
        item_name = item_name or 'Unknown',
        added_at = time(),
        notes = notes or '',
        last_analysis = nil,
    }
    
    aux.print(string.format('|cFF00FF00[MONOPOLY]|r %s agregado a watchlist', item_name or item_key))
    return true
end

function M.remove_from_watchlist(item_key)
    init_monopoly_data()
    
    if watchlist[item_key] then
        local name = watchlist[item_key].item_name
        watchlist[item_key] = nil
        aux.print(string.format('|cFFFFAA00[MONOPOLY]|r %s removido de watchlist', name))
        return true
    end
    return false
end

function M.get_watchlist()
    init_monopoly_data()
    return watchlist
end

-- ============================================================================
-- Utilidades
-- ============================================================================

function M.format_gold(copper)
    return money.to_string(copper or 0, nil, nil, nil, true)
end

function M.get_monopoly_stats()
    init_monopoly_data()
    return aux.account_data.monopoly.stats
end

function M.get_active_monopolies()
    init_monopoly_data()
    return active_monopolies
end

function M.get_monopoly_history()
    init_monopoly_data()
    return monopoly_history
end

-- ============================================================================
-- Imprimir análisis en chat
-- ============================================================================

function M.print_monopoly_analysis(analysis)
    if not analysis then return end
    
    aux.print('|cFFFFD700========== ANÁLISIS DE MONOPOLIO ==========|r')
    aux.print(string.format('Item: |cFFFFFFFF%s|r', analysis.item_name or analysis.item_key))
    aux.print(string.format('Score: |cFFFFD700%d/100|r %s', analysis.score, 
        analysis.score >= 70 and '⭐⭐⭐⭐' or 
        analysis.score >= 50 and '⭐⭐⭐' or 
        analysis.score >= 35 and '⭐⭐' or '⭐'))
    aux.print('')
    aux.print(string.format('Vendedores: |cFFFFFFFF%d|r', analysis.unique_sellers))
    aux.print(string.format('Stock total: |cFFFFFFFF%d|r unidades', analysis.total_stock))
    aux.print(string.format('Costo para comprar TODO: |cFFFFD700%s|r', M.format_gold(analysis.total_buyout_cost)))
    aux.print(string.format('Precio promedio: |cFFFFFFFF%s|r', M.format_gold(analysis.avg_price)))
    aux.print(string.format('Precio reventa sugerido: |cFF00FF00%s|r (+%.0f%%)', 
        M.format_gold(analysis.suggested_resale_price), analysis.profit_margin * 100))
    aux.print(string.format('Ganancia potencial: |cFF00FF00%s|r', M.format_gold(analysis.potential_profit)))
    aux.print(string.format('Riesgo reposición: %s', 
        analysis.restock_risk == 'BAJO' and '|cFF00FF00BAJO|r' or
        analysis.restock_risk == 'MEDIO' and '|cFFFFFF00MEDIO|r' or
        '|cFFFF4444' .. analysis.restock_risk .. '|r'))
    aux.print('')
    aux.print(string.format('Recomendación: %s', analysis.recommendation))
    
    if getn(analysis.warnings) > 0 then
        aux.print('|cFFFF4444Advertencias:|r')
        for i = 1, getn(analysis.warnings) do
            aux.print('  • ' .. analysis.warnings[i])
        end
    end
    
    aux.print('|cFFFFD700=============================================|r')
end

-- ============================================================================
-- Inicialización
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_monopoly_data()
    aux.print('|cFF00FF00[MONOPOLY]|r Sistema de monopolios inicializado')
end)

-- ============================================================================
-- Registrar módulo
-- ============================================================================

if not M.modules then M.modules = {} end
M.modules.monopoly = {
    analyze = M.analyze_monopoly_opportunity,
    find_candidates = M.find_monopoly_candidates,
    start = M.start_monopoly,
    record_sale = M.record_monopoly_sale,
    complete = M.complete_monopoly,
    add_to_watchlist = M.add_to_watchlist,
    remove_from_watchlist = M.remove_from_watchlist,
    get_watchlist = M.get_watchlist,
    get_stats = M.get_monopoly_stats,
    get_active = M.get_active_monopolies,
    get_history = M.get_monopoly_history,
    print_analysis = M.print_monopoly_analysis,
}

aux.print('|cFFFFD700[MONOPOLY]|r Módulo registrado correctamente')
