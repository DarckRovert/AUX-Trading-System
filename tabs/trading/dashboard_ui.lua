module 'aux.tabs.trading'

local aux = require 'aux'
local M = getfenv()

-- ============================================================================
-- Dashboard UI - Interfaz Visual Profesional para Estadísticas
-- ============================================================================

aux.print('[DASHBOARD_UI] Módulo de interfaz de dashboard cargado')

-- ============================================================================
-- Variables
-- ============================================================================

local dashboard_frame = nil
local update_interval = 5  -- Actualizar cada 5 segundos
local last_update = 0

-- ============================================================================
-- Funciones de Utilidad
-- ============================================================================

-- Local format_gold function (aux.util.money is not available in this context)
local function format_gold(copper)
    if not copper or copper == 0 then return "|cFF8888880c|r" end
    copper = math.floor(copper)
    local negative = copper < 0
    copper = math.abs(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    local result = ""
    if negative then result = "-" end
    if gold > 0 then result = result .. "|cFFFFD700" .. gold .. "g|r " end
    if silver > 0 or gold > 0 then result = result .. "|cFFC0C0C0" .. silver .. "s|r " end
    if cop > 0 or (gold == 0 and silver == 0) then result = result .. "|cFFB87333" .. cop .. "c|r" end
    return result
end



local function color_profit(value)
    if not value then return "|cFFFFFFFF" end
    if value > 0 then return "|cFF00FF00" end
    if value < 0 then return "|cFFFF4444" end
    return "|cFFFFFFFF"
end

local function color_percentage(value)
    if not value then return "|cFFFFFFFF" end
    if value >= 80 then return "|cFF00FF00" end
    if value >= 60 then return "|cFF88FF00" end
    if value >= 40 then return "|cFFFFFF00" end
    if value >= 20 then return "|cFFFFAA00" end
    return "|cFFFF4444"
end

-- ============================================================================
-- Crear Barra de Progreso ASCII
-- ============================================================================

local function crear_barra_progreso(valor, max_valor, ancho)
    ancho = ancho or 20
    local porcentaje = 0
    if max_valor > 0 then
        porcentaje = math.min(1, valor / max_valor)
    end
    
    local lleno = math.floor(porcentaje * ancho)
    local vacio = ancho - lleno
    
    local barra = string.rep("█", lleno) .. string.rep("░", vacio)
    return barra
end

-- ============================================================================
-- Obtener Datos del Dashboard
-- ============================================================================

local function obtener_datos_dashboard()
    -- Usar la integración UI para obtener datos del backend
    if M.get_dashboard_data_for_ui then
        local datos = M.get_dashboard_data_for_ui()
        
        -- Obtener top items
        if M.get_top_items_for_ui then
            datos.top_items = M.get_top_items_for_ui(5) or {}
        else
            datos.top_items = {}
        end
        
        -- Obtener métricas de performance
        if M.get_performance_metrics_for_ui then
            datos.performance = M.get_performance_metrics_for_ui()
        else
            datos.performance = {
                roi = 0,
                profit_factor = 0,
                max_drawdown = 0,
                volatility = 0,
                trades_per_day = 0,
            }
        end
        
        return datos
    end
    
    -- Datos por defecto si no está disponible
    local datos = {
        today = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            win_rate = 0,
            roi = 0,
            avg_profit = 0,
        },
        week = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            daily_profits = {},
        },
        month = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
        },
        all_time = {
            profit = 0,
            loss = 0,
            net = 0,
            trades = 0,
            successful = 0,
            failed = 0,
            best_trade = nil,
            worst_trade = nil,
        },
        top_items = {},
        performance = {
            roi = 0,
            profit_factor = 0,
            max_drawdown = 0,
            volatility = 0,
            trades_per_day = 0,
        },
    }
    
    return datos
end

-- ============================================================================
-- Crear UI del Dashboard
-- ============================================================================

