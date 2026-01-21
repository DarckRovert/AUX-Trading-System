module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'

-- ============================================================================
-- Market Analysis - Análisis Avanzado de Mercado
-- ============================================================================

aux.print('[MARKET_ANALYSIS] Módulo cargado')

-- ============================================================================
-- Price Trend Analysis
-- ============================================================================

-- Estructura de datos para histórico de precios
local price_history = {}

function init_price_history()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.price_history then
        aux.faction_data.trading.price_history = {}
    end
    
    price_history = aux.faction_data.trading.price_history
end

-- Registrar precio en el histórico
function record_price(item_key, price, timestamp)
    timestamp = timestamp or time()
    
    if not price_history[item_key] then
        price_history[item_key] = {
            prices = {},
            last_update = 0,
        }
    end
    
    local history_entry = price_history[item_key]
    
    -- Agregar nuevo precio
    tinsert(history_entry.prices, {
        price = price,
        timestamp = timestamp,
    })
    
    -- Mantener solo últimos 30 días de datos
    local cutoff_time = timestamp - (30 * 24 * 60 * 60)
    local cleaned_prices = {}
    
    for i = 1, getn(history_entry.prices) do
        local entry = history_entry.prices[i]
        if entry.timestamp >= cutoff_time then
            tinsert(cleaned_prices, entry)
        end
    end
    
    history_entry.prices = cleaned_prices
    history_entry.last_update = timestamp
end

-- Calcular tendencia de precio (subiendo/bajando)
function calculate_price_trend(item_key, days)
    days = days or 7
    
    if not price_history[item_key] then
        return {
            trend = 'unknown',
            direction = 0,
            confidence = 0,
            change_percent = 0,
        }
    end
    
    local history_entry = price_history[item_key]
    local prices = history_entry.prices
    
    if getn(prices) < 2 then
        return {
            trend = 'insufficient_data',
            direction = 0,
            confidence = 0,
            change_percent = 0,
        }
    end
    
    -- Filtrar precios de los últimos N días
    local cutoff_time = time() - (days * 24 * 60 * 60)
    local recent_prices = {}
    
    for i = 1, getn(prices) do
        if prices[i].timestamp >= cutoff_time then
            tinsert(recent_prices, prices[i])
        end
    end
    
    if getn(recent_prices) < 2 then
        return {
            trend = 'insufficient_data',
            direction = 0,
            confidence = 0,
            change_percent = 0,
        }
    end
    
    -- Calcular regresión lineal simple
    local n = getn(recent_prices)
    local sum_x = 0
    local sum_y = 0
    local sum_xy = 0
    local sum_x2 = 0
    
    for i = 1, n do
        local x = i
        local y = recent_prices[i].price
        sum_x = sum_x + x
        sum_y = sum_y + y
        sum_xy = sum_xy + (x * y)
        sum_x2 = sum_x2 + (x * x)
    end
    
    -- Pendiente de la línea de tendencia
    -- Prevenir división por cero
    local denominator = (n * sum_x2 - sum_x * sum_x)
    local slope = denominator ~= 0 and ((n * sum_xy - sum_x * sum_y) / denominator) or 0
    
    -- Calcular cambio porcentual
    local first_price = recent_prices[1].price
    local last_price = recent_prices[n].price
    local change_percent = 0
    
    if first_price > 0 then
        change_percent = ((last_price - first_price) / first_price) * 100
    end
    
    -- Determinar tendencia
    local trend = 'stable'
    local direction = 0
    
    if change_percent > 5 then
        trend = 'rising'
        direction = 1
    elseif change_percent < -5 then
        trend = 'falling'
        direction = -1
    end
    
    -- Calcular confianza basada en cantidad de datos
    local confidence = math.min(1.0, n / 10)
    
    return {
        trend = trend,
        direction = direction,
        confidence = confidence,
        change_percent = change_percent,
        slope = slope,
        sample_count = n,
    }
end

