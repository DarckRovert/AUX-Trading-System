module 'aux.tabs.trading'

--[[
    PRICE HISTORY MODULE
    Persistent storage of market prices across sessions
    
    Data is stored in SavedVariables: AuxPriceHistory
]]

local aux = require 'aux'
local info = require 'aux.util.info'

local M = getfenv()

-- Configuration
local CONFIG = {
    max_samples = 100,          -- Max samples per item before averaging
    stale_days = 30,            -- Remove data older than this
    min_samples_for_trend = 5,  -- Minimum samples to calculate trend
    trend_lookback = 10,        -- Number of recent samples for trend
}

-- Initialize global if not exists
function M.init_price_history()
    if not AuxPriceHistory then
        AuxPriceHistory = {}
    end
    if not AuxPriceHistory.items then
        AuxPriceHistory.items = {}
    end
    if not AuxPriceHistory.last_cleanup then
        AuxPriceHistory.last_cleanup = time()
    end
end

-- Get current timestamp
local function get_timestamp()
    return time()
end

-- Get item entry, create if not exists
local function get_or_create_entry(item_key)
    M.init_price_history()
    
    if not AuxPriceHistory.items[item_key] then
        AuxPriceHistory.items[item_key] = {
            prices = {},           -- Array of {price, timestamp}
            market_value = nil,    -- Calculated average
            min_seen = nil,
            max_seen = nil,
            last_seen = nil,
            sample_count = 0,
            trend = "unknown",     -- up, down, stable, unknown
        }
    end
    return AuxPriceHistory.items[item_key]
end

-- Record a price observation
function M.record_price(item_key, unit_price)
    if not item_key or not unit_price or unit_price <= 0 then return end
    
    local entry = get_or_create_entry(item_key)
    local ts = get_timestamp()
    
    -- Add to price samples
    table.insert(entry.prices, {
        price = unit_price,
        time = ts,
    })
    
    -- Trim old samples if too many
    while table.getn(entry.prices) > CONFIG.max_samples do
        table.remove(entry.prices, 1)
    end
    
    -- Update statistics
    entry.sample_count = table.getn(entry.prices)
    entry.last_seen = ts
    
    -- Update min/max
    if not entry.min_seen or unit_price < entry.min_seen then
        entry.min_seen = unit_price
    end
    if not entry.max_seen or unit_price > entry.max_seen then
        entry.max_seen = unit_price
    end
    
    -- Recalculate market value (weighted average, recent prices matter more)
    M.recalculate_market_value(item_key)
    
    -- Calculate trend
    M.calculate_trend(item_key)
end

-- Recalculate market value from samples
function M.recalculate_market_value(item_key)
    local entry = AuxPriceHistory.items[item_key]
    if not entry or entry.sample_count == 0 then return end
    
    local total = 0
    local weight_sum = 0
    local now = get_timestamp()
    
    for i, sample in ipairs(entry.prices) do
        -- Weight: more recent = higher weight
        local age_hours = (now - sample.time) / 3600
        local weight = math.max(0.1, 1 - (age_hours / (CONFIG.stale_days * 24)))
        
        total = total + (sample.price * weight)
        weight_sum = weight_sum + weight
    end
    
    if weight_sum > 0 then
        entry.market_value = math.floor(total / weight_sum)
    end
end

-- Calculate price trend
function M.calculate_trend(item_key)
    local entry = AuxPriceHistory.items[item_key]
    if not entry or entry.sample_count < CONFIG.min_samples_for_trend then
        entry.trend = "unknown"
        return
    end
    
    -- Compare recent vs older prices
    local prices = entry.prices
    local count = table.getn(prices)
    local lookback = math.min(CONFIG.trend_lookback, math.floor(count / 2))
    
    if lookback < 2 then
        entry.trend = "unknown"
        return
    end
    
    -- Average of recent samples
    local recent_sum = 0
    for i = count - lookback + 1, count do
        recent_sum = recent_sum + prices[i].price
    end
    local recent_avg = recent_sum / lookback
    
    -- Average of older samples
    local older_sum = 0
    for i = 1, lookback do
        older_sum = older_sum + prices[i].price
    end
    local older_avg = older_sum / lookback
    
    -- Calculate change percentage
    if older_avg > 0 then
        local change = (recent_avg - older_avg) / older_avg
        
        if change > 0.10 then
            entry.trend = "up"
        elseif change < -0.10 then
            entry.trend = "down"
        else
            entry.trend = "stable"
        end
    end
