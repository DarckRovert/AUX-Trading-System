# 🔧 API Reference - AUX Trading System

**Por Elnazzareno (DarckRovert)**  
**El Séquito del Terror** 🔮

---

## 📖 Introducción

Esta documentación describe las funciones y módulos disponibles para desarrolladores que quieran extender el sistema de trading.

---

## 📦 Módulo Principal

### `aux.tabs.trading`

Módulo principal del sistema de trading.

```lua
module 'aux.tabs.trading'
local M = getfenv()
```

---

## 🎨 Funciones de UI

### `create_backdrop(frame, bg_color, border_color, edge_size)`

Crea un fondo con borde para un frame.

**Parámetros:**
- `frame` (Frame): El frame al que aplicar el fondo
- `bg_color` (table): Color de fondo {r, g, b, a}
- `border_color` (table): Color del borde {r, g, b, a}
- `edge_size` (number): Tamaño del borde (default: 1)

**Ejemplo:**
```lua
create_backdrop(myFrame, {0.1, 0.1, 0.1, 0.9}, {0.3, 0.3, 0.3, 1}, 1)
```

---

### `create_text(parent, text, size, color, anchor, rel_frame, rel_point, x, y)`

Crea un FontString con configuración.

**Parámetros:**
- `parent` (Frame): Frame padre
- `text` (string): Texto a mostrar
- `size` (number): Tamaño de fuente
- `color` (table): Color {r, g, b}
- `anchor` (string): Punto de anclaje
- `rel_frame` (Frame): Frame relativo (opcional)
- `rel_point` (string): Punto relativo (opcional)
- `x` (number): Offset X (opcional)
- `y` (number): Offset Y (opcional)

**Retorna:** FontString

**Ejemplo:**
```lua
local texto = create_text(panel, "Hola Mundo", 14, {1, 1, 1}, "CENTER")
```

---

### `format_gold(copper)`

Formatea una cantidad de cobre a texto con colores.

**Parámetros:**
- `copper` (number): Cantidad en cobre

**Retorna:** string con formato "|cFFFFD700Xg|r |cFFC0C0C0Xs|r |cFFB87333Xc|r"

**Ejemplo:**
```lua
local texto = format_gold(12345) -- "1g 23s 45c"
```

---

## 📊 Módulo de Grupos

### `M.crear_grupo(nombre, descripcion, icono, color)`

Crea un nuevo grupo de items.

**Parámetros:**
- `nombre` (string): Nombre del grupo
- `descripcion` (string): Descripción (opcional)
- `icono` (string): Ruta del icono (opcional)
- `color` (string): Código de color (opcional)

**Retorna:** boolean (true si se creó exitosamente)

---

### `M.eliminar_grupo(nombre)`

Elimina un grupo existente.

**Parámetros:**
- `nombre` (string): Nombre del grupo a eliminar

**Retorna:** boolean

---

### `M.agregar_item_a_grupo(nombre_grupo, item_key)`

Añade un item a un grupo.

**Parámetros:**
- `nombre_grupo` (string): Nombre del grupo
- `item_key` (string): Clave del item (formato: "item:ID:0:0:0")

**Retorna:** boolean

---

### `M.obtener_todos_grupos()`

Obtiene todos los grupos definidos.

**Retorna:** table con todos los grupos

---

### `M.obtener_items_de_grupo(nombre_grupo)`

Obtiene los items de un grupo.

**Parámetros:**
- `nombre_grupo` (string): Nombre del grupo

**Retorna:** table con los items

---

## 🔍 Módulo de Escaneo

### `M.modules.full_scan.iniciar_full_scan()`

Inicia un escaneo completo de la casa de subastas.

**Ejemplo:**
```lua
if M.modules and M.modules.full_scan then
    M.modules.full_scan.iniciar_full_scan()
end
```

---

### `M.modules.full_scan.detener_scan()`

Detiene el escaneo en progreso.

---

## 🎯 Módulo Sniper

### `M.modules.sniper.iniciar(config)`

Inicia el modo sniper.

**Parámetros:**
- `config` (table): Configuración
  - `max_pct` (number): % máximo del mercado
  - `auto_buy` (boolean): Compra automática
  - `sound` (boolean): Alerta sonora

---

### `M.modules.sniper.detener()`

Detiene el modo sniper.

---

## 💰 Módulo de Mercado

### `M.modules.market_data.get_market_value(item_key)`

Obtiene el valor de mercado de un item.

**Parámetros:**
- `item_key` (string): Clave del item

**Retorna:** number (valor en cobre) o nil

---

### `M.modules.market_data.get_min_buyout(item_key)`

Obtiene el buyout mínimo actual.

**Parámetros:**
- `item_key` (string): Clave del item

**Retorna:** number o nil

---

## 📜 Módulo de Historial

### `M.modules.accounting.registrar_venta(item_key, cantidad, precio)`

Registra una venta.

**Parámetros:**
- `item_key` (string): Clave del item
- `cantidad` (number): Cantidad vendida
- `precio` (number): Precio total en cobre

---

### `M.modules.accounting.registrar_compra(item_key, cantidad, precio)`

Registra una compra.

---

### `M.modules.accounting.get_historial(dias)`

Obtiene el historial de transacciones.

**Parámetros:**
- `dias` (number): Número de días hacia atrás (0 = todo)

**Retorna:** table con transacciones

---

## 🎨 Constantes de Colores

```lua
local COLORS = {
    primary = {0.2, 0.6, 1.0, 1},      -- Azul
    success = {0.2, 0.8, 0.2, 1},      -- Verde
    warning = {1.0, 0.6, 0.0, 1},      -- Naranja
    danger = {0.9, 0.2, 0.2, 1},       -- Rojo
    gold = {1.0, 0.82, 0.0, 1},        -- Dorado
    bg_dark = {0.05, 0.05, 0.08, 0.95},
    bg_medium = {0.1, 0.1, 0.12, 0.9},
    bg_light = {0.15, 0.15, 0.18, 0.85},
    border = {0.3, 0.3, 0.35, 1},
    text = {0.9, 0.9, 0.9, 1},
    text_dim = {0.6, 0.6, 0.6, 1},
}
```

---

## 📀 Datos Guardados

El addon guarda datos en `SavedVariables`:

- `aux` - Datos generales de AUX
- `AuxTradingMarketData` - Datos de mercado
- `AuxTradingAccounting` - Historial de transacciones

---

## ⚠️ Notas Importantes

### Compatibilidad Lua 5.0

WoW 1.12 usa Lua 5.0, que tiene limitaciones:

- **No usar closures**: Las variables locales no son accesibles en funciones anidadas
- **Usar `this`**: En scripts de botones, usar `this` para referirse al frame
- **Usar `math.mod()`**: En lugar del operador `%`

**Incorrecto:**
```lua
local mi_var = "valor"
btn:SetScript("OnClick", function()
    print(mi_var) -- ERROR: mi_var es nil
end)
```

**Correcto:**
```lua
btn.mi_var = "valor"
btn:SetScript("OnClick", function()
    print(this.mi_var) -- OK
end)
```

---

*Documentación por Elnazzareno*  
*El Séquito del Terror* 🔮
