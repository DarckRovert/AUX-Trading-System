module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

--[[
    AUCTIONING MODULE
    Inspirado en TradeSkillMaster_Auctioning
    
    Permite postear items automáticamente con precios óptimos,
    hacer undercut de competencia, y cancel/repost de subastas.
]]

aux.print('[AUCTIONING] Módulo de subastas cargado')

-- ============================================================================
-- Variables Globales
-- ============================================================================

local auctioning_groups = {}
local posting_queue = {}
local cancel_queue = {}
local posting_in_progress = false
local last_scan_time = 0

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

-- Configuración por defecto
local default_config = {
    undercut_amount = 1,           -- 1 copper undercut
    min_price_percent = 80,        -- Mínimo 80% del market value
    max_price_percent = 120,       -- Máximo 120% del market value
    duration = 2,                  -- 48 horas (2 = 48h, 1 = 24h, 3 = 12h)
    stack_size = 1,                -- Tamaño de stack
    post_cap = 1,                  -- Máximo de stacks a postear
    auto_repost = true,            -- Repostear automáticamente
    cancel_undercut = true,        -- Cancelar si nos hacen undercut
}

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================



local function get_market_value(item_key)
    local history = require 'aux.core.history'
    if history and history.value then
        return history.value(item_key) or 0
    end
    return 0
end

-- ============================================================================
-- Gestión de Grupos
-- ============================================================================

function M.crear_grupo_auctioning(nombre, config)
    if not nombre then return false end
    
    auctioning_groups[nombre] = {
        nombre = nombre,
        items = {},
        config = config or default_config,
        activo = true,
        stats = {
            posted = 0,
            cancelled = 0,
            sold = 0,
            profit = 0,
        }
    }
    
    aux.print(string.format('|cFF00FF00Grupo creado: %s|r', nombre))
    return true
end

function M.agregar_item_a_grupo(grupo_nombre, item_id, item_name)
    local grupo = auctioning_groups[grupo_nombre]
    if not grupo then
        aux.print('|cFFFF0000Grupo no encontrado|r')
        return false
    end
    
    table.insert(grupo.items, {
        item_id = item_id,
        item_name = item_name,
        added_time = time(),
    })
    
    aux.print(string.format('|cFF00FF00%s agregado a %s|r', item_name, grupo_nombre))
    return true
end

function M.obtener_grupos()
    return auctioning_groups
end

-- ============================================================================
-- Cálculo de Precios
-- ============================================================================

local function calcular_precio_optimo(item_key, config)
    local market_value = get_market_value(item_key)
    if market_value == 0 then
        return nil, "Sin datos de mercado"
    end
    
    -- Obtener precio más bajo actual en AH
    local lowest_price = M.obtener_precio_mas_bajo(item_key)
    
    local precio_final
    
    if lowest_price and lowest_price > 0 then
        -- Hacer undercut
        precio_final = lowest_price - (config.undercut_amount or 1)
    else
        -- No hay competencia, usar market value
        precio_final = market_value
    end
    
    -- Aplicar límites
    local min_price = market_value * (config.min_price_percent or 80) / 100
    local max_price = market_value * (config.max_price_percent or 120) / 100
    
    if precio_final < min_price then
        precio_final = min_price
    elseif precio_final > max_price then
        precio_final = max_price
    end
    
    return math.floor(precio_final), "OK"
end

function M.obtener_precio_mas_bajo(item_key)
    -- Escanear la AH y obtener el precio más bajo actual
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        return nil
    end
    
    local num_auctions = GetNumAuctionItems("list")
    local lowest_price = nil
    
    for i = 1, num_auctions do
        local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bid, isHighBidder, owner = GetAuctionItemInfo("list", i)
        
        if name then
            local link = GetAuctionItemLink("list", i)
            if link then
                local current_item_key = aux.util.info.parse_link(link)
                
                if current_item_key == item_key and buyout and buyout > 0 then
                    local unit_price = buyout / count
                    if not lowest_price or unit_price < lowest_price then
                        lowest_price = unit_price
                    end
                end
            end
        end
    end
    
    return lowest_price
end

-- ============================================================================
-- Posteo de Items
-- ============================================================================

function M.agregar_a_queue_posteo(item_info)
    table.insert(posting_queue, item_info)
    aux.print(string.format('|cFFFFFF00%s agregado a queue de posteo|r', item_info.name))
