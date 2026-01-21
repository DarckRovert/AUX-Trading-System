module 'aux.tabs.trading'

local aux = require 'aux'

-- ============================================================================
-- NOTIFICATION SYSTEM - Sistema de Notificaciones Visuales
-- ============================================================================

aux.print('[NOTIFICATIONS] Módulo de notificaciones cargado')

-- ============================================================================
-- Notification Queue
-- ============================================================================

local notification_queue = {}
local active_notifications = {}
local notification_id_counter = 0

-- Tipos de notificaciones
local NOTIFICATION_TYPES = {
    SUCCESS = {
        color = {0, 1, 0},
        icon = '✓',
        sound = 'AuctionWindowClose',
    },
    WARNING = {
        color = {1, 0.8, 0},
        icon = '!',
        sound = 'igQuestFailed',
    },
    ERROR = {
        color = {1, 0, 0},
        icon = 'X',
        sound = 'igQuestFailed',
    },
    INFO = {
        color = {0.5, 0.8, 1},
        icon = 'i',
        sound = 'TellMessage',
    },
    PROFIT = {
        color = {0, 1, 0.5},
        icon = '¤',
        sound = 'MONEYFRAMEOPEN',
    },
    OPPORTUNITY = {
        color = {1, 0.84, 0},
        icon = '★',
        sound = 'AuctionWindowOpen',
    },
}

-- ============================================================================
-- Notification Creation
-- ============================================================================

function create_notification(notification_type, title, message, duration, on_click)
    notification_id_counter = notification_id_counter + 1
    
    local notification = {
        id = notification_id_counter,
        type = notification_type or 'INFO',
        title = title or 'Notification',
        message = message or '',
        duration = duration or 5,
        created_at = time(),
        on_click = on_click,
    }
    
    tinsert(notification_queue, notification)
    
    -- Reproducir sonido
    local type_config = NOTIFICATION_TYPES[notification.type]
    if type_config and type_config.sound then
        PlaySound(type_config.sound)
    end
    
    return notification.id
end

-- ============================================================================
-- Notification Display
-- ============================================================================

local notification_frame_pool = {}

function create_notification_frame()
    local frame = CreateFrame('Frame', nil, UIParent)
    frame:SetWidth(300)
    frame:SetHeight(80)
    frame:SetFrameStrata('DIALOG')
    frame:EnableMouse(true)
    
    -- Fondo
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints(frame)
    bg:SetTexture(0, 0, 0, 0.85)
    frame.bg = bg
    
    -- Borde
    local border_top = frame:CreateTexture(nil, 'BORDER')
    border_top:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
    border_top:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    border_top:SetHeight(2)
    frame.border_top = border_top
    
    -- Icono
    local icon = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
    icon:SetPoint('LEFT', frame, 'LEFT', 10, 0)
    icon:SetFont('Fonts\\FRIZQT__.TTF', 24, 'OUTLINE')
    frame.icon = icon
    
    -- Título
    local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', frame, 'TOPLEFT', 50, -10)
    title:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -10, -10)
    title:SetJustifyH('LEFT')
    frame.title = title
    
    -- Mensaje
    local message = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    message:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -5)
    message:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -10, 10)
    message:SetJustifyH('LEFT')
    message:SetJustifyV('TOP')
    frame.message = message
    
    -- Botón de cerrar
    local close_btn = CreateFrame('Button', nil, frame)
    close_btn:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -5, -5)
    close_btn:SetWidth(16)
    close_btn:SetHeight(16)
    
    local close_text = close_btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    close_text:SetAllPoints(close_btn)
    close_text:SetText('X')
    close_text:SetTextColor(0.8, 0.8, 0.8)
    
    close_btn:SetScript('OnEnter', function()
        close_text:SetTextColor(1, 1, 1)
    end)
    
    close_btn:SetScript('OnLeave', function()
        close_text:SetTextColor(0.8, 0.8, 0.8)
    end)
    
    frame.close_btn = close_btn
    
    -- Barra de progreso (tiempo restante)
    local progress_bar = frame:CreateTexture(nil, 'OVERLAY')
    progress_bar:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, 0)
    progress_bar:SetHeight(3)
    progress_bar:SetTexture(1, 1, 1, 0.3)
    frame.progress_bar = progress_bar
    
    frame:Hide()
    
    return frame
