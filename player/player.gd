# Player Controller for 3D Movement
#
# KEY 3D CONCEPTS:
# - In 3D, we use Vector3 instead of Vector2: Vector3(x, y, z)
# - Y axis is UP/DOWN (vertical), X and Z are horizontal
# - CharacterBody3D is the 3D equivalent of CharacterBody2D
# - rotation.y controls horizontal rotation (turning left/right)
# - We use sin/cos to convert rotation angle into movement direction

extends CharacterBody3D

# Movement parameters - same concept as 2D but we have separate horizontal (x,z) and vertical (y)
@export var speed: float = 5.0
@export var swim_speed: float = 3.0
@export var jump_velocity: float = 4.5          # Positive Y = up in 3D
@export var swim_jump_velocity: float = 6.0
@export var turn_speed: float = 3.0              # Radians per second for rotation
@export var water_level: float = 0.0             # Y position of water surface
@export var coyote_time: float = 0.15            # Grace period for jumping after leaving ground

# Get gravity from project settings (Physics > 3D > Default Gravity)
# In 3D, gravity is typically around 9.8 (realistic) or higher for snappier feel
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_swimming: bool = false
var coyote_timer: float = 0.0
var is_attacking: bool = false

# Reference to the visual model - in 3D we often separate the collision body from the visual mesh
# This lets us rotate the model independently (for smooth turning) while collision stays axis-aligned
@onready var model: Node3D = $MakoModel

# AnimationPlayer works the same as 2D - controls skeletal/transform animations
@onready var animation_player: AnimationPlayer = $MakoModel/AnimationPlayer


func _ready() -> void:
	# Connect to animation_finished signal to know when attack animation completes
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: String) -> void:
	# Reset attack state when sword animation finishes
	if anim_name == "Sword":
		is_attacking = false


func _unhandled_input(event: InputEvent) -> void:
	# Handle attack input separately from physics for immediate response
	if event.is_action_pressed("attack") and not is_attacking:
		_attack()


func _attack() -> void:
	is_attacking = true
	if animation_player:
		animation_player.play("Sword")


func _physics_process(delta: float) -> void:
	# Check if player is below water level (Y position comparison)
	# In 3D: position.y is vertical height, position.x and position.z are horizontal
	is_swimming = position.y < water_level

	if is_swimming:
		_handle_swimming(delta)
	else:
		_handle_walking(delta)

	# move_and_slide() works like 2D - applies velocity and handles collisions
	# In 3D it automatically handles slopes, stairs, etc.
	move_and_slide()


# --- WALKING STATE ---

func _handle_walking(delta: float) -> void:
	_update_coyote_time(delta)
	_apply_gravity(delta)
	_handle_jump(jump_velocity)
	_handle_rotation(delta)
	_handle_horizontal_movement(delta, speed)
	_update_movement_animation("Walk", "Idle")


func _update_coyote_time(delta: float) -> void:
	# COYOTE TIME: Small grace period after leaving ground where you can still jump
	# Makes platforming feel more forgiving
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta


func _apply_gravity(delta: float) -> void:
	# GRAVITY: In 3D, gravity affects velocity.y (vertical axis)
	# We subtract because positive Y is up, so gravity pulls down (negative)
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_jump(jump_power: float) -> void:
	# JUMPING: Set positive Y velocity to go up
	var can_jump := is_on_floor() or coyote_timer > 0
	if Input.is_action_just_pressed("jump") and can_jump:
		velocity.y = jump_power
		coyote_timer = 0.0  # Consume coyote time


# --- SWIMMING STATE ---

func _handle_swimming(delta: float) -> void:
	_handle_swim_vertical(delta)
	_handle_rotation(delta)
	_handle_horizontal_movement(delta, swim_speed)
	_update_swim_animation()


func _handle_swim_vertical(delta: float) -> void:
	# SWIMMING JUMP: Launch out of water with upward velocity
	if Input.is_action_just_pressed("jump"):
		velocity.y = swim_jump_velocity
	elif velocity.y > 0:
		# Still rising from jump - apply gravity so we arc back down
		velocity.y -= gravity * delta
	else:
		# FLOATING AT WATER LEVEL:
		# This creates a "spring" effect that pulls player toward water_level
		# (water_level - position.y) = how far below/above water we are
		# Multiply by 5.0 to control how quickly we return to surface
		# If below water: positive velocity (push up)
		# If above water: negative velocity (pull down)
		velocity.y = (water_level - position.y) * 5.0


func _update_swim_animation() -> void:
	# Play swim or walk animation based on movement
	var is_moving := velocity.x != 0 or velocity.z != 0

	if is_moving and not is_attacking:
		_play_animation("Swim", "Walk")  # Fallback to Walk if no Swim animation
	elif not is_attacking:
		_play_animation("Idle")


# --- SHARED MOVEMENT HELPERS ---

func _handle_rotation(delta: float) -> void:
	# ROTATION: In 3D, rotation.y is rotation around the Y axis (turning left/right)
	# This is different from 2D where we'd use rotation directly
	# We rotate the MODEL, not the CharacterBody3D, for smoother visuals
	var turn_input := Input.get_axis("turn_left", "turn_right")
	model.rotation.y -= turn_input * turn_speed * delta


func _handle_horizontal_movement(_delta: float, move_speed: float) -> void:
	# Get input for forward/backward movement
	var move_input := Input.get_axis("move_backward", "move_forward")

	if move_input != 0:
		# CONVERTING ROTATION TO DIRECTION:
		# This is key for 3D! We use trigonometry to get a direction vector from an angle.
		# sin(angle) gives X component, cos(angle) gives Z component
		# Y is 0 because we're moving horizontally
		#
		# Think of it like a unit circle on the XZ plane:
		# - angle 0 = facing +Z direction (forward in Godot)
		# - angle PI/2 = facing +X direction (right)
		var forward := _get_forward_direction()

		# Apply movement in the direction we're facing
		# We multiply by move_input so negative (S key) moves backward
		velocity.x = forward.x * move_input * move_speed
		velocity.z = forward.z * move_input * move_speed
	else:
		# DECELERATION: Gradually reduce horizontal velocity to 0
		# move_toward is same as 2D - smoothly approaches target value
		# Swimming decelerates slower (0.5x) for a floaty feel
		var decel_rate := move_speed * 0.5 if is_swimming else move_speed
		velocity.x = move_toward(velocity.x, 0, decel_rate)
		velocity.z = move_toward(velocity.z, 0, decel_rate)


func _get_forward_direction() -> Vector3:
	# Convert the model's Y rotation into a direction vector on the XZ plane
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))


func _update_movement_animation(walk_anim: String, idle_anim: String) -> void:
	# Update animation based on whether we're moving
	var is_moving := velocity.x != 0 or velocity.z != 0

	if is_moving and not is_attacking:
		_play_animation(walk_anim)
	elif not is_attacking:
		_play_animation(idle_anim)


# --- ANIMATION HELPERS ---

func _play_animation(anim_name: String, fallback: String = "") -> void:
	# Play animation if it exists and isn't already playing
	if not animation_player:
		return

	if animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
	elif fallback and animation_player.has_animation(fallback):
		if animation_player.current_animation != fallback:
			animation_player.play(fallback)
