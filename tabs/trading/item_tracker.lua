module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

--[[
    ITEM TRACKER + MAILING MODULE
    Inspirado en TradeSkillMaster_ItemTracker y TradeSkillMaster_Mailing
    
    Rastrea inventario de todos los alts y facilita envío de items por correo.
]]

aux.print('[ITEM_TRACKER] Módulo de tracking y correo cargado')

-- ============================================================================
-- Variables Globales
-- ============================================================================

local character_data = {}
local current_character = nil
local mailing_queue = {}
local auto_loot_enabled = false

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================

local function get_character_key()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end



-- ============================================================================
-- Escaneo de Inventario
-- ============================================================================

function M.escanear_inventario()
    local char_key = get_character_key()
    
    if not character_data[char_key] then
        character_data[char_key] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            class = UnitClass("player"),
            level = UnitLevel("player"),
            gold = 0,
            items = {},
            last_scan = time(),
        }
    end
    
    local char = character_data[char_key]
    char.items = {}
    
    -- Escanear bags
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local texture, itemCount = GetContainerItemInfo(bag, slot)
                    local item_id = M.extraer_item_id(itemLink)
                    local itemName = GetItemInfo(itemLink)
                    
                    if item_id and itemName then
                        M.agregar_item_a_inventario(char, item_id, itemName, itemCount or 1, bag, slot)
                    end
                end
            end
        end
    end
    
    -- Escanear bank (si está abierto)
    if M.is_bank_open() then
        for bag = 5, 11 do
            local numSlots = GetContainerNumSlots(bag)
            if numSlots then
                for slot = 1, numSlots do
                    local itemLink = GetContainerItemLink(bag, slot)
                    if itemLink then
                        local texture, itemCount = GetContainerItemInfo(bag, slot)
                        local item_id = M.extraer_item_id(itemLink)
                        local itemName = GetItemInfo(itemLink)
                        
                        if item_id and itemName then
                            M.agregar_item_a_inventario(char, item_id, itemName, itemCount or 1, bag, slot)
                        end
                    end
                end
            end
        end
    end
    
    -- Actualizar gold
    char.gold = GetMoney()
    char.last_scan = time()
    
    -- Guardar en SavedVariables
    M.guardar_character_data()
    
    aux.print(string.format('|cFF00FF00Inventario escaneado: %d items únicos|r', M.contar_items_unicos(char)))
    
    return char
end

function M.agregar_item_a_inventario(char, item_id, item_name, count, bag, slot)
    local item_key = tostring(item_id)
    
    if not char.items[item_key] then
        char.items[item_key] = {
            item_id = item_id,
            name = item_name,
            total_count = 0,
            locations = {},
        }
    end
    
    char.items[item_key].total_count = char.items[item_key].total_count + count
    
    table.insert(char.items[item_key].locations, {
        bag = bag,
        slot = slot,
        count = count,
    })
end

function M.extraer_item_id(item_link)
    if not item_link then return nil end
    local _, _, item_id = string.find(item_link, "item:(%d+)")
    return tonumber(item_id)
end

function M.is_bank_open()
    -- Verificar si el banco está abierto
    return false  -- TODO: Implementar detección
end

function M.contar_items_unicos(char)
    local count = 0
    for _ in pairs(char.items) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- Consultas de Inventario
-- ============================================================================

function M.obtener_todos_los_personajes()
    return character_data
end

function M.buscar_item_en_alts(item_id)
    local resultados = {}
    
    for char_key, char in pairs(character_data) do
        local item_key = tostring(item_id)
        if char.items[item_key] then
            table.insert(resultados, {
                character = char.name,
                realm = char.realm,
                count = char.items[item_key].total_count,
                locations = char.items[item_key].locations,
            })
        end
    end
    
    return resultados
end

function M.obtener_total_gold()
    local total = 0
    for char_key, char in pairs(character_data) do
        total = total + (char.gold or 0)
    end
    return total
end

function M.obtener_inventario_completo()
    local inventario = {}
    
    for char_key, char in pairs(character_data) do
        for item_key, item_data in pairs(char.items) do
            if not inventario[item_key] then
                inventario[item_key] = {
                    item_id = item_data.item_id,
                    name = item_data.name,
                    total_count = 0,
                    characters = {},
                }
            end
            
            inventario[item_key].total_count = inventario[item_key].total_count + item_data.total_count
            
            table.insert(inventario[item_key].characters, {
                name = char.name,
                count = item_data.total_count,
            })
        end
    end
    
    return inventario
