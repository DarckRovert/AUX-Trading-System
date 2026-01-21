module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

aux.print('[ITEM_TRACKER_UI] Módulo de UI de tracking y correo cargado')

-- ============================================================================
-- Item Tracker + Mailing UI
-- ============================================================================

local tracker_panel = nil

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================


-- Crear UI Principal
-- ============================================================================

function M.crear_item_tracker_ui(parent)
    if not parent then return nil end
    
    -- Import styles
    -- Fix: Use M directly
    if not M.COLORS then return end
    
    local COLORS = M.COLORS
    local create_backdrop = M.create_backdrop
    local create_text = M.create_text
    local create_button = M.create_button
    local format_gold = M.format_gold
    
    local f = CreateFrame('Frame', nil, parent)
    f:SetAllPoints()
    f:Hide()
    
    create_text(f, 'ITEM TRACKER + MAILING', 16, COLORS.gold, 'TOPLEFT', 10, -10)
    create_text(f, 'Rastreador de inventario y sistema de correo rápido', 12, COLORS.text_dim, 'TOPLEFT', 10, -28)
    
    -- ========================================================================
    -- Panel de Personajes (Izquierda)
    -- ========================================================================
    
    local alts_panel = CreateFrame('Frame', nil, f)
    alts_panel:SetWidth(180) 
    alts_panel:SetPoint('TOPLEFT', 10, -60)
    alts_panel:SetPoint('BOTTOMLEFT', 10, 10)
    create_backdrop(alts_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(alts_panel, 'Personajes', 14, COLORS.gold, 'TOP', 0, -10)
    
    local gold_total = create_text(alts_panel, 'Total: 0g', 11, COLORS.text, 'TOP', 0, -30)
    alts_panel.gold_total = gold_total
    
    -- Scroll Frame para Alts (Faux Scroll)
    local scroll_frame = CreateFrame('ScrollFrame', 'AuxTrackerAltsScroll', alts_panel, 'FauxScrollFrameTemplate')
    scroll_frame:SetPoint('TOPLEFT', 0, -50)
    scroll_frame:SetPoint('BOTTOMRIGHT', -25, 10)
    
    alts_panel.scroll_frame = scroll_frame
    
    -- Lista de alts
    alts_panel.lista = {}
    local NUM_ROWS_ALTS = 15
    local ROW_HEIGHT = 24
    
    for i = 1, NUM_ROWS_ALTS do
        local alt_btn = CreateFrame('Button', nil, alts_panel)
        alt_btn:SetWidth(150)
        alt_btn:SetHeight(ROW_HEIGHT)
        alt_btn:SetPoint('TOPLEFT', 5, -50 - (i-1) * ROW_HEIGHT)
        -- Fix anchor: relative to panel, not just floating
        alt_btn:SetPoint('LEFT', 5, 0)
        
        local bg = alt_btn:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture(1, 1, 1, 0.05)
        alt_btn.bg = bg
        
        local text = create_text(alt_btn, '', 11, COLORS.text, 'LEFT', 5, 0)
        alt_btn.text = text
        
        alt_btn:SetScript('OnClick', function()
            M.seleccionar_alt(alt_btn.alt_name)
        end)
        
        alt_btn:SetScript('OnEnter', function()
             if alt_btn.alt_name then bg:SetTexture(0.2, 0.2, 0.3, 0.4) end
        end)
        
        alt_btn:SetScript('OnLeave', function()
             bg:SetTexture(1, 1, 1, 0.05)
        end)
        
        alts_panel.lista[i] = alt_btn
    end

    scroll_frame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, M.actualizar_lista_alts)
    end)
    
    f.alts_panel = alts_panel
    
    -- ========================================================================
    -- Panel de Inventario (Centro)
    -- ========================================================================
    
    local inventario_panel = CreateFrame('Frame', nil, f)
    inventario_panel:SetWidth(280)
    inventario_panel:SetPoint('TOPLEFT', alts_panel, 'TOPRIGHT', 10, 0)
    inventario_panel:SetPoint('BOTTOMLEFT', alts_panel, 'BOTTOMRIGHT', 10, 0)
    create_backdrop(inventario_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(inventario_panel, 'Inventario', 14, COLORS.gold, 'TOP', 0, -10)
    
    -- Búsqueda
    local search_label = create_text(inventario_panel, 'Buscar:', 11, COLORS.text_dim, 'TOPLEFT', 10, -40)
    
    local search_input = CreateFrame('EditBox', nil, inventario_panel, 'InputBoxTemplate')
    search_input:SetWidth(180)
    search_input:SetHeight(20)
    search_input:SetPoint('LEFT', search_label, 'RIGHT', 5, 0)
    search_input:SetAutoFocus(false)
    search_input:SetScript('OnTextChanged', function() M.actualizar_inventario_display() end)
    inventario_panel.search_input = search_input
    
    -- Scroll Frame para Inventario (Faux Scroll)
    local scroll_frame_inv = CreateFrame('ScrollFrame', 'AuxTrackerInvScroll', inventario_panel, 'FauxScrollFrameTemplate')
    scroll_frame_inv:SetPoint('TOPLEFT', 0, -70)
    scroll_frame_inv:SetPoint('BOTTOMRIGHT', -25, 10)
    
    inventario_panel.scroll_frame = scroll_frame_inv
    
    -- Lista de items
    inventario_panel.lista = {}
    local NUM_ROWS_INV = 15 -- visible rows
    
    for i = 1, NUM_ROWS_INV do
        local item_frame = CreateFrame('Button', nil, inventario_panel)
        item_frame:SetWidth(250)
        item_frame:SetHeight(20)
        item_frame:SetPoint('TOPLEFT', 5, -70 - (i-1) * 20)
        
        local bg = item_frame:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture(1, 1, 1, 0.05)
        item_frame.bg = bg
        
        local text = create_text(item_frame, '', 11, COLORS.text, 'LEFT', 5, 0)
        item_frame.text = text
        
        item_frame:SetScript('OnEnter', function() bg:SetTexture(0.2, 0.2, 0.3, 0.4) end)
        item_frame:SetScript('OnLeave', function() 
             if math.mod(i, 2) == 0 then bg:SetTexture(1, 1, 1, 0.05) else bg:SetTexture(0,0,0,0) end
        end)
        
        item_frame:Hide()
        inventario_panel.lista[i] = item_frame
    end
    
    scroll_frame_inv:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(20, M.actualizar_inventario_display)
    end)
    
    f.inventario_panel = inventario_panel
    
    -- ========================================================================
    -- Panel de Correo (Derecha)
    -- ========================================================================
    
    local correo_panel = CreateFrame('Frame', nil, f)
    correo_panel:SetPoint('TOPLEFT', inventario_panel, 'TOPRIGHT', 10, 0)
    correo_panel:SetPoint('BOTTOMRIGHT', -10, 10)
    create_backdrop(correo_panel, COLORS.bg_medium, COLORS.border, 1)
    
    create_text(correo_panel, 'Correo Rápido', 14, COLORS.gold, 'TOP', 0, -10)
    
    -- Inputs
    create_text(correo_panel, 'Para:', 11, COLORS.text, 'TOPLEFT', 15, -50)
    local dest_input = CreateFrame('EditBox', nil, correo_panel, 'InputBoxTemplate')
    dest_input:SetWidth(150)
    dest_input:SetHeight(25)
    dest_input:SetPoint('TOPLEFT', 60, -45)
    dest_input:SetAutoFocus(false)
    correo_panel.dest_input = dest_input
    
    create_text(correo_panel, 'Asunto:', 11, COLORS.text, 'TOPLEFT', 15, -80)
    local subject_input = CreateFrame('EditBox', nil, correo_panel, 'InputBoxTemplate')
    subject_input:SetWidth(150)
    subject_input:SetHeight(25)
    subject_input:SetPoint('TOPLEFT', 60, -75)
    subject_input:SetText('Items')
    subject_input:SetAutoFocus(false)
    correo_panel.subject_input = subject_input
    
    create_text(correo_panel, 'Gold:', 11, COLORS.text, 'TOPLEFT', 15, -110)
    local gold_input = CreateFrame('EditBox', nil, correo_panel, 'InputBoxTemplate')
    gold_input:SetWidth(80)
    gold_input:SetHeight(25)
    gold_input:SetPoint('TOPLEFT', 60, -105)
    gold_input:SetText('0')
    gold_input:SetAutoFocus(false)
    correo_panel.gold_input = gold_input
    
    -- Botones de Acción
    local btn_send_all = create_button(correo_panel, 'Enviar Todo el Inventario', 200, 25, {0.6, 0.2, 0.2, 1})
    btn_send_all:SetPoint('TOP', 0, -150)
    btn_send_all:SetScript('OnClick', function() M.enviar_todo_inventario() end)
    
    local btn_send_mats = create_button(correo_panel, 'Enviar Solo Materiales', 200, 25, COLORS.warning)
    btn_send_mats:SetPoint('TOP', 0, -180)
    btn_send_mats:SetScript('OnClick', function() M.enviar_materiales() end)
    
    local btn_send_boe = create_button(correo_panel, 'Enviar Solo Equipamiento', 200, 25, COLORS.warning)
    btn_send_boe:SetPoint('TOP', 0, -210)
    btn_send_boe:SetScript('OnClick', function() M.enviar_equipamiento() end)
    
    local btn_loot = create_button(correo_panel, 'AUTO-LOOT CORREO', 200, 30, COLORS.success)
    btn_loot:SetPoint('BOTTOM', 0, 40)
    btn_loot:SetScript('OnClick', function() M.auto_loot_correo() end)
    
    local status_text = create_text(correo_panel, 'Enviados: 0 | Recibidos: 0', 10, COLORS.text_dim, 'BOTTOM', 0, 10)
    correo_panel.status_text = status_text
    
    f.correo_panel = correo_panel
    tracker_panel = f
    return f
