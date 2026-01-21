module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'

-- ============================================================================
-- Trading Strategies - Estrategias de Trading Profesionales
-- ============================================================================

aux.print('[STRATEGIES] Módulo de estrategias cargado')

-- ============================================================================
-- Strategy: Flipping (Comprar barato, vender caro)
-- ============================================================================

local flipping_config = {
    min_profit_margin = 0.15,  -- 15% mínimo de margen
    max_hold_time = 7 * 24 * 60 * 60,  -- 7 días
    preferred_categories = {
        'Materials',
        'Consumables',
        'Trade Goods',
    },
    max_investment_per_item = 50000,  -- 5g máximo por item
    target_roi = 0.25,  -- 25% ROI objetivo
}

function evaluate_flipping_opportunity(auction_info)
    -- FIX: Validación de entrada
    if not auction_info then
        return {
            viable = false,
            reason = 'nil_auction_info',
            score = 0,
        }
    end
    
    if not auction_info.item_key then
        return {
            viable = false,
            reason = 'missing_item_key',
            score = 0,
        }
    end
    
    -- Obtener precio histórico
    local market_value = history.value(auction_info.item_key)
    aux.print('[FLIPPING] Item: ' .. tostring(auction_info.item_key) .. ' Market value: ' .. tostring(market_value))
    
    if not market_value or market_value == 0 then
        aux.print('[FLIPPING] RECHAZADO - no_market_data para ' .. tostring(auction_info.item_key))
        return {
            viable = false,
            reason = 'no_market_data',
            score = 0,
        }
    end
    
    local buyout = auction_info.buyout_price or 0
    if buyout == 0 then
        return {
            viable = false,
            reason = 'no_buyout',
            score = 0,
        }
    end
    
    -- Calcular margen de ganancia (considerando AH cut de 5%)
    local sell_price = market_value * 0.95  -- Después del corte de AH
    local profit = sell_price - buyout
    -- Prevenir división por cero
    local profit_margin = buyout > 0 and (profit / buyout) or 0
    
    -- Verificar si cumple criterios mínimos
    if profit_margin < flipping_config.min_profit_margin then
        return {
            viable = false,
            reason = 'low_profit_margin',
            score = 0,
            profit_margin = profit_margin,
        }
    end
    
    if buyout > flipping_config.max_investment_per_item then
        return {
            viable = false,
            reason = 'too_expensive',
            score = 0,
        }
    end
    
    -- Calcular score basado en múltiples factores
    local score = 0
    
    -- Factor 1: Margen de ganancia (0-40 puntos)
    score = score + math.min(40, profit_margin * 100)
    
    -- Factor 2: ROI (0-30 puntos)
    -- Prevenir división por cero
    local roi = buyout > 0 and (profit / buyout) or 0
    score = score + math.min(30, roi * 60)
    
    -- Factor 3: Velocidad de venta estimada (0-20 puntos)
    local avg_volume = (M.get_average_daily_volume and M.get_average_daily_volume(auction_info.item_key, 7)) or 0
    if avg_volume > 10 then
        score = score + 20
    elseif avg_volume > 5 then
        score = score + 15
    elseif avg_volume > 2 then
        score = score + 10
    elseif avg_volume > 0 then
        score = score + 5
    end
    
    -- Factor 4: Estabilidad de precio (0-10 puntos)
    local manipulation = (M.detect_market_manipulation and M.detect_market_manipulation(auction_info.item_key)) or {is_manipulated = false}
    if not manipulation.is_manipulated then
        score = score + 10
    elseif manipulation.confidence < 0.5 then
        score = score + 5
    end
    
    -- Calcular precio de reventa recomendado
    local recommended_sell_price = market_value * 0.98  -- Ligeramente por debajo del mercado
    local expected_profit = (recommended_sell_price * 0.95) - buyout
    
    return {
        viable = true,
        score = score,
        strategy = 'flipping',
        buy_price = buyout,
        recommended_sell_price = recommended_sell_price,
        expected_profit = expected_profit,
        profit_margin = profit_margin,
        roi = roi,
        market_value = market_value,
        estimated_sell_time = (M.estimate_sell_time and M.estimate_sell_time(auction_info.item_key)) or 0,
    }
end

-- ============================================================================
-- Strategy: Sniping (Comprar items muy baratos rápidamente)
-- ============================================================================

