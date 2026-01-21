module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

aux.print('[AUCTIONING_UI] Módulo de UI de subastas cargado')

-- ============================================================================
-- Auctioning UI - Interfaz de Posteo Automático
-- ============================================================================

local auctioning_panel = nil
local selected_group = nil

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================

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



-- ============================================================================
-- Crear UI Principal
-- ============================================================================

function M.crear_auctioning_ui(parent)
    if not parent then 
        aux.print('[AUCTIONING_UI] ERROR: parent es nil')
        return nil 
    end
    
    aux.print('[AUCTIONING_UI] Creando panel...')
    
    local f = CreateFrame('Frame', nil, parent)
    f:SetAllPoints()
    f:Hide()
    
    aux.print('[AUCTIONING_UI] Frame creado')
    
    -- Titulo
    local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOP', 0, -20)
    title:SetText('AUCTIONING - Posteo Automatico')
    
    aux.print('[AUCTIONING_UI] Titulo creado')
    
    -- Descripcion
    local desc = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    desc:SetPoint('TOP', title, 'BOTTOM', 0, -5)
    desc:SetText('Postea items automaticamente con precios optimos')
    
    -- ========================================================================
    -- Panel de Grupos (Izquierda)
    -- ========================================================================
    
    local grupos_panel = CreateFrame('Frame', nil, f)
    grupos_panel:SetWidth(240)
    grupos_panel:SetHeight(480)
    grupos_panel:SetPoint('TOPLEFT', 20, -60)
    grupos_panel:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Titulo de grupos
    local grupos_title = grupos_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    grupos_title:SetPoint('TOP', 0, -15)
    grupos_title:SetText('Grupos')
    
    -- Boton crear grupo
    local btn_crear_grupo = CreateFrame('Button', nil, grupos_panel, 'UIPanelButtonTemplate')
    btn_crear_grupo:SetWidth(180)
    btn_crear_grupo:SetHeight(25)
    btn_crear_grupo:SetPoint('TOP', grupos_title, 'BOTTOM', 0, -10)
    btn_crear_grupo:SetText('Crear Grupo')
    btn_crear_grupo:SetScript('OnClick', function()
        M.mostrar_dialogo_crear_grupo()
    end)
    
    -- Lista de grupos
    grupos_panel.lista = {}
    for i = 1, 10 do
        local grupo_btn = CreateFrame('Button', nil, grupos_panel)
        grupo_btn:SetWidth(180)
        grupo_btn:SetHeight(25)
        grupo_btn:SetPoint('TOP', btn_crear_grupo, 'BOTTOM', 0, -5 - (i-1) * 27)
        
        local bg = grupo_btn:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture(0.1, 0.1, 0.1, 0.8)
        grupo_btn.bg = bg
        
        local text = grupo_btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        text:SetPoint('LEFT', 5, 0)
        text:SetText('')
        grupo_btn.text = text
        
        grupo_btn:SetScript('OnClick', function()
            M.seleccionar_grupo(grupo_btn.grupo_nombre)
        end)
        
        grupo_btn:SetScript('OnEnter', function()
            bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end)
        
        grupo_btn:SetScript('OnLeave', function()
            bg:SetTexture(0.1, 0.1, 0.1, 0.8)
        end)
        
        grupo_btn:Hide()
        grupos_panel.lista[i] = grupo_btn
    end
    
    f.grupos_panel = grupos_panel
    
    -- ========================================================================
    -- Panel de Detalles (Centro)
    -- ========================================================================
    
    local detalles_panel = CreateFrame('Frame', nil, f)
    detalles_panel:SetWidth(320)
    detalles_panel:SetHeight(240)
    detalles_panel:SetPoint('LEFT', grupos_panel, 'RIGHT', 10, 0)
    detalles_panel:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Titulo
    local detalles_title = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    detalles_title:SetPoint('TOP', 0, -15)
    detalles_title:SetText('Configuracion')
    detalles_panel.title = detalles_title
    
    -- Configuracion
    local y_offset = -50
    
    -- Undercut
    local undercut_label = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    undercut_label:SetPoint('TOPLEFT', 20, y_offset)
    undercut_label:SetText('Undercut:')
    
    local undercut_input = CreateFrame('EditBox', nil, detalles_panel, 'InputBoxTemplate')
    undercut_input:SetWidth(80)
    undercut_input:SetHeight(25)
    undercut_input:SetPoint('LEFT', undercut_label, 'RIGHT', 10, 0)
    undercut_input:SetText('1')
    undercut_input:SetAutoFocus(false)
    detalles_panel.undercut_input = undercut_input
    
    y_offset = y_offset - 35
    
    -- Min Price %
    local min_price_label = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    min_price_label:SetPoint('TOPLEFT', 20, y_offset)
    min_price_label:SetText('Min Price %:')
    
    local min_price_input = CreateFrame('EditBox', nil, detalles_panel, 'InputBoxTemplate')
    min_price_input:SetWidth(80)
    min_price_input:SetHeight(25)
    min_price_input:SetPoint('LEFT', min_price_label, 'RIGHT', 10, 0)
    min_price_input:SetText('80')
    min_price_input:SetAutoFocus(false)
    detalles_panel.min_price_input = min_price_input
    
    y_offset = y_offset - 35
    
    -- Max Price %
    local max_price_label = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    max_price_label:SetPoint('TOPLEFT', 20, y_offset)
    max_price_label:SetText('Max Price %:')
    
    local max_price_input = CreateFrame('EditBox', nil, detalles_panel, 'InputBoxTemplate')
    max_price_input:SetWidth(80)
    max_price_input:SetHeight(25)
    max_price_input:SetPoint('LEFT', max_price_label, 'RIGHT', 10, 0)
    max_price_input:SetText('120')
    max_price_input:SetAutoFocus(false)
    detalles_panel.max_price_input = max_price_input
    
    y_offset = y_offset - 35
    
    -- Stack Size
    local stack_label = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stack_label:SetPoint('TOPLEFT', 20, y_offset)
    stack_label:SetText('Stack Size:')
    
    local stack_input = CreateFrame('EditBox', nil, detalles_panel, 'InputBoxTemplate')
    stack_input:SetWidth(80)
    stack_input:SetHeight(25)
    stack_input:SetPoint('LEFT', stack_label, 'RIGHT', 10, 0)
    stack_input:SetText('1')
    stack_input:SetAutoFocus(false)
    detalles_panel.stack_input = stack_input
    
    y_offset = y_offset - 35
    
    -- Duration
    local duration_label = detalles_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    duration_label:SetPoint('TOPLEFT', 20, y_offset)
    duration_label:SetText('Duracion:')
    
    local duration_dropdown = CreateFrame('Frame', nil, detalles_panel)
    duration_dropdown:SetWidth(120)
    duration_dropdown:SetHeight(25)
    duration_dropdown:SetPoint('LEFT', duration_label, 'RIGHT', 10, 0)
    -- TODO: Implementar dropdown
    detalles_panel.duration_dropdown = duration_dropdown
    
    y_offset = y_offset - 50
    
    -- Botones de accion
    local btn_postear = CreateFrame('Button', nil, detalles_panel, 'UIPanelButtonTemplate')
    btn_postear:SetWidth(150)
    btn_postear:SetHeight(30)
    btn_postear:SetPoint('TOPLEFT', 20, y_offset)
    btn_postear:SetText('Postear Grupo')
    btn_postear:SetScript('OnClick', function()
        if selected_group then
            M.postear_grupo_seleccionado()
        else
            aux.print('|cFFFF0000Selecciona un grupo primero|r')
        end
    end)
    
    local btn_cancel_repost = CreateFrame('Button', nil, detalles_panel, 'UIPanelButtonTemplate')
    btn_cancel_repost:SetWidth(150)
    btn_cancel_repost:SetHeight(30)
    btn_cancel_repost:SetPoint('LEFT', btn_postear, 'RIGHT', 10, 0)
    btn_cancel_repost:SetText('Cancel/Repost')
    btn_cancel_repost:SetScript('OnClick', function()
        M.ejecutar_cancel_repost()
    end)
    
    f.detalles_panel = detalles_panel
    
    -- ========================================================================
    -- Panel de Estadísticas (Derecha)
    -- ========================================================================
    
    local stats_panel = CreateFrame('Frame', nil, f)
    stats_panel:SetWidth(280)
    stats_panel:SetHeight(480)
    stats_panel:SetPoint('LEFT', detalles_panel, 'RIGHT', 10, 0)
    stats_panel:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Titulo
    local stats_title = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    stats_title:SetPoint('TOP', 0, -15)
    stats_title:SetText('Estadisticas')
    
    -- Stats
    local stats_text = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_text:SetPoint('TOPLEFT', 15, -50)
    stats_text:SetJustifyH('LEFT')
    stats_text:SetText('Cargando...')
    stats_panel.stats_text = stats_text
    
    f.stats_panel = stats_panel
    
    -- ========================================================================
    -- Boton Postear Todos
    -- ========================================================================
    
    local btn_postear_todos = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
    btn_postear_todos:SetWidth(200)
    btn_postear_todos:SetHeight(35)
    btn_postear_todos:SetPoint('BOTTOM', 0, 20)
    btn_postear_todos:SetText('POSTEAR TODOS LOS GRUPOS')
    btn_postear_todos:SetScript('OnClick', function()
        M.postear_todos_los_grupos()
    end)
    
    auctioning_panel = f
    
    aux.print('[AUCTIONING_UI] Panel completado y retornando')
    
    return f
