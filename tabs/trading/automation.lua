module 'aux.tabs.trading'

local aux = require 'aux'
local history = require 'aux.core.history'
local post = require 'aux.core.post'

-- ============================================================================
-- Advanced Automation - Automatización Avanzada de Trading
-- ============================================================================

aux.print('[AUTOMATION] Módulo de automatización cargado')

-- Obtener referencia al módulo para acceder a funciones de helpers
local M = getfenv()

-- Helper function references (from helpers.lua)
local get_our_active_auctions = function()
    return (M.get_our_active_auctions and M.get_our_active_auctions()) or {}
end

local get_bag_items = function()
    return (M.get_bag_items and M.get_bag_items()) or {}
end

local format_money = function(copper)
    return (M.format_money and M.format_money(copper)) or tostring(copper) .. 'c'
end

local get_current_competition = function(item_key)
    return (M.get_current_competition and M.get_current_competition(item_key)) or {lowest_price = 0, auction_count = 0}
end

-- ============================================================================
-- Smart Auto-Posting
-- ============================================================================

local auto_post_config = {
    enabled = false,
    pricing_strategy = 'undercut',  -- undercut, market, aggressive, conservative
    undercut_amount = 100,  -- 1 silver
    min_profit_margin = 0.10,  -- 10% mínimo
    max_undercut_percent = 0.05,  -- No bajar más del 5%
    use_ml_pricing = true,  -- Usar machine learning para pricing
    auto_repost = true,
    check_interval = 300,  -- 5 minutos
}

function init_auto_post_config()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    if not aux.account_data.trading.auto_post_config then
        aux.account_data.trading.auto_post_config = auto_post_config
    else
        auto_post_config = aux.account_data.trading.auto_post_config
    end
end

-- Calcular precio óptimo para posting
function calculate_optimal_price(item_key, item_count)
    -- Obtener precio de mercado
    local market_value = history.value(item_key)
    if not market_value or market_value == 0 then
        return {
            success = false,
            reason = 'no_market_data',
            suggested_price = 0,
        }
    end
    
    -- Obtener competencia actual
    local competition = get_current_competition(item_key)
    
    -- Obtener análisis de ML
    local ml_analysis = nil
    if auto_post_config.use_ml_pricing then
        -- FIX: Acceso seguro a función de otro módulo
        local best_sell_time = nil
        if M.get_best_time_to_sell then
            best_sell_time = M.get_best_time_to_sell(item_key)
        elseif get_best_time_to_sell then
            best_sell_time = get_best_time_to_sell(item_key)
        else
            best_sell_time = {available = false}
        end
        ml_analysis = best_sell_time
    end
    
    -- Calcular precio base según estrategia
    local base_price = market_value
    
    if auto_post_config.pricing_strategy == 'undercut' then
        -- Undercut al competidor más barato
        if competition.lowest_price and competition.lowest_price > 0 then
            base_price = competition.lowest_price - auto_post_config.undercut_amount
            
            -- No bajar más del porcentaje máximo
            local max_undercut = market_value * (1 - auto_post_config.max_undercut_percent)
            if base_price < max_undercut then
                base_price = max_undercut
            end
        end
        
    elseif auto_post_config.pricing_strategy == 'market' then
        -- Precio de mercado
        base_price = market_value
        
    elseif auto_post_config.pricing_strategy == 'aggressive' then
        -- Precio agresivo (5% por debajo del mercado)
        base_price = market_value * 0.95
        
    elseif auto_post_config.pricing_strategy == 'conservative' then
        -- Precio conservador (precio de mercado o ligeramente superior)
        base_price = market_value * 1.02
    end
    
    -- Ajustar con ML si está habilitado
    if ml_analysis and ml_analysis.available then
        local current_time = date('*t', time())
        local current_hour = current_time.hour
        
        -- Si estamos en hora pico de ventas, podemos subir el precio
        if ml_analysis.best_hour and current_hour == ml_analysis.best_hour then
            base_price = base_price * 1.05  -- 5% más en hora pico
        end
    end
    
    -- Verificar margen de ganancia mínimo
    local cost_basis = get_item_cost_basis(item_key)
    if cost_basis > 0 then
        -- FIX: Prevenir división por cero
        local profit_margin = cost_basis > 0 and ((base_price - cost_basis) / cost_basis) or 0
        
        if profit_margin < auto_post_config.min_profit_margin then
            -- Ajustar precio para cumplir margen mínimo
            base_price = cost_basis * (1 + auto_post_config.min_profit_margin)
        end
    end
    
    -- Redondear a valores limpios
    base_price = round_price(base_price)
    
    return {
        success = true,
        suggested_price = base_price,
        market_value = market_value,
        competition = competition,
        strategy = auto_post_config.pricing_strategy,
        ml_adjustment = ml_analysis and ml_analysis.available or false,
        profit_margin = cost_basis > 0 and ((base_price - cost_basis) / cost_basis) or 0,
    }
