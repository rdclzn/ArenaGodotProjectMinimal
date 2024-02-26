extends Node3D

@export var head : Camera3D

var is_shooting : bool  = false
var shoot_timer : float = 0.0
var bullet = load("res://prefabs/rifle_bullet.tscn")
var instance

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(is_shooting):
		$AnimationTreeForAK.set("parameters/conditions/shoot", true)
		shoot_timer += delta
	if shoot_timer > 0.167:
		$AnimationTreeForAK.set("parameters/conditions/shoot", false)
		is_shooting = false
		shoot_timer = 0.0
	pass


func _on_player_player_fired():
	is_shooting = true
	pass # Replace with function body.
