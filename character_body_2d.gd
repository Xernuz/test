extends CharacterBody2D

@export var walk_speed := 200.0
@export var run_speed := 350.0
@export_range(0, 1) var acceleration := 0.1
@export_range(0, 1) var deceleration := 0.1
@export var jump_force := -800.0
@export_range(0, 1) var decelerate_on_jump_release := 0.5
@export var dash_speed := 1200.0
@export var dash_duration := 0.15
@export var climbing = false

@onready var icon := $Icon
@onready var cshape := $CollisionShape2D
@onready var ray1 := $RayCast2D_1
@onready var ray2 := $RayCast2D_2
@onready var coyote_timer := $CoyoteTimer
@onready var jump_buffer_timer := $JumpBufferTimer
@onready var dash_timer := $DashTimer

var is_crouching := false
var crouch_intent := false
var was_sprinting := false
var jump_buffered := false
var can_coyote_jump := false
var last_direction := 1.0
var is_dashing := false
var can_dash := false 

var standing_cshape = preload("res://resources/standing_cshape.tres")
var crouching_cshape = preload("res://resources/crouching_cshape.tres")

func _physics_process(delta: float) -> void:
	if climbing and Input.is_action_pressed("climb"):
		velocity.y = 0  # Cancel vertical velocity (gravity)

		# Move up/down with input
		if Input.is_action_pressed("up"):
			velocity.y = -walk_speed
		elif Input.is_action_pressed("crouch"):
			velocity.y = walk_speed
		else:
			velocity.y = 0

		# Optional: allow small horizontal movement on rope
		var horizontal_input = Input.get_axis("left", "right")
		velocity.x = horizontal_input * walk_speed * 0.5  # slower side movement

		# Jump off the rope
		if Input.is_action_just_pressed("jump"):
			climbing = false  # Exit climbing state
			velocity.y = jump_force  # Apply jump force upward

		move_and_slide()
		return
		
	if is_dashing:
		velocity.y = 0
	else:
		if not is_on_floor():
			velocity += get_gravity() * 1.5 * delta

		if Input.is_action_just_pressed("jump"):
			jump()
		elif Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= decelerate_on_jump_release

		crouch_intent = Input.is_action_pressed("crouch")
		var direction := Input.get_axis("left", "right")

		if direction:
			last_direction = direction
			velocity.x = move_toward(velocity.x, direction * current_speed(), current_speed() * acceleration)
			icon.flip_h = direction < 0
			icon.position.x = 64 if direction < 0 else 70
			if is_crouching:
				update_crouch_rotation()
		else:
			velocity.x = move_toward(velocity.x, 0, walk_speed * deceleration)

		update_crouch_state()

	if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
		start_dash()
		can_dash = false

	var was_on_floor = is_on_floor()
	move_and_slide()

	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_coyote_jump = true
		coyote_timer.start()
	elif not was_on_floor and is_on_floor() and jump_buffered:
		jump_buffered = false
		jump()

func current_speed() -> float:
	if is_on_floor():
		was_sprinting = Input.is_action_pressed("run")
	return run_speed if was_sprinting else walk_speed

func jump():
	if is_on_floor() or can_coyote_jump:
		velocity.y = jump_force
		can_coyote_jump = false
	elif not jump_buffered:
		jump_buffered = true
		jump_buffer_timer.start()

func start_dash():
	is_dashing = true
	velocity.x = dash_speed * last_direction
	velocity.y = 0
	dash_timer.start(dash_duration)

func _on_dash_timer_timeout():
	is_dashing = false
	velocity.x = 0

func _on_coyote_timer_timeout():
	can_coyote_jump = false

func _on_jump_buffer_timer_timeout():
	jump_buffered = false

func is_clear_above() -> bool:
	return not ray1.is_colliding() and not ray2.is_colliding()

func update_crouch_state():
	var crouch_needed = crouch_intent or not is_clear_above()
	if crouch_needed and not is_crouching:
		enter_crouch()
	elif not crouch_needed and is_crouching:
		exit_crouch()

func update_crouch_rotation():
	var _sprinting_crouch = was_sprinting and abs(velocity.x) > 0
	if last_direction < 0:
		icon.rotation_degrees = -90 if not was_sprinting else 90
		icon.position.x = 64
		icon.position.y = 35 if not was_sprinting else 30
	else:
		icon.rotation_degrees = 90 if not was_sprinting else -90
		icon.position.x = 70
		icon.position.y = 35 if not was_sprinting else 30

func enter_crouch():
	is_crouching = true
	jump_force = -600
	cshape.shape = crouching_cshape
	cshape.position.y = 31
	update_crouch_rotation()

func exit_crouch():
	is_crouching = false
	jump_force = -800
	cshape.shape = standing_cshape
	cshape.position.y = 16
	icon.rotation_degrees = 0
	icon.position.y = 16
	icon.position.x = 64 if last_direction < 0 else 70

# Call this when player picks up dash item
func grant_dash():
	print("Dash Granted")
	can_dash = true
	
func start_climbing():
	climbing = true
	velocity = Vector2.ZERO

func stop_climbing():
	climbing = false

func _on_death_body_entered(body: Node2D) -> void:
	body.global_position = Vector2(160, -90)