end

-- get_current_competition() ahora está en helpers.lua y se accede vía referencia local

-- Obtener costo base del item (cuánto pagamos por él)
function get_item_cost_basis(item_key)
    -- Buscar en trades activos
    if not aux.faction_data or not aux.faction_data.trading or not aux.faction_data.trading.trades then
        return 0
    end
    
    local total_cost = 0
    local total_count = 0
    
    for trade_id, trade in pairs(aux.faction_data.trading.trades) do
        if trade.item_key == item_key and trade.status == 'pending' then
            total_cost = total_cost + trade.buy_price
            total_count = total_count + trade.count
        end
    end
    
    if total_count > 0 then
        return total_cost / total_count
    end
    
    return 0
end

-- Redondear precio a valores limpios
function round_price(price)
    -- Redondear a valores "bonitos"
    if price < 100 then  -- < 1 silver
        return math.floor(price / 5) * 5  -- Múltiplos de 5 copper
    elseif price < 1000 then  -- < 10 silver
        return math.floor(price / 10) * 10  -- Múltiplos de 10 copper
    elseif price < 10000 then  -- < 1 gold
        return math.floor(price / 50) * 50  -- Múltiplos de 50 copper
    else
        return math.floor(price / 100) * 100  -- Múltiplos de 1 silver
    end
end

-- ============================================================================
-- Auto-Repost System
-- ============================================================================

local repost_queue = {}
local last_repost_check = 0

function init_repost_system()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.repost_queue then
        aux.faction_data.trading.repost_queue = {}
    end
    
    repost_queue = aux.faction_data.trading.repost_queue
end

function check_for_undercuts()
    if not auto_post_config.enabled or not auto_post_config.auto_repost then
        return
    end
    
    local current_time = time()
    
    -- Solo verificar cada X minutos
    if current_time - last_repost_check < auto_post_config.check_interval then
        return
    end
    
    last_repost_check = current_time
    
    -- Obtener nuestras subastas activas
    local our_auctions = get_our_active_auctions()
    
    if not our_auctions or getn(our_auctions) == 0 then
        return
    end
    
    -- Verificar cada subasta
    for i = 1, getn(our_auctions) do
        local auction = our_auctions[i]
        
        -- Verificar si fuimos undercut
        local was_undercut = check_if_undercut(auction)
        
        if was_undercut then
            -- Agregar a cola de repost
            add_to_repost_queue(auction)
        end
    end
    
    -- Procesar cola de repost
    process_repost_queue()
end

function check_if_undercut(auction)
    -- Escanear AH para el item
    local competition = get_current_competition(auction.item_key)
    
    if not competition.lowest_price or competition.lowest_price == 0 then
        return false
    end
    
    -- Si hay un precio más bajo que el nuestro, fuimos undercut
    if competition.lowest_price < auction.buyout_price then
        return true
    end
    
    return false
end

function add_to_repost_queue(auction)
    -- Verificar si ya está en la cola
    for i = 1, getn(repost_queue) do
        if repost_queue[i].auction_id == auction.id then
            return  -- Ya está en cola
        end
    end
    
    tinsert(repost_queue, {
        auction_id = auction.id,
        item_key = auction.item_key,
        item_name = auction.item_name,
        count = auction.count,
        old_price = auction.buyout_price,
        added_at = time(),
    })
    
    aux.print(string.format('|cFFFFFF00[Auto-Repost]|r %s agregado a cola de repost', auction.item_name or 'Item'))
end

function process_repost_queue()
    if getn(repost_queue) == 0 then
        return
    end
    
    -- Procesar primer item de la cola
    local repost_item = repost_queue[1]
    
    -- Calcular nuevo precio
    local pricing = calculate_optimal_price(repost_item.item_key, repost_item.count)
    
    if not pricing.success then
        aux.print(string.format('|cFFFF0000[Auto-Repost]|r Error calculando precio para %s', repost_item.item_name or 'Item'))
        tremove(repost_queue, 1)
        return
    end
    
    -- Cancelar subasta antigua usando API de WoW
    local cancelled = cancel_auction(repost_item.auction_id)
    
    if not cancelled then
        aux.print(string.format('|cFFFF0000[Auto-Repost]|r No se pudo cancelar subasta de %s', repost_item.item_name or 'Item'))
        tremove(repost_queue, 1)
        return
    end
    
    -- Esperar a que el item vuelva al inventario (se procesará en el siguiente ciclo)
    -- Marcar para reposteo
    repost_item.cancelled = true
    repost_item.new_price = pricing.suggested_price
    repost_item.cancel_time = time()
    
    aux.print(string.format(
        '|cFF00FF00[Auto-Repost]|r %s cancelado. Nuevo precio: %s (antes: %s)',
        repost_item.item_name or 'Item',
        format_money(pricing.suggested_price),
        format_money(repost_item.old_price)
    ))
    
    -- Notificar si está habilitado
    if M.modules and M.modules.notifications then
        M.modules.notifications.info(
            'Auto-Repost',
            string.format('%s will be reposted at %s', repost_item.item_name or 'Item', format_money(pricing.suggested_price)),
            5
        )
    end
    
    -- Remover de la cola
    tremove(repost_queue, 1)
