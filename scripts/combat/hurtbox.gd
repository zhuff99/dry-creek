class_name Hurtbox
extends Area2D
## The part of something a bullet can hit. Put it on the "hurtbox" physics
## layer, shape it over the sprite (you aim at what you see), and connect
## `shot`. Anything can be a target this way: a bottle, a snake, a deputy.
##
## Walls and trees stop bullets with their ordinary "world" collision
## instead, which is the footprint they stand on.

signal shot(hit: Shot)


func take_shot(hit: Shot) -> void:
	shot.emit(hit)
