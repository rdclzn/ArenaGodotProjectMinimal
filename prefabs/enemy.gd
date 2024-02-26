extends CharacterBody3D

var player = null
const SPEED = 5.0

@export var player_path : NodePath

@onready var nav_agent = $NavigationAgent3D

# Called when the node enters the scene tree for the first time.
func _ready():
	velocity = Vector3.ZERO
	player = get_node(player_path)
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	nav_agent.set_path_max_distance(0) 
		
	# Make sure to not await during _ready.
	call_deferred("actor_setup")

func actor_setup():
	# Wait for the first physics frame so the NavigationServer can sync.
	await get_tree().physics_frame

	# Now that the navigation map is no longer empty, set the movement target.
	set_movement_target(player.global_position)

func set_movement_target(movement_target: Vector3):
	nav_agent.set_target_position(movement_target)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if nav_agent.is_navigation_finished():
		return
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	velocity = Vector3.ZERO
	
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
	rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
	
	move_and_slide()