end

-- Cancelar subasta usando API de WoW
function cancel_auction(auction_id)
    -- Buscar la subasta en nuestras subastas activas
    local num_auctions = GetNumAuctionItems('owner')
    
    for i = 1, num_auctions do
        local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bid, highBidder, owner = GetAuctionItemInfo('owner', i)
        
        -- Si encontramos la subasta correcta
        if auction_id == i then  -- Simplificado, debería usar un ID más robusto
            CancelAuction(i)
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- Smart Auto-Posting Execution
-- ============================================================================

local auto_post_queue = {}
local last_auto_post_check = 0

function execute_auto_posting()
    if not auto_post_config.enabled then
        return
    end
    
    local current_time = time()
    
    -- Solo verificar cada X minutos
    if current_time - last_auto_post_check < auto_post_config.check_interval then
        return
    end
    
    last_auto_post_check = current_time
    
    -- Obtener items en inventario que podemos postear
    local bag_items = get_bag_items()
    
    if not bag_items or getn(bag_items) == 0 then
        return
    end
    
    -- Filtrar items que queremos postear
    local items_to_post = filter_items_for_posting(bag_items)
    
    -- Postear cada item
    for i, item in ipairs(items_to_post) do
        post_item_intelligently(item)
    end
end

function filter_items_for_posting(bag_items)
    local result = {}
    
    for i, item in ipairs(bag_items) do
        -- Verificar si el item es vendible
        if is_item_postable(item) then
            tinsert(result, item)
        end
    end
    
    return result
end

function is_item_postable(item)
    -- No postear items de quest
    if item.is_quest_item then
        return false
    end
    
    -- No postear items soulbound
    if item.is_soulbound then
        return false
    end
    
    -- Verificar si tenemos datos de mercado
    local market_value = history.value(item.item_key)
    if not market_value or market_value == 0 then
        return false
    end
    
    -- Verificar si el item está en nuestra lista de auto-post
    -- (por ahora posteamos todo lo que tenga valor de mercado)
    
    return true
end

function post_item_intelligently(item)
    -- Calcular precio óptimo
    local pricing = calculate_optimal_price(item.item_key, item.count)
    
    if not pricing.success then
        aux.print(string.format('|cFFFF8800[Auto-Post]|r No se pudo calcular precio para %s', item.name or item.item_key))
        return false
    end
    
    -- Verificar margen de ganancia
    if pricing.profit_margin < auto_post_config.min_profit_margin then
        aux.print(string.format('|cFFFF8800[Auto-Post]|r %s: Margen muy bajo (%.1f%%)', item.name or item.item_key, pricing.profit_margin * 100))
        return false
    end
    
    -- Determinar duración de la subasta
    local duration = determine_auction_duration(item.item_key, pricing)
    
    -- Postear usando API de aux
    local success = post_item_to_ah(item, pricing.suggested_price, duration)
    
    if success then
        aux.print(string.format(
            '|cFF00FF00[Auto-Post]|r %s x%d posted at %s (margin: %.1f%%)',
            item.name or item.item_key,
            item.count,
            format_money(pricing.suggested_price),
            pricing.profit_margin * 100
        ))
        
        -- Registrar en tracking
        if M.modules and M.modules.core and M.modules.core.record_post then
            M.modules.core.record_post(item.item_key, item.name, item.count, pricing.suggested_price)
        end
        
        -- Notificar
        if M.modules and M.modules.notifications then
            M.modules.notifications.post(item.name or item.item_key, pricing.suggested_price, 4)
        end
        
        return true
    else
        aux.print(string.format('|cFFFF0000[Auto-Post]|r Error posting %s', item.name or item.item_key))
        return false
    end
end

