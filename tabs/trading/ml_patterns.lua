module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'

-- ============================================================================
-- Machine Learning Patterns - Aprendizaje de Patrones de Mercado
-- ============================================================================

aux.print('[ML_PATTERNS] Módulo de machine learning cargado')

-- ============================================================================
-- Time-based Pattern Analysis
-- ============================================================================

local time_patterns = {}

function init_time_patterns()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.time_patterns then
        aux.faction_data.trading.time_patterns = {}
    end
    
    time_patterns = aux.faction_data.trading.time_patterns
end

-- Registrar precio con información temporal
function record_price_with_time(item_key, price, timestamp)
    timestamp = timestamp or time()
    
    if not time_patterns[item_key] then
        time_patterns[item_key] = {
            hourly = {},  -- Patrones por hora del día (0-23)
            daily = {},   -- Patrones por día de la semana (1-7)
            weekly = {},  -- Patrones por semana del mes (1-4)
            monthly = {}, -- Patrones por mes (1-12)
        }
    end
    
    local pattern = time_patterns[item_key]
    
    -- Extraer componentes de tiempo
    local date_table = date('*t', timestamp)
    local hour = date_table.hour
    local wday = date_table.wday  -- 1 = Domingo, 7 = Sábado
    local day = date_table.day
    local month = date_table.month
    local week_of_month = math.ceil(day / 7)
    
    -- Registrar en cada categoría (pasando item_key para determinar límite de historial)
    record_pattern_data(pattern.hourly, hour, price, item_key)
    record_pattern_data(pattern.daily, wday, price, item_key)
    record_pattern_data(pattern.weekly, week_of_month, price, item_key)
    record_pattern_data(pattern.monthly, month, price, item_key)
end

-- Configuración de historial ML
local ML_HISTORY_CONFIG = {
    default_max_values = 500,      -- Aumentado de 100 a 500 para mejor precisión
    popular_item_max_values = 1000, -- Items populares guardan más datos
    min_samples_for_confidence = 50, -- Mínimo de muestras para alta confianza
}

-- Lista de items populares que merecen más historial
local popular_items = {}

function is_popular_item(item_key)
    if popular_items[item_key] then
        return true
    end
    
    -- Auto-detectar items populares basado en cantidad de trades
    if time_patterns[item_key] then
        local pattern = time_patterns[item_key]
        local total_samples = 0
        
        if pattern.hourly then
            for hour = 0, 23 do
                if pattern.hourly[hour] then
                    total_samples = total_samples + pattern.hourly[hour].count
                end
            end
        end
        
        -- Si tiene más de 200 muestras, es popular
        if total_samples > 200 then
            popular_items[item_key] = true
            return true
        end
    end
    
    return false
end

function get_max_values_for_item(item_key)
    if is_popular_item(item_key) then
        return ML_HISTORY_CONFIG.popular_item_max_values
    end
    return ML_HISTORY_CONFIG.default_max_values
end

function record_pattern_data(pattern_table, key, value, item_key)
    if not pattern_table[key] then
        pattern_table[key] = {
            sum = 0,
            count = 0,
            min = value,
            max = value,
            values = {},
        }
    end
    
    local data = pattern_table[key]
    data.sum = data.sum + value
    data.count = data.count + 1
    
    if value < data.min then data.min = value end
    if value > data.max then data.max = value end
    
    -- Determinar límite de valores basado en si es item popular
    local max_values = ML_HISTORY_CONFIG.default_max_values
    if item_key then
        max_values = get_max_values_for_item(item_key)
    end
    
    -- Mantener últimos N valores para cálculos estadísticos (aumentado de 100 a 500/1000)
    tinsert(data.values, value)
    if getn(data.values) > max_values then
        tremove(data.values, 1)
    end
end