function M.crear_dashboard_ui(parent)
    if dashboard_frame then
        return dashboard_frame
    end
    
    local f = CreateFrame('Frame', 'AuxDashboardFrame', parent)
    f:SetAllPoints()
    f:Hide()
    
    -- Fondo
    f.bg = f:CreateTexture(nil, 'BACKGROUND')
    f.bg:SetAllPoints()
    f.bg:SetTexture(0, 0, 0, 0.3)
    
    -- Scroll Frame para contenido
    local scroll = CreateFrame('ScrollFrame', 'AuxDashboardScroll', f, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', 10, -10)
    scroll:SetPoint('BOTTOMRIGHT', -30, 10)
    
    local content = CreateFrame('Frame', 'AuxDashboardContent', scroll)
    content:SetWidth(scroll:GetWidth())
    content:SetHeight(1200)  -- Altura total del contenido
    scroll:SetScrollChild(content)
    
    f.scroll = scroll
    f.content = content
    
    -- ========================================
    -- SECCIÓN: ESTADÍSTICAS DE HOY
    -- ========================================
    
    local y_offset = -10
    
    local titulo_hoy = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo_hoy:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_hoy:SetText('|cFFFFD700📊 ESTADÍSTICAS DE HOY|r')
    y_offset = y_offset - 30
    
    -- Panel de estadísticas principales
    local stats_panel = CreateFrame('Frame', nil, content)
    stats_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    stats_panel:SetWidth(content:GetWidth() - 20)
    stats_panel:SetHeight(80)
    
    stats_panel.bg = stats_panel:CreateTexture(nil, 'BACKGROUND')
    stats_panel.bg:SetAllPoints()
    stats_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Columna 1: Profit/Loss
    local col1_x = 15
    stats_panel.profit_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.profit_label:SetPoint('TOPLEFT', stats_panel, 'TOPLEFT', col1_x, -10)
    stats_panel.profit_label:SetText('|cFF00FF00Profit:|r')
    
    stats_panel.profit_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    stats_panel.profit_value:SetPoint('TOPLEFT', stats_panel.profit_label, 'BOTTOMLEFT', 0, -5)
    stats_panel.profit_value:SetText('0g')
    
    stats_panel.loss_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.loss_label:SetPoint('TOPLEFT', stats_panel.profit_value, 'BOTTOMLEFT', 0, -5)
    stats_panel.loss_label:SetText('|cFFFF4444Loss:|r')
    
    stats_panel.loss_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.loss_value:SetPoint('LEFT', stats_panel.loss_label, 'RIGHT', 5, 0)
    stats_panel.loss_value:SetText('0g')
    
    -- Columna 2: Trades
    local col2_x = 180
    stats_panel.trades_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.trades_label:SetPoint('TOPLEFT', stats_panel, 'TOPLEFT', col2_x, -10)
    stats_panel.trades_label:SetText('|cFFFFFFFFTrades:|r')
    
    stats_panel.trades_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    stats_panel.trades_value:SetPoint('TOPLEFT', stats_panel.trades_label, 'BOTTOMLEFT', 0, -5)
    stats_panel.trades_value:SetText('0')
    
    stats_panel.roi_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.roi_label:SetPoint('TOPLEFT', stats_panel.trades_value, 'BOTTOMLEFT', 0, -5)
    stats_panel.roi_label:SetText('|cFFFFAA00ROI:|r')
    
    stats_panel.roi_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.roi_value:SetPoint('LEFT', stats_panel.roi_label, 'RIGHT', 5, 0)
    stats_panel.roi_value:SetText('0%')
    
    -- Columna 3: Win Rate
    local col3_x = 340
    stats_panel.winrate_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.winrate_label:SetPoint('TOPLEFT', stats_panel, 'TOPLEFT', col3_x, -10)
    stats_panel.winrate_label:SetText('|cFF88FF00Win Rate:|r')
    
    stats_panel.winrate_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    stats_panel.winrate_value:SetPoint('TOPLEFT', stats_panel.winrate_label, 'BOTTOMLEFT', 0, -5)
    stats_panel.winrate_value:SetText('0%')
    
    stats_panel.avg_label = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.avg_label:SetPoint('TOPLEFT', stats_panel.winrate_value, 'BOTTOMLEFT', 0, -5)
    stats_panel.avg_label:SetText('|cFFAAAAFFAvg:|r')
    
    stats_panel.avg_value = stats_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    stats_panel.avg_value:SetPoint('LEFT', stats_panel.avg_label, 'RIGHT', 5, 0)
    stats_panel.avg_value:SetText('0g')
    
    f.stats_panel = stats_panel
    y_offset = y_offset - 90
    
    -- ========================================
    -- SECCIÓN: GRÁFICO DE PROFIT/LOSS
    -- ========================================
    
    local titulo_grafico = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo_grafico:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_grafico:SetText('|cFFFFD700📈 PROFIT/LOSS (Últimos 7 días)|r')
    y_offset = y_offset - 30
    
    local grafico_panel = CreateFrame('Frame', nil, content)
    grafico_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    grafico_panel:SetWidth(content:GetWidth() - 20)
    grafico_panel:SetHeight(180)
    
    grafico_panel.bg = grafico_panel:CreateTexture(nil, 'BACKGROUND')
    grafico_panel.bg:SetAllPoints()
    grafico_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Crear 7 barras para los días
    grafico_panel.barras = {}
    local dias = {'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'}
    for i = 1, 7 do
        local barra = grafico_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        barra:SetPoint('TOPLEFT', grafico_panel, 'TOPLEFT', 10, -10 - ((i-1) * 24))
        barra:SetJustifyH('LEFT')
        barra:SetText(dias[i] .. ': 0g')
        grafico_panel.barras[i] = barra
    end
    
    f.grafico_panel = grafico_panel
    y_offset = y_offset - 190
    
    -- ========================================
    -- SECCIÓN: TOP ITEMS
    -- ========================================
    
    local titulo_top = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo_top:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_top:SetText('|cFFFFD700🏆 TOP 5 ITEMS MÁS RENTABLES|r')
    y_offset = y_offset - 30
    
    local top_panel = CreateFrame('Frame', nil, content)
    top_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    top_panel:SetWidth(content:GetWidth() - 20)
    top_panel:SetHeight(140)
    
    top_panel.bg = top_panel:CreateTexture(nil, 'BACKGROUND')
    top_panel.bg:SetAllPoints()
    top_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    top_panel.items = {}
    for i = 1, 5 do
        local item_text = top_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        item_text:SetPoint('TOPLEFT', top_panel, 'TOPLEFT', 10, -10 - ((i-1) * 25))
        item_text:SetJustifyH('LEFT')
        item_text:SetText(i .. '. Sin datos')
        top_panel.items[i] = item_text
    end
    
    f.top_panel = top_panel
    y_offset = y_offset - 150
    
    -- ========================================
    -- SECCIÓN: MÉTRICAS DE PERFORMANCE
    -- ========================================
    
    local titulo_perf = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo_perf:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_perf:SetText('|cFFFFD700📊 MÉTRICAS DE PERFORMANCE|r')
    y_offset = y_offset - 30
    
    local perf_panel = CreateFrame('Frame', nil, content)
    perf_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    perf_panel:SetWidth(content:GetWidth() - 20)
    perf_panel:SetHeight(120)
    
    perf_panel.bg = perf_panel:CreateTexture(nil, 'BACKGROUND')
    perf_panel.bg:SetAllPoints()
    perf_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    perf_panel.roi = perf_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    perf_panel.roi:SetPoint('TOPLEFT', perf_panel, 'TOPLEFT', 10, -10)
    perf_panel.roi:SetJustifyH('LEFT')
    perf_panel.roi:SetText('ROI: 0%')
    
    perf_panel.profit_factor = perf_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    perf_panel.profit_factor:SetPoint('TOPLEFT', perf_panel.roi, 'BOTTOMLEFT', 0, -5)
    perf_panel.profit_factor:SetJustifyH('LEFT')
    perf_panel.profit_factor:SetText('Profit Factor: 0.00')
    
    perf_panel.max_drawdown = perf_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    perf_panel.max_drawdown:SetPoint('TOPLEFT', perf_panel.profit_factor, 'BOTTOMLEFT', 0, -5)
    perf_panel.max_drawdown:SetJustifyH('LEFT')
    perf_panel.max_drawdown:SetText('Max Drawdown: 0g')
    
    perf_panel.volatility = perf_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    perf_panel.volatility:SetPoint('TOPLEFT', perf_panel.max_drawdown, 'BOTTOMLEFT', 0, -5)
    perf_panel.volatility:SetJustifyH('LEFT')
    perf_panel.volatility:SetText('Volatilidad: 0g')
    
    perf_panel.trades_per_day = perf_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    perf_panel.trades_per_day:SetPoint('TOPLEFT', perf_panel.volatility, 'BOTTOMLEFT', 0, -5)
    perf_panel.trades_per_day:SetJustifyH('LEFT')
    perf_panel.trades_per_day:SetText('Trades por día: 0.0')
    
    f.perf_panel = perf_panel
    y_offset = y_offset - 130
    
    -- ========================================
    -- SECCIÓN: RECOMENDACIONES
    -- ========================================
    
    local titulo_rec = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    titulo_rec:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    titulo_rec:SetText('|cFFFFD700💡 RECOMENDACIONES|r')
    y_offset = y_offset - 30
    
    local rec_panel = CreateFrame('Frame', nil, content)
    rec_panel:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    rec_panel:SetWidth(content:GetWidth() - 20)
    rec_panel:SetHeight(100)
    
    rec_panel.bg = rec_panel:CreateTexture(nil, 'BACKGROUND')
    rec_panel.bg:SetAllPoints()
    rec_panel.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    rec_panel.text = rec_panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    rec_panel.text:SetPoint('TOPLEFT', rec_panel, 'TOPLEFT', 10, -10)
    rec_panel.text:SetPoint('BOTTOMRIGHT', rec_panel, 'BOTTOMRIGHT', -10, 10)
    rec_panel.text:SetJustifyH('LEFT')
    rec_panel.text:SetJustifyV('TOP')
    rec_panel.text:SetText('• Cargando recomendaciones...')
    
    f.rec_panel = rec_panel
    
    -- ========================================
    -- BOTONES DE ACCIÓN
    -- ========================================
    
    y_offset = y_offset - 110
    
    local btn_refresh = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
    btn_refresh:SetWidth(120)
    btn_refresh:SetHeight(24)
    btn_refresh:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, y_offset)
    btn_refresh:SetText('Actualizar')
    btn_refresh:SetScript('OnClick', function()
        M.actualizar_dashboard_ui()
    end)
    
    local btn_export = CreateFrame('Button', nil, content, 'UIPanelButtonTemplate')
    btn_export:SetWidth(120)
    btn_export:SetHeight(24)
    btn_export:SetPoint('LEFT', btn_refresh, 'RIGHT', 5, 0)
    btn_export:SetText('Exportar Reporte')
    btn_export:SetScript('OnClick', function()
        local dashboard_module = M.modules and M.modules.dashboard
        if dashboard_module and dashboard_module.export_report_to_chat then
            dashboard_module.export_report_to_chat()
            aux.print('|cFF00FF00Reporte exportado al chat|r')
        else
            aux.print('|cFFFF0000Función de exportar no disponible|r')
        end
    end)
    
    dashboard_frame = f
    return f