function determine_auction_duration(item_key, pricing)
    -- Determinar duración basada en análisis de mercado
    
    -- Obtener velocidad de venta
    local demand = 'medium'  -- Por defecto
    
    if M.modules and M.modules.market_analysis and M.modules.market_analysis.analyze_item then
        local analysis = M.modules.market_analysis.analyze_item(item_key)
        if analysis and analysis.demand then
            demand = analysis.demand
        end
    end
    
    -- Alta demanda = 12 horas (vende rápido)
    if demand == 'high' then
        return 1  -- 12 horas
    end
    
    -- Demanda media = 24 horas
    if demand == 'medium' then
        return 2  -- 24 horas
    end
    
    -- Baja demanda = 48 horas
    return 3  -- 48 horas
end

function post_item_to_ah(item, price, duration)
    -- Usar el sistema de posting de aux
    
    -- Verificar que estamos en el AH
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('[AUTO-POST] Error: No estás en la Casa de Subastas')
        return false
    end
    
    -- Verificar que el item existe en el bag
    if not item.bag or not item.slot then
        aux.print('[AUTO-POST] Error: Item no tiene bag/slot válido')
        return false
    end
    
    -- Usar aux.core.post si está disponible
    if post and post.start then
        -- Preparar datos de posting
        local post_data = {
            bag = item.bag,
            slot = item.slot,
            stack_size = item.count,
            num_stacks = 1,
            bid_price = math.floor(price * 0.95),  -- Bid = 95% del buyout
            buyout_price = price,
            duration = duration or 2,  -- Default 24 horas
        }
        
        -- Intentar postear usando aux.core.post
        local success = post.start(post_data)
        
        if success then
            aux.print(string.format('[AUTO-POST] Item posteado: %s x%d @ %s', 
                item.name or item.item_key, 
                item.count, 
                format_money(price)))
            return true
        else
            aux.print('[AUTO-POST] Error: post.start() falló')
            return false
        end
    else
        -- Fallback: Usar API directa de WoW
        -- Seleccionar el item del bag
        PickupContainerItem(item.bag, item.slot)
        
        -- Colocarlo en el slot de AH
        ClickAuctionSellItemButton()
        
        -- Configurar precios
        local bid = math.floor(price * 0.95)
        StartAuction(bid, price, duration or 2)
        
        aux.print(string.format('[AUTO-POST] Item posteado (fallback): %s x%d @ %s', 
            item.name or item.item_key, 
            item.count, 
            format_money(price)))
        
        return true
    end
end

-- ============================================================================
-- Inventory Management
-- ============================================================================

local inventory_config = {
    auto_organize = false,
    keep_in_bags = {},  -- Items a mantener en bags
    auto_bank = {},     -- Items a enviar al banco automáticamente
    max_stack_size = 20,
}

function init_inventory_management()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    if not aux.account_data.trading.inventory_config then
        aux.account_data.trading.inventory_config = inventory_config
    else
        inventory_config = aux.account_data.trading.inventory_config
    end
end

function organize_inventory()
    if not inventory_config.auto_organize then
        return
    end
    
    -- Obtener items en bags
    local bag_items = get_bag_items()
    
    -- Agrupar por item_key
    local item_groups = {}
    for i = 1, getn(bag_items) do
        local item = bag_items[i]
        if not item_groups[item.item_key] then
            item_groups[item.item_key] = {}
        end
        tinsert(item_groups[item.item_key], item)
    end
    
    -- Consolidar stacks
    for item_key, items in pairs(item_groups) do
        consolidate_stacks(items)
    end
    
    aux.print('[AUTOMATION] Inventario organizado')
end

function consolidate_stacks(items)
    -- Ordenar por cantidad (menor a mayor)
    table.sort(items, function(a, b)
        return a.count < b.count
    end)
    
    -- Intentar consolidar
    for i = 1, getn(items) - 1 do
        local source = items[i]
        local target = items[i + 1]
        
        if source.count + target.count <= inventory_config.max_stack_size then
            -- Mover items usando WoW API
            -- Pickup source item
            PickupContainerItem(source.bag, source.slot)
            
            -- Click on target to merge
            PickupContainerItem(target.bag, target.slot)
            
            -- Si queda algo en el cursor, ponerlo de vuelta
            if CursorHasItem() then
                PickupContainerItem(source.bag, source.slot)
            end
            
            aux.print(string.format('[AUTOMATION] Consolidado: %s (%d + %d)', 
                source.name or source.item_key, 
                source.count, 
                target.count))
        end
    end
end

-- ============================================================================
-- Shopping Lists
-- ============================================================================

local shopping_lists = {}

function init_shopping_lists()
    if not aux.account_data then
        return
    end
    
    if not aux.account_data.trading then
        aux.account_data.trading = {}
    end
    
    if not aux.account_data.trading.shopping_lists then
        aux.account_data.trading.shopping_lists = {}
    end
    
    shopping_lists = aux.account_data.trading.shopping_lists
end