local sniping_config = {
    min_discount = 0.40,  -- 40% descuento mínimo
    max_response_time = 5,  -- 5 segundos para actuar
    auto_buy = false,
    max_price = 100000,  -- 10g máximo
    confidence_threshold = 0.7,
}

function evaluate_sniping_opportunity(auction_info)
    -- FIX: Validación de entrada
    if not auction_info then
        return {
            viable = false,
            reason = 'nil_auction_info',
            score = 0,
        }
    end
    
    if not auction_info.item_key then
        return {
            viable = false,
            reason = 'missing_item_key',
            score = 0,
        }
    end
    
    local market_value = history.value(auction_info.item_key)
    if not market_value or market_value == 0 then
        return {
            viable = false,
            reason = 'no_market_data',
            score = 0,
        }
    end
    
    local buyout = auction_info.buyout_price or 0
    if buyout == 0 or buyout > sniping_config.max_price then
        return {
            viable = false,
            reason = 'invalid_price',
            score = 0,
        }
    end
    
    -- Calcular descuento
    local discount = (market_value - buyout) / market_value
    
    if discount < sniping_config.min_discount then
        return {
            viable = false,
            reason = 'insufficient_discount',
            score = 0,
            discount = discount,
        }
    end
    
    -- Verificar confianza en datos de mercado
    local profile = get_profile(auction_info.item_key)
    local confidence = 0
    if profile and profile.confidence then
        if type(profile.confidence) == 'number' then
            confidence = profile.confidence
        elseif type(profile.confidence) == 'table' and profile.confidence.score then
            confidence = profile.confidence.score
        end
    end
    
    if confidence < sniping_config.confidence_threshold then
        return {
            viable = false,
            reason = 'low_confidence',
            score = 0,
            confidence = confidence,
        }
    end
    
    -- Calcular score (sniping prioriza descuento y velocidad)
    local score = 0
    
    -- Factor 1: Descuento (0-60 puntos)
    score = score + math.min(60, discount * 100)
    
    -- Factor 2: Confianza (0-20 puntos)
    score = score + (confidence * 20)
    
    -- Factor 3: Profit absoluto (0-20 puntos)
    local profit = (market_value * 0.95 - buyout) * auction_info.count
    score = score + math.min(20, profit / 5000)  -- 1g = 1 punto
    
    return {
        viable = true,
        score = score,
        strategy = 'sniping',
        buy_price = buyout,
        market_value = market_value,
        discount = discount,
        expected_profit = profit,
        confidence = confidence,
        urgency = 'high',  -- Sniping requiere acción rápida
        auto_buy_recommended = score > 80,
    }
end

-- ============================================================================
-- Strategy: Market Reset (Comprar todo y revender más caro)
-- ============================================================================

local reset_config = {
    min_market_share = 0.70,  -- Controlar 70% del mercado
    max_total_investment = 500000,  -- 50g máximo total
    min_markup = 0.30,  -- 30% markup mínimo
    preferred_items = {
        -- Items con bajo volumen pero alta demanda
        'rare_materials',
        'enchanting_materials',
        'rare_recipes',
    },
}

