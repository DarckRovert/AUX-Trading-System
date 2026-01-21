module 'aux.tabs.trading'

local aux = require 'aux'

-- ============================================================================
-- TOOLTIP SYSTEM - Sistema de Tooltips Explicativos
-- ============================================================================

aux.print('[TOOLTIPS] Módulo de tooltips cargado')

-- ============================================================================
-- Tooltip Definitions
-- ============================================================================

local TOOLTIPS = {
    -- Dashboard tooltips
    dashboard_profit = {
        title = 'Total Profit',
        lines = {
            'Your net profit from all trading activities.',
            ' ',
            '|cff00ff00Green|r = Profitable',
            '|cffff0000Red|r = Loss',
        },
    },
    
    dashboard_roi = {
        title = 'Return on Investment (ROI)',
        lines = {
            'Percentage return on your total investment.',
            ' ',
            'Formula: (Revenue - Investment) / Investment * 100',
            ' ',
            'Higher is better!',
        },
    },
    
    dashboard_success_rate = {
        title = 'Success Rate',
        lines = {
            'Percentage of trades that resulted in profit.',
            ' ',
            'Successful Trades / Total Trades * 100',
        },
    },
    
    dashboard_avg_profit = {
        title = 'Average Profit per Trade',
        lines = {
            'Average profit earned per completed trade.',
            ' ',
            'Total Net Profit / Total Trades',
        },
    },
    
    -- Strategy tooltips
    strategy_flip = {
        title = 'Flip Strategy',
        lines = {
            'Buy items below market value and resell at market price.',
            ' ',
            '|cff00ff00Best for:|r Items with high turnover',
            '|cffffff00Risk:|r Medium - Market prices can fluctuate',
            '|cff00ffffProfit:|r 10-30% per flip',
        },
    },
    
    strategy_snipe = {
        title = 'Snipe Strategy',
        lines = {
            'Quickly buy severely underpriced items.',
            ' ',
            '|cff00ff00Best for:|r Rare items, high-value goods',
            '|cffffff00Risk:|r Low - High profit margin',
            '|cff00ffffProfit:|r 50-200% per snipe',
            ' ',
            '|cffff8800Requires:|r Fast reaction time',
        },
    },
    
    strategy_reset = {
        title = 'Market Reset Strategy',
        lines = {
            'Buy all cheap supply and relist at higher price.',
            ' ',
            '|cff00ff00Best for:|r Low-supply markets',
            '|cffffff00Risk:|r High - Requires large capital',
            '|cff00ffffProfit:|r 30-100% if successful',
            ' ',
            '|cffff0000Warning:|r Can fail if new supply appears',
        },
    },
    
    strategy_craft = {
        title = 'Crafting Arbitrage',
        lines = {
            'Buy materials, craft items, sell for profit.',
            ' ',
            '|cff00ff00Best for:|r Items you can craft',
            '|cffffff00Risk:|r Low - Predictable costs',
            '|cff00ffffProfit:|r 20-50% per craft',
            ' ',
            '|cffff8800Note:|r Requires profession skills',
        },
    },
    
    strategy_transmute = {
        title = 'Transmute Strategy',
        lines = {
            'Buy materials for transmutes, sell products.',
            ' ',
            '|cff00ff00Best for:|r Alchemists',
            '|cffffff00Risk:|r Low - Daily cooldown limits supply',
            '|cff00ffffProfit:|r 50-150g per transmute',
            ' ',
            '|cffff8800Cooldown:|r Once per day',
        },
    },
    
    strategy_longterm = {
        title = 'Long-term Investment',
        lines = {
            'Buy items expected to increase in value over time.',
            ' ',
            '|cff00ff00Best for:|r Rare patterns, limited items',
            '|cffffff00Risk:|r Medium - Requires patience',
            '|cff00ffffProfit:|r 100-500% over weeks/months',
            ' ',
            '|cffff8800Requires:|r Market knowledge, patience',
        },
    },
    
    -- Automation tooltips
    auto_buy = {
        title = 'Auto-Buy',
        lines = {
            'Automatically purchase items matching your criteria.',
            ' ',
            '|cff00ff00Features:|r',
            '- Scans auction house continuously',
            '- Buys items below target price',
            '- Respects budget limits',
            ' ',
            '|cffffff00Warning:|r Monitor your gold!',
        },
    },
    
    auto_post = {
        title = 'Auto-Post',
        lines = {
            'Automatically post items from your inventory.',
            ' ',
            '|cff00ff00Features:|r',
            '- Posts at competitive prices',
            '- Undercuts competition automatically',
            '- Manages auction duration',
            ' ',
            '|cffff8800Tip:|r Set undercut amount carefully',
        },
    },
    
    auto_repost = {
        title = 'Auto-Repost',
        lines = {
            'Automatically repost expired auctions.',
            ' ',
            '|cff00ff00Features:|r',
            '- Detects expired auctions',
            '- Reposts at updated prices',
            '- Saves time on manual reposting',
        },
    },
    
    -- Market Analysis tooltips
    market_trend = {
        title = 'Market Trend',
        lines = {
            'Direction of price movement over time.',
            ' ',
            '|cff00ff00Rising|r - Prices increasing',
            '|cffffff00Stable|r - Prices steady',
            '|cffff0000Falling|r - Prices decreasing',
            ' ',
            'Based on last 7 days of data',
        },
    },
    
    market_volatility = {
        title = 'Market Volatility',
        lines = {
            'How much prices fluctuate.',
            ' ',
            '|cff00ff00Low|r - Stable, predictable',
            '|cffffff00Medium|r - Some variation',
            '|cffff0000High|r - Unpredictable, risky',
            ' ',
            'Higher volatility = Higher risk/reward',
        },
    },
    
    market_competition = {
        title = 'Competition Level',
        lines = {
            'Number of sellers in this market.',
            ' ',
            '|cff00ff00Low|r - Few sellers, easier to profit',
            '|cffffff00Medium|r - Moderate competition',
            '|cffff0000High|r - Many sellers, harder to profit',
        },
    },
    
    market_demand = {
        title = 'Demand Level',
        lines = {
            'How quickly items sell.',
            ' ',
            '|cff00ff00High|r - Sells quickly',
            '|cffffff00Medium|r - Moderate sell speed',
            '|cffff0000Low|r - Sells slowly',
            ' ',
            'Based on sales velocity',
        },
    },
    
    -- ML Predictions
    ml_prediction = {
        title = 'ML Price Prediction',
        lines = {
            'Machine learning predicted future price.',
            ' ',
            'Based on:',
            '- Historical price patterns',
            '- Time of day/week trends',
            '- Market cycles',
            ' ',
            '|cffffff00Accuracy:|r ~70-85%',
        },
    },
    
    ml_confidence = {
        title = 'Prediction Confidence',
        lines = {
            'How confident the ML model is.',
            ' ',
            '|cff00ff00High|r - Very reliable prediction',
            '|cffffff00Medium|r - Moderately reliable',
            '|cffff0000Low|r - Less reliable, use caution',
        },
    },
    
    -- Settings tooltips
    setting_budget = {
        title = 'Trading Budget',
        lines = {
            'Maximum gold to spend on trading.',
            ' ',
            'Auto-buy will stop when budget is reached.',
            ' ',
            '|cffffff00Tip:|r Start with 10-20% of total gold',
        },
    },
    
    setting_undercut = {
        title = 'Undercut Amount',
        lines = {
            'How much to undercut competition.',
            ' ',
            '|cff00ff00Copper:|r Minimal undercut (1c)',
            '|cffffff00Percentage:|r % below lowest price',
            '|cffff0000Fixed:|r Specific amount',
            ' ',
            '|cffff8800Recommended:|r 1-5%',
        },
    },
    
    setting_scan_interval = {
        title = 'Scan Interval',
        lines = {
            'How often to scan the auction house.',
            ' ',
            '|cff00ff00Fast:|r Every 30 seconds',
            '|cffffff00Normal:|r Every 2 minutes',
            '|cffff0000Slow:|r Every 5 minutes',
            ' ',
            '|cffff8800Note:|r Faster = More CPU usage',
        },
    },
}