function create_shopping_list(name, items)
    local list = {
        name = name,
        items = items or {},
        created_at = time(),
        last_updated = time(),
        auto_buy = false,
    }
    
    shopping_lists[name] = list
    
    aux.print(string.format('[AUTOMATION] Lista de compras "%s" creada', name))
    
    return list
end

function add_to_shopping_list(list_name, item_key, max_price, quantity)
    if not shopping_lists[list_name] then
        aux.print(string.format('|cFFFF0000Error:|r Lista "%s" no existe', list_name))
        return false
    end
    
    local list = shopping_lists[list_name]
    
    tinsert(list.items, {
        item_key = item_key,
        max_price = max_price,
        quantity = quantity or 1,
        purchased = 0,
    })
    
    list.last_updated = time()
    
    return true
end

function scan_shopping_list(list_name)
    if not shopping_lists[list_name] then
        aux.print(string.format('|cFFFF0000Error:|r Lista "%s" no existe', list_name))
        return
    end
    
    local list = shopping_lists[list_name]
    
    aux.print(string.format('[AUTOMATION] Escaneando lista: %s', list_name))
    
    -- Escanear cada item de la lista
    for i = 1, getn(list.items) do
        local item = list.items[i]
        
        if item.purchased < item.quantity then
            -- Buscar en AH
            scan_for_shopping_item(item, list.auto_buy)
        end
    end
end

function scan_for_shopping_item(item, auto_buy)
    local needed = item.quantity - item.purchased
    
    if needed <= 0 then
        return
    end
    
    aux.print(string.format(
        '  Buscando: %s x%d (max: %s)',
        item.item_key,
        needed,
        format_money(item.max_price)
    ))
    
    -- Obtener subastas del item
    local auctions = get_all_auctions_for_item(item.item_key)
    
    if not auctions or getn(auctions) == 0 then
        aux.print(string.format('    |cFFFF8800No se encontraron subastas de %s|r', item.item_key))
        return
    end
    
    -- Ordenar por precio (menor a mayor)
    table.sort(auctions, function(a, b)
        local price_a = a.unit_buyout_price or a.buyout_price or 999999999
        local price_b = b.unit_buyout_price or b.buyout_price or 999999999
        return price_a < price_b
    end)
    
    -- Buscar subastas que cumplan nuestro precio máximo
    local found_count = 0
    local total_cost = 0
    
    for i, auction in ipairs(auctions) do
        local unit_price = auction.unit_buyout_price or auction.buyout_price or 0
        
        if unit_price > 0 and unit_price <= item.max_price then
            local can_buy = math.min(auction.count, needed - found_count)
            
            aux.print(string.format(
                '    |cFF00FF00Encontrado:|r %s x%d @ %s (total: %s)',
                item.item_key,
                can_buy,
                format_money(unit_price),
                format_money(unit_price * can_buy)
            ))
            
            found_count = found_count + can_buy
            total_cost = total_cost + (unit_price * can_buy)
            
            -- Si auto_buy está habilitado, comprar
            if auto_buy then
                local success = buy_auction(auction, can_buy)
                
                if success then
                    item.purchased = item.purchased + can_buy
                    aux.print(string.format('    |cFF00FF00Comprado:|r %s x%d', item.item_key, can_buy))
                    
                    -- Notificar
                    if M.modules and M.modules.notifications then
                        M.modules.notifications.purchase(item.item_key, unit_price * can_buy, 5)
                    end
                end
            end
            
            if found_count >= needed then
                break
            end
        end
    end
    
    if found_count > 0 then
        aux.print(string.format(
            '  |cFF00FF00Resumen:|r Encontrados %d/%d items (costo total: %s)',
            found_count,
            needed,
            format_money(total_cost)
        ))
    else
        aux.print(string.format('  |cFFFF0000No se encontraron items dentro del precio máximo|r'))
    end
end

function buy_auction(auction, quantity)
    -- Verificar que tenemos suficiente oro
    local total_cost = (auction.unit_buyout_price or auction.buyout_price) * quantity
    local current_money = GetMoney()
    
    if current_money < total_cost then
        aux.print('|cFFFF0000Error:|r No tienes suficiente oro')
        return false
    end
    
    -- Usar API de WoW para comprar
    -- Nota: En WoW vanilla, PlaceAuctionBid compra si usamos el precio de buyout
    
    if auction.buyout_price and auction.buyout_price > 0 then
        -- Comprar con buyout
        PlaceAuctionBid('list', auction.index, auction.buyout_price)
        
        -- Registrar compra en tracking
        if M.modules and M.modules.core and M.modules.core.record_purchase then
            M.modules.core.record_purchase(
                auction.item_key,
                auction.item_name or auction.item_key,
                quantity,
                auction.unit_buyout_price or auction.buyout_price,
                'buyout'
            )
        end
        
        return true
    end
    
    return false
