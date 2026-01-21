module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- Config UI - Panel de Configuración Profesional
-- ============================================================================

aux.print('[CONFIG_UI] Módulo de configuración cargado')

-- ============================================================================
-- Variables
-- ============================================================================

local config_frame = nil
local current_profile = 'intermedio'

-- Serializador simple para exportar
local function table_to_string(tbl, indent)
    if not indent then indent = 0 end
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2 
    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if (type(k) == "number") then
            toprint = toprint .. "[" .. k .. "] = "
        elseif (type(k) == "string") then
            toprint = toprint  .. k ..  "= "   
        end
        if (type(v) == "number") then
            toprint = toprint .. v .. ",\n"
        elseif (type(v) == "string") then
            toprint = toprint .. "\"" .. v .. "\",\n"
        elseif (type(v) == "table") then
            toprint = toprint .. table_to_string(v, indent + 2) .. ",\n"
        elseif (type(v) == "boolean") then
            toprint = toprint .. tostring(v) .. ",\n"
        else
            toprint = toprint .. "\"" .. tostring(v) .. "\",\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent-2) .. "}"
    return toprint
end

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

-- Popup Definition
StaticPopupDialogs["AUX_CONFIG_EXPORT"] = {
    text = "Configuración Exportada (Ctrl+C para copiar):",
    button1 = "Cerrar",
    hasEditBox = 1,
    maxLetters = 99999,
    OnShow = function()
        local editBox = getglobal(this:GetName().."EditBox")
        if editBox and M.last_export_string then
            editBox:SetText(M.last_export_string)
            editBox:SetFocus()
            editBox:HighlightText()
        end
    end,
    OnHide = function() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}

function M.export_config()
    local cfg = M.get_config()
    if not cfg then return end
    
    local export_str = "AUX_CONFIG = " .. table_to_string(cfg)
    M.last_export_string = export_str
    
    StaticPopup_Show("AUX_CONFIG_EXPORT")
end

-- Perfiles predefinidos
local profiles = {
    principiante = {
        name = 'Principiante',
        description = 'Configuración segura para empezar',
        config = {
            max_daily_investment = 50000,  -- 5g
            max_investment_per_item = 10000,  -- 1g
            max_portfolio_value = 100000,  -- 10g
            flipping = {
                enabled = true,
                min_profit_margin = 0.20,  -- 20%
                max_investment_per_item = 30000,  -- 3g
            },
            sniping = {
                enabled = false,
                min_discount = 0.50,  -- 50%
                auto_buy = false,
            },
            market_reset = {
                enabled = false,
            },
            arbitrage = {
                enabled = false,
            },
            auto_post = {
                enabled = false,
                strategy = 'market',
                min_profit_margin = 0.15,
            },
        },
    },
    intermedio = {
        name = 'Intermedio',
        description = 'Balance entre seguridad y rentabilidad',
        config = {
            max_daily_investment = 200000,  -- 20g
            max_investment_per_item = 50000,  -- 5g
            max_portfolio_value = 500000,  -- 50g
            flipping = {
                enabled = true,
                min_profit_margin = 0.15,  -- 15%
                max_investment_per_item = 50000,  -- 5g
            },
            sniping = {
                enabled = true,
                min_discount = 0.40,  -- 40%
                auto_buy = false,
            },
            market_reset = {
                enabled = false,
            },
            arbitrage = {
                enabled = true,
                min_difference = 0.20,  -- 20%
            },
            auto_post = {
                enabled = true,
                strategy = 'undercut',
                min_profit_margin = 0.10,
            },
        },
    },
    avanzado = {
        name = 'Avanzado',
        description = 'Para traders experimentados',
        config = {
            max_daily_investment = 500000,  -- 50g
            max_investment_per_item = 100000,  -- 10g
            max_portfolio_value = 1000000,  -- 100g
            flipping = {
                enabled = true,
                min_profit_margin = 0.12,  -- 12%
                max_investment_per_item = 100000,  -- 10g
            },
            sniping = {
                enabled = true,
                min_discount = 0.35,  -- 35%
                auto_buy = true,
            },
            market_reset = {
                enabled = true,
                min_market_control = 0.70,
                max_investment = 500000,  -- 50g
            },
            arbitrage = {
                enabled = true,
                min_difference = 0.15,  -- 15%
            },
            auto_post = {
                enabled = true,
                strategy = 'aggressive',
                min_profit_margin = 0.08,
                use_ml_pricing = true,
            },
        },
    },
    experto = {
        name = 'Experto',
        description = 'Máxima agresividad y automatización',
        config = {
            max_daily_investment = 1000000,  -- 100g
            max_investment_per_item = 200000,  -- 20g
            max_portfolio_value = 2000000,  -- 200g
            flipping = {
                enabled = true,
                min_profit_margin = 0.10,  -- 10%
                max_investment_per_item = 200000,  -- 20g
            },
            sniping = {
                enabled = true,
                min_discount = 0.30,  -- 30%
                auto_buy = true,
            },
            market_reset = {
                enabled = true,
                min_market_control = 0.60,
                max_investment = 1000000,  -- 100g
            },
            arbitrage = {
                enabled = true,
                min_difference = 0.10,  -- 10%
            },
            auto_post = {
                enabled = true,
                strategy = 'aggressive',
                min_profit_margin = 0.05,
                use_ml_pricing = true,
                auto_repost = true,
            },
        },
    },
}

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================



