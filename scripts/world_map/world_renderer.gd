# WorldRenderer.gd — 超级大地图渲染器
# 将世界地图地形生成为可缩放的纹理
# 使用分块生成 + await 避免阻塞主线程

extends Node2D

## 信号：生成进度 (0.0 ~ 1.0)
signal generation_progress(pct: float)

## 外部引用
var world_gen = null   # WorldGenerator 实例
var sprite: Sprite2D = null
var city_sprites: Dictionary = {}  # key: "x,y" → Sprite2D

## 渲染参数（横屏：2560×2048 纹理覆盖 ~123k×98k 世界）
const BASE_TEX_W := 2560
const BASE_TEX_H := 2048
const TILES_PER_PIXEL := 48           # 世界格/像素
const WORLD_W := 100000.0             # 世界宽度（用于精灵缩放 X）
const WORLD_H := 100000.0             # 世界高度（用于精灵缩放 Y）
const CHUNK_ROWS := 32                # 每块行数（每 32 行 yield 一帧）
const CITY_ICON_SIZE := 16
const CITY_MARKER_SCALE := 4.0        # 建筑贴图缩放（1024px → ~4000 世界单位）
const CITY_CLICK_RADIUS := 5000       # 点击检测半径（世界单位）

## 资源图标层
var resource_markers: Node2D = null

func _ready():
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)

	resource_markers = Node2D.new()
	add_child(resource_markers)

## 生成世界地图纹理（异步协程，调用者需 await）
## 纹理缓存到 user://world_map_{seed}.png，避免重复生成
func generate(world_gen_instance):
	world_gen = world_gen_instance
	if not world_gen:
		generation_progress.emit(1.0)
		return

	var seed = world_gen.world_seed
	var cache_path = "user://world_map2_%d.png" % seed  # "2"=横屏版
	var elapsed = 0.0

	# 检查是否有缓存
	if FileAccess.file_exists(cache_path):
		print("【T=", Time.get_ticks_msec(), "】找到世界地图缓存: ", cache_path)
		var cached_img = Image.load_from_file(cache_path)
		print("【T=", Time.get_ticks_msec(), "】缓存图片加载完成")
		if cached_img:
			print("【T=", Time.get_ticks_msec(), "】开始创建纹理...")
			var tex = ImageTexture.create_from_image(cached_img)
			print("【T=", Time.get_ticks_msec(), "】纹理创建完成, 开始赋值给精灵...")
			sprite.texture = tex
			print("【T=", Time.get_ticks_msec(), "】精灵赋值完成")
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(WORLD_W / BASE_TEX_W, WORLD_H / BASE_TEX_H)
			sprite.position = Vector2(0, 0)
			generation_progress.emit(1.0)
			print("世界地图从缓存加载完成")
			return

	print("开始生成世界地图纹理 (", BASE_TEX_W, "×", BASE_TEX_H, ")")
	var img = Image.create(BASE_TEX_W, BASE_TEX_H, false, Image.FORMAT_RGBA8)
	var start_time = Time.get_ticks_usec()

	for py in range(BASE_TEX_H):
		for px in range(BASE_TEX_W):
			var wx = px * TILES_PER_PIXEL
			var wy = py * TILES_PER_PIXEL
			var t = world_gen.get_terrain(wx, wy)
			var c = world_gen.get_terrain_color(t)
			img.set_pixel(px, py, c)

		# 每 CHUNK_ROWS 行 yield 一帧 → 加载画面可以正常动画
		if py % CHUNK_ROWS == 0 and py > 0:
			generation_progress.emit(float(py) / float(BASE_TEX_H))
			await get_tree().process_frame

	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 缩放精灵（横屏 2560×2048 纹理覆盖 ~123k×98k 世界）
	sprite.scale = Vector2(WORLD_W / BASE_TEX_W, WORLD_H / BASE_TEX_H)
	sprite.position = Vector2(0, 0)

	elapsed = (Time.get_ticks_usec() - start_time) / 1000000.0
	print("世界地图生成完成: ", "%.2f" % elapsed, "秒")

	# 保存缓存
	var err = img.save_png(cache_path)
	if err == OK:
		print("世界地图缓存已保存: ", cache_path)
	else:
		push_warning("世界地图缓存保存失败: ", err)

	generation_progress.emit(1.0)

## 根据文明 ID 获取主城建筑纹理路径
func _get_capital_texture_path(civ_id: int) -> String:
	var civ_names = ["china", "rome", "britain", "egypt", "japan", "viking"]
	if civ_id < 0 or civ_id >= civ_names.size():
		civ_id = 0
	return "res://assets/textures/world_map/capital_" + civ_names[civ_id] + ".png"

