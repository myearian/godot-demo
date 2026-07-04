extends Node2D
## Entry point for the BackroomsInfinite Godot project.
## This is a blank starter — build your game out from here.


func _ready() -> void:
	print("BackroomsInfinite (Godot) — blank starter ready.")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		# Esc quits when running as a standalone window.
		get_tree().quit()
