# ServiceBuildingNode.gd — 服务建筑精灵（裁剪透明背景）
extends Node2D

const CELL_SIZE := 32

var _cell_x: int = 0
var _cell_y: int = 0
var _service_type: int = 0
var _sprite: Sprite2D = null

const SPRITE_PATHS := {
	"police": "res://assets/textures/buildings/police.png",
	"fire": "res://assets/textures/buildings/fire_station.png",
	"hospital": "res://assets/textures/buildings/hospital.png",
	"school": "res://assets/textures/buildings/office.png",
}

func setup(gx: int, gy: int, service_type: int):
	_cell_x = gx
	_cell_y = gy
	_service_type = service_type
	position = Vector2(gx * CELL_SIZE + CELL_SIZE / 2, gy * CELL_SIZE + CELL_SIZE / 2)

	_sprite = Sprite2D.new()
	_sprite.z_index = 5
	add_child(_sprite)
	_update_texture()

func _update_texture():
	if not _sprite:
		return

	var tex_path = ""
	match _service_type:
		0: tex_path = SPRITE_PATHS["police"]
		1: tex_path = SPRITE_PATHS["fire"]
		2: tex_path = SPRITE_PATHS["hospital"]
		3: tex_path = SPRITE_PATHS["school"]

	if tex_path == "" or not ResourceLoader.exists(tex_path):
		return

	var tex = load(tex_path)
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.scale = Vector2(0.8, 0.8)
