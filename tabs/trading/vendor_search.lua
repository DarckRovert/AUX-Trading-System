module 'aux.tabs.trading'

local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'
local M = getfenv()

--[[
    VENDOR SEARCH SYSTEM
    Inspirado en TradeSkillMaster
    
    Busca items en la AH que se pueden comprar y vender al vendor con ganancia.
    
    Lógica:
    - Obtener precio de venta al vendor (GetItemInfo)
    - Comparar con precio de buyout en AH
    - Si vendor_price > buyout_price = GANANCIA
]]

-- Cache de precios de vendor
local vendor_price_cache = {}

-- Obtener precio de venta al vendor de un item
function M.get_vendor_price(item_id)
    if not item_id then return 0 end
    
    -- Revisar cache primero
    if vendor_price_cache[item_id] then
        return vendor_price_cache[item_id]
    end
    
    -- GetItemInfo retorna: name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(item_id)
    
    if vendorPrice and vendorPrice > 0 then
        vendor_price_cache[item_id] = vendorPrice
        return vendorPrice
    end
    
    return 0
end

-- Evaluar si un auction es una oportunidad de vendor
function M.evaluate_vendor_opportunity(auction_info)
    if not auction_info then return nil end
    
    local item_id = auction_info.item_id
    local buyout = auction_info.buyout_price or 0
    local count = auction_info.count or 1
    
    if buyout <= 0 or not item_id then
        return nil
    end
    
    local vendor_price_per_unit = M.get_vendor_price(item_id)
    if vendor_price_per_unit <= 0 then
        return nil
    end
    
    -- Calcular precio total de venta al vendor
    local total_vendor_price = vendor_price_per_unit * count
    
    -- Calcular ganancia
    local profit = total_vendor_price - buyout
    
    -- Solo es oportunidad si hay ganancia
    if profit > 0 then
        local percent_profit = math.floor((profit / buyout) * 100)
        
        return {
            is_vendor_deal = true,
            item_id = item_id,
            item_name = auction_info.name or 'Unknown',
            buyout_price = buyout,
            vendor_price = total_vendor_price,
            vendor_price_per_unit = vendor_price_per_unit,
            count = count,
            profit = profit,
            percent_profit = percent_profit,
            score = math.min(100, percent_profit),  -- Score basado en % de ganancia
            auction_info = auction_info
        }
    end
    
    return nil
end

-- Escanear AH buscando oportunidades de vendor
local vendor_opportunities = {}
local vendor_scan_active = false
local vendor_scan_index = 0
local vendor_scan_total = 0

function M.start_vendor_scan()
    if vendor_scan_active then
        aux.print('|cFFFFFF00Vendor scan ya está activo|r')
        return
    end
    
    vendor_opportunities = {}
    vendor_scan_active = true
    vendor_scan_index = 0
    
    aux.print('|cFF00FF00Iniciando Vendor Search...|r')
    aux.print('|cFFFFFFFFBuscando items para vender al vendor con ganancia|r')
    
    -- Usar el sistema de scan de aux
    local scan = require 'aux.core.scan'
    if scan and scan.start then
        -- Configurar scan completo
        M.vendor_scan_auctions()
    else
        aux.print('|cFFFF0000Error: Sistema de scan no disponible|r')
        vendor_scan_active = false
    end
end

function M.stop_vendor_scan()
    vendor_scan_active = false
    aux.print('|cFFFF8888Vendor scan detenido|r')
end

-- Procesar resultados del scan para vendor
function M.process_vendor_scan_result(auction_info)
    if not vendor_scan_active then return end
    
    local opportunity = M.evaluate_vendor_opportunity(auction_info)
    if opportunity then
        table.insert(vendor_opportunities, opportunity)
        
        -- Ordenar por ganancia (mayor primero)
        table.sort(vendor_opportunities, function(a, b)
            return (a.profit or 0) > (b.profit or 0)
        end)
        
        -- Limitar a 100 mejores oportunidades
        while table.getn(vendor_opportunities) > 100 do
            table.remove(vendor_opportunities)
        end
    end
end

-- Obtener oportunidades de vendor encontradas
function M.get_vendor_opportunities()
    return vendor_opportunities
end

-- Verificar si vendor scan está activo
function M.is_vendor_scan_active()
    return vendor_scan_active
end

-- Escanear auctions actuales en la AH
function M.vendor_scan_auctions()
    local num_auctions = GetNumAuctionItems('list') or 0
    vendor_scan_total = num_auctions
    
    if num_auctions == 0 then
        aux.print('|cFFFFFF00No hay auctions para escanear. Haz una búsqueda primero.|r')
        vendor_scan_active = false
        return
    end
    
    aux.print(string.format('|cFF00FF00Analizando %d auctions...|r', num_auctions))
    
    local found = 0
    for i = 1, num_auctions do
        local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo('list', i)
        
        if name and buyoutPrice and buyoutPrice > 0 and itemId then
            local auction_info = {
                item_id = itemId,
                name = name,
                count = count or 1,
                quality = quality,
                buyout_price = buyoutPrice,
                bid_price = minBid,
                seller = owner,
                index = i
            }
            
            local opp = M.evaluate_vendor_opportunity(auction_info)
            if opp then
                table.insert(vendor_opportunities, opp)
                found = found + 1
            end
        end
    end
    
    -- Ordenar por ganancia
    table.sort(vendor_opportunities, function(a, b)
        return (a.profit or 0) > (b.profit or 0)
    end)
    
    vendor_scan_active = false
    
    if found > 0 then
        aux.print(string.format('|cFF00FF00¡Encontradas %d oportunidades de vendor!|r', found))
        
        -- Mostrar las mejores 3
        for i = 1, math.min(3, found) do
            local opp = vendor_opportunities[i]
            local gold = math.floor(opp.profit / 10000)
            local silver = math.floor(math.mod(opp.profit, 10000) / 100)
            aux.print(string.format('  |cFFFFD700%d.|r %s x%d - Ganancia: |cFF00FF00%dg %ds|r', 
                i, opp.item_name, opp.count, gold, silver))
        end
    else
        aux.print('|cFFFF8888No se encontraron oportunidades de vendor|r')
    end
    
    -- Actualizar UI si está disponible
    if M.update_vendor_ui then
        M.update_vendor_ui()
    end
end

-- Comprar oportunidad de vendor
function M.buy_vendor_opportunity(opportunity)
    if not opportunity or not opportunity.auction_info then
        aux.print('|cFFFF0000Error: Oportunidad inválida|r')
        return false
    end
    
    local index = opportunity.auction_info.index
    if not index then
        aux.print('|cFFFF0000Error: Índice de auction no encontrado|r')
        return false
    end
    
    -- Intentar comprar
    PlaceAuctionBid('list', index, opportunity.buyout_price)
    
    local gold = math.floor(opportunity.profit / 10000)
    local silver = math.floor(math.mod(opportunity.profit, 10000) / 100)
    aux.print(string.format('|cFF00FF00Comprando %s - Ganancia esperada: %dg %ds|r', 
        opportunity.item_name, gold, silver))
    
    return true
end

-- Limpiar oportunidades
function M.clear_vendor_opportunities()
    vendor_opportunities = {}
    aux.print('|cFFFFFFFFOportunidades de vendor limpiadas|r')
end

-- Registrar en el módulo
M.modules = M.modules or {}
M.modules.vendor_search = M

aux.print('[TRADING] Módulo Vendor Search cargado')