function evaluate_reset_opportunity(item_key)
    -- Obtener todas las subastas del item
    local auctions = (M.get_all_auctions_for_item and M.get_all_auctions_for_item(item_key)) or {}
    
    if not auctions or getn(auctions) == 0 then
        return {
            viable = false,
            reason = 'no_auctions',
            score = 0,
        }
    end
    
    -- Calcular costo total de comprar todo
    local total_cost = 0
    local total_quantity = 0
    local auction_count = getn(auctions)
    
    for i = 1, auction_count do
        local auction = auctions[i]
        if auction.buyout_price and auction.buyout_price > 0 then
            total_cost = total_cost + auction.buyout_price
            total_quantity = total_quantity + (auction.count or 1)
        end
    end
    
    if total_cost > reset_config.max_total_investment then
        return {
            viable = false,
            reason = 'too_expensive',
            score = 0,
            total_cost = total_cost,
        }
    end
    
    -- Obtener precio histórico
    local market_value = history.value(item_key)
    if not market_value or market_value == 0 then
        return {
            viable = false,
            reason = 'no_market_data',
            score = 0,
        }
    end
    
    -- Calcular precio promedio de compra
    local avg_buy_price = total_cost / total_quantity
    
    -- Calcular precio de reventa objetivo (markup)
    local target_sell_price = avg_buy_price * (1 + reset_config.min_markup)
    
    -- Verificar si el precio objetivo es razonable
    if target_sell_price > market_value * 1.5 then
        return {
            viable = false,
            reason = 'unrealistic_markup',
            score = 0,
        }
    end
    
    -- Calcular profit potencial
    local revenue = target_sell_price * 0.95 * total_quantity  -- Después de AH cut
    local profit = revenue - total_cost
    -- Prevenir división por cero
    local roi = total_cost > 0 and (profit / total_cost) or 0
    
    if roi < 0.20 then  -- ROI mínimo 20%
        return {
            viable = false,
            reason = 'low_roi',
            score = 0,
            roi = roi,
        }
    end
    
    -- Calcular score
    local score = 0
    
    -- Factor 1: ROI (0-40 puntos)
    score = score + math.min(40, roi * 100)
    
    -- Factor 2: Profit absoluto (0-30 puntos)
    score = score + math.min(30, profit / 10000)  -- 1g = 1 punto
    
    -- Factor 3: Control de mercado (0-20 puntos)
    local market_share = auction_count / (auction_count + 5)  -- Estimado
    score = score + (market_share * 20)
    
    -- Factor 4: Bajo volumen (mejor para reset) (0-10 puntos)
    local avg_volume = (M.get_average_daily_volume and M.get_average_daily_volume(item_key, 7)) or 0
    if avg_volume < 5 then
        score = score + 10
    elseif avg_volume < 10 then
        score = score + 5
    end
    
    return {
        viable = true,
        score = score,
        strategy = 'market_reset',
        total_cost = total_cost,
        total_quantity = total_quantity,
        auction_count = auction_count,
        avg_buy_price = avg_buy_price,
        target_sell_price = target_sell_price,
        expected_profit = profit,
        roi = roi,
        market_value = market_value,
        risk_level = 'high',  -- Market reset es riesgoso
    }
end

-- ============================================================================
-- Strategy: Arbitrage (Diferencias entre facciones/servidores)
-- ============================================================================

local arbitrage_config = {
    min_price_difference = 0.20,  -- 20% diferencia mínima
    transfer_cost = 0,  -- Costo de transferencia (si aplica)
    max_investment = 100000,  -- 10g máximo
}

function evaluate_arbitrage_opportunity(item_key, faction_a_price, faction_b_price)
    if not faction_a_price or not faction_b_price then
        return {
            viable = false,
            reason = 'missing_prices',
            score = 0,
        }
    end
    
    -- Calcular diferencia de precio
    local price_diff = math.abs(faction_a_price - faction_b_price)
    local lower_price = math.min(faction_a_price, faction_b_price)
    local higher_price = math.max(faction_a_price, faction_b_price)
    
    local price_difference_pct = price_diff / lower_price
    
    if price_difference_pct < arbitrage_config.min_price_difference then
        return {
            viable = false,
            reason = 'insufficient_difference',
            score = 0,
            difference = price_difference_pct,
        }
    end
    
    -- Calcular profit (considerando AH cut y costos de transferencia)
    local buy_price = lower_price
    local sell_price = higher_price * 0.95  -- AH cut
    local profit = sell_price - buy_price - arbitrage_config.transfer_cost
    local roi = profit / buy_price
    
    if profit <= 0 then
        return {
            viable = false,
            reason = 'no_profit',
            score = 0,
        }
    end
    
    -- Calcular score
    local score = 0
    
    -- Factor 1: Diferencia de precio (0-50 puntos)
    score = score + math.min(50, price_difference_pct * 100)
    
    -- Factor 2: ROI (0-30 puntos)
    score = score + math.min(30, roi * 60)
    
    -- Factor 3: Profit absoluto (0-20 puntos)
    score = score + math.min(20, profit / 5000)
    
    return {
        viable = true,
        score = score,
        strategy = 'arbitrage',
        buy_price = buy_price,
        sell_price = higher_price,
        expected_profit = profit,
        roi = roi,
        price_difference = price_difference_pct,
        buy_faction = faction_a_price < faction_b_price and 'A' or 'B',
        sell_faction = faction_a_price < faction_b_price and 'B' or 'A',
    }
