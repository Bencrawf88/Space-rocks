extends RigidBody2D
@export var engine_power = 1000
@export var spin_power = 8000
@export var bullet_scene : PackedScene
@export var fire_rate = 0.25
@export var max_shield = 100
@export var shield_regen = 5

signal lives_changed
signal dead
signal shield_changed

var reset_pos = false
var lives = 0: set = set_lives
var can_shoot = true
var thrust = Vector2.ZERO
var rotation_dir = 0 
var shield = 0 : set = set_shield

enum{INIT, ALIVE, INVULNERABLE, DEAD}
var state = INIT

var screensize = Vector2.ZERO 

func _ready():
	change_state(ALIVE)
	screensize = get_viewport_rect().size
	$GunCooldown.wait_time = fire_rate
	
func change_state(new_state):
	match new_state:
		INIT:
			$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.modulate.a = 0.5
		ALIVE:
			$CollisionShape2D.set_deferred("disabled", false)
			$Sprite2D.modulate.a = 1.0
			collision_layer = 1
			collision_mask = 1
		INVULNERABLE:
			#$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.modulate.a = 0.5
			$InvulnerabilityTimer.start()
			collision_layer = 2
			collision_mask = 2
		DEAD:
			$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.hide()
			linear_velocity = Vector2.ZERO
			dead.emit()
			$EngineSound.stop()
	state = new_state
	
func _process(delta):
	get_input()
	shield += shield_regen*delta

func set_shield(value):
	value = min(value, max_shield)
	shield = value
	shield_changed.emit(shield/max_shield)
	if shield <= 0:
		lives -=1
		explode()


func get_input():
	if get_parent().playing == true:
		thrust = Vector2.ZERO
		if state in [DEAD,INIT]:
			return
		if Input.is_action_pressed("thrust"):
			thrust = transform.x * engine_power
			if not $EngineSound.playing:
				$EngineSound.play()
		if Input.is_action_just_released("thrust"):
			$EngineSound.stop()
		if Input.is_action_pressed("reverse"):
			thrust = -transform.x * engine_power
			if not $EngineSound.playing:
				$EngineSound.play()
		if Input.is_action_just_released("reverse"):
			$EngineSound.stop()
		rotation_dir = Input.get_axis("rotate_left", "rotate_right")
		if Input.is_action_pressed("shoot") and can_shoot:
			shoot()



func _physics_process(delta):
	constant_force = thrust
	constant_torque = rotation_dir * spin_power
 
func _integrate_forces(physics_state):
	var xform = physics_state.transform
	xform.origin.x = wrapf(xform.origin.x, 0, screensize.x)
	xform.origin.y = wrapf(xform.origin.y, 0, screensize.y)
	physics_state.transform = xform
	if reset_pos:
		physics_state.transform.origin - screensize/2 
		reset_pos = false

func shoot():
	if state == INVULNERABLE:
		return
	can_shoot = false
	$GunCooldown.start()
	var b = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.start($Muzzle.global_transform)
	$LaserSound.play()
	
func _on_gun_cooldown_timeout():
	can_shoot = true

func set_lives(value):
	lives = value
	lives_changed.emit(lives)
	if lives <= 0:
		change_state(DEAD)
	else: 
		change_state(INVULNERABLE)
	shield = max_shield

func reset():
	reset_pos = true
	$Sprite2D.show()
	lives = 3
	change_state(ALIVE)
	
	

func _on_invulnerability_timer_timeout():
	change_state(ALIVE)


func _on_body_entered(body):
	if body.is_in_group("rocks"):
		shield -= body.size*25
		body.explode()

func explode():
	$Explosion.show()
	$Explosion/AnimationPlayer.play("explosion")
	await $Explosion/AnimationPlayer.animation_finished
	$Explosion.hide()