end

-- ============================================================================
-- Sistema de Correo
-- ============================================================================

function M.enviar_item(recipient, bag, slot, count)
    if not recipient or recipient == "" then
        aux.print('|cFFFF0000Destinatario inválido|r')
        return false
    end
    
    -- Verificar que el item existe
    local itemLink = GetContainerItemLink(bag, slot)
    if not itemLink then
        aux.print('|cFFFF0000Item no encontrado|r')
        return false
    end
    
    local itemName = GetItemInfo(itemLink)
    
    -- Pickup item
    PickupContainerItem(bag, slot)
    
    -- Attach to mail
    ClickSendMailItemButton()
    
    -- Set recipient
    SendMailNameEditBox:SetText(recipient)
    
    -- Send
    SendMail(recipient, "Items", "")
    
    aux.print(string.format('|cFF00FF00Enviando %s a %s|r', itemName, recipient))
    
    return true
end

function M.agregar_a_queue_mailing(recipient, item_id, count)
    table.insert(mailing_queue, {
        recipient = recipient,
        item_id = item_id,
        count = count,
        sent = 0,
    })
    
    aux.print(string.format('|cFF00FF00%dx item agregado a queue de correo|r', count))
end

function M.procesar_queue_mailing()
    if table.getn(mailing_queue) == 0 then
        aux.print('|cFFFFAA00Queue de correo vacía|r')
        return
    end
    
    aux.print(string.format('|cFF00FF00Procesando %d items en queue...|r', table.getn(mailing_queue)))
    
    for i = 1, table.getn(mailing_queue) do
        local mail_item = mailing_queue[i]
        M.enviar_items_por_id(mail_item.recipient, mail_item.item_id, mail_item.count)
    end
    
    mailing_queue = {}
    aux.print('|cFF00FF00Envío completado|r')
end

function M.enviar_items_por_id(recipient, item_id, count)
    -- Buscar items en inventario
    local char_key = get_character_key()
    local char = character_data[char_key]
    
    if not char then
        aux.print('|cFFFF0000Datos de personaje no encontrados|r')
        return false
    end
    
    local item_key = tostring(item_id)
    local item_data = char.items[item_key]
    
    if not item_data then
        aux.print('|cFFFF0000Item no encontrado en inventario|r')
        return false
    end
    
    local sent = 0
    
    for i = 1, table.getn(item_data.locations) do
        local location = item_data.locations[i]
        local to_send = math.min(location.count, count - sent)
        
        if to_send > 0 then
            M.enviar_item(recipient, location.bag, location.slot, to_send)
            sent = sent + to_send
            
            if sent >= count then
                break
            end
        end
    end
    
    aux.print(string.format('|cFF00FF00%d items enviados|r', sent))
    return true
end

-- ============================================================================
-- Auto-Loot de Correo
-- ============================================================================

function M.toggle_auto_loot()
    auto_loot_enabled = not auto_loot_enabled
    
    if auto_loot_enabled then
        aux.print('|cFF00FF00Auto-loot de correo activado|r')
    else
        aux.print('|cFFFFAA00Auto-loot de correo desactivado|r')
    end
    
    return auto_loot_enabled
end

function M.auto_loot_mail()
    if not auto_loot_enabled then return end
    
    local numItems, totalItems = GetInboxNumItems()
    
    if numItems == 0 then
        aux.print('|cFFFFFFFFNo hay correo|r')
        return
    end
    
    aux.print(string.format('|cFF00FF00Recogiendo %d correos...|r', numItems))
    
    for i = 1, numItems do
        -- Get mail info
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated = GetInboxHeaderInfo(i)
        
        if hasItem then
            -- Take attachments
            for j = 1, 12 do  -- Max 12 attachments per mail
                TakeInboxItem(i, j)
            end
        end
        
        if money and money > 0 then
            -- Take money
            TakeInboxMoney(i)
        end
        
        -- Delete mail if empty
        DeleteInboxItem(i)
    end
    
    aux.print('|cFF00FF00Correo recogido|r')
end

-- ============================================================================
-- Lógica de Envío Masivo
-- ============================================================================

function M.enviar_todo(recipient)
    local inventory = M.obtener_inventario_completo()
    local my_name = UnitName("player")
    local count = 0
    
    for item_key, data in pairs(inventory) do
        -- Filtrar solo items que tengo yo actualmente
        if data.item_id then
             M.agregar_a_queue_mailing(recipient, data.item_id, 9999) -- 9999 = max all
             count = count + 1
        end
    end
    
    if count > 0 then
        M.procesar_queue_mailing()
    else
        aux.print("No tienes items para enviar.")
    end