end

-- ============================================================================
-- Actualizar Dashboard UI
-- ============================================================================

function M.actualizar_dashboard_ui()
    if not dashboard_frame then return end
    
    local datos = obtener_datos_dashboard()
    local f = dashboard_frame
    
    -- Actualizar estadísticas de hoy
    if f.stats_panel then
        local sp = f.stats_panel
        if sp.profit_value then
            sp.profit_value:SetText(color_profit(datos.today.profit or 0) .. format_gold(datos.today.profit or 0) .. '|r')
        end
        if sp.loss_value then
            sp.loss_value:SetText(color_profit(datos.today.loss and -datos.today.loss or 0) .. format_gold(datos.today.loss or 0) .. '|r')
        end
        if sp.trades_value then
            sp.trades_value:SetText('|cFFFFFFFF' .. (datos.today.trades or 0) .. '|r')
        end
        if sp.roi_value then
            sp.roi_value:SetText(color_percentage((datos.today.roi or 0) * 100) .. string.format('%.1f%%', (datos.today.roi or 0) * 100) .. '|r')
        end
        if sp.winrate_value then
            sp.winrate_value:SetText(color_percentage((datos.today.win_rate or 0) * 100) .. string.format('%.0f%%', (datos.today.win_rate or 0) * 100) .. '|r')
        end
        if sp.avg_value then
            sp.avg_value:SetText(color_profit(datos.today.avg_profit or 0) .. format_gold(datos.today.avg_profit or 0) .. '|r')
        end
    end
    
    -- Actualizar gráfico de profit/loss CON DATOS REALES
    if f.grafico_panel and f.grafico_panel.barras then
        -- Use new real data functions
        local graph_bars = nil
        if M.modules.dashboard and M.modules.dashboard.get_graph_bars then
            graph_bars = M.modules.dashboard.get_graph_bars(7)
        end
        
        if graph_bars and table.getn(graph_bars) > 0 then
            local max_profit = 1
            for _, bar in ipairs(graph_bars) do
                if math.abs(bar.profit) > max_profit then
                    max_profit = math.abs(bar.profit)
                end
            end
            
            for i = 1, 7 do
                local bar_data = graph_bars[i]
                if bar_data then
                    local barra = crear_barra_progreso(math.abs(bar_data.profit), max_profit, 15)
                    local color = color_profit(bar_data.profit)
                    local day_label = string.sub(bar_data.date or "???", 6, 10) -- MM-DD
                    local texto = string.format('%s: %s%s %s|r', day_label, color, barra, format_gold(bar_data.profit))
                    f.grafico_panel.barras[i]:SetText(texto)
                else
                    f.grafico_panel.barras[i]:SetText('--: Sin datos')
                end
            end
        else
            -- Fallback to week data if new functions not available
            local dias = {'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'}
            local max_profit = 1
            for _, profit in ipairs(datos.week.daily_profits or {}) do
                if math.abs(profit) > max_profit then
                    max_profit = math.abs(profit)
                end
            end
            
            for i = 1, 7 do
                local profit = (datos.week.daily_profits and datos.week.daily_profits[i]) or 0
                local barra = crear_barra_progreso(math.abs(profit), max_profit, 15)
                local color = color_profit(profit)
                local texto = string.format('%s: %s%s %s|r', dias[i], color, barra, format_gold(profit))
                f.grafico_panel.barras[i]:SetText(texto)
            end
        end
    end
    
    -- Actualizar top items CON DATOS REALES
    if f.top_panel and f.top_panel.items then
        -- Try new real data function first
        local real_top_items = nil
        if M.modules.dashboard and M.modules.dashboard.get_top_profitable_items then
            real_top_items = M.modules.dashboard.get_top_profitable_items(5)
        end
        
        if real_top_items and table.getn(real_top_items) > 0 then
            for i = 1, 5 do
                local item = real_top_items[i]
                if item then
                    local texto = string.format('%d. |cFFFFFFFF%s|r - %s%s|r (%d sold)',
                        i,
                        item.name or 'Unknown',
                        color_profit(item.revenue),
                        format_gold(item.revenue),
                        item.quantity or 0
                    )
                    f.top_panel.items[i]:SetText(texto)
                else
                    f.top_panel.items[i]:SetText(i .. '. Sin datos')
                end
            end
        else
            -- Fallback to old method
            for i = 1, 5 do
                local item = datos.top_items[i]
                if item then
                    local texto = string.format('%d. |cFFFFFFFF%s|r - %s%s|r (%d trades)',
                        i,
                        item.item_name or 'Unknown',
                        color_profit(item.total_profit),
                        format_gold(item.total_profit),
                        item.trade_count or 0
                    )
                    f.top_panel.items[i]:SetText(texto)
                else
                    f.top_panel.items[i]:SetText(i .. '. Sin datos')
                end
            end
        end
    end
    
    -- Actualizar métricas de performance
    if f.perf_panel and datos.performance then
        local pp = f.perf_panel
        local perf = datos.performance
        
        pp.roi:SetText(string.format('ROI: %s%.1f%%|r', color_percentage((perf.roi or 0) * 100), (perf.roi or 0) * 100))
        pp.profit_factor:SetText(string.format('Profit Factor: %s%.2f|r', 
            (perf.profit_factor or 0) >= 2 and '|cFF00FF00' or '|cFFFFAA00', 
            perf.profit_factor or 0))
        pp.max_drawdown:SetText(string.format('Max Drawdown: |cFFFF4444%s|r', format_gold(perf.max_drawdown or 0)))
        pp.volatility:SetText(string.format('Volatilidad: |cFFFFAA00%s|r', format_gold(perf.volatility or 0)))
        pp.trades_per_day:SetText(string.format('Trades por día: |cFFFFFFFF%.1f|r', perf.trades_per_day or 0))
    end
    
    -- Actualizar recomendaciones
    if f.rec_panel and f.rec_panel.text then
        local recomendaciones = {}
        
        -- Recomendación basada en ROI
        if datos.today.roi and datos.today.roi > 0.25 then
            table.insert(recomendaciones, '• |cFF00FF00Excelente día! ROI > 25%|r')
        elseif datos.today.roi and datos.today.trades and datos.today.roi < 0.10 and datos.today.trades > 5 then
            table.insert(recomendaciones, '• |cFFFFAA00ROI bajo. Considera ajustar estrategias|r')
        end
        
        -- Recomendación basada en win rate
        if datos.today.win_rate and datos.today.trades and datos.today.win_rate < 0.60 and datos.today.trades > 10 then
            table.insert(recomendaciones, '• |cFFFF4444Win rate bajo. Revisa tus criterios de compra|r')
        elseif datos.today.win_rate and datos.today.win_rate > 0.80 then
            table.insert(recomendaciones, '• |cFF00FF00Excelente win rate! Mantén la estrategia|r')
        end
        
        -- Recomendación basada en actividad
        if datos.today.trades and datos.today.trades == 0 then
            table.insert(recomendaciones, '• |cFFFFFFFFInicia un scan para encontrar oportunidades|r')
        elseif datos.today.trades and datos.today.trades < 5 then
            table.insert(recomendaciones, '• |cFFFFAA00Poca actividad hoy. Considera hacer más scans|r')
        end
        
        -- Recomendación de ML patterns
        local ml_module = M.modules and M.modules.ml_patterns
        if ml_module and ml_module.get_best_time_to_sell then
            -- Aquí podrías añadir recomendaciones basadas en ML
            table.insert(recomendaciones, '• |cFF88FF00Mejor hora para vender: 18:00-22:00|r')
        end
        
        if table.getn(recomendaciones) == 0 then
            table.insert(recomendaciones, '• |cFFFFFFFFSigue escaneando para acumular datos|r')
        end
        
        if f.rec_panel and f.rec_panel.text then
            f.rec_panel.text:SetText(table.concat(recomendaciones, '\n'))
        end
    end
    
    last_update = time()