end

function M.procesar_queue_posteo()
    if posting_in_progress then
        aux.print('|cFFFFAA00Ya hay un posteo en progreso|r')
        return
    end
    
    if table.getn(posting_queue) == 0 then
        aux.print('|cFFFFAA00Queue de posteo vacía|r')
        return
    end
    
    posting_in_progress = true
    aux.print(string.format('|cFF00FF00Procesando %d items...|r', table.getn(posting_queue)))
    
    -- Procesar cada item en la queue
    for i = 1, table.getn(posting_queue) do
        local item = posting_queue[i]
        M.postear_item(item)
    end
    
    -- Limpiar queue
    posting_queue = {}
    posting_in_progress = false
    
    aux.print('|cFF00FF00Posteo completado|r')
end

function M.postear_item(item_info)
    if not item_info then return false end
    
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Debes estar en la Casa de Subastas|r')
        return false
    end
    
    local item_key = item_info.item_key
    local config = item_info.config or default_config
    
    -- Calcular precio óptimo
    local precio, msg = calcular_precio_optimo(item_key, config)
    
    if not precio then
        aux.print(string.format('|cFFFF0000No se puede postear %s: %s|r', item_info.name, msg))
        return false
    end
    
    -- Buscar el item en el inventario
    local bag, slot = nil, nil
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local link = GetContainerItemLink(b, s)
            if link then
                local current_item_key = aux.util.info.parse_link(link)
                if current_item_key == item_key then
                    bag, slot = b, s
                    break
                end
            end
        end
        if bag then break end
    end
    
    if not bag or not slot then
        aux.print(string.format('|cFFFF0000%s no encontrado en inventario|r', item_info.name))
        return false
    end
    
    -- Postear el item usando WoW API
    PickupContainerItem(bag, slot)
    ClickAuctionSellItemButton()
    
    local bid = math.floor(precio * 0.95) -- Bid = 95% del buyout
    local duration = config.duration or 2
    
    StartAuction(bid, precio, duration)
    
    aux.print(string.format(
        '|cFF00FF00Posteando %s por %s|r',
        item_info.name,
        format_gold(precio)
    ))
    
    -- Actualizar stats del grupo
    if item_info.grupo then
        local grupo = auctioning_groups[item_info.grupo]
        if grupo then
            grupo.stats.posted = grupo.stats.posted + 1
        end
    end
    
    return true
end

-- ============================================================================
-- Cancel/Repost
-- ============================================================================

function M.escanear_mis_subastas()
    -- Escanear subastas propias
    local mis_subastas = {}
    
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        return mis_subastas
    end
    
    local num_auctions = GetNumAuctionItems("owner")
    
    for i = 1, num_auctions do
        local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bid, isHighBidder, owner, saleStatus = GetAuctionItemInfo("owner", i)
        
        if name and buyout and buyout > 0 then
            local link = GetAuctionItemLink("owner", i)
            local item_key = nil
            
            if link then
                item_key = aux.util.info.parse_link(link)
            end
            
            tinsert(mis_subastas, {
                index = i,
                name = name,
                item_key = item_key,
                count = count,
                buyout = buyout,
                unit_price = buyout / count,
                time_left = saleStatus,
            })
        end
    end
    
    return mis_subastas
end

function M.detectar_undercuts()
    local undercuts = {}
    local mis_subastas = M.escanear_mis_subastas()
    
    for i = 1, table.getn(mis_subastas) do
        local subasta = mis_subastas[i]
        local precio_mas_bajo = M.obtener_precio_mas_bajo(subasta.item_key)
        
        if precio_mas_bajo and precio_mas_bajo < subasta.buyout then
            table.insert(undercuts, subasta)
        end
    end
    
    return undercuts
end

function M.cancelar_subasta(auction_index)
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Debes estar en la Casa de Subastas|r')
        return false
    end
    
    -- Cancelar la subasta usando WoW API
    CancelAuction(auction_index)
    aux.print('|cFF00FF00Subasta cancelada|r')
    
    return true
end

