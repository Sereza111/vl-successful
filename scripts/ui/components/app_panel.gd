extends PanelContainer

@export var panel_color: Color = UiStyles.COLOR_PANEL_LIGHT


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyles.app_panel(12, panel_color))
