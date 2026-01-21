-- ============================================================================
-- Sistema de Backup y Restauración
-- ============================================================================
-- Guarda y restaura configuraciones, datos y estado del addon
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local M = getfenv()

-- Variables globales
local backup_slots = {}
local max_backup_slots = 5
local auto_backup_enabled = true
local auto_backup_interval = 3600 -- 1 hora en segundos
local last_auto_backup = 0

-- ============================================================================
-- Funciones de Backup
-- ============================================================================

local function crear_backup(nombre)
    if not nombre or nombre == "" then
        nombre = "backup_" .. date("%Y%m%d_%H%M%S")
    end
    
    local backup = {
        nombre = nombre,
        fecha = date("%Y-%m-%d %H:%M:%S"),
        timestamp = time(),
        version = "1.0",
        datos = {}
    }
    
    -- Guardar configuración
    if aux.trading and aux.trading.config then
        backup.datos.config = {}
        for k, v in pairs(aux.trading.config) do
            backup.datos.config[k] = v
        end
    end
    
    -- Guardar historial
    if aux.trading and aux.trading.historial then
        backup.datos.historial = {}
        for i, trade in ipairs(aux.trading.historial) do
            table.insert(backup.datos.historial, trade)
        end
    end
    
    -- Guardar estadísticas
    if aux.trading and aux.trading.estadisticas then
        backup.datos.estadisticas = {}
        for k, v in pairs(aux.trading.estadisticas) do
            backup.datos.estadisticas[k] = v
        end
    end
    
    -- Guardar filtros guardados
    if aux.trading and aux.trading.filter_system then
        local filtros = aux.trading.filter_system.obtener_filtros_guardados()
        backup.datos.filtros = filtros
    end
    
    -- Guardar perfiles
    if aux.trading and aux.trading.perfiles then
        backup.datos.perfiles = {}
        for k, v in pairs(aux.trading.perfiles) do
            backup.datos.perfiles[k] = v
        end
    end
    
    return backup
end

local function guardar_backup(backup, slot)
    if not backup then
        return false, "Backup inválido"
    end
    
    slot = slot or (table.getn(backup_slots) + 1)
    
    if slot > max_backup_slots then
        -- Eliminar el backup más antiguo
        table.remove(backup_slots, 1)
        slot = max_backup_slots
    end
    
    backup_slots[slot] = backup
    
    -- Guardar en archivo
    local success = guardar_backup_a_archivo(backup)
    
    if success then
        return true, "Backup guardado en slot " .. slot
    else
        return false, "Error al guardar backup en archivo"
    end
end

local function guardar_backup_a_archivo(backup)
    local path = "Interface\\AddOns\\aux-addon\\backups\\" .. backup.nombre .. ".lua"
    
    local content = "-- Backup de AUX Trading System\n"
    content = content .. "-- Fecha: " .. backup.fecha .. "\n\n"
    content = content .. "return " .. serialize_table(backup) .. "\n"
    
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    
    return false
end

function serialize_table(tbl, indent)
    indent = indent or 0
    local result = "{\n"
    local indent_str = string.rep("    ", indent + 1)
    
    for k, v in pairs(tbl) do
        local key_str
        if type(k) == "string" then
            key_str = string.format('[%q]', k)
        else
            key_str = "[" .. tostring(k) .. "]"
        end
        
        local value_str
        if type(v) == "table" then
            value_str = serialize_table(v, indent + 1)
        elseif type(v) == "string" then
            value_str = string.format('%q', v)
        elseif type(v) == "boolean" then
            value_str = tostring(v)
        elseif type(v) == "number" then
            value_str = tostring(v)
        else
            value_str = "nil"
        end
        
        result = result .. indent_str .. key_str .. " = " .. value_str .. ",\n"
    end
    
    result = result .. string.rep("    ", indent) .. "}"
    return result
end

-- ============================================================================
-- Funciones de Restauración
-- ============================================================================

local function restaurar_backup(slot)
    if not backup_slots[slot] then
        return false, "Slot de backup vacío"
    end
    
    local backup = backup_slots[slot]
    
    -- Restaurar configuración
    if backup.datos.config and aux.trading then
        aux.trading.config = {}
        for k, v in pairs(backup.datos.config) do
            aux.trading.config[k] = v
        end
    end
    
    -- Restaurar historial
    if backup.datos.historial and aux.trading then
        aux.trading.historial = {}
        for i, trade in ipairs(backup.datos.historial) do
            table.insert(aux.trading.historial, trade)
        end
    end
    
    -- Restaurar estadísticas
    if backup.datos.estadisticas and aux.trading then
        aux.trading.estadisticas = {}
        for k, v in pairs(backup.datos.estadisticas) do
            aux.trading.estadisticas[k] = v
        end
    end
    
    -- Restaurar filtros
    if backup.datos.filtros and aux.trading and aux.trading.filter_system then
        -- Implementar restauración de filtros
    end
    
    -- Restaurar perfiles
    if backup.datos.perfiles and aux.trading then
        aux.trading.perfiles = {}
        for k, v in pairs(backup.datos.perfiles) do
            aux.trading.perfiles[k] = v
        end
    end
    
    return true, "Backup restaurado desde slot " .. slot