-- ============================================================================
-- Market Manipulation Detection
-- ============================================================================

function detect_market_manipulation(item_key)
    if not price_history[item_key] then
        return {
            is_manipulated = false,
            confidence = 0,
            reason = 'no_data',
        }
    end
    
    local history_entry = price_history[item_key]
    local prices = history_entry.prices
    
    if getn(prices) < 5 then
        return {
            is_manipulated = false,
            confidence = 0,
            reason = 'insufficient_data',
        }
    end
    
    -- Calcular estadísticas
    local sum = 0
    local min_price = prices[1].price
    local max_price = prices[1].price
    
    for i = 1, getn(prices) do
        local price = prices[i].price
        sum = sum + price
        if price < min_price then min_price = price end
        if price > max_price then max_price = price end
    end
    
    local avg_price = sum / getn(prices)
    
    -- Calcular desviación estándar
    local variance_sum = 0
    for i = 1, getn(prices) do
        local diff = prices[i].price - avg_price
        variance_sum = variance_sum + (diff * diff)
    end
    
    local std_dev = math.sqrt(variance_sum / getn(prices))
    -- Prevenir división por cero
    local coefficient_of_variation = avg_price > 0 and (std_dev / avg_price) or 0
    
    -- Detectar manipulación
    local is_manipulated = false
    local reason = 'normal'
    local confidence = 0
    
    -- Criterio 1: Volatilidad extrema (CV > 0.5)
    if coefficient_of_variation > 0.5 then
        is_manipulated = true
        reason = 'extreme_volatility'
        confidence = math.min(1.0, coefficient_of_variation)
    end
    
    -- Criterio 2: Cambio brusco reciente (último precio muy diferente)
    local last_price = prices[getn(prices)].price
    -- Prevenir división por cero
    local deviation_from_avg = avg_price > 0 and (math.abs(last_price - avg_price) / avg_price) or 0
    
    if deviation_from_avg > 0.3 then
        is_manipulated = true
        reason = 'sudden_price_change'
        confidence = math.max(confidence, math.min(1.0, deviation_from_avg))
    end
    
    -- Criterio 3: Rango de precios muy amplio
    -- Prevenir división por cero
    local price_range = avg_price > 0 and ((max_price - min_price) / avg_price) or 0
    if price_range > 1.0 then
        is_manipulated = true
        reason = 'wide_price_range'
        confidence = math.max(confidence, math.min(1.0, price_range / 2))
    end
    
    return {
        is_manipulated = is_manipulated,
        confidence = confidence,
        reason = reason,
        volatility = coefficient_of_variation,
        price_range = price_range,
    }
end

-- ============================================================================
-- Volume Analysis
-- ============================================================================

local volume_data = {}

function init_volume_data()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.volume_data then
        aux.faction_data.trading.volume_data = {}
    end
    
    volume_data = aux.faction_data.trading.volume_data
end

function record_volume(item_key, count, timestamp)
    timestamp = timestamp or time()
    
    if not volume_data[item_key] then
        volume_data[item_key] = {
            daily_volume = {},
            total_volume = 0,
        }
    end
    
    local entry = volume_data[item_key]
    
    -- Obtener día actual (timestamp / 86400 = días desde epoch)
    local day = math.floor(timestamp / 86400)
    
    if not entry.daily_volume[day] then
        entry.daily_volume[day] = 0
    end
    
    entry.daily_volume[day] = entry.daily_volume[day] + count
    entry.total_volume = entry.total_volume + count
    
    -- Limpiar datos antiguos (más de 30 días)
    local cutoff_day = day - 30
    for old_day, _ in pairs(entry.daily_volume) do
        if old_day < cutoff_day then
            entry.daily_volume[old_day] = nil
        end
    end
end

