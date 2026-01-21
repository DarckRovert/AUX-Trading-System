module 'aux.tabs.trading'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local scan = require 'aux.core.scan'
local scan_util = require 'aux.util.scan'

local M = getfenv()


local vendor_state = {
    scanning = false,
    buying = false,
    found_items = {},
}

-- Configuración de categorías a escanear (Items que suelen tener buen vendor price)
local SCAN_QUERIES = {
    { category = "Weapon" },
    { category = "Armor" },
    { category = "Trade Goods" }, -- A veces hay telas o cueros baratos
}

-- Helpers
local function get_vendor_price(item_id)
    -- 1. Intentar API nativa de Turtle WoW o addons globales
    if GetSellValue then
        local v = GetSellValue(item_id)
        if v and v > 0 then return v end
    end

    -- 2. Cache interna de AUX
    local price = info.merchant_info(item_id)
    
    -- 3. ShaguTweaks (Fallback popular)
    if not price and ShaguTweaks and ShaguTweaks.SellValueDB and ShaguTweaks.SellValueDB[item_id] then
        -- Fallback a ShaguTweaks si existe
        local charges = 1
		if info.max_item_charges(item_id) then 
			charges = info.max_item_charges(item_id) 
		end
        price = ShaguTweaks.SellValueDB[item_id] / charges
    end
    return price
end

function M.get_vendor_items()
    return vendor_state.found_items
end

function M.clear_vendor_data()
    vendor_state.found_items = {}
end

function M.start_vendor_search()
    if vendor_state.scanning then return end
    vendor_state.scanning = true
    M.clear_vendor_data()
    
    aux.print('Iniciando búsqueda de Vendor Shuffle...')
    
    -- Construir queries para el scanner de AUX
    local queries = {}
    for _, q in ipairs(SCAN_QUERIES) do
        tinsert(queries, {
            blizzard_query = {
                name = "", -- Buscar todo
                class = q.category
            }
        })
    end
    
    scan.start{
        type = 'list',
        queries = queries,
        on_page_loaded = function(page, total_pages)
            -- Callback opcional para update UI de progreso si fuera necesario
        end,
        on_auction = function(record)
            if not record or not record.buyout_price or record.buyout_price == 0 then return end
            
            -- Obtener precio de venta al NPC
            -- GetItemInfo retorna: name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(record.item_id)
            local vendorPrice = get_vendor_price(record.item_id)
            
            if vendorPrice and vendorPrice > 0 then
                local profit = vendorPrice - record.unit_buyout_price
                
                -- SI hay ganancia y el item no es bind on pickup (aunque la AH ya filtra eso por defecto)
                if profit > 0 then
                    local entry = {
                        item_id = record.item_id,
                        name = record.name,
                        texture = texture,
                        buyout = record.unit_buyout_price,
                        vendor_price = vendorPrice,
                        profit = profit,
                        count = record.count,
                        auction_record = record -- Guardamos referencia para comprar
                    }
                    tinsert(vendor_state.found_items, entry)
                end
            end
        end,
        on_complete = function()
            vendor_state.scanning = false
            aux.print('Búsqueda vendor finalizada. Encontrados: ' .. getn(vendor_state.found_items))
            if M.refresh_vendor_ui then M.refresh_vendor_ui() end
        end,
        on_abort = function()
            vendor_state.scanning = false
            aux.print('Búsqueda vendor cancelada.')
        end
    }
end


function M.buy_candidate(entry)
    if not entry or not entry.auction_record then return end
    
    aux.print("Intentando comprar: " .. entry.name)
    
    -- Create dummy status_bar for scan_util.find (it requires update_status and set_text methods)
    local dummy_status_bar = {
        update_status = function() end,
        set_text = function() end,
    }
    
    scan_util.find(
        entry.auction_record,
        dummy_status_bar,
        function() aux.print("Compra cancelada.") end,
        function() 
            aux.print("Item perdido: " .. entry.name) 
             for i, v in ipairs(vendor_state.found_items) do
                if v == entry then tremove(vendor_state.found_items, i) break end
            end
            if M.refresh_vendor_ui then M.refresh_vendor_ui() end
        end,
        function(index)
            -- Use buyout_price from auction_record (not unit price)
            local bid_amount = entry.auction_record.buyout_price
            if not bid_amount or bid_amount == 0 then
                aux.print("|cFFFF0000Error: No hay precio de buyout|r")
                return
            end
            aux.place_bid('list', index, bid_amount, function()
                aux.print("|cFF00FF00Comprado:|r " .. entry.name)
                 for i, v in ipairs(vendor_state.found_items) do
                    if v == entry then tremove(vendor_state.found_items, i) break end
                end
                if M.refresh_vendor_ui then M.refresh_vendor_ui() end
            end)
        end
    )
end

function M.stop_buy_all()
    vendor_state.buying = false
end

function M.buy_all_candidates()
    if vendor_state.buying then return end
    if getn(vendor_state.found_items) == 0 then
        aux.print("No hay items para comprar.")
        return
    end

    vendor_state.buying = true
    aux.print("Iniciando Compra Automatica...")
    
    local function process_next()
        if not vendor_state.buying then return end
        
        local entry = vendor_state.found_items[1]
        
        if not entry then
            vendor_state.buying = false
            aux.print("Compra automatica finalizada.")
            return
        end
        
        -- Validate auction_record before proceeding
        if not entry.auction_record then
            aux.print("Item sin auction_record, saltando: " .. (entry.name or "Unknown"))
            tremove(vendor_state.found_items, 1)
            if M.refresh_vendor_ui then M.refresh_vendor_ui() end
            return process_next()
        end
        
        -- Check if scan_util is available
        if not scan_util or not scan_util.find then
            aux.print("|cFFFF0000Error: scan_util no disponible|r")
            vendor_state.buying = false
            return
        end
        -- Create dummy status_bar for scan_util.find (it requires update_status and set_text methods)
        local dummy_status_bar = {
            update_status = function() end,
            set_text = function() end,
        }
        
        scan_util.find(
            entry.auction_record,
            dummy_status_bar,
            function() 
                vendor_state.buying = false
                aux.print("Compra detenida.")
            end,
            function() 
                aux.print("Saltando item perdido...")
                tremove(vendor_state.found_items, 1)
                if M.refresh_vendor_ui then M.refresh_vendor_ui() end
                process_next()
            end,
            function(index)
                -- Use buyout_price from auction_record (not unit price)
                local bid_amount = entry.auction_record.buyout_price
                if not bid_amount or bid_amount == 0 then
                    aux.print("|cFFFF0000Error: No hay precio de buyout|r")
                    tremove(vendor_state.found_items, 1)
                    return process_next()
                end
                aux.place_bid('list', index, bid_amount, function()
                    aux.print("|cFF00FF00Comprado:|r " .. entry.name)
                    tremove(vendor_state.found_items, 1)
                    if M.refresh_vendor_ui then M.refresh_vendor_ui() end
                    process_next()
                end)
            end
        )
    end
    
    process_next()
end

M.modules = M.modules or {}
M.modules.vendor = M
