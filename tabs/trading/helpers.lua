module 'aux.tabs.trading'

local aux = require 'aux'
local info = require 'aux.util.info'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'

-- ============================================================================
-- Helper Functions - Integración con APIs de WoW y aux-addon
-- ============================================================================

aux.print('[HELPERS] Módulo de helpers cargado')

-- ============================================================================
-- Item Information Helpers
-- ============================================================================

-- Obtener categoría real del item
function get_item_category(item_key)
    if not item_key then
        return 'Unknown'
    end
    
    -- Extraer item_id del item_key (formato: "item_id:suffix_id")
    -- FIX: Usar string.find en lugar de strsplit para Lua 5.0
    local colon_pos = string.find(item_key, ':')
    local item_id_str = colon_pos and string.sub(item_key, 1, colon_pos - 1) or item_key
    local item_id = tonumber(item_id_str)
    if not item_id then
        return 'Unknown'
    end
    
    -- Obtener información del item desde el cache de aux
    local item_info = info.item(item_id)
    if not item_info then
        return 'Unknown'
    end
    
    -- Retornar la clase del item (type es la categoría principal)
    return item_info.type or 'Unknown'
end

-- Obtener subcategoría del item
function get_item_subcategory(item_key)
    if not item_key then
        return 'Unknown'
    end
    
    -- FIX: Usar string.find en lugar de strsplit para Lua 5.0
    local colon_pos = string.find(item_key, ':')
    local item_id_str = colon_pos and string.sub(item_key, 1, colon_pos - 1) or item_key
    local item_id = tonumber(item_id_str)
    if not item_id then
        return 'Unknown'
    end
    
    local item_info = info.item(item_id)
    if not item_info then
        return 'Unknown'
    end
    
    return item_info.subtype or 'Unknown'
end

-- Obtener información completa del item
function get_item_info(item_key)
    if not item_key then
        return nil
    end
    
    -- FIX: Usar string.find en lugar de strsplit para Lua 5.0
    local colon_pos = string.find(item_key, ':')
    local item_id, suffix_id
    if colon_pos then
        item_id = tonumber(string.sub(item_key, 1, colon_pos - 1))
        suffix_id = tonumber(string.sub(item_key, colon_pos + 1)) or 0
    else
        item_id = tonumber(item_key)
        suffix_id = 0
    end
    
    if not item_id then
        return nil
    end
    
    local item_info = info.item(item_id, suffix_id)
    if not item_info then
        return nil
    end
    
    return {
        item_id = item_id,
        suffix_id = suffix_id,
        item_key = item_key,
        name = item_info.name,
        quality = item_info.quality,
        level = item_info.level,
        type = item_info.type,
        subtype = item_info.subtype,
        slot = item_info.slot,
        max_stack = item_info.max_stack,
        texture = item_info.texture,
    }
end

-- ============================================================================
-- Inventory/Bag Helpers
-- ============================================================================

-- Obtener todos los items del inventario (bags)
function get_bag_items()
    local items = {}
    
    -- Iterar por todas las bags (0-4)
    -- 0 = backpack, 1-4 = bags
    for bag = 0, 4 do
        local num_slots = GetContainerNumSlots(bag)
        if num_slots and num_slots > 0 then
            for slot = 1, num_slots do
                local item_data = info.container_item(bag, slot)
                if item_data then
                    tinsert(items, {
                        bag = bag,
                        slot = slot,
                        item_id = item_data.item_id,
                        suffix_id = item_data.suffix_id,
                        item_key = item_data.item_key,
                        name = item_data.name,
                        texture = item_data.texture,
                        count = item_data.count,
                        quality = item_data.quality,
                        level = item_data.level,
                        type = item_data.type,
                        subtype = item_data.subtype,
                        locked = item_data.locked,
                        max_stack = item_data.max_stack,
                    })
                end
            end
        end
    end
    
    return items
end

-- Obtener items específicos del inventario por item_key
function get_bag_items_by_key(item_key)
    local all_items = get_bag_items()
    local matching_items = {}
    
    for i = 1, getn(all_items) do
        if all_items[i].item_key == item_key then
            tinsert(matching_items, all_items[i])
        end
    end
    
    return matching_items