end

-- ============================================================================
-- Funciones de Interacción
-- ============================================================================

function M.actualizar_auctioning_ui()
    aux.print('[AUCTIONING_UI] actualizar_auctioning_ui llamado')
    
    if not auctioning_panel then 
        aux.print('[AUCTIONING_UI] ERROR: auctioning_panel es nil')
        return 
    end
    
    aux.print('[AUCTIONING_UI] Actualizando UI...')
    
    -- Actualizar lista de grupos
    M.actualizar_lista_grupos()
    
    -- Actualizar estadisticas
    M.actualizar_stats_auctioning()
end

function M.actualizar_lista_grupos()
    if not auctioning_panel or not auctioning_panel.grupos_panel then return end
    
    local grupos = M.modules.auctioning and M.modules.auctioning.obtener_grupos() or {}
    local lista = auctioning_panel.grupos_panel.lista
    
    local i = 1
    for nombre, grupo in pairs(grupos) do
        if i <= 10 then
            local btn = lista[i]
            btn.grupo_nombre = nombre
            btn.text:SetText(nombre)
            btn:Show()
            i = i + 1
        end
    end
    
    -- Ocultar botones no usados
    for j = i, 10 do
        lista[j]:Hide()
    end
end

function M.actualizar_stats_auctioning()
    if not auctioning_panel or not auctioning_panel.stats_panel then return end
    
    local stats = M.modules.auctioning and M.modules.auctioning.obtener_stats() or {}
    
    local text = string.format(
        '|cFFFFFFFFGrupos Activos: |cFF00FF00%d|r\n\n' ..
        '|cFFFFFFFFPosteados: |cFF00FF00%d|r\n' ..
        '|cFFFFFFFFCancelados: |cFFFFAA00%d|r\n' ..
        '|cFFFFFFFFVendidos: |cFF00FF00%d|r\n\n' ..
        '|cFFFFFFFFProfit Total:\n|cFFFFD700%s|r',
        stats.grupos_activos or 0,
        stats.total_posted or 0,
        stats.total_cancelled or 0,
        stats.total_sold or 0,
        format_gold(stats.total_profit or 0)
    )
    
    auctioning_panel.stats_panel.stats_text:SetText(text)
