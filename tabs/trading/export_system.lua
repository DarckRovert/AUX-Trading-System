-- ============================================================================
-- Sistema de Exportación de Datos
-- ============================================================================
-- Exporta datos a CSV, TXT, HTML y configuraciones
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local money = require('aux.util.money')
local M = getfenv()

-- Variables globales
local export_frame = nil

-- ============================================================================
-- Funciones de Exportación
-- ============================================================================

local function exportar_a_csv(datos, nombre_archivo)
    if not datos or table.getn(datos) == 0 then
        return false, "No hay datos para exportar"
    end
    
    local csv_content = "Item,Precio Compra,Precio Venta,Profit,ROI,Estrategia,Fecha\n"
    
    for _, item in ipairs(datos) do
        local linea = string.format("%s,%d,%d,%d,%.2f,%s,%s\n",
            item.item_name or "Unknown",
            item.precio_compra or 0,
            item.precio_venta or 0,
            item.profit or 0,
            item.roi or 0,
            item.estrategia or "N/A",
            item.fecha or date("%Y-%m-%d %H:%M:%S")
        )
        csv_content = csv_content .. linea
    end
    
    -- Guardar archivo
    local path = "Interface\\AddOns\\aux-addon\\exports\\" .. nombre_archivo .. ".csv"
    local file = io.open(path, "w")
    if file then
        file:write(csv_content)
        file:close()
        return true, "Exportado a " .. path
    else
        return false, "Error al crear archivo"
    end
end

local function exportar_a_txt(datos, nombre_archivo)
    if not datos or table.getn(datos) == 0 then
        return false, "No hay datos para exportar"
    end
    
    local txt_content = "=" .. string.rep("=", 70) .. "\n"
    txt_content = txt_content .. "REPORTE DE TRADING - AUX ADDON\n"
    txt_content = txt_content .. "Fecha: " .. date("%Y-%m-%d %H:%M:%S") .. "\n"
    txt_content = txt_content .. "=" .. string.rep("=", 70) .. "\n\n"
    
    local total_profit = 0
    local total_trades = table.getn(datos)
    
    for i, item in ipairs(datos) do
        txt_content = txt_content .. string.format("%d. %s\n", i, item.item_name or "Unknown")
        txt_content = txt_content .. string.format("   Precio Compra: %s\n", money.to_string(item.precio_compra or 0, true))
        txt_content = txt_content .. string.format("   Precio Venta:  %s\n", money.to_string(item.precio_venta or 0, true))
        txt_content = txt_content .. string.format("   Profit:        %s\n", money.to_string(item.profit or 0, true))
        txt_content = txt_content .. string.format("   ROI:           %.2f%%\n", item.roi or 0)
        txt_content = txt_content .. string.format("   Estrategia:    %s\n", item.estrategia or "N/A")
        txt_content = txt_content .. "\n"
        
        total_profit = total_profit + (item.profit or 0)
    end
    
    txt_content = txt_content .. "=" .. string.rep("=", 70) .. "\n"
    txt_content = txt_content .. "RESUMEN\n"
    txt_content = txt_content .. "=" .. string.rep("=", 70) .. "\n"
    txt_content = txt_content .. string.format("Total Trades:  %d\n", total_trades)
    txt_content = txt_content .. string.format("Total Profit:  %s\n", money.to_string(total_profit, true))
    txt_content = txt_content .. string.format("Avg Profit:    %s\n", money.to_string(total_profit / total_trades, true))
    
    -- Guardar archivo
    local path = "Interface\\AddOns\\aux-addon\\exports\\" .. nombre_archivo .. ".txt"
    local file = io.open(path, "w")
    if file then
        file:write(txt_content)
        file:close()
        return true, "Exportado a " .. path
    else
        return false, "Error al crear archivo"
    end
end