end

function get_notification_frame()
    -- Buscar frame disponible en el pool
    for i, frame in ipairs(notification_frame_pool) do
        if not frame:IsShown() then
            return frame
        end
    end
    
    -- Crear nuevo frame si no hay disponibles
    local frame = create_notification_frame()
    tinsert(notification_frame_pool, frame)
    return frame
end

function show_notification(notification)
    local frame = get_notification_frame()
    
    if not frame then
        return
    end
    
    -- Configurar tipo
    local type_config = NOTIFICATION_TYPES[notification.type] or NOTIFICATION_TYPES.INFO
    
    -- Configurar colores
    frame.border_top:SetTexture(unpack(type_config.color))
    frame.icon:SetTextColor(unpack(type_config.color))
    frame.title:SetTextColor(unpack(type_config.color))
    
    -- Configurar contenido
    frame.icon:SetText(type_config.icon)
    frame.title:SetText(notification.title)
    frame.message:SetText(notification.message)
    
    -- Posicionar
    local y_offset = -10
    local notification_count = 0
    
    for i, active_notif in ipairs(active_notifications) do
        if active_notif.frame and active_notif.frame:IsShown() then
            notification_count = notification_count + 1
        end
    end
    
    y_offset = y_offset - (notification_count * 90)
    
    frame:ClearAllPoints()
    frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -10, y_offset)
    
    -- Configurar botón de cerrar
    frame.close_btn:SetScript('OnClick', function()
        hide_notification(notification.id)
    end)
    
    -- Configurar click en el frame
    if notification.on_click then
        frame:SetScript('OnMouseDown', function()
            notification.on_click()
            hide_notification(notification.id)
        end)
    end
    
    -- Guardar referencia
    notification.frame = frame
    notification.shown_at = time()
    tinsert(active_notifications, notification)
    
    -- Animación de entrada (fade in)
    frame:SetAlpha(0)
    frame:Show()
    
    local fade_in_time = 0.3
    local fade_in_step = 0.05
    local alpha = 0
    
    frame.fade_in_timer = 0
    frame:SetScript('OnUpdate', function(self, elapsed)
        if not self.fade_in_timer then
            return
        end
        
        self.fade_in_timer = self.fade_in_timer + elapsed
        
        if self.fade_in_timer < fade_in_time then
            alpha = self.fade_in_timer / fade_in_time
            self:SetAlpha(alpha)
        else
            self:SetAlpha(1)
            self.fade_in_timer = nil
            self:SetScript('OnUpdate', update_notification_progress)
        end
    end)
end

function update_notification_progress(frame, elapsed)
    if not frame.notification_id then
        return
    end
    
    -- Buscar notificación activa
    local notification = nil
    for i, notif in ipairs(active_notifications) do
        if notif.id == frame.notification_id then
            notification = notif
            break
        end
    end
    
    if not notification then
        frame:SetScript('OnUpdate', nil)
        return
    end
    
    -- Actualizar barra de progreso
    local elapsed_time = time() - notification.shown_at
    local remaining_time = notification.duration - elapsed_time
    
    if remaining_time <= 0 then
        hide_notification(notification.id)
        return
    end
    
    local progress = remaining_time / notification.duration
    frame.progress_bar:SetWidth(frame:GetWidth() * progress)
end

