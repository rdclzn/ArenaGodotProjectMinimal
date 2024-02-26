extends CharacterBody3D

signal player_fired

#consts
const MAXSPEED : float = 10.0        # default: 32.0
const WALKSPEED : float = 5.0       # default: 16.0
const STOPSPEED : float = 10.0       # default: 10.0
const GRAVITY : float = 10.0         # default: 80.0
const ACCELERATE : float = 10.0      # default: 10.0
const AIRACCELERATE : float = 0.25   # default: 0.7
const MOVEFRICTION : float = 2.0     # default: 6.0
const JUMPFORCE : float = 5.0       # default: 27.0
const AIRCONTROL : float = 0.9       # default: 0.9
const STEPSIZE : float = 1.8         # default: 1.8
const MAXHANG : float = 0.2          # default: 0.2
const PLAYER_HEIGHT : float = 3.6    # default: 3.6
const CROUCH_HEIGHT : float = 2.0    # default: 2.0
const LADDER_LAYER = 2

var direction
var deltaTime : float = 0.0
var movespeed : float = 32.0
var fmove : float = 0.0
var smove : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var hangtime : float = 0.2
var impact_velocity : float = 0.0
var is_dead : bool = false
var jump_press : bool = false
var crouch_press : bool = false
var ground_plane : bool = false
var prev_y : float = 0.0
var ladder_normal : Vector3 = Vector3.UP
var _can_fire : bool = false
var _can_fire_counter = 0

enum {GROUNDED, FALLING}
var state = GROUNDED

#bullets
var bullet = load("res://prefabs/rifle_bullet.tscn")
var bulletFX = load("res://prefabs/particles_hit_metal.tscn")
var instances
#vars
@export var sensitivity = 0.10
@export var max_angle = 80
@export var min_angle = -70
var look_rot = Vector3.ZERO
@onready var head = $head
@onready var firesfx = $ShootingSFX
@onready var raycast = $head/RayCast3D
@onready var gun     = $"head/Fps Rig AKM/GunBarrel"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = GRAVITY

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	PlayerAutoload.player = self
	
func _input(event):
	if event is InputEventMouseMotion:
		look_rot.y -= event.relative.x
		look_rot.x -= event.relative.y
		look_rot.x = clamp(look_rot.x, min_angle, max_angle)
	
	movespeed = WALKSPEED if Input.is_action_pressed("shift") else MAXSPEED
	
	if Input.is_action_just_pressed("fire"):
		fire_shot()
	
	# Handle Jump.
	if Input.is_action_just_pressed("jump") and !jump_press:
		jump_press = true
	elif Input.is_action_just_released("jump"):
		jump_press = false

