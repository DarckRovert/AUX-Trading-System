module 'aux.tabs.trading'

--[[
    INTEGRATION MODULE
    Public API for external addon integration
    
    Exposes market data and trading functions to other addons via global namespace
]]

local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'

local M = getfenv()

-- ============================================================================
-- Global API Namespace
-- ============================================================================

-- Create global API accessible from other addons
AUX_TRADING_API = AUX_TRADING_API or {}

-- ============================================================================
-- Market Value Functions
-- ============================================================================

-- Get market value for an item (copper)
-- @param item_key: The item key string (e.g., "6948:0:0")
-- @return number|nil: Market value in copper, or nil if unknown
function AUX_TRADING_API.GetMarketValue(item_key)
    if not item_key then return nil end
    
    -- Try price_history first
    if M.price_history and M.price_history.get_market_value then
        local value = M.price_history.get_market_value(item_key)
        if value then return value end
    end
    
    -- Fallback to core history
    if history and history.value then
        return history.value(item_key)
    end
    
    return nil
end

-- Get market value by item ID (convenience function)
-- @param item_id: The numeric item ID
-- @return number|nil: Market value in copper, or nil if unknown
function AUX_TRADING_API.GetMarketValueByID(item_id)
    if not item_id then return nil end
    
    -- Try to construct item_key
    local item_key = item_id .. ":0:0"
    return AUX_TRADING_API.GetMarketValue(item_key)
end

-- ============================================================================
-- Price History Functions
-- ============================================================================

-- Get full price data for an item
-- @param item_key: The item key string
-- @return table|nil: Price data table with market_value, min_seen, max_seen, trend
function AUX_TRADING_API.GetPriceData(item_key)
    if M.price_history and M.price_history.get_price_data then
        return M.price_history.get_price_data(item_key)
    end
    return nil
end

-- Get price trend for an item
-- @param item_key: The item key string
-- @return string: "up", "down", "stable", or "unknown"
function AUX_TRADING_API.GetPriceTrend(item_key)
    if M.price_history and M.price_history.get_trend then
        return M.price_history.get_trend(item_key)
    end
    return "unknown"
end

-- Get price history statistics
-- @return table: {items = count, samples = count}
function AUX_TRADING_API.GetPriceHistoryStats()
    if M.price_history and M.price_history.get_stats then
        return M.price_history.get_stats()
    end
    return { items = 0, samples = 0 }
end

-- ============================================================================
-- Profit & Analytics Functions
-- ============================================================================

-- Get daily profit data for last N days
-- @param days: Number of days (default 7)
-- @return table: Array of {date, sales, purchases, profit, count}
function AUX_TRADING_API.GetProfitData(days)
    if M.modules.dashboard and M.modules.dashboard.get_real_profit_data then
        return M.modules.dashboard.get_real_profit_data(days or 7)
    end
    return {}
end

-- Get top profitable items
-- @param limit: Max number of items (default 10)
-- @return table: Array of {item_key, name, revenue, quantity, avg_price}
function AUX_TRADING_API.GetTopProfitableItems(limit)
    if M.modules.dashboard and M.modules.dashboard.get_top_profitable_items then
        return M.modules.dashboard.get_top_profitable_items(limit or 10)
    end
    return {}
end

-- Get dashboard summary data
-- @return table: Full dashboard data object
function AUX_TRADING_API.GetDashboardData()
    if M.modules.dashboard and M.modules.dashboard.get_dashboard_data then
        return M.modules.dashboard.get_dashboard_data()
    end
    return nil
end

-- ============================================================================
-- Sniper Functions
-- ============================================================================

-- Get current sniper deals
-- @return table: Array of current sniper opportunities
function AUX_TRADING_API.GetSniperDeals()
    if M.get_sniper_deals then
        return M.get_sniper_deals()
    end
    return {}
end