## 在城市位置放置主城建筑贴图
func place_city_marker(wx: int, wy: int, civ_id: int, city_name: String):
	print("【T=", Time.get_ticks_msec(), "】place_city_marker 开始")
	var marker = Sprite2D.new()

	# 加载文明对应的主城建筑纹理
	var tex_path = _get_capital_texture_path(civ_id)
	var tex = load(tex_path)
	print("【T=", Time.get_ticks_msec(), "】纹理加载完成, tex=", tex != null)

	if tex:
		marker.texture = tex
		marker.scale = Vector2(CITY_MARKER_SCALE, CITY_MARKER_SCALE)
	else:
		# 回退：文明颜色的圆形标记
		print("【T=", Time.get_ticks_msec(), "】开始生成圆形回退纹理")
		var img = Image.create(CITY_ICON_SIZE, CITY_ICON_SIZE, false, Image.FORMAT_RGBA8)
		var civ_color = _get_civ_color(civ_id)
		var cx = CITY_ICON_SIZE / 2
		var cy = CITY_ICON_SIZE / 2
		for y in range(CITY_ICON_SIZE):
			for x in range(CITY_ICON_SIZE):
				var dx = x - cx
				var dy = y - cy
				var dist = sqrt(dx * dx + dy * dy)
				if dist < cx - 2:
					img.set_pixel(x, y, civ_color)
				elif dist < cx:
					img.set_pixel(x, y, civ_color.lightened(0.3))
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		tex = ImageTexture.create_from_image(img)
		marker.texture = tex
		print("【T=", Time.get_ticks_msec(), "】圆形纹理创建完成")

	marker.centered = true
	marker.position = Vector2(wx, wy)
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.z_index = 10
	print("【T=", Time.get_ticks_msec(), "】开始 add_child(marker)")
	add_child(marker)
	print("【T=", Time.get_ticks_msec(), "】add_child 完成")

	city_sprites[str(wx) + "," + str(wy)] = marker

	# 主城发光：在建筑背后加一圈光晕
	for layer in range(3):
		var glow = Sprite2D.new()
		glow.name = "CityGlow_%d" % layer
		var gimg = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		var gcol = Color(1.0, 0.95, 0.7, 0.0)
		for gy in range(24):
			for gx in range(24):
				var gdx = gx - 12
				var gdy = gy - 12
				var gdist = sqrt(gdx*gdx + gdy*gdy)
				if gdist < 12:
					var a = (1.0 - gdist/12.0) * 0.35
					gimg.set_pixel(gx, gy, Color(1, 0.95, 0.7, a))
		glow.texture = ImageTexture.create_from_image(gimg)
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.centered = true
		glow.position = Vector2(wx, wy)
		glow.scale = Vector2(30 + layer * 20, 30 + layer * 20)
		glow.z_index = marker.z_index - 1
		add_child(glow)

		# 光晕脉动呼吸动画（每层不同相位/周期）
		var gt = glow.create_tween().set_loops()
		gt.set_trans(Tween.TRANS_SINE)
		gt.set_ease(Tween.EASE_IN_OUT)
		var phase = layer * 0.4
		gt.tween_interval(phase)
		gt.tween_property(glow, "modulate", Color(1, 1, 1, 0.9), 1.2 - layer * 0.2)
		gt.tween_property(glow, "modulate", Color(1, 1, 1, 0.15), 1.2 - layer * 0.2)

	# 主城呼吸发光（建筑本身的亮度脉冲）
	var glow_tween = marker.create_tween().set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(marker, "modulate", Color(1.4, 1.4, 1.4), 1.5)
	glow_tween.tween_property(marker, "modulate", Color(0.9, 0.9, 0.9), 1.5)