end

-- Contar cantidad total de un item en bags
function get_item_count_in_bags(item_key)
    local items = get_bag_items_by_key(item_key)
    local total = 0
    
    for i = 1, getn(items) do
        total = total + (items[i].count or 0)
    end
    
    return total
end

-- ============================================================================
-- Auction House Helpers
-- ============================================================================

-- Cache temporal para resultados de scan
local auction_cache = {}
local auction_cache_timestamp = 0
local AUCTION_CACHE_TTL = 60  -- 60 segundos

-- Obtener todas las subastas actuales de un item
function get_all_auctions_for_item(item_key)
    -- Verificar si tenemos cache válido
    local now = time()
    if auction_cache[item_key] and (now - auction_cache_timestamp) < AUCTION_CACHE_TTL then
        return auction_cache[item_key]
    end
    
    -- Intentar obtener desde el cache del módulo de integración
    if aux.tabs.trading.get_cached_scan_results then
        local cached = aux.tabs.trading.get_cached_scan_results(item_key)
        if cached.success then
            auction_cache[item_key] = cached.auctions
            auction_cache_timestamp = now
            return cached.auctions
        end
    end
    
    -- Si no hay cache, retornar vacío
    return {}
end

-- Actualizar cache de subastas (llamado desde el sistema de scan)
function update_auction_cache(item_key, auctions)
    auction_cache[item_key] = auctions
    auction_cache_timestamp = time()
end

-- Limpiar cache de subastas
function clear_auction_cache()
    auction_cache = {}
    auction_cache_timestamp = 0
end

-- Obtener competencia actual para un item
function get_current_competition(item_key)
    local auctions = get_all_auctions_for_item(item_key)
    
    if not auctions or getn(auctions) == 0 then
        return {
            exists = false,
            count = 0,
            lowest_price = 0,
            average_price = 0,
            highest_price = 0,
            total_quantity = 0,
        }
    end
    
    local lowest_price = nil
    local highest_price = 0
    local total_price = 0
    local total_quantity = 0
    local price_count = 0
    
    for i = 1, getn(auctions) do
        local auction = auctions[i]
        local price = auction.buyout_price or auction.bid_price or 0
        
        if price > 0 then
            if not lowest_price or price < lowest_price then
                lowest_price = price
            end
            
            if price > highest_price then
                highest_price = price
            end
            
            total_price = total_price + price
            price_count = price_count + 1
        end
        
        total_quantity = total_quantity + (auction.count or 1)
    end
    
    local average_price = 0
    if price_count > 0 then
        average_price = total_price / price_count
    end
    
    return {
        exists = true,
        count = getn(auctions),
        lowest_price = lowest_price or 0,
        average_price = average_price,
        highest_price = highest_price,
        total_quantity = total_quantity,
        auctions = auctions,
    }
end

-- ============================================================================
-- Player's Active Auctions
-- ============================================================================

-- Cache para subastas del jugador
local player_auctions_cache = {}
local player_auctions_timestamp = 0
local PLAYER_AUCTIONS_CACHE_TTL = 30  -- 30 segundos

-- Obtener subastas activas del jugador
function get_our_active_auctions()
    local now = time()
    
    -- Verificar cache
    if player_auctions_cache and getn(player_auctions_cache) > 0 and 
       (now - player_auctions_timestamp) < PLAYER_AUCTIONS_CACHE_TTL then
        return player_auctions_cache
    end
    
    -- Si no estamos en el AH, retornar cache o vacío
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        return player_auctions_cache or {}
    end
    
    -- Obtener subastas del jugador usando la API de WoW
    local auctions = {}
    local num_auctions = GetNumAuctionItems('owner')
    
    if not num_auctions or num_auctions == 0 then
        player_auctions_cache = {}
        player_auctions_timestamp = now
        return {}
    end
    
    for i = 1, num_auctions do
        local auction_info = info.auction(i, 'owner')
        if auction_info then
            tinsert(auctions, {
                index = i,
                item_key = auction_info.item_key,
                item_id = auction_info.item_id,
                suffix_id = auction_info.suffix_id,
                name = auction_info.name,
                texture = auction_info.texture,
                count = auction_info.count,
                quality = auction_info.quality,
                bid_price = auction_info.bid_price,
                buyout_price = auction_info.buyout_price,
                high_bidder = auction_info.high_bidder,
                time_left = auction_info.time_left,
                sale_status = auction_info.sale_status,
            })
        end
    end
    
    player_auctions_cache = auctions
    player_auctions_timestamp = now
    
    return auctions