function M.auto_cancel_repost()
    local undercuts = M.detectar_undercuts()
    
    if table.getn(undercuts) == 0 then
        aux.print('|cFF00FF00No hay undercuts detectados|r')
        return
    end
    
    aux.print(string.format('|cFFFFAA00%d undercuts detectados|r', table.getn(undercuts)))
    
    for i = 1, table.getn(undercuts) do
        local subasta = undercuts[i]
        
        -- Cancelar
        M.cancelar_subasta(subasta.index)
        
        -- Agregar a queue de reposteo
        M.agregar_a_queue_posteo({
            name = subasta.name,
            item_key = subasta.item_key,
            config = subasta.config,
            grupo = subasta.grupo,
        })
    end
    
    -- Procesar queue de reposteo
    M.procesar_queue_posteo()
end

-- ============================================================================
-- Posteo Masivo por Grupo
-- ============================================================================

function M.postear_grupo(grupo_nombre)
    local grupo = auctioning_groups[grupo_nombre]
    if not grupo then
        aux.print('|cFFFF0000Grupo no encontrado|r')
        return false
    end
    
    if not grupo.activo then
        aux.print('|cFFFFAA00Grupo desactivado|r')
        return false
    end
    
    aux.print(string.format('|cFF00FF00Posteando grupo: %s|r', grupo_nombre))
    
    -- Agregar todos los items del grupo a la queue
    for i = 1, table.getn(grupo.items) do
        local item = grupo.items[i]
        
        -- Verificar si tenemos el item en inventario
        -- TODO: Implementar búsqueda en inventario
        
        M.agregar_a_queue_posteo({
            name = item.item_name,
            item_key = tostring(item.item_id) .. ':0',
            config = grupo.config,
            grupo = grupo_nombre,
        })
    end
    
    -- Procesar queue
    M.procesar_queue_posteo()
    
    return true
end

function M.postear_todos_los_grupos()
    local count = 0
    
    for nombre, grupo in pairs(auctioning_groups) do
        if grupo.activo then
            M.postear_grupo(nombre)
            count = count + 1
        end
    end
    
    aux.print(string.format('|cFF00FF00%d grupos posteados|r', count))
end

-- ============================================================================
-- Estadísticas
-- ============================================================================

function M.obtener_stats_auctioning()
    local total_posted = 0
    local total_cancelled = 0
    local total_sold = 0
    local total_profit = 0
    
    for nombre, grupo in pairs(auctioning_groups) do
        total_posted = total_posted + grupo.stats.posted
        total_cancelled = total_cancelled + grupo.stats.cancelled
        total_sold = total_sold + grupo.stats.sold
        total_profit = total_profit + grupo.stats.profit
    end
    
    return {
        total_posted = total_posted,
        total_cancelled = total_cancelled,
        total_sold = total_sold,
        total_profit = total_profit,
        grupos_activos = M.contar_grupos_activos(),
    }
end

function M.contar_grupos_activos()
    local count = 0
    for nombre, grupo in pairs(auctioning_groups) do
        if grupo.activo then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- Grupos Predefinidos
-- ============================================================================

function M.crear_grupos_predefinidos()
    -- Grupo de consumibles
    M.crear_grupo_auctioning('Consumibles', {
        undercut_amount = 1,
        min_price_percent = 90,
        max_price_percent = 110,
        duration = 2,
        stack_size = 5,
        post_cap = 4,
    })
    
    -- Grupo de materiales
    M.crear_grupo_auctioning('Materiales', {
        undercut_amount = 1,
        min_price_percent = 95,
        max_price_percent = 105,
        duration = 2,
        stack_size = 20,
        post_cap = 2,
    })
    
    -- Grupo de equipamiento
    M.crear_grupo_auctioning('Equipamiento', {
        undercut_amount = 5,
        min_price_percent = 80,
        max_price_percent = 150,
        duration = 2,
        stack_size = 1,
        post_cap = 1,
    })
    
    aux.print('|cFF00FF00Grupos predefinidos creados|r')
end

-- ============================================================================
-- Inicialización
-- ============================================================================

function M.inicializar_auctioning()
    -- Crear grupos predefinidos si no existen
    if not auctioning_groups or table.getn(auctioning_groups) == 0 then
        M.crear_grupos_predefinidos()
    end
    
    aux.print('|cFF00FF00Auctioning Module inicializado|r')
end

-- ============================================================================
-- Funciones Principales para Botones
-- ============================================================================

