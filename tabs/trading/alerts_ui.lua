module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- Alerts UI - Sistema de Alertas Visuales
-- ============================================================================

aux.print('[ALERTS_UI] Módulo de alertas visuales cargado')

-- ============================================================================
-- Variables
-- ============================================================================

local alert_frames = {}
local alert_queue = {}
local max_alerts = 3
local alert_duration = 5  -- segundos
local next_alert_y = -100

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

-- Tipos de alertas
local alert_types = {
    exceptional = {
        color = {1, 0.84, 0},  -- Dorado
        sound = 'AuctionWindowOpen',
        icon = '⭐',
        priority = 1,
    },
    good = {
        color = {0, 1, 0},  -- Verde
        sound = 'MapPing',
        icon = '✓',
        priority = 2,
    },
    warning = {
        color = {1, 0.65, 0},  -- Naranja
        sound = 'RaidWarning',
        icon = '⚠',
        priority = 3,
    },
    error = {
        color = {1, 0.27, 0.27},  -- Rojo
        sound = 'igQuestFailed',
        icon = '✖',
        priority = 4,
    },
    info = {
        color = {0.5, 0.5, 1},  -- Azul
        sound = nil,
        icon = 'ℹ',
        priority = 5,
    },
}

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================



-- ============================================================================
-- Crear Frame de Alerta
-- ============================================================================

local function crear_alert_frame()
    local f = CreateFrame('Frame', nil, UIParent)
    f:SetWidth(350)
    f:SetHeight(80)
    f:SetFrameStrata('DIALOG')
    f:SetPoint('TOP', UIParent, 'TOP', 0, next_alert_y)
    f:Hide()
    
    -- Fondo
    f.bg = f:CreateTexture(nil, 'BACKGROUND')
    f.bg:SetAllPoints()
    f.bg:SetTexture(0, 0, 0, 0.9)
    
    -- Borde
    f.border = f:CreateTexture(nil, 'BORDER')
    f.border:SetPoint('TOPLEFT', -2, 2)
    f.border:SetPoint('BOTTOMRIGHT', 2, -2)
    f.border:SetTexture(1, 1, 1, 0.3)
    
    -- Icono
    f.icon = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
    f.icon:SetPoint('LEFT', f, 'LEFT', 10, 0)
    f.icon:SetText('⭐')
    
    -- Título
    f.title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    f.title:SetPoint('TOPLEFT', f.icon, 'TOPRIGHT', 10, 0)
    f.title:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
    f.title:SetJustifyH('LEFT')
    f.title:SetText('Alerta')
    
    -- Mensaje
    f.message = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    f.message:SetPoint('TOPLEFT', f.title, 'BOTTOMLEFT', 0, -5)
    f.message:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
    f.message:SetJustifyH('LEFT')
    f.message:SetText('Mensaje de alerta')
    
    -- Detalles
    f.details = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    f.details:SetPoint('TOPLEFT', f.message, 'BOTTOMLEFT', 0, -3)
    f.details:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
    f.details:SetJustifyH('LEFT')
    f.details:SetText('')
    
    -- Botón cerrar
    f.close_btn = CreateFrame('Button', nil, f)
    f.close_btn:SetWidth(20)
    f.close_btn:SetHeight(20)
    f.close_btn:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -5, -5)
    
    f.close_btn.text = f.close_btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    f.close_btn.text:SetPoint('CENTER')
    f.close_btn.text:SetText('|cFFFF4444✖|r')
    
    f.close_btn:SetScript('OnClick', function()
        this:GetParent():Hide()
        M.reorganizar_alertas()
    end)
    
    f.close_btn:SetScript('OnEnter', function()
        this.text:SetText('|cFFFFFFFF✖|r')
    end)
    
    f.close_btn:SetScript('OnLeave', function()
        this.text:SetText('|cFFFF4444✖|r')
    end)
    
    -- Timer para auto-cerrar
    f.elapsed = 0
    f.duration = alert_duration
    
    f:SetScript('OnUpdate', function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= this.duration then
            this:Hide()
            M.reorganizar_alertas()
        end
    end)
    
    -- Animación de entrada
    f:SetAlpha(0)
    
    return f
end

-- ============================================================================
-- Reorganizar Alertas
-- ============================================================================

function M.reorganizar_alertas()
    local y_offset = -100
    local visible_count = 0
    
    for i, frame in ipairs(alert_frames) do
        if frame:IsVisible() then
            frame:ClearAllPoints()
            frame:SetPoint('TOP', UIParent, 'TOP', 0, y_offset)
            y_offset = y_offset - 90
            visible_count = visible_count + 1
        end
    end
    
    next_alert_y = y_offset
    
    -- Procesar siguiente alerta en cola
    if visible_count < max_alerts and table.getn(alert_queue) > 0 then
        local next_alert = table.remove(alert_queue, 1)
        M.mostrar_alerta_inmediata(next_alert.type, next_alert.title, next_alert.message, next_alert.details)
    end
end

-- ============================================================================
-- Mostrar Alerta
-- ============================================================================

function M.mostrar_alerta(alert_type, title, message, details)
    -- Validar tipo
    if not alert_types[alert_type] then
        alert_type = 'info'
    end
    
    -- Contar alertas visibles
    local visible_count = 0
    for _, frame in ipairs(alert_frames) do
        if frame:IsVisible() then
            visible_count = visible_count + 1
        end
    end
    
    -- Si hay demasiadas alertas, añadir a cola
    if visible_count >= max_alerts then
        table.insert(alert_queue, {
            type = alert_type,
            title = title,
            message = message,
            details = details,
        })
        return
    end
    
    M.mostrar_alerta_inmediata(alert_type, title, message, details)