end

-- Refrescar cache de subastas del jugador
function refresh_player_auctions()
    player_auctions_cache = {}
    player_auctions_timestamp = 0
    return get_our_active_auctions()
end

-- Obtener subastas del jugador para un item específico
function get_our_auctions_for_item(item_key)
    local all_auctions = get_our_active_auctions()
    local matching = {}
    
    for i = 1, getn(all_auctions) do
        if all_auctions[i].item_key == item_key then
            tinsert(matching, all_auctions[i])
        end
    end
    
    return matching
end

-- Verificar si tenemos subastas activas de un item
function has_active_auctions(item_key)
    local auctions = get_our_auctions_for_item(item_key)
    return getn(auctions) > 0
end

-- Obtener el precio más bajo de nuestras subastas para un item
function get_our_lowest_price(item_key)
    local auctions = get_our_auctions_for_item(item_key)
    
    if getn(auctions) == 0 then
        return nil
    end
    
    local lowest = nil
    for i = 1, getn(auctions) do
        local price = auctions[i].buyout_price or auctions[i].bid_price or 0
        if price > 0 and (not lowest or price < lowest) then
            lowest = price
        end
    end
    
    return lowest
end

-- ============================================================================
-- Market Data Helpers
-- ============================================================================

-- Obtener precio de mercado de un item
function get_market_price(item_key)
    local market_value = history.value(item_key)
    return market_value or 0
end

-- Obtener datos de mercado completos
function get_market_data(item_key)
    local market_value = history.value(item_key)
    local daily_value = history.daily_value(item_key)
    
    return {
        market_value = market_value or 0,
        daily_value = daily_value or 0,
        has_data = market_value ~= nil,
    }
end

-- ============================================================================
-- Scan Integration Helpers
-- ============================================================================

-- Callback para cuando se completa un scan
local scan_callbacks = {}

function register_scan_callback(callback)
    tinsert(scan_callbacks, callback)
end

function trigger_scan_callbacks(results)
    for i = 1, getn(scan_callbacks) do
        scan_callbacks[i](results)
    end
end

-- Escanear item específico
function scan_item(item_key, callback)
    -- Usar la integración real con el sistema de scan
    if aux.tabs.trading.scan_item_for_trading then
        return aux.tabs.trading.scan_item_for_trading(item_key, nil, callback)
    else
        -- Fallback si el módulo de integración no está cargado
        if callback then
            callback({
                success = true,
                item_key = item_key,
                auctions = get_all_auctions_for_item(item_key),
            })
        end
    end
end

-- ============================================================================
-- Utility Helpers
-- ============================================================================

-- Formatear dinero (copper a string legible)
function format_money(copper)
    if not copper or copper == 0 then
        return '0c'
    end
    
    local is_negative = copper < 0
    copper = math.abs(copper)
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor(mod(copper, 10000) / 100)
    local copper_left = mod(copper, 100)
    
    local result = ''
    if gold > 0 then
        result = result .. gold .. 'g '
    end
    if silver > 0 then
        result = result .. silver .. 's '
    end
    if copper_left > 0 or result == '' then
        result = result .. copper_left .. 'c'
    end
    
    if is_negative then
        result = '-' .. result
    end
    
    return strtrim(result)
end

-- Parsear string de dinero a copper
function parse_money(money_string)
    if not money_string or money_string == '' then
        return 0
    end
    
    local total = 0
    
    -- Buscar gold (FIX: Usar string.find para Lua 5.0)
    local _, _, gold = string.find(money_string, '(%d+)g')
    if gold then
        total = total + (tonumber(gold) * 10000)
    end
    
    -- Buscar silver
    local _, _, silver = string.find(money_string, '(%d+)s')
    if silver then
        total = total + (tonumber(silver) * 100)
    end
    
    -- Buscar copper
    local _, _, copper = string.find(money_string, '(%d+)c')
    if copper then
        total = total + tonumber(copper)
    end
    
    return total
