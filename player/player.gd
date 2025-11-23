extends CharacterBody3D

@export var speed: float = 5.0
@export var swim_speed: float = 3.0
@export var jump_velocity: float = 4.5
@export var swim_jump_velocity: float = 6.0
@export var turn_speed: float = 3.0
@export var water_level: float = 0.0
@export var coyote_time: float = 0.15

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_swimming: bool = false
var coyote_timer: float = 0.0
var is_attacking: bool = false

@onready var model: Node3D = $MakoModel
@onready var animation_player: AnimationPlayer = $MakoModel/AnimationPlayer

func _ready() -> void:
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Sword":
		is_attacking = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not is_attacking:
		_attack()

func _attack() -> void:
	is_attacking = true
	if animation_player:
		animation_player.play("Sword")

func _physics_process(delta: float) -> void:
	# Check if swimming
	is_swimming = position.y < water_level

	if is_swimming:
		_handle_swimming(delta)
	else:
		_handle_walking(delta)

	move_and_slide()

func _handle_walking(delta: float) -> void:
	# Track coyote time for more forgiving jumps
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump (with coyote time)
	var can_jump := is_on_floor() or coyote_timer > 0
	if Input.is_action_just_pressed("jump") and can_jump:
		velocity.y = jump_velocity
		coyote_timer = 0.0

	# Handle rotation with A/D
	var turn_input := Input.get_axis("turn_left", "turn_right")
	model.rotation.y -= turn_input * turn_speed * delta

	# Handle forward/backward movement with W/S
	var move_input := Input.get_axis("move_backward", "move_forward")

	if move_input != 0:
		# Get forward direction based on model rotation
		var forward := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))

		# Apply movement in facing direction
		velocity.x = forward.x * move_input * speed
		velocity.z = forward.z * move_input * speed

		# Play walk animation if available (not during attack)
		if animation_player and animation_player.has_animation("Walk") and not is_attacking:
			if animation_player.current_animation != "Walk":
				animation_player.play("Walk")
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

		# Play idle animation if available (not during attack)
		if animation_player and animation_player.has_animation("Idle") and not is_attacking:
			if animation_player.current_animation != "Idle":
				animation_player.play("Idle")

func _handle_swimming(delta: float) -> void:
	# Handle jump out of water
	if Input.is_action_just_pressed("jump"):
		velocity.y = swim_jump_velocity
	elif velocity.y > 0:
		# Still rising from jump, apply gravity
		velocity.y -= gravity * delta
	else:
		# Float at water level
		velocity.y = (water_level - position.y) * 5.0

	# Handle rotation with A/D
	var turn_input := Input.get_axis("turn_left", "turn_right")
	model.rotation.y -= turn_input * turn_speed * delta

	# Handle forward/backward movement with W/S
	var move_input := Input.get_axis("move_backward", "move_forward")

	if move_input != 0:
		# Get forward direction based on model rotation
		var forward := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))

		# Apply movement in facing direction
		velocity.x = forward.x * move_input * swim_speed
		velocity.z = forward.z * move_input * swim_speed

		# Play swim animation if available, otherwise walk (not during attack)
		if not is_attacking:
			if animation_player and animation_player.has_animation("Swim"):
				if animation_player.current_animation != "Swim":
					animation_player.play("Swim")
			elif animation_player and animation_player.has_animation("Walk"):
				if animation_player.current_animation != "Walk":
					animation_player.play("Walk")
	else:
		# Decelerate in water
		velocity.x = move_toward(velocity.x, 0, swim_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0, swim_speed * 0.5)

		# Play idle animation (not during attack)
		if animation_player and animation_player.has_animation("Idle") and not is_attacking:
			if animation_player.current_animation != "Idle":
				animation_player.play("Idle")