end

local function cargar_backup_desde_archivo(nombre_archivo)
    local path = "Interface\\AddOns\\aux-addon\\backups\\" .. nombre_archivo .. ".lua"
    local backup_func = loadfile(path)
    
    if backup_func then
        local backup = backup_func()
        return true, backup
    else
        return false, "Error al cargar backup"
    end
end

-- ============================================================================
-- Funciones de Gestión de Slots
-- ============================================================================

local function obtener_backups()
    return backup_slots
end

local function eliminar_backup(slot)
    if not backup_slots[slot] then
        return false, "Slot de backup vacío"
    end
    
    local backup = backup_slots[slot]
    
    -- Eliminar archivo
    local path = "Interface\\AddOns\\aux-addon\\backups\\" .. backup.nombre .. ".lua"
    os.remove(path)
    
    -- Eliminar de slots
    table.remove(backup_slots, slot)
    
    return true, "Backup eliminado"
end

local function limpiar_backups_antiguos(dias)
    dias = dias or 30
    local tiempo_limite = time() - (dias * 24 * 60 * 60)
    
    local eliminados = 0
    
    for i = table.getn(backup_slots), 1, -1 do
        local backup = backup_slots[i]
        if backup.timestamp < tiempo_limite then
            eliminar_backup(i)
            eliminados = eliminados + 1
        end
    end
    
    return eliminados
end

-- ============================================================================
-- Auto-Backup
-- ============================================================================

local function auto_backup()
    if not auto_backup_enabled then
        return
    end
    
    local tiempo_actual = time()
    
    if tiempo_actual - last_auto_backup >= auto_backup_interval then
        local backup = crear_backup("auto_backup_" .. date("%Y%m%d_%H%M%S"))
        guardar_backup(backup)
        last_auto_backup = tiempo_actual
        print("Auto-backup creado")
    end
end

local function configurar_auto_backup(enabled, interval)
    auto_backup_enabled = enabled
    if interval then
        auto_backup_interval = interval
    end
end

-- ============================================================================
-- Interfaz de Usuario
-- ============================================================================

local function crear_backup_ui(parent)
    local backup_frame = CreateFrame("Frame", nil, parent)
    backup_frame:SetAllPoints()
    backup_frame:Hide()
    
    -- Título
    local title = backup_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Sistema de Backup y Restauración")
    title:SetTextColor(1, 0.82, 0)
    
    local y_offset = -50
    
    -- ========================================================================
    -- Crear Backup
    -- ========================================================================
    
    local create_title = backup_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    create_title:SetPoint("TOPLEFT", 20, y_offset)
    create_title:SetText("Crear Nuevo Backup:")
    create_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    local create_btn = CreateFrame("Button", nil, backup_frame, "UIPanelButtonTemplate")
    create_btn:SetSize(200, 30)
    create_btn:SetPoint("TOPLEFT", 20, y_offset)
    create_btn:SetText("Crear Backup Ahora")
    create_btn:SetScript("OnClick", function()
        StaticPopup_Show("CREATE_BACKUP_POPUP")
    end)
    
    y_offset = y_offset - 50
    
    -- ========================================================================
    -- Lista de Backups
    -- ========================================================================
    
    local list_title = backup_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list_title:SetPoint("TOPLEFT", 20, y_offset)
    list_title:SetText("Backups Guardados:")
    list_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    -- Scroll frame para lista de backups
    local scroll_frame = CreateFrame("ScrollFrame", nil, backup_frame, "UIPanelScrollFrameTemplate")
    scroll_frame:SetSize(560, 200)
    scroll_frame:SetPoint("TOPLEFT", 20, y_offset)
    
    local content = CreateFrame("Frame", nil, scroll_frame)
    content:SetSize(540, 400)
    scroll_frame:SetScrollChild(content)
    
    -- Fondo
    local bg = scroll_frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    backup_frame.backup_list_content = content
    
    y_offset = y_offset - 220
    
    -- ========================================================================
    -- Auto-Backup
    -- ========================================================================
    
    local auto_title = backup_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    auto_title:SetPoint("TOPLEFT", 20, y_offset)
    auto_title:SetText("Auto-Backup:")
    auto_title:SetTextColor(0.5, 1, 0.5)
    y_offset = y_offset - 30
    
    local auto_checkbox = CreateFrame("CheckButton", nil, backup_frame, "UICheckButtonTemplate")
    auto_checkbox:SetSize(24, 24)
    auto_checkbox:SetPoint("TOPLEFT", 20, y_offset)
    auto_checkbox:SetChecked(auto_backup_enabled)
    
    local auto_text = auto_checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    auto_text:SetPoint("LEFT", auto_checkbox, "RIGHT", 5, 0)
    auto_text:SetText("Activar auto-backup cada hora")
    
    auto_checkbox:SetScript("OnClick", function(self)
        configurar_auto_backup(self:GetChecked())
    end)
    
    y_offset = y_offset - 40
    
    -- ========================================================================
    -- Limpieza
    -- ========================================================================
    
    local clean_btn = CreateFrame("Button", nil, backup_frame, "UIPanelButtonTemplate")
    clean_btn:SetSize(250, 30)
    clean_btn:SetPoint("TOPLEFT", 20, y_offset)
    clean_btn:SetText("Limpiar Backups Antiguos (>30 días)")
    clean_btn:SetScript("OnClick", function()
        local eliminados = limpiar_backups_antiguos(30)
        print(string.format("Se eliminaron %d backups antiguos", eliminados))
        actualizar_lista_backups(backup_frame)
    end)
    
    return backup_frame