local function aplicar_perfil(profile_name)
    current_profile = profile_name
    local profile = profiles[profile_name]
    if not profile then
        aux.print('|cFFFF0000Perfil no encontrado:|r ' .. tostring(profile_name))
        return
    end
    
    -- Aplicar configuración al sistema usando la integración UI
    aux.print('|cFF00FF00[Trading]|r Aplicando perfil: ' .. profile.name)
    aux.print('|cFFFFFFFF' .. profile.description .. '|r')
    
    -- Aplicar configuración real
    -- Aplicar configuración real
    if M.set_config then
        M.set_config(profile.config)
    end
    
    aux.print('|cFF00FF00[Trading]|r Perfil aplicado correctamente')
    current_profile = profile_name
end

-- ============================================================================
-- Crear UI de Configuración
-- ============================================================================

function M.crear_config_ui(parent)
    if config_frame then
        return config_frame
    end
    
    local f = CreateFrame('Frame', 'AuxConfigFrame', parent)
    f:SetAllPoints()
    -- f:Hide() -- Dejar visible, el padre controla la visibilidad
    
    -- Fondo
    f.bg = f:CreateTexture(nil, 'BACKGROUND')
    f.bg:SetAllPoints()
    f.bg:SetTexture(0, 0, 0, 0.3)
    
    -- Scroll Frame
    local scroll = CreateFrame('ScrollFrame', 'AuxConfigScroll', f, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', 10, -10)
    scroll:SetPoint('BOTTOMRIGHT', -30, 10)
    
    local content = CreateFrame('Frame', 'AuxConfigContent', scroll)
    content:SetWidth(scroll:GetWidth())
    content:SetHeight(1000)
    scroll:SetScrollChild(content)
    
    f.scroll = scroll
    f.content = content
    
    local y_offset = -10
    
    -- ========================================
    -- TÍTULO
    -- ========================================
    
    local titulo = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo:SetText('|cFFFFD700⚙️ CONFIGURACIÓN DEL SISTEMA|r')
    y_offset = y_offset - 35
    
    -- ========================================
    -- PERFILES DE TRADING
    -- ========================================
    
    local titulo_perfil = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    titulo_perfil:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_perfil:SetText('|cFFFFFFFF📋 PERFIL DE TRADING|r')
    y_offset = y_offset - 25
    
    -- Botones de perfil
    f.profile_buttons = {}
    local profile_names = {'principiante', 'intermedio', 'avanzado', 'experto'}
    local btn_x = 10
    
    for i, profile_name in ipairs(profile_names) do
        local profile = profiles[profile_name]
        local btn = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
        btn:SetWidth(110)
        btn:SetHeight(24)
        btn:SetPoint('TOPLEFT', content, 'TOPLEFT', btn_x, y_offset)
        btn:SetText(profile.name)
        btn.profile_name = profile_name
        
        btn:SetScript('OnClick', function()
            aplicar_perfil(this.profile_name)
            M.actualizar_config_ui()
        end)
        
        btn:SetScript('OnEnter', function()
            GameTooltip:SetOwner(this, 'ANCHOR_RIGHT')
            GameTooltip:AddLine(profile.name, 1, 0.82, 0)
            GameTooltip:AddLine(profile.description, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        
        btn:SetScript('OnLeave', function()
            GameTooltip:Hide()
        end)
        
        f.profile_buttons[profile_name] = btn
        btn_x = btn_x + 115
    end
    
    y_offset = y_offset - 35
    
    -- ========================================
    -- LÍMITES DE INVERSIÓN
    -- ========================================
    
    local titulo_limites = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    titulo_limites:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_limites:SetText('|cFFFFFFFF💰 LÍMITES DE INVERSIÓN|r')
    y_offset = y_offset - 25
    
    local limites_panel = CreateFrame('Frame', nil, content)
    limites_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    limites_panel:SetWidth(content:GetWidth() - 20)
    limites_panel:SetHeight(100)
    
    limites_panel.bg = limites_panel:CreateTexture(nil, 'BACKGROUND')
    limites_panel.bg:SetAllPoints()
    limites_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.6)
    
    -- Inversión diaria
    local daily_label = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    daily_label:SetPoint('TOPLEFT', limites_panel, 'TOPLEFT', 10, -10)
    daily_label:SetText('Inversión máxima diaria:')
    
    local daily_value = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    daily_value:SetPoint('LEFT', daily_label, 'RIGHT', 10, 0)
    daily_value:SetText('|cFFFFD70020g|r')
    limites_panel.daily_value = daily_value
    
    -- Inversión por item
    local item_label = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    item_label:SetPoint('TOPLEFT', daily_label, 'BOTTOMLEFT', 0, -10)
    item_label:SetText('Inversión máxima por item:')
    
    local item_value = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    item_value:SetPoint('LEFT', item_label, 'RIGHT', 10, 0)
    item_value:SetText('|cFFFFD7005g|r')
    limites_panel.item_value = item_value
    
    -- Portfolio máximo
    local portfolio_label = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    portfolio_label:SetPoint('TOPLEFT', item_label, 'BOTTOMLEFT', 0, -10)
    portfolio_label:SetText('Portfolio máximo:')
    
    local portfolio_value = limites_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    portfolio_value:SetPoint('LEFT', portfolio_label, 'RIGHT', 10, 0)
    portfolio_value:SetText('|cFFFFD70050g|r')
    limites_panel.portfolio_value = portfolio_value
    
    f.limites_panel = limites_panel
    y_offset = y_offset - 110
    
    -- ========================================
    -- ESTRATEGIAS
    -- ========================================
    
    local titulo_estrategias = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    titulo_estrategias:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_estrategias:SetText('|cFFFFFFFF📊 ESTRATEGIAS|r')
    y_offset = y_offset - 25
    
    local estrategias_panel = CreateFrame('Frame', nil, content)
    estrategias_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    estrategias_panel:SetWidth(content:GetWidth() - 20)
    estrategias_panel:SetHeight(150)
    
    estrategias_panel.bg = estrategias_panel:CreateTexture(nil, 'BACKGROUND')
    estrategias_panel.bg:SetAllPoints()
    estrategias_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.6)
    
    -- Flipping
    local flipping_check = CreateFrame('CheckButton', nil, estrategias_panel, 'UICheckButtonTemplate')
    flipping_check:SetPoint('TOPLEFT', estrategias_panel, 'TOPLEFT', 10, -10)
    f.flipping_check = flipping_check
    
    local flipping_label = estrategias_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    flipping_label:SetPoint('LEFT', flipping_check, 'RIGHT', 5, 0)
    flipping_label:SetText('|cFF00FF00Flipping|r - Margen mín: 15% | Max inv: 5g')
    
    -- Sniping
    local sniping_check = CreateFrame('CheckButton', nil, estrategias_panel, 'UICheckButtonTemplate')
    sniping_check:SetPoint('TOPLEFT', flipping_check, 'BOTTOMLEFT', 0, -10)
    f.sniping_check = sniping_check
    
    local sniping_label = estrategias_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    sniping_label:SetPoint('LEFT', sniping_check, 'RIGHT', 5, 0)
    sniping_label:SetText('|cFFFFAA00Sniping|r - Descuento: 40% | Max: 10g')
    
    -- Market Reset
    local reset_check = CreateFrame('CheckButton', nil, estrategias_panel, 'UICheckButtonTemplate')
    reset_check:SetPoint('TOPLEFT', sniping_check, 'BOTTOMLEFT', 0, -10)
    f.reset_check = reset_check
    
    local reset_label = estrategias_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    reset_label:SetPoint('LEFT', reset_check, 'RIGHT', 5, 0)
    reset_label:SetText('|cFFFF4444Market Reset|r - Markup: 30% | Max: 50g')
    
    -- Arbitraje
    local arbitrage_check = CreateFrame('CheckButton', nil, estrategias_panel, 'UICheckButtonTemplate')
    arbitrage_check:SetPoint('TOPLEFT', reset_check, 'BOTTOMLEFT', 0, -10)
    f.arbitrage_check = arbitrage_check
    
    local arbitrage_label = estrategias_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    arbitrage_label:SetPoint('LEFT', arbitrage_check, 'RIGHT', 5, 0)
    arbitrage_label:SetText('|cFF88FF00Arbitraje|r - Diferencia: 20%')
    
    f.estrategias_panel = estrategias_panel
    y_offset = y_offset - 180 -- Aumentado de 160 para más espacio
    
    -- ========================================
    -- AUTOMATIZACIÓN
    -- ========================================
    
    local titulo_auto = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    titulo_auto:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_auto:SetText('|cFFFFFFFF🤖 AUTOMATIZACIÓN|r')
    y_offset = y_offset - 25
    
    local auto_panel = CreateFrame('Frame', nil, content)
    auto_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    auto_panel:SetWidth(content:GetWidth() - 20)
    auto_panel:SetHeight(120)
    
    auto_panel.bg = auto_panel:CreateTexture(nil, 'BACKGROUND')
    auto_panel.bg:SetAllPoints()
    auto_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.6)
    
    -- Auto-posting
    local autopost_check = CreateFrame('CheckButton', nil, auto_panel, 'UICheckButtonTemplate')
    autopost_check:SetPoint('TOPLEFT', auto_panel, 'TOPLEFT', 10, -10)
    f.autopost_check = autopost_check
    
    local autopost_label = auto_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    autopost_label:SetPoint('LEFT', autopost_check, 'RIGHT', 5, 0)
    autopost_label:SetText('|cFF00FF00Auto-posting habilitado|r')
    
    local strategy_label = auto_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    strategy_label:SetPoint('TOPLEFT', autopost_check, 'BOTTOMLEFT', 25, -5)
    strategy_label:SetText('Estrategia: |cFFFFD700Undercut|r | Undercut: 1s | Margen mín: 10%')
    
    -- Auto-repost
    local repost_check = CreateFrame('CheckButton', nil, auto_panel, 'UICheckButtonTemplate')
    repost_check:SetPoint('TOPLEFT', strategy_label, 'BOTTOMLEFT', -25, -10)
    repost_check:SetChecked(true)
    
    local repost_label = auto_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    repost_label:SetPoint('LEFT', repost_check, 'RIGHT', 5, 0)
    repost_label:SetText('|cFF88FF00Auto-repost|r (cada 5 min)')
    
    -- ML Pricing
    local ml_check = CreateFrame('CheckButton', nil, auto_panel, 'UICheckButtonTemplate')
    ml_check:SetPoint('TOPLEFT', repost_check, 'BOTTOMLEFT', 0, -10)
    ml_check:SetChecked(true)
    
    local ml_label = auto_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    ml_label:SetPoint('LEFT', ml_check, 'RIGHT', 5, 0)
    ml_label:SetText('|cFFAA88FFML Pricing|r (ajuste inteligente)')
    
    f.auto_panel = auto_panel
    y_offset = y_offset - 150 -- Aumentado de 130 para más espacio
    
    -- ========================================
    -- NOTIFICACIONES
    -- ========================================
    
    local titulo_notif = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    titulo_notif:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_notif:SetText('|cFFFFFFFF🔔 NOTIFICACIONES|r')
    y_offset = y_offset - 25
    
    local notif_panel = CreateFrame('Frame', nil, content)
    notif_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    notif_panel:SetWidth(content:GetWidth() - 20)
    notif_panel:SetHeight(100)
    
    notif_panel.bg = notif_panel:CreateTexture(nil, 'BACKGROUND')
    notif_panel.bg:SetAllPoints()
    notif_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.6)
    
    -- Alertas
    local alerts_check = CreateFrame('CheckButton', nil, notif_panel, 'UICheckButtonTemplate')
    alerts_check:SetPoint('TOPLEFT', notif_panel, 'TOPLEFT', 10, -10)
    f.alerts_check = alerts_check
    
    local alerts_label = notif_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    alerts_label:SetPoint('LEFT', alerts_check, 'RIGHT', 5, 0)
    alerts_label:SetText('Alertas de oportunidades excepcionales')
    
    -- Sonidos
    local sound_check = CreateFrame('CheckButton', nil, notif_panel, 'UICheckButtonTemplate')
    sound_check:SetPoint('TOPLEFT', alerts_check, 'BOTTOMLEFT', 0, -10)
    f.sound_check = sound_check
    
    local sound_label = notif_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    sound_label:SetPoint('LEFT', sound_check, 'RIGHT', 5, 0)
    sound_label:SetText('Sonidos')
    
    -- Pantalla
    local screen_check = CreateFrame('CheckButton', nil, notif_panel, 'UICheckButtonTemplate')
    screen_check:SetPoint('TOPLEFT', sound_check, 'BOTTOMLEFT', 0, -10)
    f.screen_check = screen_check
    
    local screen_label = notif_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    screen_label:SetPoint('LEFT', screen_check, 'RIGHT', 5, 0)
    screen_label:SetText('Notificaciones en pantalla')
    
    f.notif_panel = notif_panel
    y_offset = y_offset - 130 -- Aumentado de 110 para más espacio
    
    -- ========================================
    -- BOTONES DE ACCIÓN
    -- ========================================
    
    y_offset = y_offset - 10
    
    local btn_save = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
    btn_save:SetWidth(150)
    btn_save:SetHeight(28)
    btn_save:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    btn_save:SetText('|cFF00FF00Guardar Config|r')
    btn_save:SetScript('OnClick', function()
        -- Recopilar configuración de la UI
    local current = M.get_config() or {}
    local new_config = {
        scan = current.scan or {},
            flipping = { enabled = f.flipping_check:GetChecked() },
            sniping = { enabled = f.sniping_check:GetChecked() },
            market_reset = { enabled = f.reset_check:GetChecked() },
            arbitrage = { enabled = f.arbitrage_check:GetChecked() },
            auto_post = { enabled = f.autopost_check:GetChecked() },
            notifications = {
                alerts = f.alerts_check:GetChecked(),
                sound = f.sound_check:GetChecked(),
                screen = f.screen_check:GetChecked()
            },
            -- Mantener valores numéricos del perfil actual (simplificado por ahora)
            max_daily_investment = current.max_daily_investment,
            max_investment_per_item = current.max_investment_per_item,
            max_portfolio_value = current.max_portfolio_value
        }
        
        -- Guardar
    if M.set_config then
        M.set_config(new_config)
    end
end)
    
    local btn_reset = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
    btn_reset:SetWidth(150)
    btn_reset:SetHeight(28)
    btn_reset:SetPoint('LEFT', btn_save, 'RIGHT', 5, 0)
    btn_reset:SetText('Restaurar Defaults')
    btn_reset:SetScript('OnClick', function()
        aplicar_perfil('intermedio')
        M.actualizar_config_ui()
    end)
    
    local btn_export = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
    btn_export:SetWidth(100)
    btn_export:SetHeight(28)
    btn_export:SetPoint('LEFT', btn_reset, 'RIGHT', 5, 0)
    btn_export:SetText('Exportar')
    btn_export:SetScript('OnClick', function()
        if M.export_config then M.export_config() end
    end)
    
    config_frame = f
    return f