-- Check if sniper is running
-- @return boolean: true if sniper is active
function AUX_TRADING_API.IsSniperRunning()
    if M.is_sniper_running then
        return M.is_sniper_running()
    end
    return false
end

-- ============================================================================
-- Callback System
-- ============================================================================

local callbacks = {
    price_update = {},
    sniper_deal = {},
    sale_complete = {},
    purchase_complete = {},
}

-- Register a callback for events
-- @param event: Event name ("price_update", "sniper_deal", "sale_complete", "purchase_complete")
-- @param callback: Function to call when event fires
-- @return number: Callback ID for unregistering
function AUX_TRADING_API.RegisterCallback(event, callback)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    
    local id = table.getn(callbacks[event]) + 1
    callbacks[event][id] = callback
    return id
end

-- Unregister a callback
-- @param event: Event name
-- @param id: Callback ID from RegisterCallback
function AUX_TRADING_API.UnregisterCallback(event, id)
    if callbacks[event] and callbacks[event][id] then
        callbacks[event][id] = nil
    end
end

-- Fire callbacks (internal use)
function M.fire_integration_callback(event, ...)
    if callbacks[event] then
        for _, callback in pairs(callbacks[event]) do
            pcall(callback, unpack(arg))
        end
    end
end

-- ============================================================================
-- Tooltip Integration
-- ============================================================================

-- Get tooltip text for an item (for tooltip addons)
-- @param item_key: The item key string
-- @return table: {market_value_text, trend_text, min_text, max_text}
function AUX_TRADING_API.GetTooltipInfo(item_key)
    local market_value = AUX_TRADING_API.GetMarketValue(item_key)
    local trend = AUX_TRADING_API.GetPriceTrend(item_key)
    local price_data = AUX_TRADING_API.GetPriceData(item_key)
    
    local result = {
        has_data = market_value ~= nil,
        market_value = market_value or 0,
        market_value_text = "",
        trend = trend,
        trend_icon = "",
        min_seen = 0,
        max_seen = 0,
        sample_count = 0,
    }
    
    if market_value then
        local gold = math.floor(market_value / 10000)
        local silver = math.floor(math.mod(market_value, 10000) / 100)
        local copper = math.mod(market_value, 100)
        result.market_value_text = string.format("%dg %ds %dc", gold, silver, copper)
    end
    
    if trend == "up" then
        result.trend_icon = "|cFF00FF00↑|r"
    elseif trend == "down" then
        result.trend_icon = "|cFFFF0000↓|r"
    elseif trend == "stable" then
        result.trend_icon = "|cFFFFFF00→|r"
    else
        result.trend_icon = "|cFF888888?|r"
    end
    
    if price_data then
        result.min_seen = price_data.min_seen or 0
        result.max_seen = price_data.max_seen or 0
        result.sample_count = price_data.sample_count or 0
    end
    
    return result
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Format money value to string
-- @param copper: Amount in copper
-- @return string: Formatted string like "1g 23s 45c"
function AUX_TRADING_API.FormatMoney(copper)
    if not copper or copper == 0 then return "0c" end
    
    copper = math.floor(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    
    local result = ""
    if gold > 0 then result = result .. gold .. "g " end
    if silver > 0 then result = result .. silver .. "s " end
    if cop > 0 or result == "" then result = result .. cop .. "c" end
    
    return result
end

-- Get API version
-- @return string: Version string
function AUX_TRADING_API.GetVersion()
    return "1.0.0"
end

-- Check if API is available
-- @return boolean: Always true when this module is loaded
function AUX_TRADING_API.IsAvailable()
    return true
end

-- ============================================================================
-- Initialization
-- ============================================================================

function aux.handle.LOAD()
    aux.print("|cFF888888[Integration] AUX_TRADING_API loaded - Version " .. AUX_TRADING_API.GetVersion() .. "|r")
end

-- Export to module
M.integration = {
    fire_callback = M.fire_integration_callback,
}