## 在世界地图海洋区域生成游鱼（需在地图生成后调用）
## wx, wy: 城市中心坐标，鱼会生成在城市附近的浅海区域
func spawn_ocean_fish(wx: int, wy: int, count: int = 30) -> void:
	# 清理旧鱼
	for child in get_children():
		if child.name.begins_with("Fish_"):
			child.queue_free()

	if not world_gen:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = world_gen.world_seed + 999

	for i in range(count):
		# 在城市附近 20000 单位半径内找浅海
		var found := false
		var fx := 0
		var fy := 0
		for _attempt in 100:
			fx = wx + rng.randi_range(-20000, 20000)
			fy = wy + rng.randi_range(-20000, 20000)
			if fx < 0 or fx >= 100000 or fy < 0 or fy >= 100000:
				continue
			var t = world_gen.get_terrain(fx, fy)
			if t == 1:  # 浅海
				found = true
				break
		if not found:
			continue

		# 鱼贴图：8×6 像素鱼形（→方向, 尾部在右侧）
		# 形状: 头部尖, 身体圆, 尾巴分叉
		var fsz = 8
		var img = Image.create(fsz, 6, false, Image.FORMAT_RGBA8)
		var fcol = Color(rng.randf_range(0.3, 0.8), rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 0.95), 0.85)
		var fcol2 = Color(fcol.r * 0.7, fcol.g * 0.7, fcol.b * 0.7, 0.7)  # 暗色尾部
		# 像素鱼模板（1=身体, 2=尾巴, 0=透明）
		# 眼睛: 4,2 位置
		var fish_template = [
			[0, 0, 0, 1, 0, 0, 2, 0],
			[0, 0, 1, 1, 1, 1, 0, 2],
			[0, 1, 1, 1, 1, 1, 1, 0],
			[0, 1, 1, 1, 1, 1, 1, 0],
			[0, 0, 1, 1, 1, 1, 0, 2],
			[0, 0, 0, 1, 0, 0, 2, 0],
		]
		for py in range(6):
			for px in range(fsz):
				var v = fish_template[py][px]
				if v == 1:
					img.set_pixel(px, py, fcol)
				elif v == 2:
					img.set_pixel(px, py, fcol2)
				# v=0: 透明（默认）

		# 随机加一个小亮点当作眼睛
		if rng.randf() > 0.3:
			img.set_pixel(3, 2, Color(1, 1, 1, 0.9))

		var fish = Sprite2D.new()
		fish.name = "Fish_%d" % i
		fish.texture = ImageTexture.create_from_image(img)
		fish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fish.centered = true
		fish.position = Vector2(fx, fy)
		var s = rng.randf_range(15, 40)
		fish.scale = Vector2(s, s)
		fish.z_index = 1
		# 鱼随机朝左或朝右
		fish.rotation = rng.randf_range(-0.3, 0.3)  # 轻微上下偏
		if rng.randf() > 0.5:
			fish.flip_h = true  # 一半朝左
		add_child(fish)

		# 游动动画
		var tween = fish.create_tween().set_loops()
		tween.set_parallel(true)
		var fwd = Vector2(1, 0).rotated(fish.rotation)
		if fish.flip_h:
			fwd = -fwd
		var dist = rng.randf_range(1500, 4000)
		var dur = rng.randf_range(6.0, 14.0)
		tween.tween_property(fish, "position", fish.position + fwd * dist, dur)
		tween.tween_property(fish, "position:y", fish.position.y + rng.randf_range(-200, 200), dur * 0.4)

## 获取世界坐标对应的城市标记
func get_city_at(wx: int, wy: int):
	var closest_key = null
	var closest_dist = 99999999.0
	for key in city_sprites.keys():
		var parts = key.split(",")
		var cx = int(parts[0])
		var cy = int(parts[1])
		var d = Vector2(wx - cx, wy - cy).length()
		if d < closest_dist:
			closest_dist = d
			closest_key = key
	if closest_dist < CITY_CLICK_RADIUS:
		return closest_key
	return null

## 更新资源标记层（显示附近资源）
## 使用单一大纹理替代逐个 Sprite2D，大幅减少节点数
func show_resource_markers(wx: int, wy: int, radius: int = 20):
	# 清空旧的标记
	for child in resource_markers.get_children():
		child.queue_free()

	if not world_gen:
		return

	var size := radius * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var any_resource := false

	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nx = wx + dx
			var ny = wy + dy
			if nx < 0 or nx >= 100000 or ny < 0 or ny >= 100000:
				continue
			var r = world_gen.get_resource(nx, ny)
			if r != 0:
				any_resource = true
				var rc = world_gen.get_resource_color(r)
				var px = dx + radius
				var py = dy + radius
				img.set_pixel(px, py, rc)

	if not any_resource:
		return

	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2(wx - radius, wy - radius)
	sprite.scale = Vector2(8, 8)
	sprite.z_index = 5
	resource_markers.add_child(sprite)

func _get_civ_color(civ_id: int) -> Color:
	match civ_id:
		0: return Color(0.9, 0.2, 0.15)  # 中国红
		1: return Color(0.7, 0.2, 0.5)   # 罗马紫
		2: return Color(0.2, 0.4, 0.7)   # 英国蓝
		3: return Color(0.85, 0.7, 0.2)  # 埃及金
		4: return Color(0.8, 0.2, 0.2)   # 日本红
		5: return Color(0.2, 0.5, 0.3)   # 维京绿
		_: return Color(0.5, 0.5, 0.5)