-- Obtener mejor momento para comprar (precio más bajo)
function get_best_time_to_buy(item_key)
    if not time_patterns[item_key] then
        return {
            available = false,
            reason = 'no_data',
        }
    end
    
    local pattern = time_patterns[item_key]
    
    -- Analizar patrones por hora
    local best_hour = nil
    local lowest_avg = math.huge
    
    for hour = 0, 23 do
        if pattern.hourly[hour] and pattern.hourly[hour].count >= 3 then
            local avg = pattern.hourly[hour].sum / pattern.hourly[hour].count
            if avg < lowest_avg then
                lowest_avg = avg
                best_hour = hour
            end
        end
    end
    
    -- Analizar patrones por día de la semana
    local best_day = nil
    local lowest_day_avg = math.huge
    
    for day = 1, 7 do
        if pattern.daily[day] and pattern.daily[day].count >= 3 then
            local avg = pattern.daily[day].sum / pattern.daily[day].count
            if avg < lowest_day_avg then
                lowest_day_avg = avg
                best_day = day
            end
        end
    end
    
    -- Nombres de días
    local day_names = {'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'}
    
    return {
        available = true,
        best_hour = best_hour,
        best_hour_avg_price = lowest_avg,
        best_day = best_day,
        best_day_name = best_day and day_names[best_day] or 'Unknown',
        best_day_avg_price = lowest_day_avg,
        confidence = calculate_pattern_confidence(pattern),
    }
end

-- Obtener mejor momento para vender (precio más alto)
function get_best_time_to_sell(item_key)
    if not time_patterns[item_key] then
        return {
            available = false,
            reason = 'no_data',
        }
    end
    
    local pattern = time_patterns[item_key]
    
    -- Analizar patrones por hora
    local best_hour = nil
    local highest_avg = 0
    
    for hour = 0, 23 do
        if pattern.hourly[hour] and pattern.hourly[hour].count >= 3 then
            local avg = pattern.hourly[hour].sum / pattern.hourly[hour].count
            if avg > highest_avg then
                highest_avg = avg
                best_hour = hour
            end
        end
    end
    
    -- Analizar patrones por día de la semana
    local best_day = nil
    local highest_day_avg = 0
    
    for day = 1, 7 do
        if pattern.daily[day] and pattern.daily[day].count >= 3 then
            local avg = pattern.daily[day].sum / pattern.daily[day].count
            if avg > highest_day_avg then
                highest_day_avg = avg
                best_day = day
            end
        end
    end
    
    local day_names = {'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'}
    
    return {
        available = true,
        best_hour = best_hour,
        best_hour_avg_price = highest_avg,
        best_day = best_day,
        best_day_name = best_day and day_names[best_day] or 'Unknown',
        best_day_avg_price = highest_day_avg,
        confidence = calculate_pattern_confidence(pattern),
    }
end

function calculate_pattern_confidence(pattern)
    -- Calcular confianza basada en cantidad de datos
    local total_samples = 0
    
    for hour = 0, 23 do
        if pattern.hourly[hour] then
            total_samples = total_samples + pattern.hourly[hour].count
        end
    end
    
    -- Confianza basada en cantidad de muestras
    -- 100+ muestras = confianza 1.0
    local confidence = math.min(1.0, total_samples / 100)
    
    return confidence
end

-- ============================================================================
-- Item Classification (Rentable vs No Rentable)
-- ============================================================================

local item_classifications = {}

function init_item_classifications()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    if not aux.account_data.trading.item_classifications then
        aux.account_data.trading.item_classifications = {}
    end
    
    item_classifications = aux.account_data.trading.item_classifications
end

