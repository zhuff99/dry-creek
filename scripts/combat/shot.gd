class_name Shot
extends RefCounted
## One bullet arriving at something: what a Hurtbox hands to its owner.

var weapon: WeaponData
var shooter: Node
## Where it struck, in world coordinates.
var point: Vector2
## The way the bullet was travelling.
var direction: Vector2
var damage: int


func _init(p_weapon: WeaponData, p_shooter: Node, p_point: Vector2, p_direction: Vector2) -> void:
	weapon = p_weapon
	shooter = p_shooter
	point = p_point
	direction = p_direction
	damage = p_weapon.damage