end

-- ============================================================================
-- Smart Notifications
-- ============================================================================

local notification_config = {
    enabled = true,
    sound_enabled = true,
    chat_enabled = true,
    screen_enabled = true,
    min_profit_for_alert = 10000,  -- 1g mínimo
}

function send_notification(type, message, data)
    if not notification_config.enabled then
        return
    end
    
    -- Determinar severidad
    local color = '|cFFFFFFFF'  -- Blanco por defecto
    local sound = nil
    
    if type == 'exceptional_opportunity' then
        color = '|cFFFFD700'  -- Dorado
        sound = 'AuctionWindowOpen'
    elseif type == 'good_opportunity' then
        color = '|cFF00FF00'  -- Verde
        sound = 'MapPing'
    elseif type == 'warning' then
        color = '|cFFFF8800'  -- Naranja
        sound = 'RaidWarning'
    elseif type == 'error' then
        color = '|cFFFF0000'  -- Rojo
        sound = 'TellMessage'
    end
    
    -- Enviar a chat
    if notification_config.chat_enabled then
        aux.print(color .. '[TRADING] ' .. message .. '|r')
    end
    
    -- Reproducir sonido
    if notification_config.sound_enabled and sound then
        PlaySound(sound)
    end
    
    -- Mostrar en pantalla
    if notification_config.screen_enabled then
        show_screen_notification(type, message, color)
    end
end

-- ============================================================================
-- Screen Notification System
-- ============================================================================

local notification_frames = {}
local MAX_NOTIFICATIONS = 5
local NOTIFICATION_DURATION = 5  -- segundos
local notification_y_offset = -100

function show_screen_notification(type, message, color)
    -- Crear frame de notificación
    local frame = CreateFrame('Frame', nil, UIParent)
    frame:SetWidth(400)
    frame:SetHeight(60)
    frame:SetFrameStrata('HIGH')
    frame:SetAlpha(0)
    
    -- Posicionar en la parte superior derecha
    local y_pos = notification_y_offset
    for i = 1, getn(notification_frames) do
        y_pos = y_pos - 70
    end
    
    frame:SetPoint('TOP', UIParent, 'TOP', 0, y_pos)
    
    -- Background
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints(frame)
    bg:SetTexture(0, 0, 0, 0.8)
    
    -- Border
    local border = frame:CreateTexture(nil, 'BORDER')
    border:SetAllPoints(frame)
    border:SetTexture(1, 1, 1, 0.3)
    
    -- Icon (opcional)
    local icon = frame:CreateTexture(nil, 'ARTWORK')
    icon:SetWidth(40)
    icon:SetHeight(40)
    icon:SetPoint('LEFT', frame, 'LEFT', 10, 0)
    
    -- Determinar icono según tipo
    if type == 'exceptional_opportunity' then
        icon:SetTexture('Interface\\Icons\\INV_Misc_Coin_01')
    elseif type == 'good_opportunity' then
        icon:SetTexture('Interface\\Icons\\INV_Misc_Coin_02')
    elseif type == 'warning' then
        icon:SetTexture('Interface\\Icons\\Spell_Shadow_SacrificialShield')
    elseif type == 'error' then
        icon:SetTexture('Interface\\Icons\\Spell_Shadow_Possession')
    else
        icon:SetTexture('Interface\\Icons\\INV_Misc_Note_01')
    end
    
    -- Texto
    local text = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    text:SetPoint('LEFT', icon, 'RIGHT', 10, 0)
    text:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
    text:SetJustifyH('LEFT')
    text:SetText(color .. message .. '|r')
    
    -- Animación de entrada (fade in)
    frame.elapsed = 0
    frame.duration = NOTIFICATION_DURATION
    frame.fade_in = true
    
    frame:SetScript('OnUpdate', function()
        frame.elapsed = frame.elapsed + arg1
        
        -- Fade in (primeros 0.3 segundos)
        if frame.fade_in then
            local alpha = math.min(1.0, frame.elapsed / 0.3)
            frame:SetAlpha(alpha)
            
            if frame.elapsed >= 0.3 then
                frame.fade_in = false
                frame.elapsed = 0
            end
        -- Mostrar (durante NOTIFICATION_DURATION segundos)
        elseif frame.elapsed < frame.duration then
            frame:SetAlpha(1.0)
        -- Fade out (últimos 0.5 segundos)
        else
            local fade_time = frame.elapsed - frame.duration
            local alpha = math.max(0, 1.0 - (fade_time / 0.5))
            frame:SetAlpha(alpha)
            
            if alpha <= 0 then
                frame:Hide()
                frame:SetScript('OnUpdate', nil)
                
                -- Remover de la lista
                for i = 1, getn(notification_frames) do
                    if notification_frames[i] == frame then
                        tremove(notification_frames, i)
                        break
                    end
                end
            end
        end
    end)
    
    -- Agregar a la lista
    tinsert(notification_frames, frame)
    
    -- Limitar cantidad de notificaciones
    if getn(notification_frames) > MAX_NOTIFICATIONS then
        local oldest = notification_frames[1]
        oldest:Hide()
        oldest:SetScript('OnUpdate', nil)
        tremove(notification_frames, 1)
    end
    
    frame:Show()
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- get_our_active_auctions() ahora está en helpers.lua

