module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

aux.print('[CRAFTING_UI] Módulo de UI de crafteo cargado')

-- ============================================================================
-- Crafting UI - Interfaz de Crafteo Rentable
-- ============================================================================

local crafting_panel = nil
local selected_recipe = nil

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================



-- ============================================================================
-- Crear UI Principal
-- ============================================================================

function M.crear_crafting_ui(parent)
    if not parent then return nil end
    
    -- Import styles
    -- Import styles
    -- Fix: Use M directly as we are in the same module scope
    if not M.COLORS then return end
    
    local COLORS = M.COLORS
    local create_backdrop = M.create_backdrop
    local create_text = M.create_text
    local create_button = M.create_button
    
    local f = CreateFrame('Frame', nil, parent)
    f:SetAllPoints()
    f:Hide()
    
    -- Título
    create_text(f, 'CRAFTING - Crafteo Rentable', 16, COLORS.gold, 'TOPLEFT', 10, -10)
    create_text(f, 'Calcula profit de crafteo y gestiona queue automática', 12, COLORS.text_dim, 'TOPLEFT', 10, -28)
    
    -- ========================================================================
    -- Botones de Acción Superior
    -- ========================================================================
    
    local btn_escanear = create_button(f, 'Escanear Recetas', 120, 25, COLORS.primary)
    btn_escanear:SetPoint('TOPLEFT', 10, -50)
    btn_escanear:SetScript('OnClick', function() M.escanear_recetas_click() end)
    
    local btn_mostrar_rentables = create_button(f, 'Solo Rentables', 140, 25)
    btn_mostrar_rentables:SetPoint('LEFT', btn_escanear, 'RIGHT', 10, 0)
    btn_mostrar_rentables:SetScript('OnClick', function() M.mostrar_recetas_rentables() end)
    
    local btn_lista_compra = create_button(f, 'Lista de Compra', 120, 25)
    btn_lista_compra:SetPoint('LEFT', btn_mostrar_rentables, 'RIGHT', 10, 0)
    btn_lista_compra:SetScript('OnClick', function() M.mostrar_lista_compra_click() end)
    
    -- ========================================================================
    -- Panel de Recetas Rentables (Izquierda)
    -- ========================================================================
    
    local recetas_panel = CreateFrame('Frame', nil, f)
    recetas_panel:SetWidth(400) -- Expanded width
    recetas_panel:SetPoint('TOPLEFT', 10, -90)
    recetas_panel:SetPoint('BOTTOMLEFT', 10, 100)
    create_backdrop(recetas_panel, COLORS.bg_medium, COLORS.border, 1)
    
    -- Header
    create_text(recetas_panel, 'Receta', 11, COLORS.gold, 'TOPLEFT', 5, -5)
    create_text(recetas_panel, 'Profit', 11, COLORS.gold, 'TOPRIGHT', -25, -5)
    
    -- Scroll Frame (Faux Scroll)
    local scroll_frame = CreateFrame('ScrollFrame', 'AuxCraftingRecipeScroll', recetas_panel, 'FauxScrollFrameTemplate')
    scroll_frame:SetPoint('TOPLEFT', 0, -25)
    scroll_frame:SetPoint('BOTTOMRIGHT', -25, 5)
    
    recetas_panel.scroll_frame = scroll_frame
    
    -- Lista de recetas (Botones visuales)
    recetas_panel.lista = {}
    local NUM_BUTTONS = 12  -- Changed from 15 for cleaner display
    local BUTTON_HEIGHT = 24 -- Taller buttons
    
    for i = 1, NUM_BUTTONS do
        local receta_btn = CreateFrame('Button', nil, recetas_panel)
        receta_btn:SetWidth(375)
        receta_btn:SetHeight(BUTTON_HEIGHT)
        receta_btn:SetPoint('TOPLEFT', 5, -25 - (i-1) * BUTTON_HEIGHT)
        
        local bg = receta_btn:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture(1, 1, 1, 0.05) -- Light overlay
        receta_btn.bg = bg
        
        local text = create_text(receta_btn, '', 11, COLORS.text, 'LEFT', 5, 0)
        receta_btn.text = text
        
        local profit_text = create_text(receta_btn, '', 11, COLORS.success, 'RIGHT', -5, 0)
        receta_btn.profit_text = profit_text
        
        receta_btn:SetScript('OnClick', function()
            M.seleccionar_receta(receta_btn.recipe)
        end)
        
        receta_btn:SetScript('OnEnter', function()
            bg:SetTexture(0.2, 0.2, 0.3, 0.4)
        end)
        
        receta_btn:SetScript('OnLeave', function()
            if selected_recipe == this.recipe then
                 bg:SetTexture(0.2, 0.4, 0.2, 0.4)
            else
                 if math.mod(i, 2) == 0 then
                    bg:SetTexture(1, 1, 1, 0.05)
                 else
                    bg:SetTexture(1, 1, 1, 0.02)
                 end
            end
        end)
        
        recetas_panel.lista[i] = receta_btn
    end
    
    -- Scroll Update
    scroll_frame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(BUTTON_HEIGHT, M.actualizar_lista_recetas)
    end)
    
    f.recetas_panel = recetas_panel
    
    -- ========================================================================
    -- Panel de Detalles (Derecha)
    -- ========================================================================
    
    local detalles_panel = CreateFrame('Frame', nil, f)
    detalles_panel:SetPoint('TOPLEFT', recetas_panel, 'TOPRIGHT', 10, 0)
    detalles_panel:SetPoint('BOTTOMRIGHT', -10, 100)
    create_backdrop(detalles_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(detalles_panel, 'Detalles', 12, COLORS.gold, 'TOPLEFT', 10, -10)
    
    local recipe_name = create_text(detalles_panel, 'Selecciona una receta', 14, COLORS.primary, 'TOP', 0, -35)
    detalles_panel.recipe_name = recipe_name
    
    -- Grid de Materiales (Mejorado)
    create_text(detalles_panel, 'Materiales Requeridos:', 11, COLORS.text_dim, 'TOPLEFT', 15, -60)
    
    local materiales_text = create_text(detalles_panel, '', 11, COLORS.text, 'TOPLEFT', 25, -80)
    materiales_text:SetJustifyH('LEFT')
    materiales_text:SetWidth(300)
    detalles_panel.materiales_text = materiales_text
    
    -- Profit Info Box
    local profit_box = CreateFrame('Frame', nil, detalles_panel)
    profit_box:SetPoint('BOTTOMLEFT', 10, 50)
    profit_box:SetPoint('BOTTOMRIGHT', -10, 50)
    profit_box:SetHeight(100)
    create_backdrop(profit_box, {0,0,0,0.3}, {1,1,1,0.1}, 1)
    
    local profit_text = create_text(profit_box, '', 11, COLORS.text, 'TOPLEFT', 10, -10)
    profit_text:SetJustifyH('LEFT')
    profit_text:SetWidth(300)
    detalles_panel.profit_text = profit_text
    
    -- Controles Crafteo
    local btn_agregar_queue = create_button(detalles_panel, '+ Queue', 100, 25, COLORS.primary)
    btn_agregar_queue:SetPoint('BOTTOMLEFT', 10, 10)
    btn_agregar_queue:SetScript('OnClick', function() M.agregar_receta_a_queue() end)
    
    local btn_craftear = create_button(detalles_panel, 'Craftear', 100, 25, COLORS.success)
    btn_craftear:SetPoint('LEFT', btn_agregar_queue, 'RIGHT', 10, 0)
    btn_craftear:SetScript('OnClick', function() M.craftear_receta_ahora() end)
    
    local cantidad_input = CreateFrame('EditBox', nil, detalles_panel, 'InputBoxTemplate')
    cantidad_input:SetWidth(40)
    cantidad_input:SetHeight(25)
    cantidad_input:SetPoint('LEFT', btn_craftear, 'RIGHT', 20, 0)
    cantidad_input:SetText('1')
    cantidad_input:SetAutoFocus(false)
    detalles_panel.cantidad_input = cantidad_input
    
    create_text(detalles_panel, 'x', 12, COLORS.text, 'RIGHT', cantidad_input, 'LEFT', -5, 0)
    
    f.detalles_panel = detalles_panel
    
    -- ========================================================================
    -- Panel de Queue (Footer)
    -- ========================================================================
    
    local queue_panel = CreateFrame('Frame', nil, f)
    queue_panel:SetHeight(80)
    queue_panel:SetPoint('BOTTOMLEFT', 10, 10)
    queue_panel:SetPoint('BOTTOMRIGHT', -10, 10)
    create_backdrop(queue_panel, COLORS.bg_light, COLORS.border, 1)
    
    create_text(queue_panel, 'Queue de Crafteo', 11, COLORS.gold, 'TOPLEFT', 10, -5)
    
    local queue_text = create_text(queue_panel, 'Vacía', 10, COLORS.text_dim, 'TOPLEFT', 10, -25)
    queue_text:SetWidth(500)
    queue_panel.queue_text = queue_text
    
    local btn_procesar = create_button(queue_panel, 'Procesar Todo', 120, 22, COLORS.primary)
    btn_procesar:SetPoint('BOTTOMRIGHT', -10, 10)
    btn_procesar:SetScript('OnClick', function() M.procesar_queue_click() end)
    
    local btn_limpiar = create_button(queue_panel, 'Limpiar', 80, 22, COLORS.danger)
    btn_limpiar:SetPoint('RIGHT', btn_procesar, 'LEFT', -5, 0)
    btn_limpiar:SetScript('OnClick', function() M.limpiar_queue_click() end)
    
    f.queue_panel = queue_panel
    
    crafting_panel = f
    return f
end

-- ============================================================================
-- Funciones de Interacción
-- ============================================================================

function M.actualizar_crafting_ui()
    if not crafting_panel then return end
    
    M.actualizar_lista_recetas()
    M.actualizar_queue_display()
end

function M.actualizar_lista_recetas()
    if not crafting_panel or not crafting_panel.recetas_panel then return end
    
    -- Get all recipes from crafting module
    local all_rentables = M.modules.crafting and M.modules.crafting.obtener_rentables(0, 0) or {}
    
    -- Apply filter if Solo Rentables is active
    local rentables = {}
    if filter_only_profitable then
        for _, recipe in ipairs(all_rentables) do
            -- Only show recipes with positive profit
            if recipe.profit_info and recipe.profit_info.profit and recipe.profit_info.profit > 0 then
                table.insert(rentables, recipe)
            end
        end
    else
        rentables = all_rentables
    end
    
    local lista = crafting_panel.recetas_panel.lista
    if not lista then return end -- Guard against nil lista
    local num_rows = table.getn(lista) -- 12 buttons
    if not num_rows or num_rows == 0 then return end -- Guard against nil/zero
    local BUTTON_HEIGHT = 24
    
    FauxScrollFrame_Update(AuxCraftingRecipeScroll, table.getn(rentables) or 0, num_rows, BUTTON_HEIGHT)
    
    local offset = FauxScrollFrame_GetOffset(AuxCraftingRecipeScroll)
    
    for i = 1, num_rows do
        local btn = lista[i]
        local index = offset + i
        
        if index <= table.getn(rentables) then
            local recipe = rentables[index]
            local profit_info = recipe.profit_info
            
            if profit_info then
                btn.text:SetText(recipe.name)
                btn.profit_text:SetText(M.format_gold(profit_info.profit))
                
                btn.recipe = recipe
                btn:Show()
                
                -- Highlight selection
                local bg = btn.bg
                if selected_recipe == recipe then
                     bg:SetTexture(0.2, 0.4, 0.2, 0.6)
                else
                     if math.mod(i, 2) == 0 then
                        bg:SetTexture(1, 1, 1, 0.05)
                     else
                        bg:SetTexture(1, 1, 1, 0.02)
                     end
                end
            else
                btn:Hide()
            end
        else
            btn:Hide()
        end
    end
end
    
function M.seleccionar_receta(recipe)
     if not recipe then return end
     selected_recipe = recipe
     if not crafting_panel then return end
     
     local dp = crafting_panel.detalles_panel
     
     dp.recipe_name:SetText(recipe.name)
     
     -- Materiales
     local mat_str = ""
     if recipe.reagents then
        for _, r in ipairs(recipe.reagents) do
            mat_str = mat_str .. string.format("- %dx %s\n", r.count, r.name)
        end
     end
     dp.materiales_text:SetText(mat_str)
     
     -- Profit
     if recipe.profit_info then
        local pi = recipe.profit_info
        local str = string.format("Costo: %s\nVenta: %s\nProfit: %s (%.0f%%)",
            M.format_gold(pi.material_cost),
            M.format_gold(pi.sell_value),
            M.format_gold(pi.profit),
            pi.profit_percent
        )
        dp.profit_text:SetText(str)
     end
     
     M.actualizar_lista_recetas() -- Refresh highlight
end

function M.agregar_receta_a_queue()
    if not selected_recipe then
        aux.print('|cFFFF0000Selecciona una receta primero|r')
        return
    end
    
    local cantidad = tonumber(crafting_panel.detalles_panel.cantidad_input:GetText()) or 1
    
    if M.modules.crafting and M.modules.crafting.agregar_a_queue then
        M.modules.crafting.agregar_a_queue(selected_recipe, cantidad)
        M.actualizar_queue_display()
    end
end

function M.craftear_receta_ahora()
    if not selected_recipe then
        aux.print('|cFFFF0000Selecciona una receta primero|r')
        return
    end
    
    -- Use aux crafting system
    local recipe = selected_recipe
    local spell_id = recipe.spell_id or recipe.spellID
    
    if not spell_id then
        aux.print('|cFFFF0000No se encontró spell ID para esta receta|r')
        return
    end
    
    -- Check if we have tradeskill window open
    if TradeSkillFrame and TradeSkillFrame:IsVisible() then
        -- Find recipe index in tradeskill
        local num_skills = GetNumTradeSkills()
        for i = 1, num_skills do
            local skill_name = GetTradeSkillInfo(i)
            if skill_name == recipe.name then
                DoTradeSkill(i, 1)
                aux.print(string.format('|cFF00FF00Crafteando: %s|r', recipe.name))
                return
            end
        end
        aux.print('|cFFFF0000Receta no encontrada en ventana de profesión|r')
    else
        aux.print('|cFFFFAA00Abre la ventana de tu profesión primero|r')
    end
end

function M.actualizar_queue_display()
    if not crafting_panel or not crafting_panel.queue_panel then return end
    
    local queue = M.modules.crafting and M.modules.crafting.obtener_queue() or {}
    
    if table.getn(queue) == 0 then
        crafting_panel.queue_panel.queue_text:SetText('Vacía')
        return
    end
    
    local queue_str = ''
    for i = 1, table.getn(queue) do
        local item = queue[i]
        queue_str = queue_str .. string.format(
            '%dx %s (%d/%d) | ',
            item.cantidad,
            item.recipe.name,
            item.crafted,
            item.cantidad
        )
    end
    
    crafting_panel.queue_panel.queue_text:SetText(queue_str)
end

function M.escanear_recetas_click()
    if M.modules.crafting and M.modules.crafting.escanear_recetas then
        M.modules.crafting.escanear_recetas()
        M.actualizar_crafting_ui()
    end
end

-- Solo Rentables toggle state
local filter_only_profitable = false

function M.mostrar_recetas_rentables()
    -- Toggle the filter
    filter_only_profitable = not filter_only_profitable
    
    if filter_only_profitable then
        aux.print('|cFF00FF00Mostrando solo recetas rentables|r')
    else
        aux.print('|cFFFFFFFFMostrando todas las recetas|r')
    end
    
    M.actualizar_lista_recetas()
end

function M.is_filtering_profitable()
    return filter_only_profitable
end

function M.mostrar_lista_compra_click()
    if M.modules.crafting and M.modules.crafting.mostrar_lista_compra then
        M.modules.crafting.mostrar_lista_compra()
    end
end

function M.procesar_queue_click()
    if M.modules.crafting and M.modules.crafting.procesar_queue then
        M.modules.crafting.procesar_queue()
        M.actualizar_queue_display()
    end
end

function M.limpiar_queue_click()
    if M.modules.crafting and M.modules.crafting.limpiar_queue then
        M.modules.crafting.limpiar_queue()
        M.actualizar_queue_display()
    end
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.crafting_ui = {
    crear_crafting_ui = M.crear_crafting_ui,
    actualizar_crafting_ui = M.actualizar_crafting_ui,
}

aux.print('[CRAFTING_UI] Módulo registrado correctamente')