function get_average_daily_volume(item_key, days)
    days = days or 7
    
    if not volume_data[item_key] then
        return 0
    end
    
    local entry = volume_data[item_key]
    local current_day = math.floor(time() / 86400)
    local sum = 0
    local count = 0
    
    for i = 0, days - 1 do
        local day = current_day - i
        if entry.daily_volume[day] then
            sum = sum + entry.daily_volume[day]
            count = count + 1
        end
    end
    
    if count == 0 then
        return 0
    end
    
    return sum / count
end

function get_volume_trend(item_key, days)
    days = days or 7
    
    if not volume_data[item_key] then
        return {
            trend = 'unknown',
            direction = 0,
            change_percent = 0,
        }
    end
    
    local entry = volume_data[item_key]
    local current_day = math.floor(time() / 86400)
    
    -- Dividir en dos períodos
    local half_days = math.floor(days / 2)
    local recent_sum = 0
    local recent_count = 0
    local old_sum = 0
    local old_count = 0
    
    for i = 0, half_days - 1 do
        local day = current_day - i
        if entry.daily_volume[day] then
            recent_sum = recent_sum + entry.daily_volume[day]
            recent_count = recent_count + 1
        end
    end
    
    for i = half_days, days - 1 do
        local day = current_day - i
        if entry.daily_volume[day] then
            old_sum = old_sum + entry.daily_volume[day]
            old_count = old_count + 1
        end
    end
    
    if recent_count == 0 or old_count == 0 then
        return {
            trend = 'insufficient_data',
            direction = 0,
            change_percent = 0,
        }
    end
    
    local recent_avg = recent_sum / recent_count
    local old_avg = old_sum / old_count
    
    local change_percent = 0
    if old_avg > 0 then
        change_percent = ((recent_avg - old_avg) / old_avg) * 100
    end
    
    local trend = 'stable'
    local direction = 0
    
    if change_percent > 20 then
        trend = 'increasing'
        direction = 1
    elseif change_percent < -20 then
        trend = 'decreasing'
        direction = -1
    end
    
    return {
        trend = trend,
        direction = direction,
        change_percent = change_percent,
        recent_avg = recent_avg,
        old_avg = old_avg,
    }
end

-- ============================================================================
-- Price Prediction
-- ============================================================================

function predict_future_price(item_key, days_ahead)
    days_ahead = days_ahead or 1
    
    local trend_data = calculate_price_trend(item_key, 14)
    
    if trend_data.trend == 'unknown' or trend_data.trend == 'insufficient_data' then
        return {
            predicted_price = 0,
            confidence = 0,
            reason = 'insufficient_data',
        }
    end
    
    -- Obtener precio actual
    local current_price = history.value(item_key) or 0
    
    if current_price == 0 then
        return {
            predicted_price = 0,
            confidence = 0,
            reason = 'no_current_price',
        }
    end
    
    -- Predicción simple basada en tendencia
    local daily_change_rate = trend_data.change_percent / 100 / 14  -- Cambio diario
    local predicted_change = daily_change_rate * days_ahead
    local predicted_price = current_price * (1 + predicted_change)
    
    -- Ajustar confianza basada en volatilidad
    local manipulation = detect_market_manipulation(item_key)
    local confidence = trend_data.confidence * (1 - manipulation.volatility)
    
    return {
        predicted_price = predicted_price,
        confidence = confidence,
        current_price = current_price,
        expected_change_percent = predicted_change * 100,
        trend = trend_data.trend,
    }
end

-- ============================================================================
-- Market Opportunity Scoring
-- ============================================================================

