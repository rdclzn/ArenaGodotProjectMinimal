extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var player_path : NodePath

@onready var nav_agent = $NavigationAgent3D

var player = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	player = get_node(player_path)

func _physics_process(delta):
	velocity = (player.global_position - self.global_position).normalized() * SPEED
	look_at(Vector3(player.global_position.x, player.global_position.y, player.global_position.z), Vector3.UP)
	move_and_slide()