end

-- ============================================================================
-- Funciones de Interacción
-- ============================================================================

function M.actualizar_item_tracker_ui()
    if not tracker_panel then return end
    
    M.actualizar_lista_alts()
    M.actualizar_inventario_display()
end

function M.actualizar_lista_alts()
    if not tracker_panel or not tracker_panel.alts_panel then return end
    
    local alts = {}
    if M.modules.item_tracker and M.modules.item_tracker.obtener_alts then
        alts = M.modules.item_tracker.obtener_alts() or {}
    end
    
    -- Convertir hash map a array para FauxScroll
    local alts_array = {}
    local total_gold = 0
    for name, data in pairs(alts) do
        table.insert(alts_array, {name = name, gold = data.gold or 0})
        total_gold = total_gold + (data.gold or 0)
    end
    
    -- Actualizar header de oro
    -- Fix: Use M directly
    tracker_panel.alts_panel.gold_total:SetText(string.format('Total: %s', M.format_gold(total_gold)))
    
    -- Actualizar Faux Scroll
    local lista = tracker_panel.alts_panel.lista
    if not lista then return end
    local num_rows = 15
    local ROW_HEIGHT = 24
    
    FauxScrollFrame_Update(AuxTrackerAltsScroll, table.getn(alts_array) or 0, num_rows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(AuxTrackerAltsScroll)
    
    for i = 1, num_rows do
        local btn = lista[i]
        local index = offset + i
        if index <= table.getn(alts_array) then
            local data = alts_array[index]
            btn.alt_name = data.name
            btn.text:SetText(string.format('%s - %s', data.name, M.format_gold(data.gold)))
            btn:Show()
            
            -- Striping
             if math.mod(i, 2) == 0 then
                btn.bg:SetTexture(1, 1, 1, 0.05)
             else
                btn.bg:SetTexture(0, 0, 0, 0)
             end
        else
            btn:Hide()
        end
    end
end

function M.actualizar_inventario_display()
    if not tracker_panel or not tracker_panel.inventario_panel then return end
    
    local lista = tracker_panel.inventario_panel.lista
    local search_text = string.lower(tracker_panel.inventario_panel.search_input:GetText() or "")
    
    local inventory = {}
    if M.modules.item_tracker and M.modules.item_tracker.obtener_inventario then
        inventory = M.modules.item_tracker.obtener_inventario() or {}
    end
    
    -- Filtrar items
    local filtered_items = {}
    for item_key, data in pairs(inventory) do
        if search_text == "" or string.find(string.lower(data.name or ""), search_text) then
            table.insert(filtered_items, data)
        end
    end
    
    -- Actualizar Faux Scroll
    local num_rows = 15
    local ROW_HEIGHT = 20
    
    FauxScrollFrame_Update(AuxTrackerInvScroll, table.getn(filtered_items) or 0, num_rows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(AuxTrackerInvScroll)
    
    for i = 1, num_rows do
        local btn = lista[i]
        local index = offset + i
        if index <= table.getn(filtered_items) then
            local item = filtered_items[index]
            btn.text:SetText(string.format('%s (x%d)', string.sub(item.name, 1, 30), item.total_count))
            btn:Show()
             if math.mod(i, 2) == 0 then
                btn.bg:SetTexture(1, 1, 1, 0.05)
             else
                btn.bg:SetTexture(0, 0, 0, 0)
             end
        else
            btn:Hide()
        end
    end
end

function M.actualizar_correo_stats()
    if not tracker_panel or not tracker_panel.correo_panel then return end
    if not tracker_panel.correo_panel.status_text then return end
    
    local stats = {}
    if M.modules.item_tracker and M.modules.item_tracker.obtener_mail_stats then
        stats = M.modules.item_tracker.obtener_mail_stats() or {}
    end
    
    tracker_panel.correo_panel.status_text:SetText(string.format(
        '|cFFFFFFFFEnviados: %d | Recibidos: %d|r',
        stats.sent or 0,
        stats.received or 0
    ))
end

function M.seleccionar_alt(alt_name)
    if not alt_name then return end
    
    aux.print(string.format('|cFF00FF00Alt seleccionado: %s|r', alt_name))
    
    -- Actualizar inventario del alt seleccionado
    M.actualizar_inventario_display()
end

function M.enviar_todo_inventario()
    local dest = tracker_panel.correo_panel.dest_input:GetText()
    
    if not dest or dest == '' then
        aux.print('|cFFFF0000Especifica un destinatario|r')
        return
    end
    
    if M.modules.item_tracker and M.modules.item_tracker.enviar_todo then
        M.modules.item_tracker.enviar_todo(dest)
        M.actualizar_correo_stats()
    end
end

function M.enviar_materiales()
    local dest = tracker_panel.correo_panel.dest_input:GetText()
    
    if not dest or dest == '' then
        aux.print('|cFFFF0000Especifica un destinatario|r')
        return
    end
    
    if M.modules.item_tracker and M.modules.item_tracker.enviar_materiales then
        M.modules.item_tracker.enviar_materiales(dest)
        M.actualizar_correo_stats()
    end
end

function M.enviar_equipamiento()
    local dest = tracker_panel.correo_panel.dest_input:GetText()
    
    if not dest or dest == '' then
        aux.print('|cFFFF0000Especifica un destinatario|r')
        return
    end
    
    if M.modules.item_tracker and M.modules.item_tracker.enviar_equipamiento then
        M.modules.item_tracker.enviar_equipamiento(dest)
        M.actualizar_correo_stats()
    end
end

function M.auto_loot_correo()
    if M.modules.item_tracker and M.modules.item_tracker.auto_loot_mail then
        M.modules.item_tracker.auto_loot_mail()
        M.actualizar_correo_stats()
    end
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.item_tracker_ui = {
    crear_item_tracker_ui = M.crear_item_tracker_ui,
    actualizar_item_tracker_ui = M.actualizar_item_tracker_ui,
}

aux.print('[ITEM_TRACKER_UI] Módulo registrado correctamente')