-- ============================================================================
-- Tooltip Display Functions
-- ============================================================================

function show_tooltip(frame, tooltip_key, anchor_point)
    if not TOOLTIPS[tooltip_key] then
        return
    end
    
    local tooltip_data = TOOLTIPS[tooltip_key]
    anchor_point = anchor_point or 'ANCHOR_RIGHT'
    
    GameTooltip:SetOwner(frame, anchor_point)
    GameTooltip:ClearLines()
    
    -- Título
    GameTooltip:AddLine(tooltip_data.title, 1, 0.82, 0, 1)
    
    -- Líneas
    for i, line in ipairs(tooltip_data.lines) do
        GameTooltip:AddLine(line, 1, 1, 1, 1)
    end
    
    GameTooltip:Show()
end

function hide_tooltip()
    GameTooltip:Hide()
end

-- ============================================================================
-- Helper Function to Add Tooltip to Frame
-- ============================================================================

function add_tooltip_to_frame(frame, tooltip_key, anchor_point)
    if not frame or not tooltip_key then
        return
    end
    
    frame:SetScript('OnEnter', function()
        show_tooltip(this, tooltip_key, anchor_point)
    end)
    
    frame:SetScript('OnLeave', function()
        hide_tooltip()
    end)
end

-- ============================================================================
-- Item Tooltip Enhancement
-- ============================================================================