end

-- ============================================================================
-- Mostrar/Ocultar Dashboard
-- ============================================================================

function M.mostrar_dashboard()
    if not dashboard_frame then
        aux.print('|cFFFF0000Dashboard UI no inicializado|r')
        return
    end
    
    dashboard_frame:Show()
    M.actualizar_dashboard_ui()
end

function M.ocultar_dashboard()
    if dashboard_frame then
        dashboard_frame:Hide()
    end
end

-- ============================================================================
-- Update Loop
-- ============================================================================

function M.dashboard_ui_on_update()
    if not dashboard_frame or not dashboard_frame:IsVisible() then
        return
    end
    
    local now = time()
    if now - last_update >= update_interval then
        M.actualizar_dashboard_ui()
    end
end

-- Registrar funciones en el módulo
if not M.modules then M.modules = {} end
if not M.modules.dashboard_ui then M.modules.dashboard_ui = {} end

M.modules.dashboard_ui.crear_dashboard_ui = M.crear_dashboard_ui
M.modules.dashboard_ui.actualizar_dashboard_ui = M.actualizar_dashboard_ui
M.modules.dashboard_ui.mostrar_dashboard = M.mostrar_dashboard
M.modules.dashboard_ui.ocultar_dashboard = M.ocultar_dashboard
M.modules.dashboard_ui.dashboard_ui_on_update = M.dashboard_ui_on_update

aux.print('|cFF00FF00[DASHBOARD_UI]|r Interfaz de dashboard lista')
