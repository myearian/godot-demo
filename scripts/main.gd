extends Node3D
## BackroomsInfinite Godot slice — environment, chunk streamer, player, hum.

@onready var _world = $ChunkWorld
@onready var _player: CharacterBody3D = $Player
@onready var _env_node: WorldEnvironment = $WorldEnvironment
@onready var _hint: Label = $HUD/Hint

var _hint_age := 0.0


func _ready() -> void:
	_setup_environment()
	_world.setup()
	_player.global_position = Vector3(0.0, 0.05, 0.0)
	# Stream the spawn ring before the first physics frame so the floor exists.
	_world.update_world(_player, 0.0)
	print("BackroomsInfinite (Godot) — core loop ready.")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	_world.update_world(_player, delta)
	_hint_age += delta
	if _hint_age > 8.0 and _hint.modulate.a > 0.0:
		_hint.modulate.a = maxf(0.0, _hint.modulate.a - delta * 0.4)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0196, 0.0157, 0.0118) # #050403
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.905, 0.612) # #ffe79c
	env.ambient_light_energy = 0.10
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.0275, 0.0235, 0.0196) # #070605
	env.fog_density = 1.0
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 42.0
	env.fog_depth_curve = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env_node.environment = env