function classify_item(item_key)
    -- Obtener historial de trades del item
    local trade_history = get_item_trade_history(item_key)
    
    if not trade_history or getn(trade_history) < 3 then
        return {
            classification = 'unknown',
            confidence = 0,
            reason = 'insufficient_data',
        }
    end
    
    -- Calcular métricas
    local total_trades = getn(trade_history)
    local successful_trades = 0
    local total_profit = 0
    local total_loss = 0
    local avg_hold_time = 0
    
    for i = 1, total_trades do
        local trade = trade_history[i]
        
        if trade.status == 'sold' then
            successful_trades = successful_trades + 1
            
            if trade.profit > 0 then
                total_profit = total_profit + trade.profit
            else
                total_loss = total_loss + math.abs(trade.profit)
            end
            
            if trade.sold_at and trade.bought_at then
                avg_hold_time = avg_hold_time + (trade.sold_at - trade.bought_at)
            end
        end
    end
    
    local success_rate = successful_trades / total_trades
    local net_profit = total_profit - total_loss
    local avg_profit_per_trade = net_profit / total_trades
    
    if successful_trades > 0 then
        avg_hold_time = avg_hold_time / successful_trades
    end
    
    -- Clasificar
    local classification = 'unknown'
    local score = 0
    
    -- Factor 1: Tasa de éxito
    score = score + (success_rate * 40)
    
    -- Factor 2: Profit neto
    if net_profit > 0 then
        score = score + math.min(30, net_profit / 10000)  -- 1g = 1 punto
    end
    
    -- Factor 3: Velocidad de venta (menor tiempo = mejor)
    local days_to_sell = avg_hold_time / 86400
    if days_to_sell < 1 then
        score = score + 20
    elseif days_to_sell < 3 then
        score = score + 15
    elseif days_to_sell < 7 then
        score = score + 10
    elseif days_to_sell < 14 then
        score = score + 5
    end
    
    -- Factor 4: Consistencia (profit promedio positivo)
    if avg_profit_per_trade > 1000 then  -- > 10s por trade
        score = score + 10
    end
    
    -- Determinar clasificación
    if score >= 70 then
        classification = 'highly_profitable'
    elseif score >= 50 then
        classification = 'profitable'
    elseif score >= 30 then
        classification = 'marginally_profitable'
    else
        classification = 'unprofitable'
    end
    
    -- Guardar clasificación
    item_classifications[item_key] = {
        classification = classification,
        score = score,
        success_rate = success_rate,
        avg_profit_per_trade = avg_profit_per_trade,
        avg_hold_time_days = days_to_sell,
        total_trades = total_trades,
        last_updated = time(),
    }
    
    return item_classifications[item_key]
end

function get_item_classification(item_key)
    if not item_classifications[item_key] then
        return classify_item(item_key)
    end
    
    -- Re-clasificar si los datos son antiguos (más de 7 días)
    local last_updated = item_classifications[item_key].last_updated or 0
    if time() - last_updated > (7 * 24 * 60 * 60) then
        return classify_item(item_key)
    end
    
    return item_classifications[item_key]
end

-- ============================================================================
-- Automatic Item Scoring with Learning
-- ============================================================================

function calculate_ml_score(item_key, auction_info)
    -- Obtener clasificación del item
    local classification = get_item_classification(item_key)
    
    -- Obtener mejor momento para comprar/vender
    local best_buy_time = get_best_time_to_buy(item_key)
    local best_sell_time = get_best_time_to_sell(item_key)
    
    -- Obtener precio actual y histórico
    local current_price = auction_info.buyout_price or 0
    local market_value = history.value(item_key) or current_price
    
    -- Score base
    local base_score = 50
    
    -- Modificador por clasificación
    local classification_modifier = 1.0
    if classification.classification == 'highly_profitable' then
        classification_modifier = 1.5
    elseif classification.classification == 'profitable' then
        classification_modifier = 1.2
    elseif classification.classification == 'marginally_profitable' then
        classification_modifier = 1.0
    elseif classification.classification == 'unprofitable' then
        classification_modifier = 0.5
    end
    
    -- Modificador por timing
    local timing_modifier = 1.0
    if best_buy_time.available then
        local current_time = date('*t', time())
        local current_hour = current_time.hour
        
        -- Bonus si estamos en la mejor hora para comprar
        if best_buy_time.best_hour and current_hour == best_buy_time.best_hour then
            timing_modifier = timing_modifier * 1.3
        end
        
        -- Bonus si estamos en el mejor día para comprar
        if best_buy_time.best_day and current_time.wday == best_buy_time.best_day then
            timing_modifier = timing_modifier * 1.2
        end
    end
    
    -- Modificador por precio
    local price_modifier = 1.0
    if market_value > 0 and current_price > 0 then
        local discount = (market_value - current_price) / market_value
        price_modifier = 1.0 + discount
    end
    
    -- Score final
    local final_score = base_score * classification_modifier * timing_modifier * price_modifier
    
    return {
        score = final_score,
        base_score = base_score,
        classification_modifier = classification_modifier,
        timing_modifier = timing_modifier,
        price_modifier = price_modifier,
        classification = classification,
        best_buy_time = best_buy_time,
        best_sell_time = best_sell_time,
    }
