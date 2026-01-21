-- ============================================================================
-- Sistema de Iconos
-- ============================================================================
-- Maneja la visualización de iconos de items con cache y fallback
-- ============================================================================

module 'aux.tabs.trading'

local aux = require('aux')
local M = getfenv()

-- Variables globales
local icon_cache = {}
local default_icon = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ============================================================================
-- Funciones de Iconos
-- ============================================================================

local function obtener_icono_item(item_id)
    -- Verificar cache
    if icon_cache[item_id] then
        return icon_cache[item_id]
    end
    
    -- Obtener icono del item
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item_id)
    
    if texture then
        icon_cache[item_id] = texture
        return texture
    end
    
    -- Fallback
    return default_icon
end

local function obtener_icono_por_nombre(item_name)
    if not item_name then
        return default_icon
    end
    
    -- Verificar cache por nombre
    if icon_cache[item_name] then
        return icon_cache[item_name]
    end
    
    -- Buscar item por nombre
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item_name)
    
    if texture then
        icon_cache[item_name] = texture
        return texture
    end
    
    return default_icon
end

local function crear_icono_frame(parent, item_id_or_name, size)
    size = size or 32
    
    local icon_frame = CreateFrame("Frame", nil, parent)
    icon_frame:SetSize(size, size)
    
    -- Textura del icono
    local icon_texture = icon_frame:CreateTexture(nil, "ARTWORK")
    icon_texture:SetAllPoints()
    
    -- Obtener icono
    local icon_path
    if type(item_id_or_name) == "number" then
        icon_path = obtener_icono_item(item_id_or_name)
    else
        icon_path = obtener_icono_por_nombre(item_id_or_name)
    end
    
    icon_texture:SetTexture(icon_path)
    
    -- Borde
    local border = icon_frame:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:Hide()
    
    -- Hover effect
    icon_frame:SetScript("OnEnter", function(self)
        border:Show()
    end)
    
    icon_frame:SetScript("OnLeave", function(self)
        border:Hide()
    end)
    
    icon_frame.texture = icon_texture
    icon_frame.border = border
    
    return icon_frame
end

local function actualizar_icono(icon_frame, item_id_or_name)
    if not icon_frame or not icon_frame.texture then
        return
    end
    
    local icon_path
    if type(item_id_or_name) == "number" then
        icon_path = obtener_icono_item(item_id_or_name)
    else
        icon_path = obtener_icono_por_nombre(item_id_or_name)
    end
    
    icon_frame.texture:SetTexture(icon_path)
end

local function limpiar_cache()
    icon_cache = {}
end

local function obtener_tamanio_cache()
    local count = 0
    for _ in pairs(icon_cache) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- Funciones de Rareza
-- ============================================================================

local function obtener_color_rareza(rareza)
    local colores = {
        ["Común"] = {1, 1, 1},
        ["Poco común"] = {0, 1, 0},
        ["Raro"] = {0, 0.44, 0.87},
        ["Épico"] = {0.64, 0.21, 0.93},
        ["Legendario"] = {1, 0.5, 0}
    }
    
    return colores[rareza] or {1, 1, 1}
end

local function aplicar_color_rareza(frame, rareza)
    if not frame then
        return
    end
    
    local r, g, b = unpack(obtener_color_rareza(rareza))
    
    if frame.border then
        frame.border:SetVertexColor(r, g, b)
    end
end

-- ============================================================================
-- Funciones de Tooltip
-- ============================================================================

local function agregar_tooltip_a_icono(icon_frame, item_id_or_name, datos_adicionales)
    if not icon_frame then
        return
    end
    
    icon_frame:EnableMouse(true)
    
    icon_frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        
        if type(item_id_or_name) == "number" then
            GameTooltip:SetItemByID(item_id_or_name)
        else
            GameTooltip:SetText(item_id_or_name, 1, 1, 1)
        end
        
        -- Agregar datos adicionales
        if datos_adicionales then
            GameTooltip:AddLine(" ")
            
            if datos_adicionales.profit then
                local profit_text = money.to_string(datos_adicionales.profit, true)
                local r, g, b = datos_adicionales.profit > 0 and 0 or 1, datos_adicionales.profit > 0 and 1 or 0, 0
                GameTooltip:AddDoubleLine("Profit Estimado:", profit_text, 1, 1, 1, r, g, b)
            end
            
            if datos_adicionales.roi then
                GameTooltip:AddDoubleLine("ROI:", string.format("%.1f%%", datos_adicionales.roi), 1, 1, 1, 1, 0.82, 0)
            end
            
            if datos_adicionales.estrategia then
                GameTooltip:AddDoubleLine("Estrategia:", datos_adicionales.estrategia, 1, 1, 1, 0.5, 1, 0.5)
            end
        end
        
        GameTooltip:Show()
        
        if self.border then
            self.border:Show()
        end
    end)
    
    icon_frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self.border then
            self.border:Hide()
        end
    end)
end

-- ============================================================================
-- Funciones de Lista con Iconos
-- ============================================================================

local function crear_item_con_icono(parent, item_data, x, y, width, height)
    local item_frame = CreateFrame("Button", nil, parent)
    item_frame:SetSize(width or 400, height or 40)
    item_frame:SetPoint("TOPLEFT", x, y)
    
    -- Fondo
    local bg = item_frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    item_frame.bg = bg
    
    -- Icono
    local icon = crear_icono_frame(item_frame, item_data.item_name or item_data.item_id, 32)
    icon:SetPoint("LEFT", 5, 0)
    
    if item_data.rareza then
        aplicar_color_rareza(icon, item_data.rareza)
    end
    
    agregar_tooltip_a_icono(icon, item_data.item_name or item_data.item_id, {
        profit = item_data.profit,
        roi = item_data.roi,
        estrategia = item_data.estrategia
    })
    
    -- Nombre del item
    local name_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name_text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name_text:SetText(item_data.item_name or "Unknown")
    name_text:SetTextColor(1, 0.82, 0)
    
    -- Profit
    if item_data.profit then
        local profit_text = item_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        profit_text:SetPoint("RIGHT", -10, 0)
        profit_text:SetText(money.to_string(item_data.profit, true))
        if item_data.profit > 0 then
            profit_text:SetTextColor(0, 1, 0)
        else
            profit_text:SetTextColor(1, 0, 0)
        end
    end
    
    -- Hover
    item_frame:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.2, 0.4, 0.6, 0.8)
    end)
    
    item_frame:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    end)
    
    item_frame.icon = icon
    item_frame.name_text = name_text
    
    return item_frame
end

-- ============================================================================
-- Registrar Módulo
-- ============================================================================

M.modules = M.modules or {}
M.modules.icon_system = {
    obtener_icono_item = obtener_icono_item,
    obtener_icono_por_nombre = obtener_icono_por_nombre,
    crear_icono_frame = crear_icono_frame,
    crear_icono_item = crear_icono_frame,  -- Alias para compatibilidad
    actualizar_icono = actualizar_icono,
    limpiar_cache = limpiar_cache,
    obtener_tamanio_cache = obtener_tamanio_cache,
    obtener_color_rareza = obtener_color_rareza,
    aplicar_color_rareza = aplicar_color_rareza,
    agregar_tooltip_a_icono = agregar_tooltip_a_icono,
    crear_item_con_icono = crear_item_con_icono
}

aux.print('[TRADING] icon_system.lua cargado - VERSION 2.0 - CON RETURN')
