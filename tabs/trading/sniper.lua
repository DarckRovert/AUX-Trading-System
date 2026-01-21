module 'aux.tabs.trading'

local T = require 'T'
local aux = require 'aux'
local history = require 'aux.core.history'
local money = require 'aux.util.money'
local info = require 'aux.util.info'

local M = getfenv()

--[[
    SNIPER MODE
    Refactored for correctness and performance.
]]

-- Configuration
local sniper_config = {
    enabled = false,
    min_profit_percent = 5,
    min_profit_gold = 1,
    max_price_gold = 1000,
    scan_interval = 0.5,
    sound_alert = true,
    auto_refresh = true,
    min_discount = 0.40, -- Default if missing
}

local function get_config()
    local global_cfg = M.get_config and M.get_config()
    if global_cfg and global_cfg.sniping then
        -- Merge defaults with global config
        local cfg = global_cfg.sniping
        -- Map global keys to sniper keys if different
        return {
            enabled = cfg.enabled,
            min_profit_percent = cfg.min_profit_percent or sniper_config.min_profit_percent,
            min_profit_gold = cfg.min_profit_gold or sniper_config.min_profit_gold,
            max_price_gold = cfg.max_price_gold or sniper_config.max_price_gold,
            scan_interval = cfg.scan_interval or sniper_config.scan_interval,
            sound_alert = cfg.sound_alert or sniper_config.sound_alert,
            min_discount = cfg.min_discount or sniper_config.min_discount
        }
    end
    return sniper_config
end

-- State
local sniper_state = {
    running = false,
    last_scan_time = 0,
    deals_found = 0,
    items_scanned = 0,
    current_deals = {}, -- We will not use T for this persistent list to avoid complex release logic, or careful manual management
    scan_count = 0,
    listener_id = nil,
}

local page_price_cache = {}

function M.clear_price_cache()
    page_price_cache = {}
end

-- Dedicated scanning frame (for the interval timer)
local sniper_frame = CreateFrame('Frame')
sniper_frame:Hide()

-- Revised evaluate_snipe accepting page_context
function M.evaluate_snipe(auction_record, page_context)
    local item_id = auction_record.item_id
    if not item_id then return end

    local buyout_price = auction_record.buyout_price
    if buyout_price == 0 then return end
    
    local stack_size = auction_record.aux_quantity
    local unit_buyout = buyout_price / stack_size
    
    local cfg = get_config()
    
    -- Max price check
    if unit_buyout > cfg.max_price_gold * 10000 then return end

    local item_key = auction_record.item_key
    
    -- PRIORITY 1: Try persistent price history first
    local market_value = nil
    local source = 'unknown'
    
    if M.price_history and M.price_history.get_market_value then
        market_value = M.price_history.get_market_value(item_key)
        if market_value then source = 'price_history' end
    end
    
    -- PRIORITY 2: Core history module
    if not market_value then
        market_value = history.value(item_key)
        if market_value then source = 'history' end
    end
    
    -- PRIORITY 3: Use page context if no history
    if not market_value and page_context and page_context[item_id] then
        local ctx = page_context[item_id]
        -- Heuristic: If we have multiple items and this one is cheaper than the max seen on page
        if ctx.count > 1 and ctx.max > unit_buyout then
             -- Use the max price on page as reference - relaxed threshold to 10%
             if (ctx.max - unit_buyout) / ctx.max > 0.10 then
                 market_value = ctx.max
                 source = 'page_local'
             end
        end
    end
    
    -- PRIORITY 4: Vendor price fallback
    if not market_value and auction_record.unit_buyout_price and auction_record.unit_buyout_price > 0 then
        local vendor_price = nil
        local item_info_data = info.item(item_id)
        if item_info_data and item_info_data.sell_price then
            vendor_price = item_info_data.sell_price
        end
        if vendor_price and vendor_price > unit_buyout then
            market_value = vendor_price
            source = 'vendor'
        end
    end
    
    -- ALWAYS record prices to persistent history for future reference
    if M.price_history and M.price_history.record_price and item_key and unit_buyout > 0 then
        M.price_history.record_price(item_key, unit_buyout)
    end

    if not market_value then return end

    local profit = market_value - unit_buyout
    if profit <= 0 then return end

    local percent_below = math.floor((profit / market_value) * 100)
    
    -- Threshold checks
    if profit < (cfg.min_profit_gold * 10000) then return end
    if percent_below < cfg.min_profit_percent then return end

    -- It's a deal
    local deal = T.acquire()
    deal.is_snipe = true
    deal.item_id = item_id
    deal.item_name = info.item(item_id).name
    deal.buyout_price = buyout_price
    deal.unit_buyout = unit_buyout
    deal.market_value = market_value * stack_size
    deal.profit = profit * stack_size
    deal.percent_below = percent_below
    deal.auction_record = T.acquire()
    aux.assign(deal.auction_record, auction_record) -- Copy record
    deal.found_time = GetTime()
    deal.value_source = source

    return deal