function hide_notification(notification_id)
    for i, notification in ipairs(active_notifications) do
        if notification.id == notification_id then
            if notification.frame then
                -- Animación de salida (fade out)
                local frame = notification.frame
                local fade_out_time = 0.2
                
                frame.fade_out_timer = 0
                frame:SetScript('OnUpdate', function(self, elapsed)
                    if not self.fade_out_timer then
                        return
                    end
                    
                    self.fade_out_timer = self.fade_out_timer + elapsed
                    
                    if self.fade_out_timer < fade_out_time then
                        local alpha = 1 - (self.fade_out_timer / fade_out_time)
                        self:SetAlpha(alpha)
                    else
                        self:Hide()
                        self:SetAlpha(1)
                        self.fade_out_timer = nil
                        self:SetScript('OnUpdate', nil)
                    end
                end)
            end
            
            tremove(active_notifications, i)
            break
        end
    end
    
    -- Reposicionar notificaciones restantes
    reposition_notifications()
end

function reposition_notifications()
    local y_offset = -10
    
    for i, notification in ipairs(active_notifications) do
        if notification.frame and notification.frame:IsShown() then
            notification.frame:ClearAllPoints()
            notification.frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -10, y_offset)
            y_offset = y_offset - 90
        end
    end
end

-- ============================================================================
-- Notification Queue Processing
-- ============================================================================

function process_notification_queue()
    if getn(notification_queue) == 0 then
        return
    end
    
    -- Limitar número de notificaciones activas
    local max_active = 5
    
    while getn(notification_queue) > 0 and getn(active_notifications) < max_active do
        local notification = tremove(notification_queue, 1)
        show_notification(notification)
    end
end

-- ============================================================================
-- Convenience Functions
-- ============================================================================

function notify_success(title, message, duration)
    return create_notification('SUCCESS', title, message, duration)
end

function notify_warning(title, message, duration)
    return create_notification('WARNING', title, message, duration)
end

function notify_error(title, message, duration)
    return create_notification('ERROR', title, message, duration)
end

function notify_info(title, message, duration)
    return create_notification('INFO', title, message, duration)
end

function notify_profit(item_name, profit, duration)
    local title = 'Profit Made!'
    local message = string.format('Sold %s for %s profit', item_name, format_money(profit))
    return create_notification('PROFIT', title, message, duration or 7)
end

function notify_opportunity(item_name, potential_profit, duration)
    local title = 'Trading Opportunity!'
    local message = string.format('%s - Potential profit: %s', item_name, format_money(potential_profit))
    return create_notification('OPPORTUNITY', title, message, duration or 10)
end

function notify_purchase(item_name, price, duration)
    local title = 'Item Purchased'
    local message = string.format('Bought %s for %s', item_name, format_money(price))
    return create_notification('SUCCESS', title, message, duration or 5)
end

function notify_post(item_name, price, duration)
    local title = 'Item Posted'
    local message = string.format('Posted %s for %s', item_name, format_money(price))
    return create_notification('INFO', title, message, duration or 4)
end

function notify_sale(item_name, profit, roi, duration)
    local title = 'Item Sold!'
    local message = string.format('%s sold! Profit: %s (ROI: %.1f%%)', item_name, format_money(profit), roi)
    return create_notification('PROFIT', title, message, duration or 8)
end

-- ============================================================================
-- Update Loop
-- ============================================================================

local update_timer = 0
local UPDATE_INTERVAL = 0.5

local function on_update(elapsed)
    elapsed = elapsed or 0
    update_timer = update_timer + elapsed
    
    if update_timer >= UPDATE_INTERVAL then
        process_notification_queue()
        update_timer = 0
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

local notification_update_frame = CreateFrame('Frame')
notification_update_frame:SetScript('OnUpdate', on_update)

aux.event_listener('LOAD2', function()
    aux.print('[NOTIFICATIONS] Sistema de notificaciones inicializado')
end)

-- ============================================================================
-- Public API
-- ============================================================================

local M = getfenv()
if M.modules then
    M.modules.notifications = {
        create = create_notification,
        hide = hide_notification,
        -- Convenience functions
        success = notify_success,
        warning = notify_warning,
        error = notify_error,
        info = notify_info,
        profit = notify_profit,
        opportunity = notify_opportunity,
        purchase = notify_purchase,
        post = notify_post,
        sale = notify_sale,
    }
    aux.print('[NOTIFICATIONS] Funciones registradas en M.modules.notifications')
end