end

-- Get stored market value for an item
function M.get_market_value(item_key)
    M.init_price_history()
    
    local entry = AuxPriceHistory.items[item_key]
    if entry and entry.market_value then
        return entry.market_value
    end
    return nil
end

-- Get all stored data for an item
function M.get_price_data(item_key)
    M.init_price_history()
    return AuxPriceHistory.items[item_key]
end

-- Get trend for an item
function M.get_trend(item_key)
    M.init_price_history()
    
    local entry = AuxPriceHistory.items[item_key]
    if entry then
        return entry.trend or "unknown"
    end
    return "unknown"
end

-- Get trend icon for display
function M.get_trend_icon(item_key)
    local trend = M.get_trend(item_key)
    if trend == "up" then
        return "|cFF00FF00↑|r"
    elseif trend == "down" then
        return "|cFFFF0000↓|r"
    elseif trend == "stable" then
        return "|cFFFFFF00→|r"
    else
        return "|cFF888888?|r"
    end
end

-- Cleanup old data
function M.cleanup_price_history()
    M.init_price_history()
    
    local now = get_timestamp()
    local stale_threshold = now - (CONFIG.stale_days * 24 * 3600)
    local removed = 0
    
    for item_key, entry in pairs(AuxPriceHistory.items) do
        -- Remove entries not seen recently
        if entry.last_seen and entry.last_seen < stale_threshold then
            AuxPriceHistory.items[item_key] = nil
            removed = removed + 1
        else
            -- Clean old price samples
            local new_prices = {}
            for _, sample in ipairs(entry.prices or {}) do
                if sample.time >= stale_threshold then
                    table.insert(new_prices, sample)
                end
            end
            entry.prices = new_prices
            entry.sample_count = table.getn(new_prices)
            
            -- Recalculate if we removed samples
            if entry.sample_count > 0 then
                M.recalculate_market_value(item_key)
            end
        end
    end
    
    AuxPriceHistory.last_cleanup = now
    
    if removed > 0 then
        aux.print(string.format("|cFF888888[Price History] Cleaned up %d stale entries|r", removed))
    end
end

-- Get statistics about stored data
function M.get_price_history_stats()
    M.init_price_history()
    
    local item_count = 0
    local sample_count = 0
    
    for _, entry in pairs(AuxPriceHistory.items) do
        item_count = item_count + 1
        sample_count = sample_count + (entry.sample_count or 0)
    end
    
    return {
        items = item_count,
        samples = sample_count,
        last_cleanup = AuxPriceHistory.last_cleanup,
    }
end

-- Bulk record from scan results
function M.bulk_record_prices(records)
    if not records then return end
    
    local count = 0
    for _, record in ipairs(records) do
        if record.item_key and record.unit_buyout_price and record.unit_buyout_price > 0 then
            M.record_price(record.item_key, record.unit_buyout_price)
            count = count + 1
        end
    end
    
    return count
end

-- Export price history functions to M
M.price_history = {
    record_price = M.record_price,
    get_market_value = M.get_market_value,
    get_price_data = M.get_price_data,
    get_trend = M.get_trend,
    get_trend_icon = M.get_trend_icon,
    cleanup = M.cleanup_price_history,
    get_stats = M.get_price_history_stats,
    bulk_record = M.bulk_record_prices,
    init = M.init_price_history,
}

-- Auto-cleanup on load (once per day)
-- Auto-cleanup on load (once per day)
function aux.handle.LOAD()
    M.init_price_history()
    
    local now = get_timestamp()
    local last = AuxPriceHistory.last_cleanup or 0
    
    -- Cleanup if more than 24 hours since last
    if now - last > 86400 then
        M.cleanup_price_history()
    end
    
    local stats = M.get_price_history_stats()
    if stats.items > 0 then
        aux.print(string.format("|cFF888888[Price History] Loaded %d items with %d samples|r", stats.items, stats.samples))
    end
end