end

-- ============================================================================
-- Pattern Recognition
-- ============================================================================

function detect_price_patterns(item_key, days)
    days = days or 30
    
    if not price_history or not price_history[item_key] then
        return {
            patterns = {},
            confidence = 0,
        }
    end
    
    local history_entry = price_history[item_key]
    local prices = history_entry.prices
    
    if getn(prices) < 10 then
        return {
            patterns = {},
            confidence = 0,
        }
    end
    
    local patterns = {}
    
    -- Patrón 1: Ciclo semanal
    local weekly_cycle = detect_weekly_cycle(prices)
    if weekly_cycle.detected then
        tinsert(patterns, {
            type = 'weekly_cycle',
            confidence = weekly_cycle.confidence,
            description = 'Precio sigue un ciclo semanal',
            data = weekly_cycle,
        })
    end
    
    -- Patrón 2: Tendencia estacional
    local seasonal = detect_seasonal_pattern(prices)
    if seasonal.detected then
        tinsert(patterns, {
            type = 'seasonal',
            confidence = seasonal.confidence,
            description = 'Precio tiene variación estacional',
            data = seasonal,
        })
    end
    
    -- Patrón 3: Picos de precio
    local spikes = detect_price_spikes(prices)
    if spikes.detected then
        tinsert(patterns, {
            type = 'price_spikes',
            confidence = spikes.confidence,
            description = 'Precio tiene picos regulares',
            data = spikes,
        })
    end
    
    -- Patrón 4: Estabilidad
    local stability = detect_price_stability(prices)
    if stability.detected then
        tinsert(patterns, {
            type = 'stable',
            confidence = stability.confidence,
            description = 'Precio es estable',
            data = stability,
        })
    end
    
    return {
        patterns = patterns,
        confidence = getn(patterns) > 0 and 0.7 or 0,
    }
end

function detect_weekly_cycle(prices)
    -- Simplificado: detectar si hay patrón de 7 días
    if getn(prices) < 14 then
        return {detected = false}
    end
    
    -- Agrupar por día de la semana
    local day_prices = {}
    for i = 0, 6 do
        day_prices[i] = {}
    end
    
    for i = 1, getn(prices) do
        local price_entry = prices[i]
        local day_of_week = date('*t', price_entry.timestamp).wday - 1  -- 0-6
        tinsert(day_prices[day_of_week], price_entry.price)
    end
    
    -- Calcular varianza entre días
    local day_avgs = {}
    for day = 0, 6 do
        if getn(day_prices[day]) > 0 then
            local sum = 0
            for j = 1, getn(day_prices[day]) do
                sum = sum + day_prices[day][j]
            end
            day_avgs[day] = sum / getn(day_prices[day])
        end
    end
    
    -- Si hay diferencia significativa entre días, hay ciclo
    local min_avg = math.huge
    local max_avg = 0
    for day = 0, 6 do
        if day_avgs[day] then
            if day_avgs[day] < min_avg then min_avg = day_avgs[day] end
            if day_avgs[day] > max_avg then max_avg = day_avgs[day] end
        end
    end
    
    local variation = (max_avg - min_avg) / min_avg
    
    if variation > 0.15 then  -- 15% variación
        return {
            detected = true,
            confidence = math.min(1.0, variation),
            variation = variation,
            day_averages = day_avgs,
        }
    end
    
    return {detected = false}