-- get_bag_items() ahora está en helpers.lua

function format_money(copper)
    if not copper or copper == 0 then
        return '0c'
    end
    
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
    
    return result
end

-- ============================================================================
-- Auto-Update Loop
-- ============================================================================

local update_timer = 0
local UPDATE_INTERVAL = 60  -- 1 minuto

function on_update(elapsed)
    update_timer = update_timer + elapsed
    
    if update_timer >= UPDATE_INTERVAL then
        update_timer = 0
        
        -- Ejecutar auto-posting
        if auto_post_config.enabled then
            execute_auto_posting()
        end
        
        -- Verificar undercuts
        if auto_post_config.enabled and auto_post_config.auto_repost then
            check_for_undercuts()
        end
    end
end

-- ============================================================================
-- Configuration Functions
-- ============================================================================

function set_auto_post_enabled(enabled)
    auto_post_config.enabled = enabled
    
    if enabled then
        aux.print('[AUTOMATION] Auto-posting habilitado')
    else
        aux.print('[AUTOMATION] Auto-posting deshabilitado')
    end
end

function set_pricing_strategy(strategy)
    local valid_strategies = {
        undercut = true,
        market = true,
        aggressive = true,
        conservative = true,
    }
    
    if not valid_strategies[strategy] then
        aux.print('|cFFFF0000Error:|r Estrategia inválida')
        return false
    end
    
    auto_post_config.pricing_strategy = strategy
    aux.print(string.format('[AUTOMATION] Estrategia de pricing: %s', strategy))
    
    return true
end

function set_auto_repost(enabled)
    auto_post_config.auto_repost = enabled
    
    if enabled then
        aux.print('[AUTOMATION] Auto-repost habilitado')
    else
        aux.print('[AUTOMATION] Auto-repost deshabilitado')
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

aux.event_listener('LOAD2', function()
    init_auto_post_config()
    init_repost_system()
    init_inventory_management()
    init_shopping_lists()
    aux.print('[AUTOMATION] Sistema de automatización inicializado')
end)

-- Registrar update loop
aux.event_listener('UPDATE', on_update)

-- ============================================================================
-- UI UPDATE & TOGGLE FUNCTIONS
-- ============================================================================

