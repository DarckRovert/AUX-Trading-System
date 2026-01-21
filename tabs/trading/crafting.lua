module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

--[[
    CRAFTING MODULE
    Inspirado en TradeSkillMaster_Crafting
    
    Calcula profit de crafteo, gestiona queue de crafteo,
    y ayuda a restock de materiales.
]]

aux.print('[CRAFTING] Módulo de crafteo cargado')

-- ============================================================================
-- Variables Globales
-- ============================================================================

local crafting_queue = {}
local crafting_recipes = {}
local material_costs = {}
local crafting_in_progress = false

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

-- Profesiones soportadas
local professions = {
    ['Alchemy'] = true,
    ['Blacksmithing'] = true,
    ['Enchanting'] = true,
    ['Engineering'] = true,
    ['Leatherworking'] = true,
    ['Tailoring'] = true,
    ['Cooking'] = true,
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
-- Escaneo de Recetas
-- ============================================================================

function M.escanear_recetas()
    crafting_recipes = {}
    
    -- Obtener número de profesiones
    local numSkills = GetNumSkillLines()
    
    for i = 1, numSkills do
        local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier,
              skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType = GetSkillLineInfo(i)
        
        if skillName and professions[skillName] and not isHeader then
            -- Expandir si está colapsado
            if not isExpanded then
                ExpandSkillHeader(i)
            end
            
            -- Escanear recetas de esta profesión
            M.escanear_recetas_profesion(skillName, i)
        end
    end
    
    aux.print(string.format('|cFF00FF00%d recetas escaneadas|r', table.getn(crafting_recipes)))
    return crafting_recipes
end

function M.escanear_recetas_profesion(profession_name, skill_index)
    -- Abrir ventana de tradeskill
    CastSpellByName(profession_name)
    
    -- Esperar a que se abra
    -- TODO: Implementar espera asíncrona
    
    local numRecipes = GetNumTradeSkills()
    
    for i = 1, numRecipes do
        local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
        
        if skillName and skillType ~= "header" then
            local recipe = M.obtener_info_receta(i, profession_name)
            if recipe then
                table.insert(crafting_recipes, recipe)
            end
        end
    end
    
    CloseTradeSkill()
end

function M.obtener_info_receta(recipe_index, profession)
    local skillName, skillType, numAvailable = GetTradeSkillInfo(recipe_index)
    if not skillName then return nil end
    
    -- Obtener link del item resultante
    local itemLink = GetTradeSkillItemLink(recipe_index)
    if not itemLink then return nil end
    
    -- Extraer item_id del link
    local item_id = M.extraer_item_id(itemLink)
    if not item_id then return nil end
    
    -- Obtener reagentes
    local reagents = {}
    local numReagents = GetTradeSkillNumReagents(recipe_index)
    
    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(recipe_index, i)
        local reagentLink = GetTradeSkillReagentItemLink(recipe_index, i)
        local reagent_id = M.extraer_item_id(reagentLink)
        
        if reagent_id then
            table.insert(reagents, {
                item_id = reagent_id,
                name = reagentName,
                count = reagentCount,
                have = playerReagentCount,
            })
        end
    end
    
    return {
        recipe_index = recipe_index,
        name = skillName,
        item_id = item_id,
        item_link = itemLink,
        profession = profession,
        num_available = numAvailable,
        reagents = reagents,
    }
end

function M.extraer_item_id(item_link)
    if not item_link then return nil end
    local _, _, item_id = string.find(item_link, "item:(%d+)")
    return tonumber(item_id)
end

-- ============================================================================
-- Cálculo de Costos y Profit
-- ============================================================================

function M.calcular_costo_materiales(recipe)
    if not recipe or not recipe.reagents then return 0 end
    
    local total_cost = 0
    
    for i = 1, table.getn(recipe.reagents) do
        local reagent = recipe.reagents[i]
        local item_key = tostring(reagent.item_id) .. ':0'
        local market_value = get_market_value(item_key)
        
        if market_value > 0 then
            total_cost = total_cost + (market_value * reagent.count)
        else
            -- Sin datos de mercado, no podemos calcular
            return nil
        end
    end
    
    return total_cost
end

function M.calcular_profit_crafteo(recipe)
    if not recipe then return nil end
    
    -- Costo de materiales
    local material_cost = M.calcular_costo_materiales(recipe)
    if not material_cost then
        return nil, "Sin datos de materiales"
    end
    
    -- Valor de venta del item crafteado
    local item_key = tostring(recipe.item_id) .. ':0'
    local sell_value = get_market_value(item_key)
    
    if sell_value == 0 then
        return nil, "Sin datos de venta"
    end
    
    -- Considerar AH cut de 5%
    local net_value = sell_value * 0.95
    
    -- Profit
    local profit = net_value - material_cost
    local profit_percent = (profit / material_cost) * 100
    
    return {
        material_cost = material_cost,
        sell_value = sell_value,
        net_value = net_value,
        profit = profit,
        profit_percent = profit_percent,
        profitable = profit > 0,
    }
end

function M.obtener_recetas_rentables(min_profit, min_profit_percent)
    min_profit = min_profit or 0
    min_profit_percent = min_profit_percent or 0
    
    local rentables = {}
    
    for i = 1, table.getn(crafting_recipes) do
        local recipe = crafting_recipes[i]
        local profit_info = M.calcular_profit_crafteo(recipe)
        
        if profit_info and profit_info.profitable then
            if profit_info.profit >= min_profit and profit_info.profit_percent >= min_profit_percent then
                recipe.profit_info = profit_info
                table.insert(rentables, recipe)
            end
        end
    end
    
    -- Ordenar por profit descendente
    table.sort(rentables, function(a, b)
        return (a.profit_info.profit or 0) > (b.profit_info.profit or 0)
    end)
    
    return rentables
end

-- ============================================================================
-- Queue de Crafteo
-- ============================================================================

function M.agregar_a_queue_crafteo(recipe, cantidad)
    if not recipe then return false end
    
    cantidad = cantidad or 1
    
    table.insert(crafting_queue, {
        recipe = recipe,
        cantidad = cantidad,
        crafted = 0,
        added_time = time(),
    })
    
    aux.print(string.format('|cFF00FF00%dx %s agregado a queue|r', cantidad, recipe.name))
    return true
end

function M.obtener_queue_crafteo()
    return crafting_queue
end

function M.limpiar_queue_crafteo()
    crafting_queue = {}
    aux.print('|cFF00FF00Queue de crafteo limpiada|r')
end

function M.procesar_queue_crafteo()
    if crafting_in_progress then
        aux.print('|cFFFFAA00Ya hay un crafteo en progreso|r')
        return
    end
    
    if table.getn(crafting_queue) == 0 then
        aux.print('|cFFFFAA00Queue de crafteo vacía|r')
        return
    end
    
    crafting_in_progress = true
    aux.print(string.format('|cFF00FF00Procesando %d items en queue...|r', table.getn(crafting_queue)))
    
    for i = 1, table.getn(crafting_queue) do
        local queue_item = crafting_queue[i]
        M.craftear_item(queue_item)
    end
    
    crafting_in_progress = false
    aux.print('|cFF00FF00Crafteo completado|r')
end

function M.craftear_item(queue_item)
    if not queue_item or not queue_item.recipe then return false end
    
    local recipe = queue_item.recipe
    local cantidad = queue_item.cantidad - queue_item.crafted
    
    -- Verificar materiales
    if not M.verificar_materiales(recipe) then
        aux.print(string.format('|cFFFF0000Materiales insuficientes para %s|r', recipe.name))
        return false
    end
    
    -- Craftear
    -- DoTradeSkill(recipe.recipe_index, cantidad)
    
    aux.print(string.format('|cFF00FF00Crafteando %dx %s|r', cantidad, recipe.name))
    
    queue_item.crafted = queue_item.crafted + cantidad
    
    return true
end

function M.verificar_materiales(recipe)
    if not recipe or not recipe.reagents then return false end
    
    for i = 1, table.getn(recipe.reagents) do
        local reagent = recipe.reagents[i]
        if reagent.have < reagent.count then
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- Restock de Materiales
-- ============================================================================

function M.calcular_materiales_necesarios()
    local materiales = {}
    
    for i = 1, table.getn(crafting_queue) do
        local queue_item = crafting_queue[i]
        local recipe = queue_item.recipe
        local cantidad_pendiente = queue_item.cantidad - queue_item.crafted
        
        for j = 1, table.getn(recipe.reagents) do
            local reagent = recipe.reagents[j]
            local needed = reagent.count * cantidad_pendiente
            local have = reagent.have
            local to_buy = math.max(0, needed - have)
            
            if to_buy > 0 then
                local item_key = tostring(reagent.item_id) .. ':0'
                
                if not materiales[item_key] then
                    materiales[item_key] = {
                        item_id = reagent.item_id,
                        name = reagent.name,
                        needed = 0,
                        have = have,
                        to_buy = 0,
                    }
                end
                
                materiales[item_key].needed = materiales[item_key].needed + needed
                materiales[item_key].to_buy = materiales[item_key].to_buy + to_buy
            end
        end
    end
    
    return materiales
end

function M.generar_lista_compra()
    local materiales = M.calcular_materiales_necesarios()
    local lista = {}
    
    for item_key, material in pairs(materiales) do
        if material.to_buy > 0 then
            local market_value = get_market_value(item_key)
            local total_cost = market_value * material.to_buy
            
            table.insert(lista, {
                name = material.name,
                item_id = material.item_id,
                cantidad = material.to_buy,
                precio_unitario = market_value,
                costo_total = total_cost,
            })
        end
    end
    
    -- Ordenar por costo total descendente
    table.sort(lista, function(a, b)
        return (a.costo_total or 0) > (b.costo_total or 0)
    end)
    
    return lista
end

function M.mostrar_lista_compra()
    local lista = M.generar_lista_compra()
    
    if table.getn(lista) == 0 then
        aux.print('|cFF00FF00No se necesitan materiales|r')
        return
    end
    
    aux.print('|cFFFFD700=== LISTA DE COMPRA ===|r')
    
    local total = 0
    for i = 1, table.getn(lista) do
        local item = lista[i]
        aux.print(string.format(
            '|cFFFFFFFF%dx %s - %s (%s c/u)|r',
            item.cantidad,
            item.name,
            format_gold(item.costo_total, nil, true),
            format_gold(item.precio_unitario, nil, true)
        ))
        total = total + item.costo_total
    end
    
    aux.print(string.format('|cFFFFD700Total: %s|r', format_gold(total, nil, true)))
end

-- ============================================================================
-- Estadísticas
-- ============================================================================

function M.obtener_stats_crafteo()
    local total_recipes = table.getn(crafting_recipes)
    local rentables = M.obtener_recetas_rentables(0, 0)
    local total_rentables = table.getn(rentables)
    
    local mejor_profit = 0
    local mejor_recipe = nil
    
    for i = 1, table.getn(rentables) do
        local recipe = rentables[i]
        if recipe.profit_info and recipe.profit_info.profit > mejor_profit then
            mejor_profit = recipe.profit_info.profit
            mejor_recipe = recipe
        end
    end
    
    return {
        total_recipes = total_recipes,
        total_rentables = total_rentables,
        mejor_profit = mejor_profit,
        mejor_recipe = mejor_recipe,
        queue_size = table.getn(crafting_queue),
    }
end

-- ============================================================================
-- Inicialización
-- ============================================================================

function M.inicializar_crafting()
    -- Escanear recetas al iniciar
    -- M.escanear_recetas()
    
    aux.print('|cFF00FF00Crafting Module inicializado|r')
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.crafting = {
    escanear_recetas = M.escanear_recetas,
    obtener_rentables = M.obtener_recetas_rentables,
    calcular_profit = M.calcular_profit_crafteo,
    agregar_a_queue = M.agregar_a_queue_crafteo,
    procesar_queue = M.procesar_queue_crafteo,
    obtener_queue = M.obtener_queue_crafteo,
    limpiar_queue = M.limpiar_queue_crafteo,
    generar_lista_compra = M.generar_lista_compra,
    mostrar_lista_compra = M.mostrar_lista_compra,
    obtener_stats = M.obtener_stats_crafteo,
    inicializar = M.inicializar_crafting,
}

aux.print('[CRAFTING] Módulo registrado correctamente')
