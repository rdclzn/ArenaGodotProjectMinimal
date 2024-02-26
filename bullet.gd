extends Node3D

const SPEED = 150

@onready var mesh = $MeshInstance3D
@onready var ray = $RayCast3D
#@onready var particles1 = $GPUParticles3D/GPUParticles3D
#@onready var particles2 = $GPUParticles3D/GPUParticles3D2
#@onready var particles_audio = $GPUParticles3D/AudioStreamPlayer3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += transform.basis*Vector3(0, 0, -SPEED)*delta
	if ray.is_colliding():
		ray.enabled = false
		if ray.get_collider().is_in_group("enemy"):
			ray.get_collider().hit()
		await get_tree().create_timer(1.0).timeout
		queue_free()

func _on_timer_timeout():
	queue_free()