func _physics_process(delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
	deltaTime = delta
	update_fire()
	ground_normal = get_floor_normal()
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	fmove = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	smove = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction = (transform.basis * Vector3(-fmove, 0, -smove)).normalized()
	direction = Vector2(direction.x, direction.z)
		
	#Rotation
	rotation_degrees.y = look_rot.y
	head.rotation_degrees.x = look_rot.x
	
	$AnimationTree.set("parameters/conditions/stop", input_dir == Vector2.ZERO and is_on_floor())
	$AnimationTree.set("parameters/conditions/walk", input_dir == Vector2.UP and is_on_floor())
	$AnimationTree.set("parameters/conditions/right", input_dir == Vector2.RIGHT and is_on_floor())
	$AnimationTree.set("parameters/conditions/left", input_dir == Vector2.LEFT and is_on_floor())
	$AnimationTree.set("parameters/conditions/retreat", input_dir == Vector2.DOWN and is_on_floor())
	$AnimationTree.set("parameters/conditions/right_walk", input_dir.angle() < Vector2.UP.angle() and is_on_floor())
	$AnimationTree.set("parameters/conditions/left_walk", (input_dir.angle() - Vector2.UP.angle() > 0) and input_dir.angle() < Vector2.LEFT.angle() and is_on_floor())
	$AnimationTree.set("parameters/conditions/left_retreat", (input_dir.angle() - Vector2.LEFT.angle() > 0) and input_dir.angle() < Vector2.DOWN.angle() and is_on_floor())
	$AnimationTree.set("parameters/conditions/right_retreat", (input_dir.angle() - Vector2.DOWN.angle() > 0) and is_on_floor())
	$AnimationTree.set("parameters/conditions/jump", (velocity.y != 0) or !is_on_floor())
	$AnimationTree.set("parameters/conditions/landed", is_on_floor())
	
	if(velocity.y != 0 or (!is_on_floor() and !is_on_ceiling())):
		state = FALLING
	elif is_on_ceiling() or is_on_floor():
		state = GROUNDED
	
	
	jump_button()
	check_state()
	
	move_and_slide()


func jump_button():
	if is_dead: 
		return
	if state == GROUNDED and jump_press:
		$JumpSFX.play_sfx()
		$JumpGruntSFX.play()
		state = FALLING
		jump_press = false
		velocity.y += JUMPFORCE

func check_state():
	match(state):
		GROUNDED:
			ground_move()
		FALLING:
			air_move()
			
func ground_move():
	if direction:
		process_footsteps(true)
		var current_horizontal_v = Vector2(velocity.x, velocity.z)
		current_horizontal_v = Vector2(velocity.x, velocity.z).lerp(movespeed * direction, ACCELERATE * deltaTime) 
		velocity.x = current_horizontal_v.x
		velocity.z = current_horizontal_v.y
	else:
		process_footsteps(false)
		var current_horizontal_v = Vector2(velocity.x, velocity.z)
		current_horizontal_v = Vector2(velocity.x, velocity.z).lerp(Vector2.ZERO, MOVEFRICTION * deltaTime) 
		velocity.x = current_horizontal_v.x
		velocity.z = current_horizontal_v.y
		
	impact_velocity = 0

func air_move():
	var wishdir = (global_transform.basis.x * smove + -global_transform.basis.z * fmove).normalized()
	air_accelerate(wishdir, STOPSPEED if velocity.dot(wishdir) < 0 else AIRACCELERATE)
	
	velocity.y -= GRAVITY * deltaTime
	if global_transform.origin[1] >= prev_y: 
		prev_y = global_transform.origin[1]
		
	impact_velocity = abs(int(round(velocity[1])))


func air_accelerate(wishdir : Vector3, accel : float):
	var addspeed     : float
	var accelspeed   : float
	var currentspeed : float
	
	var wishspeed = slope_speed(ground_normal[1])
	
	currentspeed = velocity.dot(wishdir)
	addspeed = wishspeed - currentspeed
	if addspeed <= 0.0: 
		return
	
	accelspeed = accel * deltaTime * wishspeed
	if accelspeed > addspeed: accelspeed = addspeed
	
	velocity[0] += accelspeed * wishdir[0]
	velocity[1] += accelspeed * wishdir[1]
	velocity[2] += accelspeed * wishdir[2]

"""
===============
air_control
===============
"""
func air_control(wishdir : Vector3):
	var dot        : float
	var speed      : float
	var original_y : float
	
	if fmove == 0.0: 
		return
	
	original_y = velocity[1]
	velocity[1] = 0.0
	speed = velocity.length()
	velocity = velocity.normalized()
	
	# Change direction while slowing down
	dot = velocity.dot(wishdir)
	if dot > 0.0 :
		var k = 32.0 * AIRCONTROL * dot * dot * deltaTime
		velocity[0] = velocity[0] * speed + wishdir[0] * k
		velocity[1] = velocity[1] * speed + wishdir[1] * k
		velocity[2] = velocity[2] * speed + wishdir[2] * k
		velocity = velocity.normalized()
	
	velocity[0] *= speed
	velocity[1] = original_y
	velocity[2] *= speed

"""
===============
slope_speed

Change velocity while moving up/down sloped ground
===============
"""
func slope_speed(y_normal : float):
	if y_normal <= 0.97:
		var multiplier = y_normal if velocity[1] > 0.0 else 2.0 - y_normal
		return clamp(movespeed * multiplier, 5.0, movespeed * 1.2)
	return movespeed


func fire_shot():
	if _can_fire:
		#firesfx.play()
		$ShootingSFX2.play_sfx()
		_can_fire = false
		_can_fire_counter = 0
		emit_signal("player_fired")
		instances = bullet.instantiate()
		instances.position = gun.global_position
		instances.transform.basis = gun.global_transform.basis
		get_parent().get_parent().add_child(instances)
		var center_of_camera = get_viewport().get_size()/2
		var ray_origin = head.project_ray_origin(center_of_camera)
		var ray_end    = ray_origin + head.project_ray_normal(center_of_camera)*50
		
		var new_intersection = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var Intersection = get_world_3d().direct_space_state.intersect_ray(new_intersection)
		
		if !(Intersection.is_empty()):
			var shotFX = bulletFX.instantiate()
			get_parent().get_parent().add_child(shotFX)
			shotFX.global_position = Intersection.position
			shotFX.look_at(ray_origin + Intersection.normal, Vector3.UP)
			shotFX.find_child("GPUParticles3D").emitting = true
			shotFX.find_child("GPUParticles3D2").emitting = true
			shotFX.find_child("AudioStreamPlayer3D").play()
			

func update_fire():
	if _can_fire == false:
		if _can_fire_counter > 0.167:
			_can_fire = true
			_can_fire_counter += deltaTime
		else:
			_can_fire_counter += deltaTime

func _on_timer_timeout():
	pass

func process_footsteps(play : bool) -> void:
	if($Timer.is_stopped() and play):
		$Timer.start()
		$PlayerFootstep.pitch_scale = randf_range(0.7,0.95)
		$PlayerFootstep.play_sfx()
	elif !play:
		$Timer.stop()
		$PlayerFootstep.stop()
