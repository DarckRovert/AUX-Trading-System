module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- UI Integration - Conecta Backend con Frontend
-- ============================================================================

aux.print('[UI_INTEGRATION] Módulo de integración UI cargado')

-- ============================================================================
-- Referencias a Módulos Backend
-- ============================================================================

-- Este módulo actúa como puente entre las UIs y los módulos backend
-- Proporciona una API limpia para que las UIs accedan a la funcionalidad

-- ============================================================================
-- Dashboard Integration
-- ============================================================================

-- Obtener datos del dashboard para mostrar en UI
function M.get_dashboard_data_for_ui()
    -- Llamar a la función del módulo dashboard
    if M.get_dashboard_data then
        return M.get_dashboard_data()
    end
    
    -- Datos por defecto si el módulo no está disponible
    return {
        today = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            win_rate = 0,
            roi = 0,
            avg_profit = 0,
        },
        week = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            win_rate = 0,
            roi = 0,
            avg_profit = 0,
        },
        month = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            win_rate = 0,
            roi = 0,
            avg_profit = 0,
        },
        all_time = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            win_rate = 0,
            roi = 0,
            avg_profit = 0,
            best_trade = nil,
            worst_trade = nil,
        },
    }
end

-- Obtener datos de gráficos
function M.get_chart_data_for_ui(days)
    days = days or 30
    
    if M.get_profit_chart_data then
        return M.get_profit_chart_data(days)
    end
    
    return {}
end

-- Obtener top items
function M.get_top_items_for_ui(limit)
    limit = limit or 10
    
    if M.get_top_items_by_profit then
        return M.get_top_items_by_profit(limit)
    end
    
    return {}
end

-- Obtener historial de trades
function M.get_trade_history_for_ui(filters)
    if M.get_trade_history then
        return M.get_trade_history(filters)
    end
    
    return {}
end

-- Obtener métricas de performance
function M.get_performance_metrics_for_ui()
    if M.calculate_performance_metrics then
        return M.calculate_performance_metrics()
    end
    
    return {
        roi = 0,
        profit_factor = 0,
        max_drawdown = 0,
        volatility = 0,
        trades_per_day = 0,
    }
end

-- Exportar reporte
function M.export_report_for_ui()
    if M.export_report_to_chat then
        M.export_report_to_chat()
        return true
    end
    
    aux.print('|cFFFF4444[Trading]|r Función de exportar reporte no disponible')
    return false
end

-- ============================================================================
-- Automation Integration
-- ============================================================================

-- Obtener configuración de auto-posting
function M.get_auto_post_config_for_ui()
    if M.get_auto_post_config then
        return M.get_auto_post_config()
    end
    
    -- Configuración por defecto
    return {
        enabled = false,
        pricing_strategy = 'undercut',
        undercut_amount = 100,
        min_profit_margin = 0.10,
        max_undercut_percent = 0.05,
        use_ml_pricing = true,
        auto_repost = true,
        check_interval = 300,
    }
end

-- Actualizar configuración de auto-posting
function M.update_auto_post_config_for_ui(config)
    if M.set_auto_post_config then
        M.set_auto_post_config(config)
        aux.print('|cFF00FF00[Trading]|r Configuración de auto-posting actualizada')
        return true
    end
    
    aux.print('|cFFFF4444[Trading]|r No se pudo actualizar la configuración')
    return false
end

-- Calcular precio óptimo
function M.calculate_optimal_price_for_ui(item_key, item_count)
    if M.calculate_optimal_price then
        return M.calculate_optimal_price(item_key, item_count)
    end
    
    return {
        success = false,
        reason = 'function_not_available',
        suggested_price = 0,
    }
end

-- Habilitar/deshabilitar auto-posting
function M.toggle_auto_post_for_ui(enabled)
    if M.set_auto_post_enabled then
        M.set_auto_post_enabled(enabled)
        local status = enabled and 'habilitado' or 'deshabilitado'
        aux.print('|cFF00FF00[Trading]|r Auto-posting ' .. status)
        return true
    end
    
    return false
end

-- Cambiar estrategia de pricing
function M.set_pricing_strategy_for_ui(strategy)
    if M.set_pricing_strategy then
        M.set_pricing_strategy(strategy)
        aux.print('|cFF00FF00[Trading]|r Estrategia cambiada a: ' .. strategy)
        return true
    end
    
    return false
