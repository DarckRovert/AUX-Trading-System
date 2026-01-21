module 'aux.tabs.trading'

local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'
local M = getfenv()

--[[
    DEALFINDING SYSTEM
    Inspirado en TradeSkillMaster
    
    Permite crear listas de items con precios máximos.
    Si un item está en la AH por debajo del precio máximo, es una oportunidad.
    
    Estructura de datos:
    aux_trading_dealfinding = {
        ["Lista1"] = {
            [itemID] = {
                name = "Item Name",
                maxPrice = 10000,  -- en copper
                lastSeen = timestamp,
                notes = "opcional"
            }
        }
    }
]]

-- Inicializar SavedVariables si no existe
local function init_saved_vars()
    if not aux_trading_dealfinding then
        aux_trading_dealfinding = {
            ["Default"] = {}
        }
    end
    if not aux_trading_settings then
        aux_trading_settings = {
            min_profit_margin = 0.15,  -- 15% mínimo de ganancia
            max_price_percent = 80,    -- Máximo 80% del valor de mercado
            scan_delay = 0.5,          -- Delay entre scans
            auto_refresh = false,
            sound_alert = true
        }
    end
end

-- Obtener todas las listas
function M.get_dealfinding_lists()
    init_saved_vars()
    return aux_trading_dealfinding
end

-- Crear nueva lista
function M.create_list(name)
    init_saved_vars()
    if not name or name == "" then
        aux.print("|cFFFF0000Error: Nombre de lista inválido|r")
        return false
    end
    if aux_trading_dealfinding[name] then
        aux.print("|cFFFF0000Error: La lista '" .. name .. "' ya existe|r")
        return false
    end
    aux_trading_dealfinding[name] = {}
    aux.print("|cFF00FF00Lista '" .. name .. "' creada exitosamente|r")
    return true
end

-- Eliminar lista
function M.delete_list(name)
    init_saved_vars()
    if not aux_trading_dealfinding[name] then
        aux.print("|cFFFF0000Error: La lista '" .. name .. "' no existe|r")
        return false
    end
    if name == "Default" then
        aux.print("|cFFFF0000Error: No puedes eliminar la lista Default|r")
        return false
    end
    aux_trading_dealfinding[name] = nil
    aux.print("|cFF00FF00Lista '" .. name .. "' eliminada|r")
    return true
end

-- Agregar item a lista
function M.add_item_to_list(list_name, item_id, max_price, item_name)
    init_saved_vars()
    
    list_name = list_name or "Default"
    
    if not aux_trading_dealfinding[list_name] then
        aux.print("|cFFFF0000Error: La lista '" .. list_name .. "' no existe|r")
        return false
    end
    
    if not item_id or not max_price then
        aux.print("|cFFFF0000Error: item_id y max_price son requeridos|r")
        return false
    end
    
    -- Obtener nombre del item si no se proporcionó
    if not item_name then
        local item_info = info.item(item_id)
        item_name = item_info and item_info.name or "Item #" .. item_id
    end
    
    aux_trading_dealfinding[list_name][item_id] = {
        name = item_name,
        maxPrice = max_price,
        lastSeen = time(),
        addedAt = time()
    }
    
    local gold = math.floor(max_price / 10000)
    local silver = math.floor(math.mod(max_price, 10000) / 100)
    aux.print(string.format("|cFF00FF00Agregado '%s' a lista '%s' con precio máximo: %dg %ds|r", 
        item_name, list_name, gold, silver))
    return true
end

-- Remover item de lista
function M.remove_item_from_list(list_name, item_id)
    init_saved_vars()
    
    list_name = list_name or "Default"
    
    if not aux_trading_dealfinding[list_name] then
        aux.print("|cFFFF0000Error: La lista '" .. list_name .. "' no existe|r")
        return false
    end
    
    if not aux_trading_dealfinding[list_name][item_id] then
        aux.print("|cFFFF0000Error: Item no encontrado en la lista|r")
        return false
    end
    
    local item_name = aux_trading_dealfinding[list_name][item_id].name
    aux_trading_dealfinding[list_name][item_id] = nil
    aux.print("|cFF00FF00Removido '" .. item_name .. "' de lista '" .. list_name .. "'|r")
    return true