end

function M.process_scan()
    if not sniper_state.running then return end

    local num_auctions = GetNumAuctionItems('list')
    if num_auctions == 0 then return end
    
    -- Nota: Ya no limpiamos datos aquí para permitir acumulación en Monopolio
    
    sniper_state.items_scanned = sniper_state.items_scanned + num_auctions
    sniper_state.scan_count = sniper_state.scan_count + 1

    local new_deals_count = 0
    
    -- PASS 1: Build Page Context (Price Map)
    local page_context = T.acquire()
    -- We must iterate all to build context
    -- Since we can't easily iterate twice without calling GetAuctionItemInfo twice (slow?),
    -- We will store the records in a temp list to avoid double API calls.
    
    local records = T.acquire()
    
    for i = 1, num_auctions do
        local record = info.auction(i, 'list')
        if record and record.buyout_price > 0 then
             tinsert(records, record)
             
             -- Alimentar datos a Monopolio
             if M.ingest_auction_record then
                 M.ingest_auction_record(record)
             end
             
             -- Update context
             local id = record.item_id
             if not page_context[id] then
                 page_context[id] = T.map('min', record.unit_buyout_price, 'max', record.unit_buyout_price, 'count', 0)
             end
             local ctx = page_context[id]
             ctx.count = ctx.count + 1
             if record.unit_buyout_price < ctx.min then ctx.min = record.unit_buyout_price end
             if record.unit_buyout_price > ctx.max then ctx.max = record.unit_buyout_price end
        else
            -- Check if record exists but has no buyout, still release if T used?
            -- info.auction returns a new T table.
            if record then T.release(record) end
        end
    end

    -- PASS 2: Evaluate Deals
    for _, record in records do
        -- Ignore user's own auctions
        if record.owner ~= UnitName('player') then
             local deal = M.evaluate_snipe(record, page_context)
             
             if deal then
                -- Check for duplicates
                local is_dup = false
                for _, d in ipairs(sniper_state.current_deals) do
                    if d.item_id == deal.item_id and d.buyout_price == deal.buyout_price and d.auction_record.owner == record.owner then
                        is_dup = true
                        break
                    end
                end

                if not is_dup then
                    tinsert(sniper_state.current_deals, 1, deal)
                    sniper_state.deals_found = sniper_state.deals_found + 1
                    new_deals_count = new_deals_count + 1
                    
                    if getn(sniper_state.current_deals) > 50 then
                         local old = tremove(sniper_state.current_deals)
                         if old.auction_record then T.release(old.auction_record) end
                         T.release(old)
                    end
                else
                    if deal.auction_record then T.release(deal.auction_record) end
                    T.release(deal)
                end
             end
        end
        -- We are done with this record
        T.release(record)
    end
    
    -- Cleanup
    -- Release context maps
    for _, ctx in page_context do
        T.release(ctx)
    end
    T.release(page_context)
    T.release(records)

    if new_deals_count > 0 then
        M.sniper_alert(new_deals_count)
    end
    
    if M.update_sniper_ui then
        M.update_sniper_ui()
    end
end

function M.sniper_alert(count)
    if sniper_config.sound_alert then
        PlaySound('LEVELUPSOUND')
    end
    
    if count == 1 then
        local deal = sniper_state.current_deals[1]
        local profit_text = money.to_string(deal.profit, nil, true)
        aux.print(string.format(
            '|cFF00FF00[SNIPE!]|r %s - |cFFFFD700%s|r (Profit: %s)',
            deal.item_name,
            money.to_string(deal.buyout_price, nil, true),
            profit_text
        ))
    else
        aux.print(string.format('|cFF00FF00[SNIPE!]|r Found %d new deals!', count))
    end
end