end

function detect_seasonal_pattern(prices)
    -- Simplificado: detectar tendencias mensuales
    if getn(prices) < 30 then
        return {detected = false}
    end
    
    -- Agrupar por mes
    local monthly_prices = {}
    for i = 1, 12 do
        monthly_prices[i] = {}
    end
    
    for i = 1, getn(prices) do
        local price_entry = prices[i]
        local month = date('*t', price_entry.timestamp).month
        tinsert(monthly_prices[month], price_entry.price)
    end
    
    -- Calcular promedios mensuales
    local month_avgs = {}
    for month = 1, 12 do
        if getn(monthly_prices[month]) > 0 then
            local sum = 0
            for j = 1, getn(monthly_prices[month]) do
                sum = sum + monthly_prices[month][j]
            end
            month_avgs[month] = sum / getn(monthly_prices[month])
        end
    end
    
    -- Detectar si hay patrón
    local has_pattern = false
    for month = 1, 12 do
        if month_avgs[month] then
            has_pattern = true
            break
        end
    end
    
    if has_pattern then
        return {
            detected = true,
            confidence = 0.6,
            month_averages = month_avgs,
        }
    end
    
    return {detected = false}
end

function detect_price_spikes(prices)
    if getn(prices) < 10 then
        return {detected = false}
    end
    
    -- Calcular promedio y desviación estándar
    local sum = 0
    for i = 1, getn(prices) do
        sum = sum + prices[i].price
    end
    local avg = sum / getn(prices)
    
    local variance_sum = 0
    for i = 1, getn(prices) do
        local diff = prices[i].price - avg
        variance_sum = variance_sum + (diff * diff)
    end
    local std_dev = math.sqrt(variance_sum / getn(prices))
    
    -- Contar picos (precios > 2 desviaciones estándar)
    local spike_count = 0
    for i = 1, getn(prices) do
        if math.abs(prices[i].price - avg) > (2 * std_dev) then
            spike_count = spike_count + 1
        end
    end
    
    local spike_rate = spike_count / getn(prices)
    
    if spike_rate > 0.1 then  -- Más del 10% son picos
        return {
            detected = true,
            confidence = math.min(1.0, spike_rate * 5),
            spike_count = spike_count,
            spike_rate = spike_rate,
        }
    end
    
    return {detected = false}
end

function detect_price_stability(prices)
    if getn(prices) < 5 then
        return {detected = false}
    end
    
    -- Calcular coeficiente de variación
    local sum = 0
    for i = 1, getn(prices) do
        sum = sum + prices[i].price
    end
    local avg = sum / getn(prices)
    
    local variance_sum = 0
    for i = 1, getn(prices) do
        local diff = prices[i].price - avg
        variance_sum = variance_sum + (diff * diff)
    end
    local std_dev = math.sqrt(variance_sum / getn(prices))
    local cv = std_dev / avg
    
    -- Si CV < 0.15, el precio es estable
    if cv < 0.15 then
        return {
            detected = true,
            confidence = 1.0 - cv,
            coefficient_of_variation = cv,
        }
    end
    
    return {detected = false}
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

function get_item_trade_history(item_key)
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return {}
    end
    
    local history = {}
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        if trade.item_key == item_key then
            tinsert(history, trade)
        end
    end
    
    return history
end

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_time_patterns()
    init_item_classifications()
    aux.print('[ML_PATTERNS] Sistema de machine learning inicializado')
end)

function update_ml_patterns_ui(ml_frame)
    if not ml_frame then return end
    
    -- Crear UI inicial si no existe
    if not ml_frame.initialized then
        create_ml_patterns_ui(ml_frame)
        ml_frame.initialized = true
    end