end

-- Obtener items de una lista
function M.get_list_items(list_name)
    init_saved_vars()
    list_name = list_name or "Default"
    return aux_trading_dealfinding[list_name] or {}
end

-- Actualizar precio máximo de un item
function M.update_max_price(list_name, item_id, new_max_price)
    init_saved_vars()
    
    list_name = list_name or "Default"
    
    if not aux_trading_dealfinding[list_name] or not aux_trading_dealfinding[list_name][item_id] then
        aux.print("|cFFFF0000Error: Item no encontrado|r")
        return false
    end
    
    aux_trading_dealfinding[list_name][item_id].maxPrice = new_max_price
    aux_trading_dealfinding[list_name][item_id].lastSeen = time()
    
    local gold = math.floor(new_max_price / 10000)
    local silver = math.floor(math.mod(new_max_price, 10000) / 100)
    aux.print(string.format("|cFF00FF00Precio actualizado a: %dg %ds|r", gold, silver))
    return true
end

-- Evaluar si un auction es una oportunidad de dealfinding
function M.evaluate_dealfinding_opportunity(auction_info)
    init_saved_vars()
    
    if not auction_info or not auction_info.item_id then
        return nil
    end
    
    local item_id = auction_info.item_id
    local buyout = auction_info.buyout_price or 0
    
    if buyout <= 0 then
        return nil
    end
    
    -- Buscar en todas las listas
    for list_name, items in pairs(aux_trading_dealfinding) do
        if items[item_id] then
            local max_price = items[item_id].maxPrice
            if buyout <= max_price then
                local profit = max_price - buyout
                local percent_of_max = math.floor((buyout / max_price) * 100)
                
                return {
                    is_deal = true,
                    list_name = list_name,
                    item_name = items[item_id].name,
                    max_price = max_price,
                    current_price = buyout,
                    profit = profit,
                    percent_of_max = percent_of_max,
                    score = 100 - percent_of_max  -- Mayor score = mejor deal
                }
            end
        end
    end
    
    return nil
end

-- Escanear AH buscando items de las listas de dealfinding
function M.scan_dealfinding_lists(callback)
    init_saved_vars()
    
    local opportunities = {}
    local items_to_scan = {}
    
    -- Recopilar todos los items de todas las listas
    for list_name, items in pairs(aux_trading_dealfinding) do
        for item_id, item_data in pairs(items) do
            table.insert(items_to_scan, {
                item_id = item_id,
                list_name = list_name,
                item_data = item_data
            })
        end
    end
    
    if table.getn(items_to_scan) == 0 then
        aux.print("|cFFFFFF00No hay items en las listas de dealfinding|r")
        if callback then callback({}) end
        return
    end
    
    aux.print(string.format("|cFF00FF00Escaneando %d items de dealfinding...|r", table.getn(items_to_scan)))
    
    -- Por ahora retornamos la lista de items a escanear
    -- La integración con el scanner de aux se hará en scan_integration.lua
    if callback then
        callback(items_to_scan)
    end
    
    return items_to_scan
end

-- Comando para agregar item desde chat: /aux dealfind add <itemlink> <maxprice>
function M.handle_slash_command(args)
    init_saved_vars()
    
    if not args or args == "" then
        M.print_help()
        return
    end
    
    -- Lua 5.0 compatible: use string.find with captures
    local _, _, cmd, rest = string.find(args, '^(%S+)%s*(.*)')
    cmd = string.lower(cmd or '')
    
    if cmd == "list" or cmd == "lists" then
        M.print_lists()
    elseif cmd == "add" then
        M.handle_add_command(rest)
    elseif cmd == "remove" or cmd == "delete" then
        M.handle_remove_command(rest)
    elseif cmd == "create" then
        M.create_list(rest)
    elseif cmd == "scan" then
        M.scan_dealfinding_lists()
    elseif cmd == "help" then
        M.print_help()
    else
        aux.print("|cFFFF0000Comando desconocido: " .. cmd .. "|r")
        M.print_help()
    end
