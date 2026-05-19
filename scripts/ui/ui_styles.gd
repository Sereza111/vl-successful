class_name UiStyles
extends RefCounted

const COLOR_BG := Color(0.08, 0.09, 0.12, 1)
const COLOR_CARD := Color(0.102, 0.153, 0.267, 1)
const COLOR_CARD_ACCENT := Color(0.29, 0.5, 1.0, 1)
const COLOR_CHIP := Color(0.835, 0.659, 0.263, 1)
const COLOR_PANEL := Color(0.12, 0.14, 0.18, 1)
const COLOR_PANEL_LIGHT := Color(0.16, 0.18, 0.24, 1)
const COLOR_GOLD := Color(0.9, 0.75, 0.55, 1)
const COLOR_SUCCESS := Color(0.4, 0.95, 0.55, 1)
const COLOR_TAX_APP := Color(0.15, 0.22, 0.18, 1)


static func bank_card_panel(radius: int = 16) -> StyleBoxFlat:
	return card_panel(radius, COLOR_CARD)


static func card_panel(radius: int = 16, bg: Color = COLOR_CARD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


static func app_panel(radius: int = 12, bg: Color = COLOR_PANEL_LIGHT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func swipe_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.28, 1)
	style.set_corner_radius_all(28)
	return style


static func swipe_thumb() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.85, 0.45, 1)
	style.set_corner_radius_all(24)
	return style


static func dock_button(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(28)
	return style


static func tab_selected() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.55, 0.38, 1)
	style.set_corner_radius_all(8)
	return style


static func document_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.96, 0.98, 1)
	style.border_color = Color(0.75, 0.78, 0.82, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
