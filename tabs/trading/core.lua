module 'aux.tabs.trading'

local aux = require 'aux'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
-- NO requerir profiles aquí - mismo módulo
-- NO requerir frame_module aquí para evitar dependencia circular

-- Obtener referencia al módulo actual
local M = getfenv()

-- ============================================================================
-- SISTEMA DE REGISTRO DE MÓDULOS
-- ============================================================================
-- Este sistema permite que cada módulo registre sus funciones públicas
-- para que puedan ser llamadas desde frame.lua sin conflictos de namespace

M.modules = M.modules or {
    dashboard = {},
    market_analysis = {},
    strategies = {},
    automation = {},
    ml_patterns = {},
    optimization = {},
}

-- Cargar módulos de trading después de inicializar M.modules
require 'aux.tabs.trading.strategies'
require 'aux.tabs.trading.scan_integration'
require 'aux.tabs.trading.market_analysis'
require 'aux.tabs.trading.automation'
require 'aux.tabs.trading.ml_patterns'
require 'aux.tabs.trading.optimization'
require 'aux.tabs.trading.notifications'
require 'aux.tabs.trading.dashboard'
require 'aux.tabs.trading.dashboard_ui'
require 'aux.tabs.trading.monopoly'
require 'aux.tabs.trading.monopoly_ui'
require 'aux.tabs.trading.vendor'    -- Nuevo Modulo
require 'aux.tabs.trading.vendor_ui' -- Nueva UI
require 'aux.tabs.trading.config_ui'
require 'aux.tabs.trading.alerts_ui'
require 'aux.tabs.trading.tooltips_advanced'
require 'aux.tabs.trading.search_system'
require 'aux.tabs.trading.filter_system'
require 'aux.tabs.trading.export_system'
require 'aux.tabs.trading.icon_system'
require 'aux.tabs.trading.sort_system'
require 'aux.tabs.trading.backup_system'
require 'aux.tabs.trading.helpers'
-- Módulos TSM-inspired
require 'aux.tabs.trading.auctioning'
require 'aux.tabs.trading.crafting'
require 'aux.tabs.trading.item_tracker'
require 'aux.tabs.trading.auctioning_ui'
require 'aux.tabs.trading.crafting_ui'
require 'aux.tabs.trading.item_tracker_ui'

-- Print para confirmar que el módulo se carga
aux.print('[TRADING] Módulo core.lua cargado correctamente')
aux.print('[TRADING] Sistema de registro de módulos inicializado')

-- Register tab
local tab = aux.tab('Trading')

-- State
local current_scan_id = nil
local opportunities = {}
local is_scanning = false
local scan_stats = {
    total_scanned = 0,
    opportunities_found = 0,
    start_time = 0,
    current_query = 0,
    total_queries = 0,
    current_page = 0,
    total_pages = 0,
}

-- Trade tracking
local active_trades = {}
local trade_history = {}

-- Helper function para formatear dinero (cobre a oro/plata/cobre)
local function format_money(copper)
    return money.to_string(copper, nil, nil, nil, true)
end

-- Exportar format_money para uso externo
M.format_money = format_money

-- Daily investment tracking
local daily_investments = {}

-- ============================================================================
-- Initialization
-- ============================================================================