local function exportar_a_html(datos, nombre_archivo)
    if not datos or table.getn(datos) == 0 then
        return false, "No hay datos para exportar"
    end
    
    local html_content = [[<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte de Trading - AUX Addon</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a1a; color: #fff; }
        h1 { color: #ffd700; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background: #333; padding: 10px; text-align: left; border: 1px solid #555; }
        td { padding: 8px; border: 1px solid #555; }
        tr:nth-child(even) { background: #2a2a2a; }
        tr:nth-child(odd) { background: #1f1f1f; }
        .profit-positive { color: #00ff00; }
        .profit-negative { color: #ff0000; }
        .summary { margin-top: 30px; padding: 20px; background: #2a2a2a; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Reporte de Trading - AUX Addon</h1>
    <p>Fecha: ]] .. date("%Y-%m-%d %H:%M:%S") .. [[</p>
    
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Item</th>
                <th>Precio Compra</th>
                <th>Precio Venta</th>
                <th>Profit</th>
                <th>ROI</th>
                <th>Estrategia</th>
            </tr>
        </thead>
        <tbody>
]]
    
    local total_profit = 0
    
    for i, item in ipairs(datos) do
        local profit_class = (item.profit or 0) > 0 and "profit-positive" or "profit-negative"
        html_content = html_content .. string.format([[            <tr>
                <td>%d</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td class="%s">%s</td>
                <td>%.2f%%</td>
                <td>%s</td>
            </tr>
]],
            i,
            item.item_name or "Unknown",
            money.to_string(item.precio_compra or 0, true),
            money.to_string(item.precio_venta or 0, true),
            profit_class,
            money.to_string(item.profit or 0, true),
            item.roi or 0,
            item.estrategia or "N/A"
        )
        
        total_profit = total_profit + (item.profit or 0)
    end
    
    html_content = html_content .. [[        </tbody>
    </table>
    
    <div class="summary">
        <h2>Resumen</h2>
        <p><strong>Total Trades:</strong> ]] .. table.getn(datos) .. [[</p>
        <p><strong>Total Profit:</strong> <span class="]] .. (total_profit > 0 and "profit-positive" or "profit-negative") .. [[">]] .. money.to_string(total_profit, true) .. [[</span></p>
        <p><strong>Avg Profit:</strong> ]] .. money.to_string(total_profit / table.getn(datos), true) .. [[</p>
    </div>
</body>
</html>
]]
    
    -- Guardar archivo
    local path = "Interface\\AddOns\\aux-addon\\exports\\" .. nombre_archivo .. ".html"
    local file = io.open(path, "w")
    if file then
        file:write(html_content)
        file:close()
        return true, "Exportado a " .. path
    else
        return false, "Error al crear archivo"
    end
end

local function exportar_configuracion(config, nombre_archivo)
    if not config then
        return false, "No hay configuración para exportar"
    end
    
    local config_str = "-- Configuración de AUX Trading System\n"
    config_str = config_str .. "-- Exportado: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    config_str = config_str .. "return {\n"
    
    for key, value in pairs(config) do
        if type(value) == "string" then
            config_str = config_str .. string.format("    %s = \"%s\",\n", key, value)
        elseif type(value) == "number" then
            config_str = config_str .. string.format("    %s = %d,\n", key, value)
        elseif type(value) == "boolean" then
            config_str = config_str .. string.format("    %s = %s,\n", key, tostring(value))
        elseif type(value) == "table" then
            config_str = config_str .. string.format("    %s = {},\n", key)
        end
    end
    
    config_str = config_str .. "}\n"
    
    -- Guardar archivo
    local path = "Interface\\AddOns\\aux-addon\\exports\\" .. nombre_archivo .. ".lua"
    local file = io.open(path, "w")
    if file then
        file:write(config_str)
        file:close()
        return true, "Configuración exportada a " .. path
    else
        return false, "Error al crear archivo"
    end
end

local function importar_configuracion(nombre_archivo)
    local path = "Interface\\AddOns\\aux-addon\\exports\\" .. nombre_archivo .. ".lua"
    local config = loadfile(path)
    
    if config then
        return true, config()
    else
        return false, "Error al cargar configuración"
    end
end

-- ============================================================================
-- Interfaz de Usuario
-- ============================================================================

local function crear_export_ui(parent)
    export_frame = CreateFrame("Frame", nil, parent)
    export_frame:SetAllPoints()
    export_frame:Hide()
    
    -- Título
    local title = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Sistema de Exportación")
    title:SetTextColor(1, 0.82, 0)
    
    -- Descripción
    local desc = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", 0, -40)
    desc:SetText("Exporta tus datos de trading a diferentes formatos")
    desc:SetTextColor(0.7, 0.7, 0.7)
    
    local y_offset = -80
    
    -- ========================================================================
    -- Exportar Oportunidades
    -- ========================================================================
    
    local opp_title = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opp_title:SetPoint("TOPLEFT", 20, y_offset)
    opp_title:SetText("Exportar Oportunidades Actuales:")
    opp_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    local csv_opp_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    csv_opp_btn:SetSize(150, 30)
    csv_opp_btn:SetPoint("TOPLEFT", 20, y_offset)
    csv_opp_btn:SetText("Exportar a CSV")
    csv_opp_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.oportunidades then
            local success, msg = exportar_a_csv(aux.trading.oportunidades, "oportunidades_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay oportunidades para exportar")
        end
    end)
    
    local txt_opp_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    txt_opp_btn:SetSize(150, 30)
    txt_opp_btn:SetPoint("LEFT", csv_opp_btn, "RIGHT", 10, 0)
    txt_opp_btn:SetText("Exportar a TXT")
    txt_opp_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.oportunidades then
            local success, msg = exportar_a_txt(aux.trading.oportunidades, "oportunidades_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay oportunidades para exportar")
        end
    end)
    
    local html_opp_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    html_opp_btn:SetSize(150, 30)
    html_opp_btn:SetPoint("LEFT", txt_opp_btn, "RIGHT", 10, 0)
    html_opp_btn:SetText("Exportar a HTML")
    html_opp_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.oportunidades then
            local success, msg = exportar_a_html(aux.trading.oportunidades, "oportunidades_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay oportunidades para exportar")
        end
    end)
    
    y_offset = y_offset - 50
    
    -- ========================================================================
    -- Exportar Historial
    -- ========================================================================
    
    local hist_title = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hist_title:SetPoint("TOPLEFT", 20, y_offset)
    hist_title:SetText("Exportar Historial de Trades:")
    hist_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    local csv_hist_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    csv_hist_btn:SetSize(150, 30)
    csv_hist_btn:SetPoint("TOPLEFT", 20, y_offset)
    csv_hist_btn:SetText("Exportar a CSV")
    csv_hist_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.historial then
            local success, msg = exportar_a_csv(aux.trading.historial, "historial_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay historial para exportar")
        end
    end)
    
    local txt_hist_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    txt_hist_btn:SetSize(150, 30)
    txt_hist_btn:SetPoint("LEFT", csv_hist_btn, "RIGHT", 10, 0)
    txt_hist_btn:SetText("Exportar a TXT")
    txt_hist_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.historial then
            local success, msg = exportar_a_txt(aux.trading.historial, "historial_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay historial para exportar")
        end
    end)
    
    local html_hist_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    html_hist_btn:SetSize(150, 30)
    html_hist_btn:SetPoint("LEFT", txt_hist_btn, "RIGHT", 10, 0)
    html_hist_btn:SetText("Exportar a HTML")
    html_hist_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.historial then
            local success, msg = exportar_a_html(aux.trading.historial, "historial_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay historial para exportar")
        end
    end)
    
    y_offset = y_offset - 50
    
    -- ========================================================================
    -- Exportar Configuración
    -- ========================================================================
    
    local config_title = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    config_title:SetPoint("TOPLEFT", 20, y_offset)
    config_title:SetText("Exportar/Importar Configuración:")
    config_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    local export_config_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    export_config_btn:SetSize(200, 30)
    export_config_btn:SetPoint("TOPLEFT", 20, y_offset)
    export_config_btn:SetText("Exportar Configuración")
    export_config_btn:SetScript("OnClick", function()
        if aux.trading and aux.trading.config then
            local success, msg = exportar_configuracion(aux.trading.config, "config_" .. date("%Y%m%d_%H%M%S"))
            print(msg)
        else
            print("No hay configuración para exportar")
        end
    end)
    
    local import_config_btn = CreateFrame("Button", nil, export_frame, "UIPanelButtonTemplate")
    import_config_btn:SetSize(200, 30)
    import_config_btn:SetPoint("LEFT", export_config_btn, "RIGHT", 10, 0)
    import_config_btn:SetText("Importar Configuración")
    import_config_btn:SetScript("OnClick", function()
        StaticPopup_Show("IMPORT_CONFIG_POPUP")
    end)
    
    y_offset = y_offset - 50
    
    -- ========================================================================
    -- Información
    -- ========================================================================
    
    local info_text = export_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info_text:SetPoint("TOPLEFT", 20, y_offset)
    info_text:SetWidth(560)
    info_text:SetJustifyH("LEFT")
    info_text:SetText("Los archivos se guardarán en: Interface\\AddOns\\aux-addon\\exports\\\n\nFormatos disponibles:\n• CSV: Para análisis en Excel/Google Sheets\n• TXT: Reporte legible para humanos\n• HTML: Reporte visual con estilos\n• LUA: Configuración importable")
    info_text:SetTextColor(0.7, 0.7, 0.7)
    
    return export_frame
end

-- Popup para importar configuración
StaticPopupDialogs["IMPORT_CONFIG_POPUP"] = {
    text = "Nombre del archivo de configuración (sin .lua):",
    button1 = "Importar",
    button2 = "Cancelar",
    hasEditBox = true,
    OnAccept = function(self)
        local nombre = self.editBox:GetText()
        local success, result = importar_configuracion(nombre)
        if success then
            print("Configuración importada exitosamente")
            if aux.trading then
                aux.trading.config = result
            end
        else
            print("Error: " .. result)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- ============================================================================
-- Funciones Públicas
-- ============================================================================

local function mostrar_export()
    if export_frame then
        export_frame:Show()
    end
end

local function ocultar_export()
    if export_frame then
        export_frame:Hide()
    end
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.export_system = {
    crear_export_ui = crear_export_ui,
    mostrar_export = mostrar_export,
    ocultar_export = ocultar_export,
    exportar_a_csv = exportar_a_csv,
    exportar_a_txt = exportar_a_txt,
    exportar_a_html = exportar_a_html,
    exportar_configuracion = exportar_configuracion,
    importar_configuracion = importar_configuracion
}

aux.print('[TRADING] export_system.lua cargado')