end

-- ============================================================================
-- Risk Management
-- ============================================================================

local risk_config = {
    max_portfolio_value = 1000000,  -- 100g máximo en inventario
    max_per_item_pct = 0.20,  -- 20% máximo en un solo item
    max_per_category_pct = 0.40,  -- 40% máximo en una categoría
    diversification_bonus = 1.1,  -- Bonus por diversificar
}

function calculate_portfolio_risk()
    -- Obtener todos los trades activos
    local active_trades = get_active_trades()
    
    if not active_trades or getn(active_trades) == 0 then
        return {
            total_value = 0,
            risk_level = 'none',
            diversification = 1.0,
            recommendations = {},
        }
    end
    
    -- Calcular valor total
    local total_value = 0
    local item_values = {}
    local category_values = {}
    
    for i = 1, getn(active_trades) do
        local trade = active_trades[i]
        local value = trade.buy_price or 0
        
        total_value = total_value + value
        
        -- Por item
        local item_key = trade.item_key
        item_values[item_key] = (item_values[item_key] or 0) + value
        
        -- Por categoría (simplificado)
        local category = (M.get_item_category and M.get_item_category(item_key)) or 'unknown'
        category_values[category] = (category_values[category] or 0) + value
    end
    
    -- Calcular concentración
    local max_item_pct = 0
    local max_category_pct = 0
    
    for item_key, value in pairs(item_values) do
        local pct = value / total_value
        if pct > max_item_pct then
            max_item_pct = pct
        end
    end
    
    for category, value in pairs(category_values) do
        local pct = value / total_value
        if pct > max_category_pct then
            max_category_pct = pct
        end
    end
    
    -- Determinar nivel de riesgo
    local risk_level = 'low'
    local recommendations = {}
    
    if total_value > risk_config.max_portfolio_value then
        risk_level = 'high'
        tinsert(recommendations, 'Reducir valor total del portfolio')
    end
    
    if max_item_pct > risk_config.max_per_item_pct then
        risk_level = 'medium'
        tinsert(recommendations, 'Demasiada concentración en un item')
    end
    
    if max_category_pct > risk_config.max_per_category_pct then
        risk_level = 'medium'
        tinsert(recommendations, 'Demasiada concentración en una categoría')
    end
    
    -- Calcular diversificación (1.0 = perfecta, 0.0 = todo en un item)
    local unique_items = 0
    for _ in pairs(item_values) do
        unique_items = unique_items + 1
    end
    
    local diversification = math.min(1.0, unique_items / 10)
    
    return {
        total_value = total_value,
        risk_level = risk_level,
        diversification = diversification,
        max_item_concentration = max_item_pct,
        max_category_concentration = max_category_pct,
        unique_items = unique_items,
        recommendations = recommendations,
    }
end

function should_invest(item_key, amount)
    local portfolio_risk = calculate_portfolio_risk()
    
    -- Verificar límite total
    if portfolio_risk.total_value + amount > risk_config.max_portfolio_value then
        return false, 'portfolio_limit_exceeded'
    end
    
    -- Verificar concentración por item
    local item_value = get_item_portfolio_value(item_key)
    local new_item_pct = (item_value + amount) / (portfolio_risk.total_value + amount)
    
    if new_item_pct > risk_config.max_per_item_pct then
        return false, 'item_concentration_too_high'
    end
    
    return true, 'ok'
end

-- ============================================================================
-- Strategy Selector
-- ============================================================================