-- Local storage for trading data (fallback if aux.faction_data doesn't exist)
local trading_data = {
    stats = {
        total_scans = 0,
        total_opportunities_found = 0,
        total_trades = 0,
        successful_trades = 0,
        failed_trades = 0,
        total_profit = 0,
        total_loss = 0,
        success_rate = 0,
        average_profit_per_trade = 0,
        last_scan = 0,
    },
    opportunities = {},
}

local trading_config = {
    scan = {
        min_discount = 0.20,
        max_price = 1000000,
        min_profit = 1000,
        scan_pages = 5,
        auto_buy = false,
        auto_buy_threshold = 0.40,
        max_daily_investment = 1000000,  -- 100g default
        max_investment_per_item = 100000,  -- 10g default
    },
    scoring = {
        weights = {
            discount = 0.30,
            roi = 0.25,
            confidence = 0.20,
            profit = 0.15,
            volatility = 0.10,
        },
        bonuses = {
            low_price = 1.2,
            full_stack = 1.1,
            high_confidence = 1.15,
        },
    },
}

-- Helper functions to access data
local function get_trading_data()
    if aux.faction_data and aux.faction_data.trading then
        return aux.faction_data.trading
    end
    return trading_data
end

-- Merge two tables recursively (defaults + saved)
local function merge_config(defaults, saved)
    if not saved then
        return defaults
    end
    
    local result = {}
    
    -- Copy all defaults
    for key, value in pairs(defaults) do
        if type(value) == 'table' then
            result[key] = merge_config(value, saved[key])
        else
            result[key] = value
        end
    end
    
    -- Override with saved values
    for key, value in pairs(saved) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = merge_config(result[key], value)
        else
            result[key] = value
        end
    end
    
    return result
end

local function get_trading_config()
    if aux.account_data and aux.account_data.trading and aux.account_data.trading.config then
        -- Merge saved config with defaults to ensure all fields exist
        return merge_config(trading_config, aux.account_data.trading.config)
    end
    return trading_config
end

-- Guardar configuración de trading en el almacenamiento de aux
local function save_trading_config(config)
    if not config then return end

    -- Ensure account_data structure exists
    if aux.account_data then
        aux.account_data.trading = aux.account_data.trading or {}
        aux.account_data.trading.config = config
    end

    -- Also persist to faction_data for session-level storage
    if aux.faction_data then
        aux.faction_data.trading = aux.faction_data.trading or {}
        aux.faction_data.trading.config = config
    end

    -- Update runtime defaults merge
    trading_config = merge_config(trading_config, config)

    aux.print('[TRADING] Configuración guardada')
end

-- Export Config Functions
function M.get_config()
    return get_trading_config()
end

function M.set_config(config)
    save_trading_config(config)
end

function M.get_default_config()
    return trading_config
end

aux.handle.LOAD = function()
    -- Try to use aux storage if available, otherwise use local storage
    if aux.faction_data then
        aux.faction_data.trading = aux.faction_data.trading or trading_data
    end
    if aux.account_data then
        aux.account_data.trading = aux.account_data.trading or {config = trading_config}
    end
    
    -- Inicializar trade tracking
    init_trade_tracking()
    
    -- Note: init_database() from profiles.lua se llama via LOAD2 event
end

aux.handle.INIT_UI = function()
    -- Initialize frame
    -- frame_module.init() -- No necesario, el frame se crea al cargar el módulo
end

tab.OPEN = function()
    if M.frame then
        M.frame:Show()
    end
    update_opportunities_display()
    update_stats_display()
end

tab.CLOSE = function()
    if M.frame then
        M.frame:Hide()
    end
    if is_scanning then
        stop_scan()
    end
end

-- ============================================================================
-- Scanning
-- ============================================================================

-- Función para scan rápido (solo 5 páginas)
function start_quick_scan()
    aux.print('[TRADING] Iniciando Scan Rápido...')
    
    if is_scanning then
        aux.print('[TRADING] Ya hay un scan en progreso')
        return false
    end
    
    -- Verificar que estamos en el AH
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000[ERROR]|r Debes estar en la Casa de Subastas para escanear')
        return false
    end
    
    -- Reset state
    opportunities = {}
    scan_stats = {
        total_scanned = 0,
        opportunities_found = 0,
        start_time = time(),
        current_query = 0,
        total_queries = 0,
        current_page = 0,
        total_pages = 0,
    }
    
    is_scanning = true
    
    -- Build queries para scan rápido (solo 5 páginas)
    local queries = build_quick_queries()
    if not queries or getn(queries) == 0 then
        aux.print('|cFFFF0000[ERROR]|r No se pudieron crear queries para el scan')
        is_scanning = false
        return false
    end
    scan_stats.total_queries = getn(queries)
    
    aux.print('[TRADING] Escaneando primeras páginas...')
    
    -- Start scan
    current_scan_id = scan.start({
        type = 'list',
        ignore_owner = true,
        queries = queries,
        on_scan_start = on_scan_start,
        on_page_loaded = on_page_loaded,
        on_auction = on_auction,
        on_complete = on_scan_complete,
        on_abort = on_scan_abort,
    })
    
    if not current_scan_id then
        aux.print('|cFFFF0000[ERROR]|r No se pudo iniciar el scan')
        is_scanning = false
        return false
    end
    
    return true
end

function start_scan()
    aux.print('[TRADING] Iniciando Full Scan...')
    
    if is_scanning then
        aux.print('[TRADING] Ya hay un scan en progreso')
        return false
    end
    
    -- Verificar que estamos en el AH
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000[ERROR]|r Debes estar en la Casa de Subastas para escanear')
        return false
    end
    
    -- Reset state
    opportunities = {}
    scan_stats = {
        total_scanned = 0,
        opportunities_found = 0,
        start_time = time(),
        current_query = 0,
        total_queries = 0,
        current_page = 0,
        total_pages = 0,
    }
    
    is_scanning = true
    
    -- Get config
    local config = get_trading_config()
    
    -- Build queries para items populares
    local queries = build_queries()
    if not queries or getn(queries) == 0 then
        aux.print('|cFFFF0000[ERROR]|r No se pudieron crear queries para el scan')
        is_scanning = false
        return false
    end
    scan_stats.total_queries = getn(queries)
    
    aux.print(string.format('[TRADING] Escaneando %d categorías...', scan_stats.total_queries))
    update_scan_status('Iniciando scan...')
    
    -- Queries creadas correctamente
    
    -- USAR SISTEMA REAL DE AUX.CORE.SCAN (mismo formato que full_scan.lua)
    current_scan_id = scan.start({
        type = 'list',
        ignore_owner = true,  -- Agregar esto como en full_scan.lua
        queries = queries,
            
            on_scan_start = function()
                aux.print('Iniciando scan de oportunidades...')
                update_scan_status('Escaneando...')
                
                -- Limpiar datos para Monopolio
                if M.clear_scan_data then
                    M.clear_scan_data()
                end
            end,
            
            on_start_query = function(query_index)
                scan_stats.current_query = query_index
                update_scan_status(string.format('Query %d/%d', query_index, scan_stats.total_queries))
            end,
            
            on_page_loaded = function(current, total, total_all)
                scan_stats.current_page = current
                scan_stats.total_pages = total
                update_scan_status(string.format('Página %d/%d', current, total))
            end,
            
            on_auction = function(auction_info)
                process_auction(auction_info)
            end,
            
            on_page_scanned = function()
                update_opportunities_display()
            end,
            
            on_complete = function()
                on_scan_complete()
            end,
            
            on_abort = function()
                on_scan_abort()
            end,
            
            auto_buy_validator = config.scan.auto_buy and function(auction_info)
                return should_auto_buy(auction_info)
            end or nil,
        })
    
    -- Update stats
    local stats = get_trading_data().stats
    stats.total_scans = stats.total_scans + 1
    stats.last_scan = time()
    
    return true
end

function stop_scan()
    if not is_scanning then
        return
    end
    
    if current_scan_id then
        scan.abort(current_scan_id)
        current_scan_id = nil
    end
    
    is_scanning = false
    update_scan_status('Detenido')
    aux.print('Scan detenido')
end

-- Función para comprar una oportunidad seleccionada
function buy_opportunity(opportunity)
    if not opportunity then
        aux.print('|cFFFF0000[ERROR]|r No hay oportunidad seleccionada')
        return false
    end
    
    -- Verificar que estamos en el AH
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000[ERROR]|r Debes estar en la Casa de Subastas para comprar')
        return false
    end
    
    -- Verificar que tenemos suficiente oro
    local player_money = GetMoney()
    if player_money < opportunity.buyout then
        aux.print(string.format('|cFFFF0000[ERROR]|r No tienes suficiente oro. Necesitas %s', 
            M.modules.helpers.format_money(opportunity.buyout)))
        return false
    end
    
    -- Intentar comprar usando automation.lua
    if M.modules.automation and M.modules.automation.buy_auction then
        local success = M.modules.automation.buy_auction(opportunity.auction_id)
        if success then
            aux.print(string.format('|cFF00FF00[COMPRA]|r %s por %s', 
                opportunity.item_name,
                M.modules.helpers.format_money(opportunity.buyout)))
            
            -- Registrar la compra
            local trade_record = {
                item_key = opportunity.item_key,
                item_name = opportunity.item_name,
                buy_price = opportunity.buyout,
                quantity = opportunity.count,
                timestamp = time(),
                strategy = opportunity.strategy,
                expected_profit = opportunity.profit,
                status = 'bought',
            }
            
            tinsert(trade_history, trade_record)
            if aux.faction_data and aux.faction_data.trading then
                aux.faction_data.trading.trade_history = trade_history
            end
            
            return true
        else
            aux.print('|cFFFF0000[ERROR]|r No se pudo completar la compra')
            return false
        end
    else
        aux.print('|cFFFF0000[ERROR]|r Módulo de automatización no disponible')
        return false
    end
end

function build_queries()
    local config = get_trading_config()
    local queries = {}
    
    -- Popular materials
    local materials = {
        'Runecloth', 'Mageweave', 'Silk Cloth',
        'Essence', 'Shard', 'Crystal',
        'Thorium', 'Mithril', 'Arcanite',
        'Righteous Orb', 'Flask', 'Elixir',
    }
    
    for i = 1, getn(materials) do
        local name = materials[i]
        tinsert(queries, {
            blizzard_query = {
                name = name,
                first_page = 0,
                last_page = config.scan.scan_pages - 1,
            },
            validator = function(auction_info) return true end,  -- Process all auctions
        })
    end
    
    return queries
end

function process_auction(auction_info)
    -- Validate auction_info
    if not auction_info or not auction_info.item_key then
        return
    end
    
    -- Skip auctions without buyout (solo tienen bid)
    local buyout = auction_info.buyout_price or 0
    if buyout == 0 then
        return
    end
    
    scan_stats.total_scanned = scan_stats.total_scanned + 1
    
    -- Update stats every 50 auctions
    if mod(scan_stats.total_scanned, 50) == 0 then
        update_scan_status(string.format('Escaneadas: %d', scan_stats.total_scanned))
    end
    
    -- Registrar precio en market_analysis (integración con helpers)
    local unit_price = auction_info.unit_buyout_price or auction_info.buyout_price or 0
    local timestamp = time()
    if unit_price > 0 then
        -- Registrar precio en market_analysis
        if M.modules.market_analysis.record_price then
            M.modules.market_analysis.record_price(auction_info.item_key, unit_price, timestamp)
        end
        
        -- Registrar volumen en market_analysis
        if M.modules.market_analysis.record_volume then
            M.modules.market_analysis.record_volume(auction_info.item_key, auction_info.count or 1, timestamp)
        end
        
        if M.modules.ml_patterns and M.modules.ml_patterns.record_price_with_time then
            M.modules.ml_patterns.record_price_with_time(auction_info.item_key, unit_price, timestamp)
        end
    end
    
    -- Alimentar datos a Monopolio
    if M.ingest_auction_record then
        M.ingest_auction_record(auction_info)
    end
    
    -- MODO DEBUG: Agregar TODAS las subastas para verificar que el scan funciona
    -- TODO: Descomentar esto cuando funcione
    -- if not is_opportunity(auction_info) then
    --     return  -- Skip this auction
    -- end
    
    -- Get historical data
    local avg_price = history.value(auction_info.item_key)
    local market_price = history.market_value(auction_info.item_key)
    
    -- Get safe values
    local unit_price = auction_info.unit_buyout_price or auction_info.buyout_price or 0
    local buyout = auction_info.buyout_price or 0
    local count = auction_info.count or 1
    
    -- Si no hay datos históricos, skip esta subasta
    if not avg_price or avg_price == 0 then
        return
    end
    
    -- Prevent division by zero
    if avg_price == 0 then
        return
    end
    
    -- Calculate metrics
    local discount = (avg_price - unit_price) / avg_price
    local profit = (avg_price * 0.95 - unit_price) * count
    -- Prevenir división por cero en ROI
    local roi = buyout > 0 and (profit / buyout) or 0
    
    -- Get or create profile
    local profile = get_profile(auction_info.item_key)
    
    -- Calculate score
    local score = calculate_opportunity_score(auction_info, avg_price, profile)
    
    -- Select best strategy (solo para oportunidades positivas)
    local strategy_info = nil
    if score > 0 and M.strategies and M.strategies.select_best_strategy then
        local market_data = {
            current_price = buyout,
            market_price = avg_price,
            discount = discount,
            profit = profit,
            roi = roi,
            available_quantity = auction_info.count or 1
        }
        strategy_info = M.strategies.select_best_strategy(auction_info.item_key, market_data)
    end
    
    -- Create opportunity
    local opportunity = {
        auction_info = auction_info,
        avg_price = avg_price,
        market_price = market_price,
        discount = discount,
        profit = profit,
        roi = roi,
        score = score,
        strategy = strategy_info,  -- NUEVO: Estrategia recomendada
        confidence = type(profile.confidence) == 'number' and profile.confidence or (type(profile.confidence) == 'table' and profile.confidence.score or 0),
        recommendation = get_recommendation(score, discount, type(profile.confidence) == 'number' and profile.confidence or (type(profile.confidence) == 'table' and profile.confidence.score or 0)),
    }
    
    tinsert(opportunities, opportunity)
    scan_stats.opportunities_found = scan_stats.opportunities_found + 1
    
    -- Update status every 10 opportunities
    if mod(scan_stats.opportunities_found, 10) == 0 then
        update_scan_status(string.format('Oportunidades: %d', scan_stats.opportunities_found))
    end
    
    -- Actualizar la UI cada 10 oportunidades para no sobrecargar
    if mod(scan_stats.opportunities_found, 10) == 0 then
        if M.update_opportunities_display then
            M.update_opportunities_display()
        end
    end
    
    -- Update global stats
    local stats = get_trading_data().stats
    stats.total_opportunities_found = stats.total_opportunities_found + 1
end

function is_opportunity(auction_info)
    local config = get_trading_config()
    
    -- Must have buyout
    if not auction_info.buyout_price or auction_info.buyout_price == 0 then
        return false
    end
    
    -- Check max price
    if auction_info.buyout_price > config.scan.max_price then
        return false
    end
    
    -- Get historical data
    local avg_price = history.value(auction_info.item_key)
    if not avg_price or avg_price == 0 then
        -- Debug: No historical data
        if mod(scan_stats.total_scanned, 50) == 0 then
            aux.print(string.format('Sin datos históricos para: %s', auction_info.name or 'unknown'))
        end
        return false
    end
    
    -- Calculate discount
    local discount = (avg_price - auction_info.unit_buyout_price) / avg_price
    
    -- Check minimum discount
    if discount < config.scan.min_discount then
        return false
    end
    
    -- Calculate profit
    local profit = (avg_price * 0.95 - auction_info.unit_buyout_price) * auction_info.count
    
    -- Check minimum profit
    if profit < config.scan.min_profit then
        return false
    end
    
    return true
end

function calculate_opportunity_score(auction_info, avg_price, profile)
    -- Obtener configuración con valores por defecto
    local scoring_config = {
        discount_weight = 0.4,
        profit_weight = 0.3,
        roi_weight = 0.2,
        confidence_weight = 0.1,
    }
    
    -- Intentar obtener configuración guardada
    local cfg = get_trading_config()
    
    -- Usar valores de configuración si existen
    if cfg and cfg.scoring and cfg.scoring.weights then
        scoring_config.discount_weight = cfg.scoring.weights.discount
        scoring_config.profit_weight = cfg.scoring.weights.profit
        scoring_config.roi_weight = cfg.scoring.weights.roi
        scoring_config.confidence_weight = cfg.scoring.weights.confidence
    end
    
    -- Validate inputs
    if not auction_info or not auction_info.unit_buyout_price or auction_info.unit_buyout_price <= 0 then
        return 0
    end
    
    if not avg_price or avg_price <= 0 then
        return 0
    end
    
    -- Base metrics
    local discount = (avg_price - auction_info.unit_buyout_price) / avg_price
    local profit = (avg_price * 0.95 - auction_info.unit_buyout_price) * auction_info.count
    
    -- Prevenir división por cero en ROI
    local buyout = auction_info.buyout_price or 0
    if buyout == 0 then
        return 0
    end
    local roi = profit / buyout
    
    -- Normalize metrics (-1 to 1, clamped)
    -- Permitimos valores negativos pero limitados a -1.0 para penalizar malas oportunidades
    local discount_norm = math.max(-1.0, math.min(1.0, discount / 0.5))  -- 50% discount = 1.0, -50% = -1.0
    local roi_norm = math.max(-1.0, math.min(1.0, roi / 1.0))  -- 100% ROI = 1.0, -100% = -1.0
    local profit_norm = math.max(-1.0, math.min(1.0, profit / 100000))  -- 100g profit = 1.0, -100g = -1.0
    
    -- Handle confidence (compatible con formato antiguo y nuevo)
    local confidence_norm = 0
    if profile and profile.confidence then
        if type(profile.confidence) == 'number' then
            confidence_norm = profile.confidence
        elseif type(profile.confidence) == 'table' and profile.confidence.score then
            confidence_norm = profile.confidence.score
        end
    end
    
    local volatility_norm = 0.5  -- Default medium volatility
    
    -- Weighted score
    local score = (
        discount_norm * scoring_config.discount_weight +
        roi_norm * scoring_config.roi_weight +
        confidence_norm * scoring_config.confidence_weight +
        profit_norm * scoring_config.profit_weight
    ) * 100
    
    -- Apply simple bonuses (no usar scoring_config.bonuses que no existe)
    if auction_info.buyout_price < 5000 then  -- < 50s
        score = score * 1.1  -- 10% bonus
    end
    
    if auction_info.count >= 20 then  -- Full stack
        score = score * 1.05  -- 5% bonus
    end
    
    -- Usar confidence_norm que ya maneja ambos formatos (number y table)
    if confidence_norm > 0.8 then
        score = score * 1.15  -- 15% bonus
    end
    
    -- Ensure score is not negative (clamp to 0)
    score = math.max(0, score)
    
    return score
end

function get_recommendation(score, discount, confidence)
    if score >= 80 and discount >= 0.30 and confidence >= 0.7 then
        return 'strong_buy'
    elseif score >= 60 and discount >= 0.20 then
        return 'buy'
    elseif score >= 40 then
        return 'watch'
    else
        return 'skip'
    end
end

function should_auto_buy(auction_info)
    local config = get_trading_config()
    
    -- Get historical data
    local avg_price = history.value(auction_info.item_key)
    if not avg_price or avg_price == 0 then
        return false
    end
    
    -- Verificar que unit_buyout_price existe
    if not auction_info.unit_buyout_price or auction_info.unit_buyout_price == 0 then
        return false
    end
    
    -- Calculate discount
    local discount = (avg_price - auction_info.unit_buyout_price) / avg_price
    
    -- Check threshold (ahora config.scan.auto_buy_threshold siempre existe gracias al merge)
    if discount < config.scan.auto_buy_threshold then
        return false
    end
    
    -- Get profile (profiles está en el mismo módulo)
    local profile = M.get_profile(auction_info.item_key)
    
    -- Check confidence
    local conf_value = type(profile.confidence) == 'number' and profile.confidence or (type(profile.confidence) == 'table' and profile.confidence.score or 0)
    if conf_value < 0.6 then
        return false  -- Not confident enough
    end
    
    -- Check volatility (only if price_analysis exists and has enough data)
    if profile and profile.price_analysis and profile.price_analysis.volatility and profile.sample_count and profile.sample_count >= 5 then
        if profile.price_analysis.volatility > 0.3 then
            return false  -- Too volatile
        end
    end
    
    -- Additional safety checks
    local buyout_price = auction_info.buyout_price or 0
    if buyout_price > (config.scan.max_price or 100000) then
        return false  -- Too expensive
    end
    
    local profit = (avg_price * 0.95 - auction_info.unit_buyout_price) * auction_info.count
    if profit < (config.scan.min_profit or 1000) then
        return false  -- Profit too low
    end
    
    return true
end

function get_daily_investment(date_key)
    return daily_investments[date_key] or 0
end

function update_daily_investment(date_key, amount)
    daily_investments[date_key] = (daily_investments[date_key] or 0) + amount
    
    -- Clean up old entries (keep only last 30 days)
    local current_time = time()
    local cutoff_time = current_time - (30 * 24 * 60 * 60)
    
    for key, _ in pairs(daily_investments) do
        -- Parse date key format: YYYY-MM-DD using string.find (Lua 5.0 compatible)
        local _, _, year, month, day = string.find(key, '(%d+)-(%d+)-(%d+)')
        if year and month and day then
            local entry_time = time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
            if entry_time < cutoff_time then
                daily_investments[key] = nil
            end
        end
    end
end

function on_scan_complete()
    is_scanning = false
    current_scan_id = nil
    
    local duration = time() - scan_stats.start_time
    
    aux.print(string.format(
        'Scan completado: %d subastas escaneadas, %d oportunidades encontradas en %d segundos',
        scan_stats.total_scanned,
        scan_stats.opportunities_found,
        duration
    ))
    
    -- Update global stats
    local stats = get_trading_data().stats
    stats.total_scans = (stats.total_scans or 0) + 1
    stats.last_scan = time()
    
    -- Sort opportunities by score
    table.sort(opportunities, function(a, b)
        return a.score > b.score
    end)
    
    update_opportunities_display()
    update_scan_status('Completado')
    
    -- Update stats display if function exists
    if update_stats_display then
        update_stats_display()
    end
end

function on_scan_abort()
    is_scanning = false
    current_scan_id = nil
    
    aux.print('Scan abortado')
    update_scan_status('Abortado')
end

-- ============================================================================
-- Build Queries
-- ============================================================================

function build_queries()
    -- Crear queries para escanear items populares
    -- Formato correcto según aux.util.filter.queries()
    
    local queries = {}
    
    -- Query 1: Escanear todo (sin filtro)
    -- Debe tener: blizzard_query, validator, prettified
    tinsert(queries, {
        blizzard_query = {
            name = '',  -- Filtro vacío = escanea todo
            first_page = 0,
            -- NO especificar last_page para escanear todo
        },
        validator = function(auction_record)
            -- Aceptar todas las subastas
            return true
        end,
        prettified = '<>'  -- Formato para "sin filtro"
    })
    
    return queries
end

-- Función para crear queries de scan rápido (solo primeras 5 páginas)
function build_quick_queries()
    local queries = {}
    
    -- Query para scan rápido: solo primeras 5 páginas (250 subastas)
    tinsert(queries, {
        blizzard_query = {
            name = '',  -- Filtro vacío = escanea todo
            first_page = 0,
            last_page = 4,  -- Solo 5 páginas (0-4)
        },
        validator = function(auction_record)
            return true
        end,
        prettified = '<>',
    })
    
    return queries
end

-- ============================================================================
-- UI Updates
-- ============================================================================

function update_opportunities_display()
    -- Llamar a la función update_opportunities del módulo si existe
    if M.update_opportunities then
        M.update_opportunities()
    end
end

function update_stats_display()
    -- Por ahora no hace nada, se puede implementar después
end

function update_scan_status(status)
    -- Acceder al frame directamente desde el módulo global
    if frame and frame.opportunities then
        if frame.opportunities.update_status then
            frame.opportunities.update_status(status)
        end
        if frame.opportunities.update_progress then
            frame.opportunities.update_progress()
        end
    end
end

-- ============================================================================
-- Actions
-- ============================================================================

function buy_opportunity(opportunity)
    if not opportunity or not opportunity.auction_info then
        aux.print('|cFFFF0000Error: Oportunidad inválida|r')
        return false
    end
    
    local auction_info = opportunity.auction_info
    
    if not auction_info.buyout_price or auction_info.buyout_price <= 0 then
        aux.print('|cFFFF0000Error: Información de subasta incompleta|r')
        return false
    end
    
    -- Risk management checks
    local config = get_trading_config()
    local buyout_price = auction_info.buyout_price
    
    -- Check daily investment limit
    local today = date('*t', time())
    local today_key = string.format('%d-%d-%d', today.year, today.month, today.day)
    local daily_investment = get_daily_investment(today_key)
    
    if daily_investment + buyout_price > (config.scan.max_daily_investment or 1000000) then
        aux.print('|cFFFF0000Error: Límite diario de inversión excedido|r')
        return false
    end
    
    -- Check per-item investment limit
    if buyout_price > (config.scan.max_investment_per_item or 100000) then
        aux.print('|cFFFF0000Error: Precio demasiado alto para esta oportunidad|r')
        return false
    end
    
    -- Check available gold
    local player_gold = GetMoney()
    if player_gold < buyout_price then
        aux.print('|cFFFF0000Error: No tienes suficiente oro|r')
        return false
    end
    
    -- Check if aux is already buying something
    if aux.bid_in_progress and aux.bid_in_progress() then
        aux.print('|cFFFFFF00Esperando... hay una compra en progreso|r')
        return false
    end
    
    -- Format money for display
    local copper = auction_info.buyout_price
    local gold = floor(copper / 10000)
    local silver = floor(mod(copper, 10000) / 100)
    local copper_left = mod(copper, 100)
    local money_str = string.format('%dg %ds %dc', gold, silver, copper_left)
    
    -- Store opportunity reference for removal after purchase
    local opp_to_remove = opportunity
    
    -- Use aux's scan system to find and buy the item
    -- This searches for the exact item and buys it when found
    local item_name = auction_info.name
    local target_buyout = auction_info.buyout_price
    local target_count = auction_info.count or 1
    
    aux.print(string.format(
        '|cFFFFFF00Buscando:|r %s x%d por %s...',
        item_name or 'Unknown',
        target_count,
        money_str
    ))
    
    -- Start a scan to find and buy this specific auction
    local scan = require 'aux.core.scan'
    
    scan.start({
        type = 'list',
        ignore_owner = true,
        queries = {
            {
                blizzard_query = {
                    name = item_name,
                },
                validator = function(record)
                    -- Match exact buyout price and stack size
                    return record.buyout_price == target_buyout 
                        and record.count == target_count
                        and record.owner ~= UnitName('player')
                end
            }
        },
        on_auction = function(record)
            -- Found the auction, now buy it
            if record and record.index and record.buyout_price > 0 then
                aux.place_bid('list', record.index, record.buyout_price, function()
                    -- Success callback
                    aux.print(string.format(
                        '|cFF00FF00Comprado:|r %s x%d por %s (%.0f%% descuento)',
                        item_name or 'Unknown',
                        target_count,
                        money_str,
                        (opportunity.discount or 0) * 100
                    ))
                    
                    -- Record purchase
                    record_purchase(auction_info)
                    
                    -- Update daily investment
                    update_daily_investment(today_key, buyout_price)
                    
                    -- Remove from opportunities list
                    for i = 1, getn(opportunities) do
                        if opportunities[i] == opp_to_remove then
                            tremove(opportunities, i)
                            break
                        end
                    end
                    
                    update_opportunities_display()
                end)
                
                -- Stop scanning after finding the item
                scan.stop()
            end
        end,
        on_complete = function()
            -- Scan finished
        end,
        on_abort = function()
            aux.print('|cFFFF0000Búsqueda cancelada|r')
        end
    })
    
    return true
end

function place_bid(auction_info)
    if not auction_info then
        aux.print('|cFFFF0000Error: Información de subasta inválida|r')
        return
    end
    
    -- Check if AH is open
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000Error: Debes tener la Casa de Subastas abierta|r')
        return
    end
    
    -- Check if we have page and index from scan
    if not auction_info.page or not auction_info.index then
        aux.print('|cFFFF0000Error: Información de página/índice no disponible. Haz un nuevo scan.|r')
        return
    end
    
    -- Get current page
    local current_page = AuctionFrameBrowse.page or 0
    
    -- If we're not on the right page, we need to navigate there
    if current_page ~= auction_info.page then
        aux.print(string.format('Cambiando a página %d para comprar...', auction_info.page + 1))
        AuctionFrameBrowse.page = auction_info.page
        AuctionFrameBrowse_Update()
    end
    
    -- Verify the auction still exists at the expected index
    local num_auctions = GetNumAuctionItems('list')
    if auction_info.index > num_auctions then
        aux.print('|cFFFF0000Error: La subasta ya no existe. Intenta hacer un nuevo scan.|r')
        return
    end
    
    -- Get auction info at the expected index
    local name, _, count, _, _, _, _, _, buyout, _, _, _, _, _ = GetAuctionItemInfo('list', auction_info.index)
    
    -- Verify this is still the same auction
    if name ~= auction_info.item_name or count ~= auction_info.count or buyout ~= auction_info.buyout_price then
        aux.print('|cFFFF0000Error: La subasta ha cambiado. Intenta hacer un nuevo scan.|r')
        return
    end
    
    -- Get current page
    local current_page = AuctionFrameBrowse.page or 0
    
    -- If we're not on the right page, we need to navigate there
    if current_page ~= auction_info.page then
        aux.print(string.format('Cambiando a página %d para hacer bid...', auction_info.page + 1))
        AuctionFrameBrowse.page = auction_info.page
        -- Trigger page change
        AuctionFrameBrowse_Update()
        -- Wait a bit for the page to load
        -- Note: In a real implementation, we'd need to wait for the page to load
        -- For now, we'll assume the page change is instant
    end
    
    -- Verify the auction still exists at the expected index
    local num_auctions = GetNumAuctionItems('list')
    if auction_info.index > num_auctions then
        aux.print('|cFFFF0000Error: La subasta ya no existe en el índice esperado. Intenta hacer un nuevo scan.|r')
        return
    end
    
    -- Get auction info at the expected index
    local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bidAmount, highBidder, owner, saleStatus = GetAuctionItemInfo('list', auction_info.index)
    
    -- Verify this is still the same auction (basic check)
    if name ~= auction_info.item_name or count ~= auction_info.count or buyout ~= auction_info.buyout_price then
        aux.print('|cFFFF0000Error: La subasta ha cambiado. Intenta hacer un nuevo scan.|r')
        return
    end
    
    -- Calculate bid price
    local bid_price
    if bidAmount and bidAmount > 0 then
        -- There are existing bids, bid at least minIncrement more
        bid_price = bidAmount + minIncrement
    else
        -- No existing bids, bid at minBid
        bid_price = minBid
    end
    
    if not bid_price or bid_price == 0 then
        aux.print('|cFFFF0000Error: No se pudo calcular el precio de bid|r')
        return
    end
    
    -- Check if we have enough money
    if GetMoney() < bid_price then
        aux.print('|cFFFF0000Error: No tienes suficiente oro para hacer esta oferta|r')
        return
    end
    
    -- Format money for display
    local gold = floor(bid_price / 10000)
    local silver = floor(mod(bid_price, 10000) / 100)
    local copper = mod(bid_price, 100)
    local money_str = string.format('%dg %ds %dc', gold, silver, copper)
    
    aux.print(string.format('|cFFFFFF00Haciendo oferta de %s por %s x%d|r', money_str, name or 'Unknown', count or 1))
    
    -- Place the bid
    PlaceAuctionBid('list', auction_info.index, bid_price)
    
    -- Record the bid attempt
    record_bid_attempt(auction_info, bid_price)
end

function place_buyout(auction_info)
    -- For buyout, we can reuse the buy_opportunity logic but call it with a mock opportunity
    local mock_opportunity = {
        auction_info = auction_info,
        discount = 0,  -- We don't have this info for direct buyout
    }
    buy_opportunity(mock_opportunity)
end

function record_bid_attempt(auction_info, bid_price)
    -- Record the bid in trade history
    local trade = {
        id = 'bid_' .. time() .. '_' .. random(1000),
        item_key = auction_info.item_key,
        item_name = auction_info.item_name,
        count = auction_info.count,
        bid_price = bid_price,
        timestamp = time(),
        type = 'bid',
    }
    
    -- Add to active trades
    tinsert(active_trades, trade)
    
    -- Update stats
    local stats = get_trading_data().stats
    stats.total_trades = (stats.total_trades or 0) + 1
end

-- ============================================================================
-- Trade Tracking System
-- ============================================================================

function init_trade_tracking()
    if not aux.faction_data then
        return
    end
    
    if not aux.faction_data.trading then
        aux.faction_data.trading = {}
    end
    
    if not aux.faction_data.trading.active_trades then
        aux.faction_data.trading.active_trades = {}
    end
    
    if not aux.faction_data.trading.trade_history then
        aux.faction_data.trading.trade_history = {}
    end
    
    active_trades = aux.faction_data.trading.active_trades
    
    -- Inicializar subsistemas de trading
    if M.init_price_history then 
        M.init_price_history() 
        aux.print('[TRADING] Price history initialized')
    end
    
    if M.init_time_patterns then 
        M.init_time_patterns() 
        aux.print('[TRADING] Time patterns initialized')
    end
    
    if M.init_auto_post_config then 
        M.init_auto_post_config() 
        aux.print('[TRADING] Auto-post config initialized')
    end
    
    if M.init_repost_system then 
        M.init_repost_system() 
        aux.print('[TRADING] Repost system initialized')
    end
    
    if M.init_item_classifications then 
        M.init_item_classifications() 
        aux.print('[TRADING] Item classifications initialized')
    end

    trade_history = aux.faction_data.trading.trade_history
end

-- Registrar compra de item
function record_purchase(auction_info)
    if not auction_info then
        return
    end
    
    -- Usar el módulo accounting para registrar
    local accounting = require 'aux.tabs.trading.accounting'
    local item_key = auction_info.item_key or 'unknown'
    local price = auction_info.unit_buyout_price or (auction_info.buyout_price and auction_info.count and auction_info.buyout_price / auction_info.count) or 0
    local quantity = auction_info.count or 1
    local seller = auction_info.owner or 'Desconocido'
    
    -- Llamar al módulo accounting
    if accounting and accounting.record_purchase then
        accounting.record_purchase(item_key, price, quantity, seller)
    end
    
    -- También guardar en active_trades para tracking interno
    if not auction_info.item_key then
        return
    end
    
    local trade_id = string.format('%s_%d', auction_info.item_key, time())
    local item_key = auction_info.item_key
    local item_name = auction_info.name or 'Unknown'
    local count = auction_info.count or 1
    local buy_price = auction_info.buyout_price or auction_info.bid_price or 0
    local unit_price = auction_info.unit_buyout_price or (buy_price / count)
    
    local trade = {
        id = trade_id,
        item_key = item_key,
        item_name = item_name,
        item_link = auction_info.link,
        count = count,
        buy_price = buy_price,
        unit_buy_price = unit_price,
        purchased_at = time(),
        status = 'active', -- active, posted, sold, expired
        expected_sell_price = 0,
        actual_sell_price = 0,
        profit = 0,
        roi = 0,
        posted_at = nil,
        sold_at = nil,
        expired_at = nil,
    }
    
    -- Calcular precio de venta esperado (basado en market value)
    if history and history.market_value then
        local market_value = history.market_value(item_key)
        if market_value and market_value > 0 then
            trade.expected_sell_price = market_value * 0.95 -- Después de AH cut
        end
    end
    
    -- Guardar trade en active_trades
    active_trades[trade_id] = trade
    
    -- El módulo accounting ya guardó en AuxTradingAccounting
    aux.print(string.format('[TRADE] Compra registrada: %s x%d', item_name, count))
end

-- Registrar cuando posteamos un item
function record_post(item_key, count, price)
    -- Buscar trade activo que coincida
    for trade_id, trade in pairs(active_trades) do
        if trade.item_key == item_key and trade.status == 'active' and trade.count == count then
            trade.status = 'posted'
            trade.posted_at = time()
            trade.actual_sell_price = price
            
            aux.print(string.format('[TRADE] Post registrado: %s x%d por %d copper', 
                trade.item_name, trade.count, price))
            return
        end
    end
end

-- Registrar cuando se vende un item
function record_sale(item_key, count, price)
    local item_name = item_key
    local unit_price = price / (count > 0 and count or 1)
    
    -- Usar el módulo accounting para registrar
    local accounting = require 'aux.tabs.trading.accounting'
    if accounting and accounting.record_sale then
        accounting.record_sale(item_key, unit_price, count, 'Comprador')
    end
    
    -- Buscar trade posteado que coincida
    for trade_id, trade in pairs(active_trades) do
        if trade.item_key == item_key and trade.status == 'posted' and trade.count == count then
            trade.status = 'sold'
            trade.sold_at = time()
            trade.actual_sell_price = price
            item_name = trade.item_name
            
            -- Calcular profit y ROI
            trade.profit = trade.actual_sell_price - trade.buy_price
            if trade.buy_price > 0 then
                trade.roi = trade.profit / trade.buy_price
            end
            
            -- Mover a historial
            tinsert(trade_history, trade)
            active_trades[trade_id] = nil
            
            -- Actualizar estadísticas del dashboard
            if M.modules.dashboard and M.modules.dashboard.update_stats_on_trade then
                M.modules.dashboard.update_stats_on_trade(trade)
            end
            
            aux.print(string.format('[TRADE] Venta completada: %s x%d | Profit: %d copper (%.1f%% ROI)', 
                trade.item_name, trade.count, trade.profit, trade.roi * 100))
            break
        end
    end
    
    -- Ya no necesitamos guardar aquí porque accounting.record_sale lo hace
    -- Pero mantenemos el mensaje de log
    aux.print(string.format('[TRADE] Venta registrada en historial: %s x%d', item_name, count))
end

-- Registrar cuando expira un item
function record_expiration(item_key, count)
    -- Buscar trade posteado que coincida
    for trade_id, trade in pairs(active_trades) do
        if trade.item_key == item_key and trade.status == 'posted' and trade.count == count then
            trade.status = 'expired'
            trade.expired_at = time()
            
            -- Volver a estado activo para repostear
            trade.status = 'active'
            trade.posted_at = nil
            
            aux.print(string.format('[TRADE] Expiración registrada: %s x%d (listo para repostear)', 
                trade.item_name, trade.count))
            return
        end
    end
end

-- Obtener trades activos
function get_active_trades()
    local trades = {}
    for _, trade in pairs(active_trades) do
        tinsert(trades, trade)
    end
    return trades
end

-- Obtener historial de trades
function get_trade_history(limit)
    limit = limit or 50
    local history = {}
    local count = 0
    
    -- Obtener los últimos N trades
    for i = getn(trade_history), 1, -1 do
        if count >= limit then
            break
        end
        tinsert(history, trade_history[i])
        count = count + 1
    end
    
    return history
end

-- Limpiar trades antiguos (más de 30 días)
function cleanup_old_trades()
    local current_time = time()
    local thirty_days = 30 * 24 * 60 * 60
    local cleaned = 0
    
    -- Limpiar historial
    local new_history = {}
    for _, trade in ipairs(trade_history) do
        if current_time - (trade.sold_at or trade.expired_at or 0) < thirty_days then
            tinsert(new_history, trade)
        else
            cleaned = cleaned + 1
        end
    end
    
    trade_history = new_history
    if aux.faction_data and aux.faction_data.trading then
        aux.faction_data.trading.trade_history = new_history
    end
    
    if cleaned > 0 then
        aux.print(string.format('[TRADE] Limpiados %d trades antiguos', cleaned))
    end
end

-- ============================================================================
-- Exports for frame.lua
-- ============================================================================
-- Las funciones start_scan, stop_scan, etc. ya están en el módulo porque
-- fueron definidas sin 'local'. Solo necesitamos exportar las funciones
-- que acceden a variables locales.

get_opportunities = function() return opportunities end
get_scan_stats = function() return scan_stats end
is_scanning_func = function() return is_scanning end
get_trading_data = get_trading_data
get_trading_config = get_trading_config

-- ============================================================================
-- REGISTRO DE FUNCIONES PÚBLICAS DEL CORE
-- ============================================================================
-- Registrar funciones principales para que frame.lua pueda acceder a ellas

M.modules.core = {
    -- Scan functions
    start_scan = start_scan,
    stop_scan = stop_scan,
    is_scanning = is_scanning_func,
    get_scan_stats = get_scan_stats,
    
    -- Opportunities
    get_opportunities = get_opportunities,
    buy_opportunity = buy_opportunity,
    
    -- Bid/Buyout
    place_bid = place_bid,
    place_buyout = place_buyout,
    
    -- Config
    get_trading_data = get_trading_data,
    get_trading_config = get_trading_config,
    save_trading_config = save_trading_config,
    
    -- Trade tracking
    get_active_trades = get_active_trades,
    get_trade_history = get_trade_history,
    record_purchase = record_purchase,
    record_post = record_post,
    record_sale = record_sale,
    record_expiration = record_expiration,
    cleanup_old_trades = cleanup_old_trades,
}

-- Also register directly on M for backward compatibility
M.place_bid = place_bid
M.place_buyout = place_buyout
M.buy_opportunity = buy_opportunity
M.save_trading_config = save_trading_config

-- Export scan functions for frame.lua
M.start_scan = start_scan
M.start_quick_scan = start_quick_scan
M.stop_scan = stop_scan
M.get_opportunities = get_opportunities
M.get_scan_stats = get_scan_stats
M.is_scanning = is_scanning_func
M.buy_opportunity = buy_opportunity

-- Simple cache clearing function
function clear_cache()
    aux.print('Limpiando cache del sistema de trading...')
    -- Clear opportunities
    opportunities = {}
    -- Clear scan stats
    scan_stats = {
        total_scanned = 0,
        opportunities_found = 0,
        start_time = 0,
        current_query = 0,
        total_queries = 0,
        current_page = 0,
        total_pages = 0,
    }
    -- Clear daily investments (keep only current day)
    local today = date('*t', time())
    local today_key = string.format('%d-%d-%d', today.year, today.month, today.day)
    local current_investment = daily_investments[today_key] or 0
    daily_investments = {}
    daily_investments[today_key] = current_investment
    
    aux.print('Cache limpiado exitosamente')
end

M.clear_cache = clear_cache

aux.print('[TRADING] Funciones del core registradas en M.modules.core')

-- ============================================================================
-- COMANDOS DE CONSOLA
-- ============================================================================

-- Comando para ejecutar tests
SlashCmdList['AUXTEST'] = function(msg)
    if M.modules and M.modules.testing then
        aux.print('[TRADING] Ejecutando tests del sistema...')
        M.modules.testing.run_all_tests()
    else
        aux.print('[TRADING] Módulo de testing no disponible')
    end
end
SLASH_AUXTEST1 = '/auxtest'

-- Comando para mostrar estadísticas
SlashCmdList['AUXSTATS'] = function(msg)
    if M.modules and M.modules.dashboard then
        local stats = M.modules.dashboard.get_stats()
        aux.print('[TRADING] ===== ESTADÍSTICAS =====')
        aux.print('[TRADING] Total Profit: ' .. (stats.total_profit or 0) .. ' copper')
        aux.print('[TRADING] Total Trades: ' .. (stats.total_trades or 0))
        aux.print('[TRADING] Success Rate: ' .. string.format('%.1f%%', stats.success_rate or 0))
        aux.print('[TRADING] Avg ROI: ' .. string.format('%.1f%%', stats.avg_roi or 0))
    else
        aux.print('[TRADING] Dashboard no disponible')
    end
end
SLASH_AUXSTATS1 = '/auxstats'

-- Comando para limpiar datos antiguos
SlashCmdList['AUXCLEANUP'] = function(msg)
    if M.modules and M.modules.optimization then
        aux.print('[TRADING] Ejecutando limpieza de datos...')
        M.modules.optimization.cleanup_old_data()
        M.modules.optimization.compress_historical_data()
        collectgarbage('collect')
        aux.print('[TRADING] Limpieza completada')
    else
        aux.print('[TRADING] Módulo de optimización no disponible')
    end
end
SLASH_AUXCLEANUP1 = '/auxcleanup'

aux.print('[TRADING] Comandos de consola registrados: /auxtest, /auxstats, /auxcleanup')

-- ============================================================================
-- INTEGRACIÓN CON SCAN_INTEGRATION.LUA
-- ============================================================================

-- Comando para escanear con el nuevo sistema
SlashCmdList['AUXSCAN'] = function(msg)
    if M.scan_for_opportunities then
        aux.print('[TRADING] Iniciando scan con sistema de integración...')
        start_scan()
    else
        aux.print('[TRADING] Sistema de scan_integration no disponible')
    end
end
SLASH_AUXSCAN1 = '/auxscan'

-- Comando para detectar undercuts
SlashCmdList['AUXUNDERCUT'] = function(msg)
    if M.check_for_undercuts then
        aux.print('[TRADING] Detectando undercuts...')
        M.check_for_undercuts(function(result)
            if result.success then
                if result.count > 0 then
                    aux.print(string.format('|cFFFF0000¡Te hicieron undercut en %d items!|r', result.count))
                    for i = 1, min(5, result.count) do
                        local u = result.undercuts[i]
                        aux.print(string.format('  %s: Tu precio %s vs Competencia %s', 
                            u.item_name,
                            M.format_money(u.our_price),
                            M.format_money(u.competitor_price)))
                    end
                else
                    aux.print('|cFF00FF00No hay undercuts|r')
                end
            else
                aux.print('|cFFFF0000Error al detectar undercuts|r')
            end
        end)
    else
        aux.print('[TRADING] Sistema de detección de undercuts no disponible')
    end
end
SLASH_AUXUNDERCUT1 = '/auxundercut'

aux.print('[TRADING] Comandos adicionales: /auxscan, /auxundercut')

-- ============================================================================
-- SNIPER SYSTEM
-- ============================================================================

local sniper_state = {
    running = false,
    items_scanned = 0,
    deals_found = 0,
    scan_id = nil,
}

local sniper_deals = {}
local sniper_config = {
    min_profit_percent = 30,  -- Minimo 30% de ganancia
    max_price = 1000000,      -- Maximo 100g
    scan_interval = 0.5,      -- Intervalo entre scans
    sound_alert = true,       -- Sonido al encontrar deal
}

-- Obtener estado del sniper
function get_sniper_state()
    return sniper_state
end

-- Obtener deals encontrados
function get_sniper_deals()
    return sniper_deals
end

-- Verificar si el sniper esta corriendo
function is_sniper_running()
    return sniper_state.running
end

-- Toggle sniper on/off
function toggle_sniper()
    if sniper_state.running then
        stop_sniper()
    else
        start_sniper()
    end
end

-- Iniciar sniper
function start_sniper()
    if sniper_state.running then
        aux.print('|cFFFFFF00[SNIPER]|r Ya esta corriendo')
        return
    end
    
    -- Verificar que estamos en la AH
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        aux.print('|cFFFF0000[SNIPER]|r Debes estar en la Casa de Subastas')
        return
    end
    
    sniper_state.running = true
    sniper_state.items_scanned = 0
    sniper_state.deals_found = 0
    sniper_deals = {}
    
    aux.print('|cFF00FF00=== SNIPER MODE ACTIVADO ===|r')
    aux.print(string.format('|cFF00FF00Config:|r Min %d%% ganancia, Min 50s profit', sniper_config.min_profit_percent))
    aux.print('|cFF00FF00Buscando deals en la AH...|r')
    
    -- Iniciar scan continuo
    run_sniper_scan()
end

-- Detener sniper
function stop_sniper()
    sniper_state.running = false
    
    -- Abortar scan si hay uno activo
    if sniper_state.scan_id then
        local scan = require 'aux.core.scan'
        scan.abort(sniper_state.scan_id)
        sniper_state.scan_id = nil
    end
    
    aux.print('|cFFFF0000[SNIPER]|r Detenido')
    aux.print(string.format('|cFFFFFF00Resumen:|r Escaneados: %d, Deals encontrados: %d', 
        sniper_state.items_scanned, sniper_state.deals_found))
end

-- Ejecutar un ciclo de scan del sniper
function run_sniper_scan()
    if not sniper_state.running then return end
    
    local scan = require 'aux.core.scan'
    local history = require 'aux.core.history'
    
    -- Scan de la ultima pagina (donde aparecen los items nuevos)
    sniper_state.scan_id = scan.start({
        type = 'list',
        ignore_owner = true,
        queries = {
            {
                blizzard_query = {
                    first_page = 0,
                    last_page = 0,  -- Solo primera pagina (items mas recientes)
                },
            }
        },
        on_auction = function(auction_info)
            if not sniper_state.running then return end
            
            sniper_state.items_scanned = sniper_state.items_scanned + 1
            
            -- Solo items con buyout
            if not auction_info.buyout_price or auction_info.buyout_price <= 0 then
                return
            end
            
            -- Verificar precio maximo
            if auction_info.buyout_price > sniper_config.max_price then
                return
            end
            
            -- Obtener valor de mercado
            local item_key = auction_info.item_key or (auction_info.item_id .. ':' .. (auction_info.suffix_id or 0))
            local market_value = history.value(item_key)
            
            if not market_value or market_value <= 0 then
                return
            end
            
            -- Calcular ganancia potencial
            local unit_buyout = auction_info.buyout_price / (auction_info.count or 1)
            local unit_market = market_value
            local profit = unit_market - unit_buyout
            local profit_percent = (profit / unit_buyout) * 100
            
            -- Verificar si cumple criterios
            if profit_percent >= sniper_config.min_profit_percent and profit >= 5000 then  -- Min 50s profit
                -- Es un deal!
                local deal = {
                    item_id = auction_info.item_id,
                    item_name = auction_info.name,
                    item_key = item_key,
                    count = auction_info.count or 1,
                    buyout_price = auction_info.buyout_price,
                    market_value = market_value * (auction_info.count or 1),
                    profit = profit * (auction_info.count or 1),
                    percent_below = math.floor(profit_percent),
                    auction_info = auction_info,
                    found_at = time(),
                }
                
                -- Agregar a la lista (maximo 20 deals)
                tinsert(sniper_deals, 1, deal)  -- Insertar al inicio
                if getn(sniper_deals) > 20 then
                    tremove(sniper_deals)  -- Remover el mas viejo
                end
                
                sniper_state.deals_found = sniper_state.deals_found + 1
                
                -- Notificar
                aux.print(string.format(
                    '|cFF00FF00[SNIPER DEAL]|r %s x%d - %s (-%d%% = +%s)',
                    auction_info.name or 'Unknown',
                    auction_info.count or 1,
                    format_money(auction_info.buyout_price),
                    math.floor(profit_percent),
                    format_money(profit * (auction_info.count or 1))
                ))
                
                -- Sonido de alerta
                if sniper_config.sound_alert then
                    PlaySound('LEVELUPSOUND')
                end
                
                -- Actualizar UI
                if M.update_sniper_ui then
                    M.update_sniper_ui()
                end
            end
        end,
        on_complete = function()
            sniper_state.scan_id = nil
            
            -- Actualizar UI
            if M.update_sniper_ui then
                M.update_sniper_ui()
            end
            
            -- Continuar escaneando si sigue activo
            if sniper_state.running then
                -- Esperar un poco antes del siguiente scan
                local timer_frame = CreateFrame('Frame')
                local elapsed = 0
                timer_frame:SetScript('OnUpdate', function()
                    elapsed = elapsed + arg1
                    if elapsed >= sniper_config.scan_interval then
                        timer_frame:SetScript('OnUpdate', nil)
                        run_sniper_scan()
                    end
                end)
            end
        end,
        on_abort = function()
            sniper_state.scan_id = nil
        end
    })
end

-- Comprar un deal del sniper
function buy_sniper_deal(deal)
    if not deal or not deal.auction_info then
        aux.print('|cFFFF0000[SNIPER]|r Deal invalido')
        return false
    end
    
    -- Verificar oro
    if GetMoney() < deal.buyout_price then
        aux.print('|cFFFF0000[SNIPER]|r No tienes suficiente oro')
        return false
    end
    
    -- Verificar si aux esta comprando algo
    if aux.bid_in_progress and aux.bid_in_progress() then
        aux.print('|cFFFFFF00[SNIPER]|r Esperando... hay una compra en progreso')
        return false
    end
    
    local auction_info = deal.auction_info
    local scan = require 'aux.core.scan'
    
    aux.print(string.format(
        '|cFFFFFF00[SNIPER]|r Buscando %s para comprar...',
        deal.item_name or 'Unknown'
    ))
    
    -- Buscar y comprar el item
    scan.start({
        type = 'list',
        ignore_owner = true,
        queries = {
            {
                blizzard_query = {
                    name = deal.item_name,
                },
                validator = function(record)
                    return record.buyout_price == deal.buyout_price 
                        and record.count == deal.count
                        and record.owner ~= UnitName('player')
                end
            }
        },
        on_auction = function(record)
            if record and record.index and record.buyout_price > 0 then
                aux.place_bid('list', record.index, record.buyout_price, function()
                    aux.print(string.format(
                        '|cFF00FF00[SNIPER]|r Comprado: %s x%d por %s',
                        deal.item_name or 'Unknown',
                        deal.count or 1,
                        format_money(deal.buyout_price)
                    ))
                    
                    -- Remover de la lista de deals
                    for i = 1, getn(sniper_deals) do
                        if sniper_deals[i] == deal then
                            tremove(sniper_deals, i)
                            break
                        end
                    end
                    
                    -- Actualizar UI
                    if M.update_sniper_ui then
                        M.update_sniper_ui()
                    end
                end)
                
                scan.stop()
            end
        end,
        on_complete = function()
            -- Scan terminado
        end
    })
    
    return true
end

-- Exportar funciones del sniper
M.toggle_sniper = toggle_sniper
M.start_sniper = start_sniper
M.stop_sniper = stop_sniper
M.is_sniper_running = is_sniper_running
M.get_sniper_state = get_sniper_state
M.get_sniper_deals = get_sniper_deals
M.buy_sniper_deal = buy_sniper_deal

aux.print('[TRADING] Sistema de trading completamente integrado')