end

-- Habilitar/deshabilitar auto-repost
function M.toggle_auto_repost_for_ui(enabled)
    if M.set_auto_repost then
        M.set_auto_repost(enabled)
        local status = enabled and 'habilitado' or 'deshabilitado'
        aux.print('|cFF00FF00[Trading]|r Auto-repost ' .. status)
        return true
    end
    
    return false
end

-- Verificar undercuts manualmente
function M.check_undercuts_for_ui()
    if M.check_for_undercuts then
        aux.print('|cFF00FF00[Trading]|r Verificando undercuts...')
        M.check_for_undercuts()
        return true
    end
    
    return false
end

-- ============================================================================
-- Config Integration
-- ============================================================================

-- Obtener configuración de estrategias
function M.get_strategies_config_for_ui()
    local config = {}
    
    -- Flipping
    if M.get_flipping_config then
        config.flipping = M.get_flipping_config()
    else
        config.flipping = {
            enabled = true,
            min_profit_margin = 0.15,
            max_investment_per_item = 50000,
            target_roi = 0.25,
        }
    end
    
    -- Sniping
    if M.get_sniping_config then
        config.sniping = M.get_sniping_config()
    else
        config.sniping = {
            enabled = true,
            min_discount = 0.40,
            auto_buy = false,
            max_price = 100000,
            confidence_threshold = 0.7,
        }
    end
    
    -- Market Reset
    if M.get_reset_config then
        config.market_reset = M.get_reset_config()
    else
        config.market_reset = {
            enabled = false,
            min_market_control = 0.70,
            max_investment = 500000,
            min_markup = 0.30,
        }
    end
    
    -- Arbitrage
    if M.get_arbitrage_config then
        config.arbitrage = M.get_arbitrage_config()
    else
        config.arbitrage = {
            enabled = true,
            min_difference = 0.20,
        }
    end
    
    return config
end

-- Actualizar configuración de estrategias
function M.update_strategies_config_for_ui(strategy_name, config)
    local success = false
    
    if strategy_name == 'flipping' and M.set_flipping_config then
        M.set_flipping_config(config)
        success = true
    elseif strategy_name == 'sniping' and M.set_sniping_config then
        M.set_sniping_config(config)
        success = true
    elseif strategy_name == 'market_reset' and M.set_reset_config then
        M.set_reset_config(config)
        success = true
    elseif strategy_name == 'arbitrage' and M.set_arbitrage_config then
        M.set_arbitrage_config(config)
        success = true
    end
    
    if success then
        aux.print('|cFF00FF00[Trading]|r Configuración de ' .. strategy_name .. ' actualizada')
    else
        aux.print('|cFFFF4444[Trading]|r No se pudo actualizar ' .. strategy_name)
    end
    
    return success
end

-- Aplicar perfil predefinido
function M.apply_profile_for_ui(profile_name)
    -- Los perfiles están definidos en config_ui.lua
    -- Esta función aplicaría todas las configuraciones del perfil
    
    aux.print('|cFF00FF00[Trading]|r Aplicando perfil: ' .. profile_name)
    
    -- TODO: Implementar aplicación de perfiles
    -- Por ahora solo mostramos el mensaje
    
    return true
end

-- ============================================================================
-- Market Analysis Integration
-- ============================================================================

-- Analizar oportunidad de trading
function M.analyze_opportunity_for_ui(item_key, buyout_price)
    if not M.select_best_strategy then
        return {
            viable = false,
            reason = 'analysis_not_available',
        }
    end
    
    local auction_info = {
        item_key = item_key,
        buyout_price = buyout_price,
    }
    
    return M.select_best_strategy(auction_info)
end

-- Obtener tendencia de precio
function M.get_price_trend_for_ui(item_key, days)
    days = days or 7
    
    if M.calculate_price_trend then
        return M.calculate_price_trend(item_key, days)
    end
    
    return {
        trend = 0,
        direction = 'stable',
        confidence = 0,
    }
end

-- Detectar manipulación de mercado
function M.detect_manipulation_for_ui(item_key)
    if M.detect_market_manipulation then
        return M.detect_market_manipulation(item_key)
    end
    
    return {
        is_manipulated = false,
        confidence = 0,
    }
end