function select_best_strategy(auction_info)
    local strategies = {}
    
    -- Evaluar todas las estrategias
    local flipping = evaluate_flipping_opportunity(auction_info)
    if flipping.viable then
        tinsert(strategies, flipping)
    end
    
    local sniping = evaluate_sniping_opportunity(auction_info)
    if sniping.viable then
        tinsert(strategies, sniping)
    end
    
    -- Market reset requiere análisis más complejo
    -- Solo evaluar si hay señales de oportunidad
    if flipping.viable and flipping.score > 60 then
        local reset = evaluate_reset_opportunity(auction_info.item_key)
        if reset.viable then
            tinsert(strategies, reset)
        end
    end
    
    -- Si no hay estrategias viables
    if getn(strategies) == 0 then
        return {
            viable = false,
            reason = 'no_viable_strategy',
            score = 0,
        }
    end
    
    -- Ordenar por score
    table.sort(strategies, function(a, b)
        return a.score > b.score
    end)
    
    -- Retornar la mejor estrategia
    local best = strategies[1]
    best.alternatives = {}
    
    for i = 2, math.min(3, getn(strategies)) do
        tinsert(best.alternatives, strategies[i])
    end
    
    return best
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function estimate_sell_time(item_key)
    local avg_volume = (M.get_average_daily_volume and M.get_average_daily_volume(item_key, 7)) or 0
    
    if avg_volume >= 10 then
        return '< 1 día'
    elseif avg_volume >= 5 then
        return '1-2 días'
    elseif avg_volume >= 2 then
        return '2-5 días'
    elseif avg_volume >= 1 then
        return '5-7 días'
    else
        return '> 7 días'
    end
end

-- Obtener perfil de item (datos de mercado y confianza)
function get_profile(item_key)
    if not item_key then
        return nil
    end
    
    -- Obtener datos de mercado
    local market_value = history.value(item_key)
    local daily_value = history.daily_value and history.daily_value(item_key) or market_value
    
    if not market_value or market_value == 0 then
        return {
            item_key = item_key,
            has_data = false,
            confidence = 0,
        }
    end
    
    -- Calcular confianza basada en cantidad de datos históricos
    local sample_count = 0
    if history.item_data and history.item_data(item_key) then
        local item_data = history.item_data(item_key)
        sample_count = item_data.sample_count or 0
    end
    
    -- Confianza: 0.0 a 1.0 basada en muestras
    -- 1-5 muestras = baja confianza (0.2-0.4)
    -- 6-20 muestras = media confianza (0.5-0.7)
    -- 21+ muestras = alta confianza (0.8-1.0)
    local confidence = 0
    if sample_count >= 21 then
        confidence = math.min(1.0, 0.8 + (sample_count - 21) / 100)
    elseif sample_count >= 6 then
        confidence = 0.5 + ((sample_count - 6) / 14) * 0.2
    elseif sample_count >= 1 then
        confidence = 0.2 + ((sample_count - 1) / 4) * 0.2
    end
    
    return {
        item_key = item_key,
        has_data = true,
        market_value = market_value,
        daily_value = daily_value,
        sample_count = sample_count,
        confidence = confidence,
    }
end

-- Obtener recomendación de estrategia para un item
function get_strategy_recommendation(item_key)
    if not item_key then
        return {
            recommended = 'none',
            reason = 'invalid_item',
            confidence = 0,
        }
    end
    
    -- Obtener perfil del item
    local profile = get_profile(item_key)
    if not profile or not profile.has_data then
        return {
            recommended = 'none',
            reason = 'no_market_data',
            confidence = 0,
        }
    end
    
    -- Obtener análisis de mercado
    local trend = nil
    if M.calculate_price_trend then
        trend = M.calculate_price_trend(item_key, 7)
    end
    
    local volume = (M.get_average_daily_volume and M.get_average_daily_volume(item_key, 7)) or 0
    
    -- Determinar mejor estrategia
    local recommended = 'flipping'  -- Por defecto
    local reason = 'general_trading'
    local confidence = profile.confidence
    
    -- Si el precio está cayendo y hay bajo volumen = oportunidad de snipe
    if trend and trend.trend == 'falling' and volume < 5 then
        recommended = 'sniping'
        reason = 'falling_price_low_volume'
        confidence = confidence * 0.9
    
    -- Si hay alto volumen y precio estable = buen para flipping
    elseif volume >= 10 and trend and trend.trend == 'stable' then
        recommended = 'flipping'
        reason = 'high_volume_stable_price'
        confidence = confidence * 1.1
    
    -- Si hay muy bajo volumen = oportunidad de market reset
    elseif volume < 3 then
        recommended = 'market_reset'
        reason = 'very_low_volume'
        confidence = confidence * 0.7
    
    -- Si el precio está subiendo = esperar o vender
    elseif trend and trend.trend == 'rising' then
        recommended = 'hold'
        reason = 'rising_price_trend'
        confidence = confidence * 0.8
    end
    
    return {
        recommended = recommended,
        reason = reason,
        confidence = math.min(1.0, confidence),
        profile = profile,
        trend = trend,
        volume = volume,
    }