end

function actualizar_lista_backups(backup_frame)
    if not backup_frame or not backup_frame.backup_list_content then
        return
    end
    
    local content = backup_frame.backup_list_content
    
    -- Limpiar lista anterior
    if content.items then
        for _, item in ipairs(content.items) do
            if item.frame then
                item.frame:Hide()
            end
        end
    end
    content.items = {}
    
    local backups = obtener_backups()
    local y_offset = -10
    
    for i, backup in ipairs(backups) do
        local item_frame = CreateFrame("Frame", nil, content)
        item_frame:SetSize(520, 60)
        item_frame:SetPoint("TOPLEFT", 10, y_offset)
        
        -- Fondo
        local bg = item_frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if math.mod(i, 2) == 0 then
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        else
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        end
        
        -- Nombre
        local name_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name_text:SetPoint("TOPLEFT", 10, -10)
        name_text:SetText(backup.nombre)
        name_text:SetTextColor(1, 0.82, 0)
        
        -- Fecha
        local date_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        date_text:SetPoint("TOPLEFT", 10, -30)
        date_text:SetText("Fecha: " .. backup.fecha)
        date_text:SetTextColor(0.7, 0.7, 0.7)
        
        -- Botón restaurar
        local restore_btn = CreateFrame("Button", nil, item_frame, "UIPanelButtonTemplate")
        restore_btn:SetSize(100, 25)
        restore_btn:SetPoint("RIGHT", -120, 0)
        restore_btn:SetText("Restaurar")
        restore_btn:SetScript("OnClick", function()
            local success, msg = restaurar_backup(i)
            print(msg)
        end)
        
        -- Botón eliminar
        local delete_btn = CreateFrame("Button", nil, item_frame, "UIPanelButtonTemplate")
        delete_btn:SetSize(100, 25)
        delete_btn:SetPoint("RIGHT", -10, 0)
        delete_btn:SetText("Eliminar")
        delete_btn:SetScript("OnClick", function()
            local success, msg = eliminar_backup(i)
            print(msg)
            actualizar_lista_backups(backup_frame)
        end)
        
        table.insert(content.items, {frame = item_frame, data = backup})
        y_offset = y_offset - 65
    end
end

-- Popup para crear backup
StaticPopupDialogs["CREATE_BACKUP_POPUP"] = {
    text = "Nombre del backup:",
    button1 = "Crear",
    button2 = "Cancelar",
    hasEditBox = true,
    OnAccept = function(self)
        local nombre = self.editBox:GetText()
        if nombre == "" then
            nombre = nil
        end
        local backup = crear_backup(nombre)
        local success, msg = guardar_backup(backup)
        print(msg)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- ============================================================================
-- Funciones Públicas
-- ============================================================================

local function mostrar_backup()
    if backup_frame then
        backup_frame:Show()
        actualizar_lista_backups(backup_frame)
    end
end

local function ocultar_backup()
    if backup_frame then
        backup_frame:Hide()
    end
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.backup_system = {
    crear_backup_ui = crear_backup_ui,
    mostrar_backup = mostrar_backup,
    ocultar_backup = ocultar_backup,
    crear_backup = crear_backup,
    guardar_backup = guardar_backup,
    restaurar_backup = restaurar_backup,
    obtener_backups = obtener_backups,
    eliminar_backup = eliminar_backup,
    limpiar_backups_antiguos = limpiar_backups_antiguos,
    auto_backup = auto_backup,
    configurar_auto_backup = configurar_auto_backup,
    actualizar_lista_backups = actualizar_lista_backups
}

aux.print('[TRADING] backup_system.lua cargado')