-- Predecir precio futuro
function M.predict_price_for_ui(item_key, days_ahead)
    days_ahead = days_ahead or 3
    
    if M.predict_future_price then
        return M.predict_future_price(item_key, days_ahead)
    end
    
    return {
        predicted_price = 0,
        confidence = 0,
    }
end

-- ============================================================================
-- ML Patterns Integration
-- ============================================================================

-- Obtener mejor momento para comprar
function M.get_best_buy_time_for_ui(item_key)
    if M.get_best_time_to_buy then
        return M.get_best_time_to_buy(item_key)
    end
    
    return {
        available = false,
    }
end

-- Obtener mejor momento para vender
function M.get_best_sell_time_for_ui(item_key)
    if M.get_best_time_to_sell then
        return M.get_best_time_to_sell(item_key)
    end
    
    return {
        available = false,
    }
end

-- Clasificar item
function M.classify_item_for_ui(item_key)
    if M.classify_item then
        return M.classify_item(item_key)
    end
    
    return {
        classification = 'unknown',
        score = 0,
    }
end

-- ============================================================================
-- Scan Integration
-- ============================================================================

-- Escanear item para trading
function M.scan_item_for_ui(item_key, on_progress, on_complete)
    if M.scan_item_for_trading then
        M.scan_item_for_trading(item_key, on_progress, on_complete)
        return true
    end
    
    aux.print('|cFFFF4444[Trading]|r Función de scan no disponible')
    return false
end

-- Buscar oportunidades
function M.scan_opportunities_for_ui(config, on_progress, on_complete)
    if M.scan_for_opportunities then
        M.scan_for_opportunities(config, on_progress, on_complete)
        return true
    end
    
    aux.print('|cFFFF4444[Trading]|r Función de búsqueda no disponible')
    return false
end

-- ============================================================================
-- Notifications Integration
-- ============================================================================

-- Enviar notificación
function M.send_notification_for_ui(type, message, data)
    if M.send_notification then
        M.send_notification(type, message, data)
        return true
    end
    
    -- Fallback a print simple
    local color = '|cFFFFFFFF'
    if type == 'exceptional_opportunity' then
        color = '|cFFFFD700'
    elseif type == 'good_opportunity' then
        color = '|cFF00FF00'
    elseif type == 'warning' then
        color = '|cFFFFAA00'
    elseif type == 'error' then
        color = '|cFFFF4444'
    end
    
    aux.print(color .. '[Trading] ' .. message .. '|r')
    return true
end

-- ============================================================================
-- Helpers
-- ============================================================================

-- Verificar si un módulo está disponible
function M.is_module_available(module_name)
    local modules = {
        dashboard = M.get_dashboard_data ~= nil,
        automation = M.calculate_optimal_price ~= nil,
        strategies = M.select_best_strategy ~= nil,
        market_analysis = M.calculate_price_trend ~= nil,
        ml_patterns = M.get_best_time_to_buy ~= nil,
        scan_integration = M.scan_item_for_trading ~= nil,
        optimization = M.get_performance_stats ~= nil,
    }
    
    return modules[module_name] or false
end

-- Obtener estado de todos los módulos
function M.get_modules_status_for_ui()
    return {
        dashboard = M.is_module_available('dashboard'),
        automation = M.is_module_available('automation'),
        strategies = M.is_module_available('strategies'),
        market_analysis = M.is_module_available('market_analysis'),
        ml_patterns = M.is_module_available('ml_patterns'),
        scan_integration = M.is_module_available('scan_integration'),
        optimization = M.is_module_available('optimization'),
    }
end

-- ============================================================================
-- Inicialización
-- ============================================================================

function M.init_ui_integration()
    aux.print('[UI_INTEGRATION] Inicializando integración UI...')
    
    -- Verificar módulos disponibles
    local status = M.get_modules_status_for_ui()
    
    aux.print('[UI_INTEGRATION] Estado de módulos:')
    for module, available in pairs(status) do
        local status_text = available and '|cFF00FF00✓|r' or '|cFFFF4444✗|r'
        aux.print('  ' .. status_text .. ' ' .. module)
    end
    
    aux.print('[UI_INTEGRATION] Integración UI lista')
end

-- Inicializar al cargar
M.init_ui_integration()

aux.print('[UI_INTEGRATION] Módulo de integración UI completamente cargado')