function M.start_sniper()
    if sniper_state.running then return end
    
    M.clear_price_cache()
    
    -- Limpiar datos de Monopolio al INICIO de la sesión de sniper
    if M.clear_scan_data then M.clear_scan_data() end
    
    sniper_state.running = true
    sniper_state.items_scanned = 0
    sniper_state.deals_found = 0
    sniper_state.scan_count = 0
    
    aux.print('|cFF00FF00[Sniper]|r Started. Scanning last page...')

    -- Register Event Listener
    sniper_state.listener_id = aux.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        M.process_scan()
    end)
    
    -- Start Loop
    sniper_frame:SetScript('OnUpdate', function()
        if not sniper_state.running then return end
        
        sniper_frame.elapsed = (sniper_frame.elapsed or 0) + arg1
        if sniper_frame.elapsed >= sniper_config.scan_interval then
            sniper_frame.elapsed = 0
            
            -- Trigger Query
            if CanSendAuctionQuery() then
                -- Query last page
                -- We need total pages. How to get it without an initial scan?
                -- We can guess or use cached.
                -- Better: Query page 0 first, then update.
                -- If we queried recently, we know total pages.
                 
                -- For now, query page 0 without arguments to get a valid list update
                -- Then subsequent queries can be targeted if we knew the page.
                -- Getting "Last Page" reliably requires knowing total items.
                -- We can do `QueryAuctionItems("", ...)`
                
                -- Strategy: Always query everything (empty args) but only request the last page?
                -- `QueryAuctionItems` takes `page`.
                -- If we don't know the last page, we query 0.
                -- `GetNumAuctionItems("list")` gives total.
                -- logic:
                local _, total_auctions = GetNumAuctionItems('list')
                local last_page = 0
                if total_auctions and total_auctions > 0 then
                    last_page = math.max(0, math.ceil(total_auctions / 50) - 1)
                end
                
                QueryAuctionItems('', nil, nil, last_page, nil, nil, nil, nil, nil)
            end
        end
    end)
    
    sniper_frame:Show()
    
    -- Initial Query
    QueryAuctionItems('', nil, nil, 0, nil, nil, nil, nil, nil)
end

function M.stop_sniper()
    if not sniper_state.running then return end
    
    sniper_state.running = false
    sniper_frame:Hide()
    sniper_frame:SetScript('OnUpdate', nil)
    
    if sniper_state.listener_id then
        aux.kill_listener(sniper_state.listener_id)
        sniper_state.listener_id = nil
    end
    
    aux.print('|cFFFF8888[Sniper]|r Stopped.')
end

function M.toggle_sniper()
    if sniper_state.running then
        M.stop_sniper()
    else
        M.start_sniper()
    end
end

function M.is_sniper_running() return sniper_state.running end
function M.get_sniper_state() return sniper_state end
function M.get_sniper_deals() return sniper_state.current_deals end
function M.get_sniper_config() return sniper_config end

function M.buy_sniper_deal(deal)
    if not deal then return end
    
    -- Re-use aux.place_bid logic or similar
    -- Since we have the index from the scan... wait.
    -- The index is only valid IF the page hasn't changed.
    -- Sniper scans change rapidly. The 'deal' contains 'auction_record'.
    -- 'auction_record.index' is valid for the moment of scan.
    
    -- Verify if the item is still there?
    -- Attempt to buy.
    
    -- IMPORTANT: 'aux.place_bid' uses type, index, amount.
    -- But index likely shifted if we didn't buy immediately.
    -- However, in 1.12, indices are relative to the current page view.
    -- If we haven't refreshed, it's valid.
    -- If we refreshed, it's gone/moved.
    
    -- For safety, we should assume we need to re-find it or buy blindly if user clicks fast.
    -- The original code did a full scan to find it. That is safer.
    -- I will keep the original logic of "Find it again then buy" if possible, 
    -- but simplified.
    
    aux.print('Attempting to buy ' .. deal.item_name)
    
    -- For now, simple placeholder for buy logic relying on core
    -- (The user didn't ask explicitly to rewrite buy logic, but it was in the original file)
    -- I'll reimplement a clean version of "Find and Buy".
    
    local scan = require 'aux.core.scan'
    
    scan.start{
        type = 'list',
        ignore_owner = true,
        queries = {{
            blizzard_query = { name = deal.item_name },
            validator = function(record)
                return record.buyout_price == deal.buyout_price and record.aux_quantity == deal.auction_record.aux_quantity
            end
        }},
        on_auction = function(record)
            if record then
                aux.place_bid('list', record.index, record.buyout_price, function()
                    aux.print('Snipped ' .. deal.item_name)
                    -- Remove from list
                    for i, d in ipairs(sniper_state.current_deals) do
                        if d == deal then
                            tremove(sniper_state.current_deals, i)
                            break
                        end
                    end
                    if M.update_sniper_ui then M.update_sniper_ui() end
                end)
                scan.stop()
            end
        end
    }
end

M.modules = M.modules or {}
M.modules.sniper = M

aux.print('Sniper Module (Refactored) Loaded')