end

-- ============================================================================
-- Actualizar Config UI
-- ============================================================================

function M.actualizar_config_ui()
    if not config_frame then return end
    
    local f = config_frame
    local profile = profiles[current_profile]
    
    if not profile then return end
    
    -- Actualizar botones de perfil
    for name, btn in pairs(f.profile_buttons) do
        if name == current_profile then
            btn:SetText('|cFF00FF00>' .. profiles[name].name .. '<|r')
        else
            btn:SetText(profiles[name].name)
        end
    end
    
    -- Actualizar límites (Visual)
    if f.limites_panel and profile then
        f.limites_panel.daily_value:SetText('|cFFFFD700' .. format_gold(profile.config.max_daily_investment) .. '|r')
        f.limites_panel.item_value:SetText('|cFFFFD700' .. format_gold(profile.config.max_investment_per_item) .. '|r')
        f.limites_panel.portfolio_value:SetText('|cFFFFD700' .. format_gold(profile.config.max_portfolio_value) .. '|r')
    end

    -- Actualizar estado de checkboxes desde la config real
    if M.get_config then
        local cfg = M.get_config()
        if cfg then
            if f.flipping_check then f.flipping_check:SetChecked(cfg.flipping and cfg.flipping.enabled) end
            if f.sniping_check then f.sniping_check:SetChecked(cfg.sniping and cfg.sniping.enabled) end
            if f.reset_check then f.reset_check:SetChecked(cfg.market_reset and cfg.market_reset.enabled) end
            if f.arbitrage_check then f.arbitrage_check:SetChecked(cfg.arbitrage and cfg.arbitrage.enabled) end
            if f.autopost_check then f.autopost_check:SetChecked(cfg.auto_post and cfg.auto_post.enabled) end
            
            if cfg.notifications then
                if f.alerts_check then f.alerts_check:SetChecked(cfg.notifications.alerts) end
                if f.sound_check then f.sound_check:SetChecked(cfg.notifications.sound) end
                if f.screen_check then f.screen_check:SetChecked(cfg.notifications.screen) end
            end
        end
    end
end

-- ============================================================================
-- Mostrar/Ocultar Config
-- ============================================================================

function M.mostrar_config()
    if not config_frame then
        aux.print('|cFFFF0000Config UI no inicializado|r')
        return
    end
    
    config_frame:Show()
    M.actualizar_config_ui()
end

function M.ocultar_config()
    if config_frame then
        config_frame:Hide()
    end
end

-- Registrar funciones en el módulo
if not M.modules then M.modules = {} end
if not M.modules.config_ui then M.modules.config_ui = {} end

M.modules.config_ui.crear_config_ui = M.crear_config_ui
M.modules.config_ui.actualizar_config_ui = M.actualizar_config_ui
M.modules.config_ui.mostrar_config = M.mostrar_config
M.modules.config_ui.ocultar_config = M.ocultar_config
M.modules.config_ui.aplicar_perfil = aplicar_perfil

aux.print('|cFF00FF00[CONFIG_UI]|r Panel de configuración listo')
