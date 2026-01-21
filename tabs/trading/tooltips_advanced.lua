module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'
local M = getfenv()

-- ============================================================================
-- Advanced Tooltips - Tooltips Mejorados con Información Completa
-- ============================================================================

aux.print('[TOOLTIPS_ADVANCED] Módulo de tooltips avanzados cargado')

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================

-- Safe money formatting with fallback
local money = nil
pcall(function() money = require 'aux.util.money' end)

local function format_gold(copper)
    if money and money.to_string then
        return money.to_string(copper or 0)
    end
    -- Fallback
    if not copper or copper == 0 then return "|cFF8888880c|r" end
    copper = math.floor(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    local result = ""
    if gold > 0 then result = result .. "|cFFFFD700" .. gold .. "g|r " end
    if silver > 0 or gold > 0 then result = result .. "|cFFC0C0C0" .. silver .. "s|r " end
    if cop > 0 or (gold == 0 and silver == 0) then result = result .. "|cFFB87333" .. cop .. "c|r" end
    return result
end



local function color_trend(trend)
    if trend == 'rising' then return 0, 1, 0 end
    if trend == 'falling' then return 1, 0.27, 0.27 end
    return 1, 1, 1
end

-- ============================================================================
-- Mostrar Tooltip Avanzado
-- ============================================================================

function M.mostrar_tooltip_avanzado(item_key, item_name, auction_info)
    if not item_key then return end
    
    -- Título
    GameTooltip:AddLine(item_name or 'Item desconocido', 1, 0.82, 0)
    GameTooltip:AddLine(' ')
    
    -- Precio de mercado
    local market_value = history.value(item_key)
    if market_value and market_value > 0 then
        GameTooltip:AddDoubleLine('Precio de Mercado:', format_gold(market_value), 1, 1, 1, 0.5, 1, 0.5)
    end
    
    -- Precio de la subasta (si está disponible)
    if auction_info and auction_info.buyout_price then
        GameTooltip:AddDoubleLine('Precio Subasta:', format_gold(auction_info.buyout_price), 1, 1, 1, 1, 1, 1)
        
        -- Calcular descuento
        if market_value and market_value > 0 then
            local discount = ((market_value - auction_info.buyout_price) / market_value) * 100
            local profit = market_value - auction_info.buyout_price
            
            if discount > 0 then
                GameTooltip:AddDoubleLine('Descuento:', string.format('%.0f%%', discount), 1, 1, 1, 0, 1, 0)
                GameTooltip:AddDoubleLine('Ganancia Potencial:', format_gold(profit), 1, 1, 1, 0, 1, 0)
            else
                GameTooltip:AddDoubleLine('Sobreprecio:', string.format('%.0f%%', -discount), 1, 1, 1, 1, 0.27, 0.27)
            end
        end
    end
    
    GameTooltip:AddLine(' ')
    
    -- Histórico de precios
    local market_analysis = M.modules and M.modules.market_analysis
    if market_analysis then
        -- Obtener tendencia
        if market_analysis.calculate_price_trend then
            local trend, direction, confidence, change_percent = market_analysis.calculate_price_trend(item_key, 7)
            
            if trend and direction then
                local r, g, b = color_trend(direction)
                local trend_text = direction == 'rising' and '↑ Subiendo' or (direction == 'falling' and '↓ Bajando' or '→ Estable')
                GameTooltip:AddDoubleLine('Tendencia (7d):', trend_text, 1, 1, 1, r, g, b)
                
                if change_percent then
                    GameTooltip:AddDoubleLine('Cambio:', string.format('%.1f%%', change_percent * 100), 1, 1, 1, r, g, b)
                end
            end
        end
        
        -- Detección de manipulación
        if market_analysis.detect_market_manipulation then
            local is_manipulated, confidence, reason = market_analysis.detect_market_manipulation(item_key)
            
            if is_manipulated then
                GameTooltip:AddLine(' ')
                GameTooltip:AddLine('⚠ Posible Manipulación', 1, 0.65, 0)
                if reason then
                    GameTooltip:AddLine(reason, 0.8, 0.8, 0.8, true)
                end
            end
        end
        
        -- Volumen de ventas
        if market_analysis.get_average_daily_volume then
            local avg_volume = market_analysis.get_average_daily_volume(item_key, 7)
            if avg_volume and avg_volume > 0 then
                GameTooltip:AddLine(' ')
                GameTooltip:AddDoubleLine('Volumen Diario:', string.format('%.1f items', avg_volume), 1, 1, 1, 0.7, 0.7, 1)
            end
        end
    end
    
    -- Machine Learning - Mejor momento para vender
    local ml_patterns = M.modules and M.modules.ml_patterns
    if ml_patterns and ml_patterns.get_best_time_to_sell then
        local best_time = ml_patterns.get_best_time_to_sell(item_key)
        
        if best_time and best_time.best_hour and best_time.confidence and best_time.confidence > 0.5 then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine('💡 Recomendación ML', 0.7, 0.5, 1)
            
            local dias = {'Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'}
            local dia_nombre = best_time.best_day_name or (best_time.best_day and dias[best_time.best_day]) or '?'
            
            GameTooltip:AddDoubleLine('Mejor momento venta:', 
                string.format('%s %02d:00', dia_nombre, best_time.best_hour),
                1, 1, 1, 0, 1, 0.5)
        end
    end
    
    -- Clasificación del item
    if ml_patterns and ml_patterns.classify_item then
        local classification, score, success_rate = ml_patterns.classify_item(item_key)
        
        if classification and classification ~= 'unknown' then
            GameTooltip:AddLine(' ')
            local class_text = classification == 'highly_profitable' and '🏆 Muy Rentable' or
                              classification == 'profitable' and '✓ Rentable' or
                              classification == 'marginally_profitable' and '∼ Poco Rentable' or
                              '✖ No Rentable'
            
            local class_color = classification == 'highly_profitable' and {0, 1, 0} or
                               classification == 'profitable' and {0.5, 1, 0.5} or
                               classification == 'marginally_profitable' and {1, 1, 0} or
                               {1, 0.27, 0.27}
            
            GameTooltip:AddLine(class_text, unpack(class_color))
            
            if success_rate then
                GameTooltip:AddDoubleLine('Tasa de éxito:', string.format('%.0f%%', success_rate * 100), 1, 1, 1, unpack(class_color))
            end
        end
    end
    
    -- Estrategias recomendadas
    local strategies = M.modules and M.modules.strategies
    if strategies and auction_info then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('🎯 Estrategias', 1, 0.82, 0)
        
        -- Flipping
        if strategies.evaluate_flipping_opportunity then
            local flip_result = strategies.evaluate_flipping_opportunity(auction_info)
            if flip_result and flip_result.viable then
                GameTooltip:AddLine('✓ Flipping viable', 0, 1, 0)
            end
        end
        
        -- Sniping
        if strategies.evaluate_sniping_opportunity then
            local snipe_result = strategies.evaluate_sniping_opportunity(auction_info)
            if snipe_result and snipe_result.viable then
                GameTooltip:AddLine('✓ Sniping viable', 0, 1, 0)
            end
        end
    end
    
    -- Vendedor (si está disponible)
    if auction_info and auction_info.seller then
        GameTooltip:AddLine(' ')
        GameTooltip:AddDoubleLine('Vendedor:', auction_info.seller, 1, 1, 1, 0.5, 0.5, 0.5)
    end
    
    GameTooltip:Show()
end

-- ============================================================================
-- Tooltip para Oportunidad
-- ============================================================================

function M.mostrar_tooltip_oportunidad(oportunidad)
    if not oportunidad then return end
    
    local item_key = oportunidad.item_key or (oportunidad.auction_info and oportunidad.auction_info.item_key)
    local item_name = oportunidad.item_name or (oportunidad.auction_info and oportunidad.auction_info.name)
    local auction_info = oportunidad.auction_info or oportunidad
    
    M.mostrar_tooltip_avanzado(item_key, item_name, auction_info)
end

-- ============================================================================
-- Tooltip Simple (para items en inventario)
-- ============================================================================

function M.mostrar_tooltip_simple(item_key, item_name)
    if not item_key then return end
    
    GameTooltip:AddLine(item_name or 'Item desconocido', 1, 0.82, 0)
    GameTooltip:AddLine(' ')
    
    -- Precio de mercado
    local market_value = history.value(item_key)
    if market_value and market_value > 0 then
        GameTooltip:AddDoubleLine('Precio de Mercado:', format_gold(market_value), 1, 1, 1, 0.5, 1, 0.5)
    else
        GameTooltip:AddLine('Sin datos de mercado', 0.8, 0.8, 0.8)
    end
    
    GameTooltip:Show()
end

-- Registrar funciones en el módulo
if not M.modules then M.modules = {} end
if not M.modules.tooltips_advanced then M.modules.tooltips_advanced = {} end

M.modules.tooltips_advanced.mostrar_tooltip_avanzado = M.mostrar_tooltip_avanzado
M.modules.tooltips_advanced.mostrar_tooltip_oportunidad = M.mostrar_tooltip_oportunidad
M.modules.tooltips_advanced.mostrar_tooltip_simple = M.mostrar_tooltip_simple

aux.print('|cFF00FF00[TOOLTIPS_ADVANCED]|r Tooltips avanzados listos')