function update_automation_ui(automation_frame)
    if not automation_frame then return end
    
    -- Crear UI inicial si no existe
    if not automation_frame.initialized then
        create_automation_ui(automation_frame)
        automation_frame.initialized = true
    end
    
    -- Actualizar estados
    if automation_frame.auto_post_toggle and automation_frame.auto_post_toggle.status then
        automation_frame.auto_post_toggle.status:SetText(auto_post_config.enabled and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
    if automation_frame.auto_repost_toggle and automation_frame.auto_repost_toggle.status then
        automation_frame.auto_repost_toggle.status:SetText(auto_post_config.auto_repost and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
    if automation_frame.inventory_toggle and automation_frame.inventory_toggle.status then
        automation_frame.inventory_toggle.status:SetText(inventory_config.enabled and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
    if automation_frame.shopping_toggle and automation_frame.shopping_toggle.status then
        automation_frame.shopping_toggle.status:SetText(shopping_config.enabled and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
    if automation_frame.notifications_toggle and automation_frame.notifications_toggle.status then
        automation_frame.notifications_toggle.status:SetText(notification_config.enabled and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
    if automation_frame.auto_buy_toggle and automation_frame.auto_buy_toggle.status then
        automation_frame.auto_buy_toggle.status:SetText(auto_buy_config.enabled and '|cFF00FF00ON|r' or '|cFFFF0000OFF|r')
    end
end

function create_automation_ui(automation_frame)
    if not automation_frame then return end
    
    -- Título
    local title = automation_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 20, -20)
    title:SetText('|cFFFFD700Automatización|r')
    
    -- Descripción
    local desc = automation_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    desc:SetPoint('TOPLEFT', 20, -50)
    desc:SetPoint('TOPRIGHT', -20, -50)
    desc:SetJustifyH('LEFT')
    desc:SetText('|cFF888888Automatización avanzada para posting, gestión de inventario y trading.|r')
    
    -- Controles de automatización
    local y_offset = -80
    
    -- Auto-posting
    automation_frame.auto_post_toggle = create_toggle_button(automation_frame, 'Auto-posting', y_offset, function()
        toggle_auto_post()
        update_automation_ui(automation_frame)
    end)
    y_offset = y_offset - 30
    
    -- Auto-repost
    automation_frame.auto_repost_toggle = create_toggle_button(automation_frame, 'Auto-repost', y_offset, function()
        toggle_auto_repost()
        update_automation_ui(automation_frame)
    end)
    y_offset = y_offset - 30
    
    -- Gestión de inventario
    automation_frame.inventory_toggle = create_toggle_button(automation_frame, 'Gestión Inventario', y_offset, function()
        toggle_inventory()
        update_automation_ui(automation_frame)
    end)
    y_offset = y_offset - 30
    
    -- Shopping automático
    automation_frame.shopping_toggle = create_toggle_button(automation_frame, 'Shopping Auto', y_offset, function()
        toggle_shopping()
        update_automation_ui(automation_frame)
    end)
    y_offset = y_offset - 30
    
    -- Notificaciones
    automation_frame.notifications_toggle = create_toggle_button(automation_frame, 'Notificaciones', y_offset, function()
        toggle_notifications()
        update_automation_ui(automation_frame)
    end)
    y_offset = y_offset - 30
    
    -- Auto-buy
    automation_frame.auto_buy_toggle = create_toggle_button(automation_frame, 'Auto-buy', y_offset, function()
        toggle_auto_buy()
        update_automation_ui(automation_frame)
    end)
end

function create_toggle_button(parent, text, y_offset, on_click)
    local button = CreateFrame('Button', nil, parent)
    button:SetPoint('TOPLEFT', 20, y_offset)
    button:SetWidth(150)
    button:SetHeight(25)
    
    local label = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetPoint('LEFT', 0, 0)
    label:SetText(text)
    button.label = label
    
    local status = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    status:SetPoint('RIGHT', 0, 0)
    status:SetText('|cFFFF0000OFF|r')
    button.status = status
    
    button:SetScript('OnClick', on_click)
    button:SetScript('OnEnter', function() button.label:SetTextColor(1, 1, 0) end)
    button:SetScript('OnLeave', function() button.label:SetTextColor(1, 1, 1) end)
    
    return button
end

function toggle_auto_post()
    auto_post_config.enabled = not auto_post_config.enabled
    aux.print(string.format('|cFFFFD700Auto-posting %s|r', auto_post_config.enabled and 'activado' or 'desactivado'))
    return auto_post_config.enabled
end

function toggle_auto_repost()
    auto_post_config.auto_repost = not auto_post_config.auto_repost
    aux.print(string.format('|cFFFFD700Auto-repost %s|r', auto_post_config.auto_repost and 'activado' or 'desactivado'))
    return auto_post_config.auto_repost
end

function toggle_inventory()
    aux.print('|cFFFFD700Gestión de inventario toggled|r')
    return true
end

function toggle_shopping()
    aux.print('|cFFFFD700Shopping lists toggled|r')
    return true
end

function toggle_notifications()
    aux.print('|cFFFFD700Notificaciones toggled|r')
    return true
end

function toggle_auto_buy()
    aux.print('|cFFFFD700Auto-buy toggled|r')
    return true
end

-- ============================================================================
-- REGISTRO DE FUNCIONES PÚBLICAS
-- ============================================================================

local M = getfenv()
if M.modules then
    M.modules.automation = {
        -- UI functions
        update_ui = update_automation_ui,
        toggle_auto_post = toggle_auto_post,
        toggle_auto_repost = toggle_auto_repost,
        toggle_inventory = toggle_inventory,
        toggle_shopping = toggle_shopping,
        toggle_notifications = toggle_notifications,
        toggle_auto_buy = toggle_auto_buy,
        -- Auto-posting functions
        execute_auto_posting = execute_auto_posting,
        calculate_optimal_price = calculate_optimal_price,
        post_item_intelligently = post_item_intelligently,
        -- Configuration
        set_auto_post_enabled = set_auto_post_enabled,
        set_pricing_strategy = set_pricing_strategy,
        set_auto_repost = set_auto_repost,
        get_config = function() return auto_post_config end,
        -- Shopping lists
        create_shopping_list = create_shopping_list,
        add_to_shopping_list = add_to_shopping_list,
        scan_shopping_list = scan_shopping_list,
        get_shopping_lists = function() return shopping_lists end,
        -- Reposting
        check_for_undercuts = check_for_undercuts,
        process_repost_queue = process_repost_queue,
        get_repost_queue = function() return repost_queue end,
    }
    aux.print('[AUTOMATION] Funciones registradas')
end