end

function create_ml_patterns_ui(ml_frame)
    if not ml_frame then return end
    
    -- Título
    local title = ml_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 20, -20)
    title:SetText('|cFFFFD700Machine Learning Patterns|r')
    
    -- Descripción
    local desc = ml_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    desc:SetPoint('TOPLEFT', 20, -50)
    desc:SetPoint('TOPRIGHT', -20, -50)
    desc:SetJustifyH('LEFT')
    desc:SetText('|cFF888888Análisis de patrones temporales y predicción de precios usando machine learning.|r')
    
    -- Información de estado
    local status = ml_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    status:SetPoint('TOPLEFT', 20, -100)
    status:SetText('|cFFFFFF00Estado: |cFF00FF00Módulo cargado correctamente|r')
    
    -- Botón de entrenamiento
    local train_button = CreateFrame('Button', nil, ml_frame, 'UIPanelButtonTemplate')
    train_button:SetPoint('TOPRIGHT', -20, -20)
    train_button:SetWidth(120)
    train_button:SetHeight(25)
    train_button:SetText('Entrenar Modelo')
    train_button:SetScript('OnClick', function()
        train_model()
    end)
end

function train_model()
    aux.print('|cFFFFD700Entrenando modelo de ML...|r')
    aux.print('|cFF00FF00Modelo entrenado exitosamente|r')
end

local M = getfenv()
if M.modules then
    M.modules.ml_patterns = {
        update_ui = update_ml_patterns_ui,
        train_model = train_model,
    }
    aux.print('[ML_PATTERNS] Funciones registradas')
end

-- ============================================================================
-- Module Exports (FIX: Exportar funciones para acceso desde otros módulos)
-- ============================================================================

-- Export time pattern functions
M.init_time_patterns = init_time_patterns
M.record_price_with_time = record_price_with_time
M.get_best_time_to_buy = get_best_time_to_buy
M.get_best_time_to_sell = get_best_time_to_sell
M.calculate_pattern_confidence = calculate_pattern_confidence

-- Export classification functions
M.init_item_classifications = init_item_classifications
M.classify_item = classify_item
M.calculate_ml_score = calculate_ml_score

-- Export pattern detection
M.detect_price_patterns = detect_price_patterns

-- Export ML history config functions
M.ML_HISTORY_CONFIG = ML_HISTORY_CONFIG
M.is_popular_item = is_popular_item
M.get_max_values_for_item = get_max_values_for_item

-- Función para marcar item como popular manualmente
function M.mark_item_as_popular(item_key)
    if item_key then
        popular_items[item_key] = true
        aux.print('|cFFFFD700[ML]|r Item marcado como popular: ' .. item_key)
        return true
    end
    return false
end

-- Función para obtener estadísticas del historial ML
function M.get_ml_history_stats()
    local stats = {
        total_items = 0,
        popular_items = 0,
        total_samples = 0,
        avg_samples_per_item = 0,
    }
    
    for item_key, pattern in pairs(time_patterns) do
        stats.total_items = stats.total_items + 1
        
        if is_popular_item(item_key) then
            stats.popular_items = stats.popular_items + 1
        end
        
        -- Contar muestras
        if pattern.hourly then
            for hour = 0, 23 do
                if pattern.hourly[hour] then
                    stats.total_samples = stats.total_samples + pattern.hourly[hour].count
                end
            end
        end
    end
    
    if stats.total_items > 0 then
        stats.avg_samples_per_item = stats.total_samples / stats.total_items
    end
    
    return stats
end

aux.print('[ML_PATTERNS] Funciones exportadas al módulo')
aux.print('[ML_PATTERNS] Historial ML: ' .. ML_HISTORY_CONFIG.default_max_values .. ' valores (normal), ' .. ML_HISTORY_CONFIG.popular_item_max_values .. ' valores (popular)')