end

function M.enviar_materiales(recipient)
    local inventory = M.obtener_inventario_completo()
    for item_key, data in pairs(inventory) do
        local _, _, _, _, _, type = GetItemInfo(data.item_id)
        if type == "Trade Goods" or type == "Quest" or type == "Reagent" then
             M.agregar_a_queue_mailing(recipient, data.item_id, 9999)
        end
    end
    M.procesar_queue_mailing()
end

function M.enviar_equipamiento(recipient)
    local inventory = M.obtener_inventario_completo()
    for item_key, data in pairs(inventory) do
        local _, _, _, _, _, type = GetItemInfo(data.item_id)
        if type == "Weapon" or type == "Armor" then
             M.agregar_a_queue_mailing(recipient, data.item_id, 9999)
        end
    end
    M.procesar_queue_mailing()
end

-- ============================================================================
-- Grupos de Envío
-- ============================================================================

local mailing_groups = {}

function M.crear_grupo_mailing(nombre, recipient, items)
    mailing_groups[nombre] = {
        nombre = nombre,
        recipient = recipient,
        items = items or {},
    }
    
    aux.print(string.format('|cFF00FF00Grupo de correo creado: %s|r', nombre))
end

function M.enviar_grupo(nombre)
    local grupo = mailing_groups[nombre]
    if not grupo then
        aux.print('|cFFFF0000Grupo no encontrado|r')
        return false
    end
    
    aux.print(string.format('|cFF00FF00Enviando grupo: %s a %s|r', nombre, grupo.recipient))
    
    for i = 1, table.getn(grupo.items) do
        local item = grupo.items[i]
        M.agregar_a_queue_mailing(grupo.recipient, item.item_id, item.count)
    end
    
    M.procesar_queue_mailing()
    return true
end

-- ============================================================================
-- Persistencia de Datos
-- ============================================================================

function M.guardar_character_data()
    -- Guardar en SavedVariables
    if not aux.faction_data then
        aux.faction_data = {}
    end
    
    if not aux.faction_data.item_tracker then
        aux.faction_data.item_tracker = {}
    end
    
    aux.faction_data.item_tracker = character_data
end

function M.cargar_character_data()
    if aux.faction_data and aux.faction_data.item_tracker then
        character_data = aux.faction_data.item_tracker
        aux.print(string.format('|cFF00FF00Datos de %d personajes cargados|r', M.contar_personajes()))
    end
end

function M.contar_personajes()
    local count = 0
    for _ in pairs(character_data) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- Estadísticas
-- ============================================================================

function M.obtener_stats_tracker()
    local total_chars = M.contar_personajes()
    local total_gold = M.obtener_total_gold()
    local inventario = M.obtener_inventario_completo()
    
    local total_items = 0
    for _ in pairs(inventario) do
        total_items = total_items + 1
    end
    
    return {
        total_characters = total_chars,
        total_gold = total_gold,
        total_unique_items = total_items,
        current_character = get_character_key(),
    }
end

-- ============================================================================
-- Inicialización
-- ============================================================================

function M.inicializar_item_tracker()
    -- Cargar datos guardados
    M.cargar_character_data()
    
    -- Escanear inventario actual
    M.escanear_inventario()
    
    aux.print('|cFF00FF00Item Tracker + Mailing inicializado|r')
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.item_tracker = {
    escanear_inventario = M.escanear_inventario,
    obtener_personajes = M.obtener_todos_los_personajes,
    obtener_alts = M.obtener_todos_los_personajes, -- Alias for UI compatibility
    buscar_item = M.buscar_item_en_alts,
    obtener_inventario = M.obtener_inventario_completo,
    enviar_item = M.enviar_item,
    enviar_grupo = M.enviar_grupo,
    crear_grupo = M.crear_grupo_mailing,
    toggle_auto_loot = M.toggle_auto_loot,
    auto_loot_mail = M.auto_loot_mail,
    obtener_stats = M.obtener_stats_tracker,
    obtener_mail_stats = M.obtener_stats_tracker, -- Alias for UI compatibility
    inicializar = M.inicializar_item_tracker,
    enviar_todo = M.enviar_todo,
    enviar_materiales = M.enviar_materiales,
    enviar_equipamiento = M.enviar_equipamiento,
}

aux.print('[ITEM_TRACKER] Módulo registrado correctamente')