function enhance_item_tooltip(item_key)
    if not item_key then
        return
    end
    
    -- Obtener datos de mercado
    local market_price = get_market_price and get_market_price(item_key) or 0
    local competition = get_current_competition and get_current_competition(item_key) or {}
    
    -- Añadir información de trading al tooltip
    if market_price > 0 then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('|cff00ff00Trading Info|r')
        GameTooltip:AddDoubleLine('Market Price:', format_money(market_price), 1, 1, 1, 1, 1, 1)
        
        if competition.lowest_price then
            GameTooltip:AddDoubleLine('Lowest Price:', format_money(competition.lowest_price), 1, 1, 1, 1, 1, 1)
        end
        
        if competition.avg_price then
            GameTooltip:AddDoubleLine('Average Price:', format_money(competition.avg_price), 1, 1, 1, 1, 1, 1)
        end
        
        if competition.num_auctions then
            GameTooltip:AddDoubleLine('Auctions:', tostring(competition.num_auctions), 1, 1, 1, 1, 1, 1)
        end
    end
    
    -- Obtener predicción ML si está disponible
    if M.modules and M.modules.ml_patterns and M.modules.ml_patterns.predict_price then
        local prediction = M.modules.ml_patterns.predict_price(item_key)
        
        if prediction and prediction.predicted_price then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine('|cff00ccffML Prediction|r')
            GameTooltip:AddDoubleLine('Predicted Price:', format_money(prediction.predicted_price), 0.5, 0.8, 1, 1, 1, 1)
            
            if prediction.confidence then
                local confidence_text = string.format('%.0f%%', prediction.confidence * 100)
                local r, g, b = 1, 0, 0
                
                if prediction.confidence > 0.7 then
                    r, g, b = 0, 1, 0
                elseif prediction.confidence > 0.5 then
                    r, g, b = 1, 1, 0
                end
                
                GameTooltip:AddDoubleLine('Confidence:', confidence_text, 1, 1, 1, r, g, b)
            end
        end
    end
    
    -- Obtener nuestros trades activos
    if M.modules and M.modules.core and M.modules.core.get_active_trades then
        local active_trades = M.modules.core.get_active_trades()
        local our_trades = {}
        
        for i, trade in ipairs(active_trades) do
            if trade.item_key == item_key then
                tinsert(our_trades, trade)
            end
        end
        
        if getn(our_trades) > 0 then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine('|cffffff00Your Active Trades|r')
            
            for i, trade in ipairs(our_trades) do
                if trade.status == 'posted' then
                    GameTooltip:AddDoubleLine('Posted at:', format_money(trade.sell_price), 1, 1, 1, 1, 1, 1)
                elseif trade.status == 'active' then
                    GameTooltip:AddDoubleLine('Bought for:', format_money(trade.buy_price), 1, 1, 1, 1, 1, 1)
                end
            end
        end
    end
end

-- Hook into item tooltips
local original_SetAuctionItem = GameTooltip.SetAuctionItem
GameTooltip.SetAuctionItem = function(self, type, index)
    original_SetAuctionItem(self, type, index)
    
    -- Obtener item info
    local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bid, highBidder, owner = GetAuctionItemInfo(type, index)
    
    if name then
        local item_key = name -- Simplificado, debería incluir suffix_id
        enhance_item_tooltip(item_key)
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    aux.print('[TOOLTIPS] Sistema de tooltips inicializado')
end)

-- ============================================================================
-- Public API
-- ============================================================================

local M = getfenv()
if M.modules then
    M.modules.tooltips = {
        show = show_tooltip,
        hide = hide_tooltip,
        add_to_frame = add_tooltip_to_frame,
        enhance_item = enhance_item_tooltip,
        definitions = TOOLTIPS,
    }
    aux.print('[TOOLTIPS] Funciones registradas en M.modules.tooltips')
end