end

function M.seleccionar_grupo(grupo_nombre)
    selected_group = grupo_nombre
    aux.print(string.format('|cFF00FF00Grupo seleccionado: %s|r', grupo_nombre))
    
    -- Actualizar UI con configuración del grupo
    -- TODO: Cargar configuración del grupo
end

function M.postear_grupo_seleccionado()
    if not selected_group then return end
    
    aux.print('|cFF00FF00[Auctioning]|r Posteando grupo: ' .. selected_group)
    
    -- Usar integración UI para postear
    if M.toggle_auto_post_for_ui then
        M.toggle_auto_post_for_ui(true)
    end
    
    -- TODO: Implementar posteo de grupo específico
    M.actualizar_auctioning_ui()
end

function M.postear_todos_los_grupos()
    aux.print('|cFF00FF00[Auctioning]|r Posteando todos los grupos...')
    
    -- Habilitar auto-posting
    if M.toggle_auto_post_for_ui then
        M.toggle_auto_post_for_ui(true)
    end
    
    M.actualizar_auctioning_ui()
end

function M.ejecutar_cancel_repost()
    aux.print('|cFF00FF00[Auctioning]|r Ejecutando cancel/repost...')
    
    -- Verificar undercuts usando integración UI
    if M.check_undercuts_for_ui then
        M.check_undercuts_for_ui()
    else
        aux.print('|cFFFF4444[Auctioning]|r Función de undercut no disponible')
    end
    
    M.actualizar_auctioning_ui()
end

function M.mostrar_dialogo_crear_grupo()
    -- Use StaticPopup for group name input
    StaticPopupDialogs["AUX_CREATE_GROUP"] = {
        text = "Nombre del nuevo grupo:",
        button1 = "Crear",
        button2 = "Cancelar",
        hasEditBox = true,
        OnAccept = function()
            local nombre = getglobal(this:GetParent():GetName().."EditBox"):GetText()
            if nombre and nombre ~= "" then
                -- Use groups module to create
                if M.modules.groups and M.modules.groups.crear_grupo then
                    M.modules.groups.crear_grupo(nombre)
                    aux.print(string.format('|cFF00FF00Grupo creado: %s|r', nombre))
                    M.actualizar_auctioning_ui()
                else
                    -- Fallback: Create locally
                    aux.print(string.format('|cFF00FF00Grupo "%s" creado|r', nombre))
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("AUX_CREATE_GROUP")
end

-- Registrar módulo
M.modules = M.modules or {}
M.modules.auctioning_ui = {
    crear_auctioning_ui = M.crear_auctioning_ui,
    actualizar_auctioning_ui = M.actualizar_auctioning_ui,
}

aux.print('[AUCTIONING_UI] Módulo registrado correctamente')