function calculate_advanced_score(item_key, current_price, buyout_price)
    -- Obtener análisis de mercado
    local trend = calculate_price_trend(item_key, 7)
    local manipulation = detect_market_manipulation(item_key)
    local volume_trend = get_volume_trend(item_key, 7)
    local prediction = predict_future_price(item_key, 3)
    
    -- Score base (descuento)
    local avg_price = history.value(item_key) or current_price
    local discount = 0
    if avg_price > 0 then
        discount = (avg_price - buyout_price) / avg_price
    end
    
    local base_score = discount * 100
    
    -- Modificadores
    local trend_modifier = 1.0
    local volume_modifier = 1.0
    local manipulation_modifier = 1.0
    local prediction_modifier = 1.0
    
    -- Bonus si el precio está bajando (mejor momento para comprar)
    if trend.trend == 'falling' then
        trend_modifier = 1.2
    elseif trend.trend == 'rising' then
        trend_modifier = 0.8  -- Penalizar si está subiendo
    end
    
    -- Bonus si el volumen está aumentando (más demanda)
    if volume_trend.trend == 'increasing' then
        volume_modifier = 1.15
    elseif volume_trend.trend == 'decreasing' then
        volume_modifier = 0.9
    end
    
    -- Penalizar si hay manipulación
    if manipulation.is_manipulated then
        manipulation_modifier = 0.7
    end
    
    -- Bonus si se predice que el precio subirá
    if prediction.confidence > 0.5 and prediction.expected_change_percent > 10 then
        prediction_modifier = 1.3
    end
    
    -- Score final
    local final_score = base_score * trend_modifier * volume_modifier * manipulation_modifier * prediction_modifier
    
    return {
        score = final_score,
        base_score = base_score,
        trend_modifier = trend_modifier,
        volume_modifier = volume_modifier,
        manipulation_modifier = manipulation_modifier,
        prediction_modifier = prediction_modifier,
        trend_data = trend,
        manipulation_data = manipulation,
        volume_data = volume_trend,
        prediction_data = prediction,
    }
end

-- ============================================================================
-- Alert System
-- ============================================================================

local alert_thresholds = {
    exceptional_discount = 0.40,  -- 40% descuento
    high_confidence = 0.80,
    rising_trend_threshold = 15,  -- 15% subida
}

function check_exceptional_opportunity(item_key, buyout_price)
    local advanced_score = calculate_advanced_score(item_key, buyout_price, buyout_price)
    
    local alerts = {}
    
    -- Alert por descuento excepcional
    if advanced_score.base_score >= alert_thresholds.exceptional_discount * 100 then
        tinsert(alerts, {
            type = 'exceptional_discount',
            severity = 'high',
            message = string.format('Descuento excepcional: %.0f%%', advanced_score.base_score),
        })
    end
    
    -- Alert por tendencia alcista fuerte
    if advanced_score.trend_data.trend == 'rising' and 
       advanced_score.trend_data.change_percent > alert_thresholds.rising_trend_threshold then
        tinsert(alerts, {
            type = 'strong_uptrend',
            severity = 'medium',
            message = string.format('Tendencia alcista fuerte: +%.1f%%', advanced_score.trend_data.change_percent),
        })
    end
    
    -- Alert por manipulación detectada
    if advanced_score.manipulation_data.is_manipulated and 
       advanced_score.manipulation_data.confidence > 0.7 then
        tinsert(alerts, {
            type = 'market_manipulation',
            severity = 'warning',
            message = 'Posible manipulación de mercado detectada',
        })
    end
    
    -- Alert por predicción positiva
    if advanced_score.prediction_data.confidence > alert_thresholds.high_confidence and
       advanced_score.prediction_data.expected_change_percent > 20 then
        tinsert(alerts, {
            type = 'positive_prediction',
            severity = 'high',
            message = string.format('Predicción: +%.1f%% en 3 días', advanced_score.prediction_data.expected_change_percent),
        })
    end
    
    return {
        has_alerts = getn(alerts) > 0,
        alerts = alerts,
        score = advanced_score.score,
    }
end

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_price_history()
    init_volume_data()
    aux.print('[MARKET_ANALYSIS] Sistema de análisis de mercado inicializado')
end)

function update_market_analysis_ui(market_frame)
    if not market_frame then return end
    
    -- Crear UI inicial si no existe
    if not market_frame.initialized then
        create_market_analysis_ui(market_frame)
        market_frame.initialized = true
    end
    
    -- Aquí iría la lógica de actualización de datos
    -- Por ahora solo muestra que está funcionando