end

-- Obtener timestamp actual
function get_timestamp()
    return time()
end

-- Obtener nombre del día de la semana
function get_day_name(wday)
    local days = {
        [1] = 'Domingo',
        [2] = 'Lunes',
        [3] = 'Martes',
        [4] = 'Miércoles',
        [5] = 'Jueves',
        [6] = 'Viernes',
        [7] = 'Sábado',
    }
    return days[wday] or 'Unknown'
end

-- ============================================================================
-- Event Listeners para actualizar caches
-- ============================================================================

-- Actualizar cache cuando se actualiza el AH
aux.event_listener('AUCTION_HOUSE_SHOW', function()
    clear_auction_cache()
    refresh_player_auctions()
end)

aux.event_listener('AUCTION_HOUSE_CLOSED', function()
    clear_auction_cache()
    player_auctions_cache = {}
end)

-- Actualizar cuando cambian las subastas del jugador
aux.event_listener('AUCTION_OWNED_LIST_UPDATE', function()
    refresh_player_auctions()
end)

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    aux.print('[HELPERS] Sistema de helpers inicializado')
end)

-- ============================================================================
-- Exports
-- ============================================================================

-- Exportar funciones para que otros módulos puedan usarlas
local M = getfenv()
M.get_item_category = get_item_category
M.get_item_subcategory = get_item_subcategory
M.get_item_info = get_item_info
M.get_bag_items = get_bag_items
M.get_bag_items_by_key = get_bag_items_by_key
M.get_item_count_in_bags = get_item_count_in_bags
M.get_all_auctions_for_item = get_all_auctions_for_item
M.update_auction_cache = update_auction_cache
M.clear_auction_cache = clear_auction_cache
M.get_current_competition = get_current_competition
M.get_our_active_auctions = get_our_active_auctions
M.refresh_player_auctions = refresh_player_auctions
M.get_our_auctions_for_item = get_our_auctions_for_item
M.has_active_auctions = has_active_auctions
M.get_our_lowest_price = get_our_lowest_price
M.get_market_price = get_market_price
M.get_market_data = get_market_data
M.register_scan_callback = register_scan_callback
M.trigger_scan_callbacks = trigger_scan_callbacks
M.scan_item = scan_item
M.format_money = format_money
M.parse_money = parse_money
M.get_timestamp = get_timestamp
M.get_day_name = get_day_name

-- ============================================================================
-- Market Analysis Helpers (para strategies.lua)
-- ============================================================================

-- Obtener volumen promedio diario de un item
function get_average_daily_volume(item_key, days)
    -- Intentar usar la función real de market_analysis si está disponible
    if M.modules and M.modules.market_analysis and M.modules.market_analysis.get_average_daily_volume then
        return M.modules.market_analysis.get_average_daily_volume(item_key, days)
    end
    
    -- Fallback: Versión simplificada basada en auctions actuales
    local auctions = get_all_auctions_for_item(item_key)
    if not auctions or getn(auctions) == 0 then
        return 0
    end
    
    -- Asumir que las auctions actuales representan ~1 día de volumen
    local total_quantity = 0
    -- Usar iteración manual en lugar de ipairs para compatibilidad con Lua 5.0
    for i = 1, getn(auctions) do
        local auction = auctions[i]
        total_quantity = total_quantity + (auction.count or 1)
    end
    
    return total_quantity
end

-- Detectar manipulación del mercado
function detect_market_manipulation(item_key)
    -- Intentar usar la función real de market_analysis si está disponible
    if M.modules and M.modules.market_analysis and M.modules.market_analysis.detect_market_manipulation then
        return M.modules.market_analysis.detect_market_manipulation(item_key)
    end
    
    -- Fallback: Versión simplificada
    return {
        is_manipulated = false,
        confidence = 0,
        reason = 'no_data',
        volatility = 0,
    }
end

-- Exportar nuevas funciones
M.get_average_daily_volume = get_average_daily_volume
M.detect_market_manipulation = detect_market_manipulation

aux.print('[HELPERS] Funciones exportadas al módulo trading')