end

-- Obtener valor total del portfolio
function get_portfolio_value()
    local active_trades = get_active_trades()
    local total = 0
    
    for i = 1, getn(active_trades) do
        total = total + (active_trades[i].buy_price or 0)
    end
    
    return total
end

-- Obtener configuración de estrategias
function get_strategy_config()
    return {
        flipping = flipping_config,
        sniping = sniping_config,
        reset = reset_config,
        arbitrage = arbitrage_config,
        risk = risk_config,
    }
end

-- Establecer configuración de estrategias
function set_strategy_config(strategy_name, config)
    if strategy_name == 'flipping' then
        for key, value in pairs(config) do
            flipping_config[key] = value
        end
        aux.print('[STRATEGIES] Configuración de Flipping actualizada')
    elseif strategy_name == 'sniping' then
        for key, value in pairs(config) do
            sniping_config[key] = value
        end
        aux.print('[STRATEGIES] Configuración de Sniping actualizada')
    elseif strategy_name == 'reset' then
        for key, value in pairs(config) do
            reset_config[key] = value
        end
        aux.print('[STRATEGIES] Configuración de Market Reset actualizada')
    elseif strategy_name == 'arbitrage' then
        for key, value in pairs(config) do
            arbitrage_config[key] = value
        end
        aux.print('[STRATEGIES] Configuración de Arbitrage actualizada')
    elseif strategy_name == 'risk' then
        for key, value in pairs(config) do
            risk_config[key] = value
        end
        aux.print('[STRATEGIES] Configuración de Risk Management actualizada')
    else
        aux.print('[STRATEGIES] ERROR: Estrategia desconocida: ' .. tostring(strategy_name))
    end
end

-- get_all_auctions_for_item() ahora está en helpers.lua

function get_active_trades()
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return {}
    end
    
    local active = {}
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        if trade.status == 'pending' then
            tinsert(active, trade)
        end
    end
    
    return active
end

function get_item_portfolio_value(item_key)
    local active_trades = get_active_trades()
    local total = 0
    
    for i = 1, getn(active_trades) do
        if active_trades[i].item_key == item_key then
            total = total + (active_trades[i].buy_price or 0)
        end
    end
    
    return total
end

-- get_item_category() ahora está en helpers.lua

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    aux.print('[STRATEGIES] Sistema de estrategias de trading inicializado')
end)

-- Estado de estrategias activas
local active_strategies = {
	flipping = true,
	sniping = true,
	reset = false,
	arbitrage = false,
}

function toggle_strategy(strategy_name)
	if active_strategies[strategy_name] ~= nil then
		active_strategies[strategy_name] = not active_strategies[strategy_name]
		local status = active_strategies[strategy_name] and "activada" or "desactivada"
		aux.print(string.format('|cFFFFD700Estrategia %s %s|r', strategy_name, status))
	else
		aux.print(string.format('|cFFFF0000Estrategia desconocida: %s|r', strategy_name))
	end
end

function get_active_strategies()
	return active_strategies
end

function update_strategies_ui(strategies_frame)
    if not strategies_frame then return end
end

-- ============================================================================
-- EXPORTAR FUNCIONES AL MÓDULO
-- ============================================================================

local M = getfenv()

-- Exportar funciones principales
M.evaluate_flipping_opportunity = evaluate_flipping_opportunity
M.evaluate_sniping_opportunity = evaluate_sniping_opportunity
M.evaluate_reset_opportunity = evaluate_reset_opportunity
M.evaluate_arbitrage_opportunity = evaluate_arbitrage_opportunity
M.select_best_strategy = select_best_strategy
M.calculate_portfolio_risk = calculate_portfolio_risk
M.get_strategy_recommendation = get_strategy_recommendation

-- Registrar en módulos
if M.modules then
    M.modules.strategies = {
        update_ui = update_strategies_ui,
        toggle_strategy = toggle_strategy,
        get_active_strategies = get_active_strategies,
        evaluate_flipping_opportunity = evaluate_flipping_opportunity,
        evaluate_sniping_opportunity = evaluate_sniping_opportunity,
        evaluate_reset_opportunity = evaluate_reset_opportunity,
        evaluate_arbitrage_opportunity = evaluate_arbitrage_opportunity,
        select_best_strategy = select_best_strategy,
        calculate_portfolio_risk = calculate_portfolio_risk,
        get_strategy_recommendation = get_strategy_recommendation,
    }
    aux.print('[STRATEGIES] Funciones registradas y exportadas')