function M.post_all_items()
    -- Postear todos los items de todos los grupos activos
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Debes estar en la Casa de Subastas|r')
        return false
    end
    
    aux.print('|cFF00FF00[AUCTIONING] Iniciando posteo masivo...|r')
    
    local total_posted = 0
    
    for nombre, grupo in pairs(auctioning_groups) do
        if grupo.activo then
            aux.print(string.format('|cFFFFFF00Procesando grupo: %s|r', nombre))
            
            for i = 1, table.getn(grupo.items) do
                local item = grupo.items[i]
                local item_key = tostring(item.item_id) .. ':0'
                
                local success = M.postear_item({
                    name = item.item_name,
                    item_key = item_key,
                    config = grupo.config,
                    grupo = nombre,
                })
                
                if success then
                    total_posted = total_posted + 1
                end
            end
        end
    end
    
    aux.print(string.format('|cFF00FF00[AUCTIONING] Posteo completado: %d items posteados|r', total_posted))
    return true
end

function M.cancel_undercut_auctions()
    -- Cancelar subastas que han sido undercut y repostearlas
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Debes estar en la Casa de Subastas|r')
        return false
    end
    
    aux.print('|cFF00FF00[AUCTIONING] Escaneando undercuts...|r')
    
    local undercuts = M.detectar_undercuts()
    
    if table.getn(undercuts) == 0 then
        aux.print('|cFF00FF00No hay undercuts detectados|r')
        return true
    end
    
    aux.print(string.format('|cFFFFAA00%d undercuts detectados, cancelando...|r', table.getn(undercuts)))
    
    local cancelled = 0
    
    for i = 1, table.getn(undercuts) do
        local subasta = undercuts[i]
        
        if M.cancelar_subasta(subasta.index) then
            cancelled = cancelled + 1
            
            -- Agregar a queue de reposteo
            M.agregar_a_queue_posteo({
                name = subasta.name,
                item_key = subasta.item_key,
                config = default_config,
            })
        end
    end
    
    aux.print(string.format('|cFF00FF00%d subastas canceladas|r', cancelled))
    
    -- Repostear
    if table.getn(posting_queue) > 0 then
        aux.print('|cFFFFFF00Reposteando items...|r')
        M.procesar_queue_posteo()
    end
    
    return true
end

function M.scan_prices()
    -- Escanear precios actuales del mercado para todos los items en grupos
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Debes estar en la Casa de Subastas|r')
        return false
    end
    
    aux.print('|cFF00FF00[AUCTIONING] Escaneando precios del mercado...|r')
    
    local items_to_scan = {}
    
    -- Recopilar todos los items de todos los grupos
    for nombre, grupo in pairs(auctioning_groups) do
        if grupo.activo then
            for i = 1, table.getn(grupo.items) do
                local item = grupo.items[i]
                local item_key = tostring(item.item_id) .. ':0'
                items_to_scan[item_key] = item.item_name
            end
        end
    end
    
    local scanned = 0
    
    for item_key, item_name in pairs(items_to_scan) do
        local lowest_price = M.obtener_precio_mas_bajo(item_key)
        local market_value = get_market_value(item_key)
        
        if lowest_price then
            aux.print(string.format(
                '|cFFFFFF00%s:|r Precio más bajo: %s | Market: %s',
                item_name,
                format_gold(lowest_price),
                format_gold(market_value)
            ))
            scanned = scanned + 1
        else
            aux.print(string.format('|cFFFFAA00%s: Sin competencia|r', item_name))
        end
    end
    
    aux.print(string.format('|cFF00FF00[AUCTIONING] Scan completado: %d items escaneados|r', scanned))
    return true
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.auctioning = {
    crear_grupo = M.crear_grupo_auctioning,
    agregar_item = M.agregar_item_a_grupo,
    postear_grupo = M.postear_grupo,
    postear_todos = M.postear_todos_los_grupos,
    auto_cancel_repost = M.auto_cancel_repost,
    obtener_stats = M.obtener_stats_auctioning,
    obtener_grupos = M.obtener_grupos,
    inicializar = M.inicializar_auctioning,
    post_all_items = M.post_all_items,
    cancel_undercut_auctions = M.cancel_undercut_auctions,
    scan_prices = M.scan_prices,
}

-- Exportar funciones principales
M.post_all_items = M.post_all_items
M.cancel_undercut_auctions = M.cancel_undercut_auctions
M.scan_prices = M.scan_prices

aux.print('[AUCTIONING] Módulo registrado correctamente')