end

function M.print_help()
    aux.print("|cFFFFD700=== Aux Trading - Dealfinding Commands ===")
    aux.print("|cFFFFFFFF/aux dealfind list|r - Mostrar todas las listas")
    aux.print("|cFFFFFFFF/aux dealfind add <itemlink> <maxprice>|r - Agregar item")
    aux.print("|cFFFFFFFF/aux dealfind remove <itemID>|r - Remover item")
    aux.print("|cFFFFFFFF/aux dealfind create <listname>|r - Crear nueva lista")
    aux.print("|cFFFFFFFF/aux dealfind scan|r - Escanear items de dealfinding")
end

function M.print_lists()
    init_saved_vars()
    
    aux.print("|cFFFFD700=== Listas de Dealfinding ===")
    
    local total_items = 0
    for list_name, items in pairs(aux_trading_dealfinding) do
        local count = 0
        for _ in pairs(items) do count = count + 1 end
        total_items = total_items + count
        
        aux.print(string.format("|cFF00FF00%s|r: %d items", list_name, count))
        
        for item_id, item_data in pairs(items) do
            local gold = math.floor(item_data.maxPrice / 10000)
            local silver = math.floor(math.mod(item_data.maxPrice, 10000) / 100)
            aux.print(string.format("  |cFFFFFFFF- %s|r (ID: %d) - Max: %dg %ds", 
                item_data.name, item_id, gold, silver))
        end
    end
    
    aux.print(string.format("|cFFFFD700Total: %d items en dealfinding|r", total_items))
end

function M.handle_add_command(args)
    -- Parsear: <itemlink> <maxprice> [listname]
    -- El itemlink puede contener espacios, así que buscamos el patrón del link primero
    
    -- Lua 5.0 compatible: use string.find with captures
    local _, _, item_link = string.find(args, '|c%x+|Hitem:(%d+)')
    local item_id = tonumber(item_link)
    
    if not item_id then
        -- Intentar parsear como ID directo
        local _, _, id_str = string.find(args, '^(%d+)')
        item_id = tonumber(id_str)
    end
    
    if not item_id then
        aux.print("|cFFFF0000Error: No se pudo obtener el item. Usa shift+click en un item.|r")
        return
    end
    
    -- Buscar el precio (número seguido de 'g' opcional) - Lua 5.0 compatible
    local _, _, price_str = string.find(args, '(%d+)g?')
    local price = tonumber(price_str)
    
    if not price then
        aux.print("|cFFFF0000Error: Especifica un precio máximo (en gold)|r")
        return
    end
    
    -- Convertir gold a copper
    local max_price = price * 10000
    
    -- Obtener nombre del item
    local item_name = GetItemInfo(item_id)
    
    M.add_item_to_list("Default", item_id, max_price, item_name)
end

function M.handle_remove_command(args)
    local item_id = tonumber(args)
    if not item_id then
        aux.print("|cFFFF0000Error: Especifica el ID del item a remover|r")
        return
    end
    
    -- Buscar en todas las listas
    for list_name, items in pairs(aux_trading_dealfinding) do
        if items[item_id] then
            M.remove_item_from_list(list_name, item_id)
            return
        end
    end
    
    aux.print("|cFFFF0000Error: Item no encontrado en ninguna lista|r")
end

-- Registrar en el módulo
M.modules = M.modules or {}
M.modules.dealfinding = M

aux.print('[TRADING] Módulo Dealfinding cargado')