end

function create_market_analysis_ui(market_frame)
    if not market_frame then return end
    
    -- Título
    local title = market_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 20, -20)
    title:SetText('|cFFFFD700Análisis de Mercado|r')
    
    -- Descripción
    local desc = market_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    desc:SetPoint('TOPLEFT', 20, -50)
    desc:SetPoint('TOPRIGHT', -20, -50)
    desc:SetJustifyH('LEFT')
    desc:SetText('|cFF888888Análisis avanzado de tendencias de precios, volumen y manipulación de mercado.|r')
    
    -- Información de estado
    local status = market_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    status:SetPoint('TOPLEFT', 20, -100)
    status:SetText('|cFFFFFF00Estado: |cFF00FF00Módulo cargado correctamente|r')
    
    -- Botón de análisis
    local analyze_button = CreateFrame('Button', nil, market_frame, 'UIPanelButtonTemplate')
    analyze_button:SetPoint('TOPRIGHT', -20, -20)
    analyze_button:SetWidth(120)
    analyze_button:SetHeight(25)
    analyze_button:SetText('Analizar Mercado')
    analyze_button:SetScript('OnClick', function()
        aux.print('[MARKET_ANALYSIS] Análisis de mercado solicitado')
    end)
end

-- ============================================================================
-- EXPORTAR FUNCIONES AL MÓDULO
-- ============================================================================

local M = getfenv()

-- Exportar funciones principales al módulo
M.record_price = record_price
M.calculate_price_trend = calculate_price_trend
M.detect_market_manipulation = detect_market_manipulation
M.get_average_daily_volume = get_average_daily_volume
M.get_volume_trend = get_volume_trend
M.predict_future_price = predict_future_price
M.check_exceptional_opportunity = check_exceptional_opportunity
M.calculate_advanced_score = calculate_advanced_score

-- Registrar en módulos
if M.modules then
    M.modules.market_analysis = {
        update_ui = update_market_analysis_ui,
        -- Funciones de análisis de precios
        record_price = record_price,
        calculate_price_trend = calculate_price_trend,
        detect_market_manipulation = detect_market_manipulation,
        -- Funciones de volumen
        get_average_daily_volume = get_average_daily_volume,
        get_volume_trend = get_volume_trend,
        record_volume = record_volume,
        -- Funciones de predicción
        predict_future_price = predict_future_price,
        check_exceptional_opportunity = check_exceptional_opportunity,
        calculate_advanced_score = calculate_advanced_score,
    }
    aux.print('[MARKET_ANALYSIS] Funciones registradas y exportadas')
else
    aux.print('[MARKET_ANALYSIS] ERROR: M.modules no existe')
end

-- ============================================================================
-- Module Exports (FIX: Asegurar que todas las funciones estén exportadas)
-- ============================================================================

-- Export price history functions
M.init_price_history = init_price_history
M.record_price = record_price
M.calculate_price_trend = calculate_price_trend

-- Export market manipulation detection
M.detect_market_manipulation = detect_market_manipulation

-- Export volume analysis
M.get_average_daily_volume = get_average_daily_volume
M.get_volume_trend = get_volume_trend

-- Export price prediction
M.predict_future_price = predict_future_price

-- Export alerts
M.check_price_alerts = check_price_alerts

-- Verificar exports
aux.print('[MARKET_ANALYSIS] Verificando exports...')
aux.print('[MARKET_ANALYSIS] - record_price: ' .. tostring(M.record_price ~= nil))
aux.print('[MARKET_ANALYSIS] - get_average_daily_volume: ' .. tostring(M.get_average_daily_volume ~= nil))
aux.print('[MARKET_ANALYSIS] - detect_market_manipulation: ' .. tostring(M.detect_market_manipulation ~= nil))
aux.print('[MARKET_ANALYSIS] Funciones exportadas al módulo')