end

function M.mostrar_alerta_inmediata(alert_type, title, message, details)
    local alert_config = alert_types[alert_type]
    
    -- Buscar frame disponible o crear uno nuevo
    local frame = nil
    for _, f in ipairs(alert_frames) do
        if not f:IsVisible() then
            frame = f
            break
        end
    end
    
    if not frame then
        frame = crear_alert_frame()
        table.insert(alert_frames, frame)
    end
    
    -- Configurar frame
    frame.icon:SetText(alert_config.icon)
    frame.icon:SetTextColor(unpack(alert_config.color))
    
    frame.title:SetText(title or 'Alerta')
    frame.title:SetTextColor(unpack(alert_config.color))
    
    frame.message:SetText(message or '')
    frame.details:SetText(details or '')
    
    -- Resetear timer
    frame.elapsed = 0
    frame.duration = alert_duration
    
    -- Mostrar con animación
    frame:Show()
    frame:SetAlpha(0)
    
    -- Fade in
    local fade_time = 0.3
    local fade_elapsed = 0
    frame:SetScript('OnUpdate', function()
        fade_elapsed = fade_elapsed + arg1
        if fade_elapsed < fade_time then
            this:SetAlpha(fade_elapsed / fade_time)
        else
            this:SetAlpha(1)
            -- Restaurar script normal
            this.elapsed = 0
            this:SetScript('OnUpdate', function()
                this.elapsed = this.elapsed + arg1
                if this.elapsed >= this.duration then
                    -- Fade out
                    local fade_out_time = 0.3
                    local fade_out_elapsed = 0
                    this:SetScript('OnUpdate', function()
                        fade_out_elapsed = fade_out_elapsed + arg1
                        if fade_out_elapsed < fade_out_time then
                            this:SetAlpha(1 - (fade_out_elapsed / fade_out_time))
                        else
                            this:Hide()
                            this:SetAlpha(1)
                            M.reorganizar_alertas()
                        end
                    end)
                end
            end)
        end
    end)
    
    -- Reproducir sonido
    if alert_config.sound then
        PlaySound(alert_config.sound)
    end
    
    M.reorganizar_alertas()
end

-- ============================================================================
-- Alertas Predefinidas
-- ============================================================================

function M.alerta_oportunidad_excepcional(item_name, profit, discount)
    local title = '⭐ OPORTUNIDAD EXCEPCIONAL'
    local message = item_name or 'Item desconocido'
    local details = string.format('Ganancia: %s | Descuento: %d%%', 
        format_gold(profit or 0), 
        math.floor((discount or 0) * 100))
    
    M.mostrar_alerta('exceptional', title, message, details)
end

function M.alerta_sniper(item_name, profit, discount)
    local title = '🎯 SNIPER: COMPRA RÁPIDO!'
    local message = item_name or 'Item desconocido'
    local details = string.format('Ganancia: %s | Descuento: %d%%', 
        format_gold(profit or 0), 
        math.floor((discount or 0) * 100))
    
    M.mostrar_alerta('exceptional', title, message, details)
end

function M.alerta_venta_exitosa(item_name, profit)
    local title = '✓ Venta Exitosa'
    local message = item_name or 'Item desconocido'
    local details = string.format('Ganancia: %s', format_gold(profit or 0))
    
    M.mostrar_alerta('good', title, message, details)
end

function M.alerta_undercut(item_name)
    local title = '⚠ Te hicieron Undercut'
    local message = item_name or 'Item desconocido'
    local details = 'Considera repostear con nuevo precio'
    
    M.mostrar_alerta('warning', title, message, details)
end

function M.alerta_manipulacion(item_name)
    local title = '⚠ Posible Manipulación'
    local message = item_name or 'Item desconocido'
    local details = 'Mercado volátil - Precaución al comprar'
    
    M.mostrar_alerta('warning', title, message, details)
end

function M.alerta_error(mensaje)
    local title = '✖ Error'
    local message = mensaje or 'Error desconocido'
    
    M.mostrar_alerta('error', title, message, '')
end

function M.alerta_info(titulo, mensaje)
    M.mostrar_alerta('info', titulo or 'Información', mensaje or '', '')
end

-- ============================================================================
-- Limpiar Alertas
-- ============================================================================

function M.limpiar_alertas()
    for _, frame in ipairs(alert_frames) do
        frame:Hide()
    end
    alert_queue = {}
    M.reorganizar_alertas()
end

-- Registrar funciones en el módulo
if not M.modules then M.modules = {} end
if not M.modules.alerts_ui then M.modules.alerts_ui = {} end

M.modules.alerts_ui.mostrar_alerta = M.mostrar_alerta
M.modules.alerts_ui.alerta_oportunidad_excepcional = M.alerta_oportunidad_excepcional
M.modules.alerts_ui.alerta_sniper = M.alerta_sniper
M.modules.alerts_ui.alerta_venta_exitosa = M.alerta_venta_exitosa
M.modules.alerts_ui.alerta_undercut = M.alerta_undercut
M.modules.alerts_ui.alerta_manipulacion = M.alerta_manipulacion
M.modules.alerts_ui.alerta_error = M.alerta_error
M.modules.alerts_ui.alerta_info = M.alerta_info
M.modules.alerts_ui.limpiar_alertas = M.limpiar_alertas

aux.print('|cFF00FF00[ALERTS_UI]|r Sistema de alertas visuales listo')
