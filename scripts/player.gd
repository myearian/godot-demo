extends CharacterBody3D
## Keyboard-only FPS controller: WASD move, arrows look, F flashlight, C crouch.

const STAND_HEIGHT := 1.70
const CROUCH_HEIGHT := 0.62
const STAND_EYE := 1.65
const CROUCH_EYE := 0.50
const CAPSULE_RADIUS := 0.28
const WALK_SPEED := 4.3
const CROUCH_SPEED := 1.9
const LOOK_SPEED := 1.85
const PITCH_LIMIT := 1.35
const FLASHLIGHT_ENERGY := 8.0

@onready var _camera: Camera3D = $Camera3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _flashlight: SpotLight3D = $Camera3D/Flashlight

var _yaw := 0.0
var _pitch := 0.0
var _crouching := false
var _eye_y := STAND_EYE
var _capsule: CapsuleShape3D


func _ready() -> void:
	_capsule = _shape.shape as CapsuleShape3D
	if _capsule == null:
		_capsule = CapsuleShape3D.new()
		_shape.shape = _capsule
	_capsule.radius = CAPSULE_RADIUS
	_apply_stance(false, true)
	_flashlight.light_energy = 0.0
	_camera.current = true


func _physics_process(delta: float) -> void:
	_look(delta)
	_stance(delta)

	var input_2d := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_back", "move_forward")
	)
	var wish := (transform.basis * Vector3(input_2d.x, 0.0, -input_2d.y))
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var speed := CROUCH_SPEED if _crouching else WALK_SPEED
	var target := wish * speed
	velocity.x = target.x
	velocity.z = target.z
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if Input.is_action_just_pressed("flashlight"):
		var on := _flashlight.light_energy <= 0.01
		_flashlight.light_energy = FLASHLIGHT_ENERGY if on else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _look(delta: float) -> void:
	var yaw_axis := Input.get_axis("look_left", "look_right")
	var pitch_axis := Input.get_axis("look_down", "look_up")
	_yaw -= yaw_axis * LOOK_SPEED * delta
	_pitch += pitch_axis * LOOK_SPEED * delta
	_pitch = clampf(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	rotation.y = _yaw
	_camera.rotation.x = _pitch


func _stance(delta: float) -> void:
	var want_crouch := Input.is_action_pressed("crouch")
	if _crouching and not want_crouch and not _can_stand():
		want_crouch = true
	_apply_stance(want_crouch, false)
	var target_eye := CROUCH_EYE if _crouching else STAND_EYE
	_eye_y = lerpf(_eye_y, target_eye, 1.0 - exp(-12.0 * delta))
	_camera.position.y = _eye_y


func _apply_stance(crouch: bool, instant: bool) -> void:
	_crouching = crouch
	var height := CROUCH_HEIGHT if crouch else STAND_HEIGHT
	_capsule.height = height
	_shape.position.y = height * 0.5
	if instant:
		_eye_y = CROUCH_EYE if crouch else STAND_EYE
		_camera.position.y = _eye_y


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = CAPSULE_RADIUS
	probe.height = STAND_HEIGHT
	params.shape = probe
	params.transform = global_transform.translated(Vector3(0.0, STAND_HEIGHT * 0.5, 0.0))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return space.intersect_shape(params, 1).is_empty()
