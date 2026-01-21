module 'aux.tabs.trading'

local aux = require 'aux'

-- ============================================================================
-- Database Management
-- ============================================================================

local profiles_db = {}

function init_database()
    aux.print('[PROFILES] Inicializando base de datos...')
    
    -- Initialize faction-specific data
    if not aux.faction_data then
        aux.print('[PROFILES ERROR] aux.faction_data no existe')
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {
            profiles = {},
            version = 1,
        }
        aux.print('[PROFILES] Base de datos creada')
    end
    
    profiles_db = aux.faction_data.trading.profiles
    local count = 0
    for _ in pairs(profiles_db) do count = count + 1 end
    aux.print('[PROFILES] Base de datos cargada. Items: ' .. tostring(count))
end

function get_profile(item_key)
    if not profiles_db[item_key] then
        create_default_profile(item_key)
    end
    return profiles_db[item_key]
end

function create_default_profile(item_key)
    profiles_db[item_key] = {
        item_key = item_key,
        avg_price = 0,
        min_price = 0,
        max_price = 0,
        sample_count = 0,
        last_seen = 0,
        confidence = 0,
    }
end

function update_profile_stats(item_key, price)
    local profile = get_profile(item_key)
    
    if profile.sample_count == 0 then
        profile.avg_price = price
        profile.min_price = price
        profile.max_price = price
    else
        -- Actualizar promedio
        local total = profile.avg_price * profile.sample_count
        profile.avg_price = (total + price) / (profile.sample_count + 1)
        
        -- Actualizar min/max
        if price < profile.min_price then
            profile.min_price = price
        end
        if price > profile.max_price then
            profile.max_price = price
        end
    end
    
    profile.sample_count = profile.sample_count + 1
    profile.last_seen = time()
    
    -- Calcular confianza (0-1) basado en cantidad de muestras
    if profile.sample_count >= 10 then
        profile.confidence = 1
    else
        profile.confidence = profile.sample_count / 10
    end
end

-- ============================================================================
-- Trade Management
-- ============================================================================

local trades_db = {}
local trade_counter = 0

function create_trade(auction_info, buy_price)
    trade_counter = trade_counter + 1
    
    local trade = {
        id = 'trade_' .. trade_counter .. '_' .. time(),
        item_key = auction_info.item_key,
        item_name = auction_info.item_name or 'Unknown',
        count = auction_info.count or 1,
        buy_price = buy_price,
        unit_buy_price = buy_price / (auction_info.count or 1),
        seller = auction_info.owner or 'Unknown',
        bought_at = time(),
        status = 'pending',  -- pending, sold, failed, expired
        sell_price = 0,
        buyer = nil,
        sold_at = 0,
        profit = 0,
    }
    
    return trade
end

function save_trade(trade)
    if not aux.faction_data or not aux.faction_data.trading then
        aux.print('[PROFILES ERROR] No se puede guardar trade - base de datos no inicializada')
        return
    end
    
    if not aux.faction_data.trading.trades then
        aux.faction_data.trading.trades = {}
    end
    
    aux.faction_data.trading.trades[trade.id] = trade
    aux.print('[PROFILES] Trade guardado: ' .. trade.item_name .. ' x' .. trade.count)
end

function get_trade(trade_id)
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return nil
    end
    return aux.faction_data.trading.trades[trade_id]
end

function update_trade_status(trade_id, status, sell_price, buyer)
    local trade = get_trade(trade_id)
    if not trade then
        return
    end
    
    trade.status = status
    
    if status == 'sold' then
        trade.sell_price = sell_price or 0
        trade.buyer = buyer or 'Unknown'
        trade.sold_at = time()
        trade.profit = trade.sell_price - trade.buy_price
        
        -- Actualizar estadísticas del perfil
        update_profile_stats(trade.item_key, trade.unit_buy_price)
    end
end

-- ============================================================================
-- Configuration
-- ============================================================================

function default_config()
    return {
        min_discount = 0.15,
        min_profit = 1000,
        min_roi = 0.10,
        max_buyout = 100000,
        auto_buy = false,
        scoring = {
            discount_weight = 0.4,
            profit_weight = 0.3,
            roi_weight = 0.2,
            confidence_weight = 0.1,
        },
    }
end

function get_config()
    if not aux.account_data then
        return default_config()
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {
            config = default_config(),
        }
    end
    
    return aux.account_data.trading.config or default_config()
end

function save_config(config)
    if not aux.account_data then
        aux.print('[PROFILES ERROR] No se puede guardar configuración')
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    aux.account_data.trading.config = config
    aux.print('[PROFILES] Configuración guardada')
end

-- ============================================================================
-- Event Handler
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_database()
end)