else
    aux.print('[STRATEGIES] ERROR: M.modules no existe')
end

-- Verificar exports
aux.print('[STRATEGIES] Verificando exports...')
aux.print('[STRATEGIES] - evaluate_flipping_opportunity: ' .. tostring(M.evaluate_flipping_opportunity ~= nil))
aux.print('[STRATEGIES] - evaluate_sniping_opportunity: ' .. tostring(M.evaluate_sniping_opportunity ~= nil))
aux.print('[STRATEGIES] - select_best_strategy: ' .. tostring(M.select_best_strategy ~= nil))

-- ============================================================================
-- Strategy Toggle Functions
-- ============================================================================

local active_strategies = {
    flipping = false,
    sniping = false,
    market_reset = false,
    arbitrage = false,
}

function toggle_flipping()
    active_strategies.flipping = not active_strategies.flipping
    aux.print(string.format('[STRATEGIES] Flipping %s', active_strategies.flipping and 'activado' or 'desactivado'))
end

function toggle_sniping()
    active_strategies.sniping = not active_strategies.sniping
    aux.print(string.format('[STRATEGIES] Sniping %s', active_strategies.sniping and 'activado' or 'desactivado'))
end

function toggle_market_reset()
    active_strategies.market_reset = not active_strategies.market_reset
    aux.print(string.format('[STRATEGIES] Market Reset %s', active_strategies.market_reset and 'activado' or 'desactivado'))
end

function toggle_arbitrage()
    active_strategies.arbitrage = not active_strategies.arbitrage
    aux.print(string.format('[STRATEGIES] Arbitrage %s', active_strategies.arbitrage and 'activado' or 'desactivado'))
end

function is_flipping_active()
    return active_strategies.flipping
end

function is_sniping_active()
    return active_strategies.sniping
end

function is_market_reset_active()
    return active_strategies.market_reset
end

function is_arbitrage_active()
    return active_strategies.arbitrage
end

-- Registrar funciones en el módulo
if M.modules then
    M.modules.strategies = M.modules.strategies or {}
    M.modules.strategies.toggle_flipping = toggle_flipping
    M.modules.strategies.toggle_sniping = toggle_sniping
    M.modules.strategies.toggle_market_reset = toggle_market_reset
    M.modules.strategies.toggle_arbitrage = toggle_arbitrage
    M.modules.strategies.is_flipping_active = is_flipping_active
    M.modules.strategies.is_sniping_active = is_sniping_active
    M.modules.strategies.is_market_reset_active = is_market_reset_active
    M.modules.strategies.is_arbitrage_active = is_arbitrage_active
    
    aux.print('[STRATEGIES] Funciones de toggle registradas')
else
    aux.print('[STRATEGIES] ERROR: No se pudieron registrar funciones de toggle')
end

-- ============================================================================
-- Module Exports (FIX: Exportar funciones principales)
-- ============================================================================

-- Export strategy evaluation functions
M.evaluate_flipping_opportunity = evaluate_flipping_opportunity
M.evaluate_sniping_opportunity = evaluate_sniping_opportunity
M.evaluate_reset_opportunity = evaluate_reset_opportunity
M.evaluate_arbitrage_opportunity = evaluate_arbitrage_opportunity
M.select_best_strategy = select_best_strategy

-- Export helper functions
M.estimate_sell_time = estimate_sell_time
M.get_profile = get_profile
M.get_strategy_recommendation = get_strategy_recommendation
M.get_active_trades = get_active_trades
M.get_item_portfolio_value = get_item_portfolio_value

-- Export risk management
M.calculate_portfolio_risk = calculate_portfolio_risk
M.should_invest = should_invest
M.get_portfolio_value = get_portfolio_value

-- Export configuration
M.get_strategy_config = get_strategy_config
M.set_strategy_config = set_strategy_config

-- Export strategy toggles
M.toggle_strategy = toggle_strategy
M.get_active_strategies = get_active_strategies

aux.print('[STRATEGIES] Funciones exportadas al módulo')
