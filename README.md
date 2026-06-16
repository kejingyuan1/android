# City Builder — Godot 4.6 等距城市建造游戏

基于 Godot 4.6 的 2.5D 等距视角（Isometric）城市建造游戏，类似《部落冲突》（Clash of Clans）的视角风格。

## 快速开始

1. 安装 **Godot 4.6**（或更高版本）
2. 打开此项目文件夹（Godot 会识别 `project.godot`）
3. 点击运行 ▶（F5）
4. 从**世界地图**点击一座城市进入**城市视图**

> **首次运行可能需要点击 `项目 → 重新加载当前项目`**，确保所有脚本和纹理缓存生效。

## 技术栈

| 技术 | 版本 |
|------|------|
| Godot | 4.6+ |
| 渲染 | 2D Canvas（等距 TileMap） |
| 语言 | GDScript |
| 纹理生成 | Python 3 + PIL（`scripts/gen_iso_*.py`） |
| 地形生成 | FastNoiseLite（内置） |

## 游戏架构

### 视图层级

```
Main (Node2D)
├── WorldMapLayer         # 超级世界地图（未激活）
├── CityViewLayer         # 城市视图（核心）
│   ├── GameWorld
│   │   ├── GridRenderer  ← 旧的平面渲染器（等距模式下隐藏）
│   │   ├── RoadMap       ← 旧的道路层（等距模式下隐藏）
│   │   ├── ZoneMap       ← 旧的分区层（等距模式下隐藏）
│   │   ├── HighlightMap  ← 旧的高亮层（等距模式下隐藏）
│   │   ├── BuildingContainer  # 建筑精灵容器
│   │   └── SelectionRect
│   ├── CityCamera        ← 带 camera_controller.gd 脚本
│   └── GameManager       ← 核心游戏管理器
├── GlobalGame            ← 全局控制器，管理世界↔城市切换
└── UICanvas              ← UI（CanvasLayer, layer=10）
```

### 核心脚本

| 脚本 | 职责 | 关键方法 |
|------|------|----------|
| `game_manager.gd` | 游戏主控制器、输入处理、全量渲染 | `_ready()`, `_handle_game_input()`, `_full_render()`, `_update_cell_visual()` |
| `grid_map.gd` | 网格数据模型（240×160） | `get_cell()`, `set_terrain()`, TerrainType 枚举 |
| `iso_renderer.gd` | 等距渲染器（地形+道路+高亮） | `generate()`, `grid_to_world()`, `world_to_grid()`, `update_road()` |
| `camera_controller.gd` | 相机控制（平移/缩放/惯性） | `_input()`, `_clamp_position()` |
| `road_system.gd` | 道路绘制系统 | `start_draw()`, `continue_draw()`, `end_draw()` |
| `building_system.gd` | 建筑自动生长和升级 | `process_tick()`, `_try_grow_building()` |
| `building_node.gd` | 建筑精灵节点 | `setup()`, `update_level()`, `get_building_info()` |
| `grid_renderer.gd` | 旧的平面地形渲染（被iso取代） | `generate()` |
| `terrain_generator.gd` | FastNoiseLite 地形数据生成 | `generate()` |
| `global_game.gd` | 全局状态和视图切换 | `enter_city_view()`, `exit_to_world_map()` |
| `economy.gd` | 经济系统 | `setup()`, `process_tick()` |

## 等距（Isometric）系统

### 核心原理

地图网格大小 **240×160**，每个单元格在等距视角下渲染为 **64×32** 像素的菱形。

```
TILE_W = 64, TILE_H = 32
HALF_W = 32, HALF_H = 16
```

### 坐标转换

```gdscript
# 网格坐标 → 世界坐标（精灵位置）
grid_to_world(gx, gy) → Vector2((gx - gy) * 32, (gx + gy) * 16)

# 世界坐标 → 网格坐标（鼠标拾取）
world_to_grid(pos) → Vector2(
	floor((pos.x/32 + pos.y/16) / 2),
	floor((pos.y/16 - pos.x/32) / 2)
)
```

### 菱形碰撞检测

```gdscript
func is_in_diamond(x, y, cx, cy):
	return abs(x-cx)/cx + abs(y-cy)/cy <= 1.0
```

### TileMap 配置

等距 TileMap 必须设置以下属性：

```gdscript
tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
tileset.tile_size = Vector2i(64, 32)
tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

### 地图边界

240×160 网格的等距菱形世界范围：
- X: **-5088 ~ 7648**（中心约 1280）
- Y: **0 ~ 6368**（中心约 3184）

相机位置推荐 **`(1280, 2800)`**，缩放 **`0.18`**。

**⚠️ 重要**：`global_game.gd` 的 `enter_city_view()` 会重置相机位置和缩放，修改那个函数中的 `city_center_x/y` 和 `zoom`。

## 等距 vs 平面渲染

### 关键规则

项目从平面顶视图重构为等距视图，两种渲染器并存但**等距模式下必须隐藏平面层**。

```gdscript
# _generate_terrain_texture() 中必须执行：
grid_renderer.visible = false
road_map_layer.visible = false
zone_map_layer.visible = false
highlight_map_layer.visible = false
```

### IsoRenderer 调用链

```
game_manager._ready()
  → _generate_terrain_texture()
	→ iso_renderer.setup(grid_map, seed)     # 传入网格引用
	→ iso_renderer.generate()                 # 创建TileMap、填充地形、道路、高亮
	  → _clear_children()                     # 清理旧子节点
	  → _create_terrain_tileset()             # 创建地形 TileMap
	  → _fill_terrain()                       # 填充240×160地形格
	  → _create_road_tileset()               # 创建道路 TileMap
	  → init_overlays()                       # 创建高亮/虚影 Sprite
```

## 道路系统

### 道路纹理

道路贴图为 **128×64** 的 spritesheet，包含 4 个 **64×32** 子图块：

| 子图索引 | 坐标 | 含义 |
|----------|------|------|
| 0 | (0,0) | 水平道路 |
| 1 | (1,0) | 垂直道路 |
| 2 | (0,1) | 十字路口 |
| 3 | (1,1) | 孤岛（单格） |

**⚠️ `texture_region_size` 必须设为 `(64, 32)`**，不能设为 `(128, 64)`，否则子图块 (1,0)/(0,1)/(1,1) 越界渲染为空。

### 道路放置流程

```
用户点击选择道路工具
  → bottom_bar 设置 _current_variant = 0/1/2
  → 点击地图 → _handle_game_input()
	→ iso_renderer.world_to_grid() 获取网格坐标
	→ _handle_tool_input() → _handle_road_input()
	→ road_system.start_draw(cell, road_type)  # 设置数据
	→ _update_cell_visual(x, y)                # 渲染（调用 iso_renderer.update_road）
	→ 拖拽: continue_draw + _update_cell_visual
	→ 松手: end_draw + _full_render()          # 全量重绘
```

### 道路邻居检测

```gdscript
_get_road_coords(cx, cy):
  检测上下左右四个邻居（TerrainType.ROAD）
  水平+垂直邻居 → Vector2i(0,1) 十字
  水平邻居 → Vector2i(0,0) 水平
  垂直邻居 → Vector2i(1,0) 垂直
  无邻居 → Vector2i(1,1) 孤岛
```

## 地形系统

### 地形类型

| 枚举值 | 类型 | 纹理文件 |
|--------|------|----------|
| 0 | WATER (水域) | `water_0/1/2.png` |
| 1 | SAND (沙滩) | `sand.png` |
| 2 | GRASS (草地) | `grass_0/1/2.png` |
| 3 | FOREST (森林) | `forest.png` |
| 4 | HILL (丘陵) | `mountain.png` |
| 5 | MOUNTAIN (山脉) | `mountain.png` |

所有地形纹理在 **`assets/textures/isometric/`** 下，64×32 像素。

### 地形生成

使用 `terrain_generator.gd`（FastNoiseLite 双层噪声）生成 240×160 的天然地形数据：
- 海拔噪声 → WATER/SAND/GRASS/HILL/MOUNTAIN
- 湿度噪声 → 区分 GRASS/FOREST
- 后处理：去除孤立水域、扩展沙滩

## 纹理生成

### 地形纹理（Python + PIL）

```bash
python scripts/gen_iso_textures.py
```

生成 `assets/textures/isometric/` 下的所有 64×32 菱形纹理。

- 草地：绿色底色 + 彩色小花
- 水域：蓝色 + 波纹
- 山脉：灰度岩层 + 水平条纹 + 边缘阴影（**不能有雪顶**, 否则看起来像独立的银色小块）
- 高亮/虚影/阴影：半透明菱形

### 道路纹理（Python + PIL）

```bash
python scripts/gen_iso_roads.py
```

生成 `assets/textures/roads/iso_*.png`（128×64 spritesheet）。

三种样式：
- **土路**：棕色路面，浅色标线
- **沥青路**：深灰色路面，黄色中心线，混凝土路缘
- **高速路**：深色路面，亮黄线

关键要素：
- 菱形中心亮、边缘暗（模拟光照）
- 路缘高光/阴影
- 黄色中心标线按方向绘制
- 十字路口有交叉阴影

## 已知技术坑

### GDScript 语法

1. **`ImageTexture` 没有 `texture_filter`** — 必须在 Sprite2D/TileMap 上设置：`sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`
2. **`"." * n` 是 Python 语法** — Godot 用 `".".repeat(n)`
3. **`.tscn` 不支持 `#` 注释**
4. **`await` 必须配合对应的 await** — 否则协程不等待
5. **`ColorRect` 全屏遮罩** — 必须用 `set_anchors_preset(PRESET_FULL_RECT)`，不能只设 size
6. **`civ_select_ui.visible = false` 可能不生效** — 需要 `remove_child() + queue_free() + await process_frame`

### 等距系统

7. **道路 texture_region_size** — 128×64 spritesheet 必须设 `(64, 32)`，不是 `(128, 64)`
8. **动画/云朵只应有一套** — 多套会在同一位置创建重叠节点
9. **`building_ref` 类型必须正确** — 手动放置的建筑使用 Sprite2D，不应设置 `building_ref`（`BuildingNode` 才有 `update_level`/`get_building_info`）
10. **`full_render` 必须清空 iso_renderer 的道路层** — 调用 `iso_renderer.clear_all_roads()`
11. **`enter_city_view()` 会重置相机** — 修改 `global_game.gd` 中的相机位置才对

### Git

12. **仓库地址**使用了 `ghfast.top` 代理，token 推完即清

## 文件清单

```
project.godot                    # 项目配置
main.tscn                        # 主场景
scripts/
├── game_manager.gd              # 游戏主控制器
├── grid_map.gd                  # 网格数据模型 (240×160)
├── iso_renderer.gd              # 等距渲染器
├── camera_controller.gd         # 相机控制
├── grid_renderer.gd             # 平面渲染器（废弃）
├── road_system.gd               # 道路系统
├── zone_system.gd               # 分区系统
├── building_system.gd           # 建筑系统
├── building_node.gd             # 建筑节点
├── economy.gd                   # 经济系统
├── terrain_generator.gd         # 地形生成
├── save_manager.gd              # 存档管理
├── gen_iso_textures.py          # 地形纹理生成 (Python)
├── gen_iso_roads.py             # 道路纹理生成 (Python)
├── ui/
│   ├── bottom_bar.gd            # 底部工具栏
│   ├── top_bar.gd               # 顶部状态栏
│   ├── rci_bar.gd               # RCI 需求面板
│   ├── info_card.gd             # 信息卡片
│   └── sub_menu.gd              # 子菜单
└── world_map/
	├── global_game.gd           # 全局控制器
	├── world_renderer.gd        # 世界地图渲染
	└── world_camera.gd          # 世界地图相机

assets/textures/
├── isometric/                   # 等距地形纹理 (64×32)
│   ├── grass_0/1/2.png
│   ├── water_0/1/2.png
│   ├── sand.png
│   ├── forest.png
│   ├── mountain.png
│   ├── dirt.png
│   ├── highlight.png
│   ├── ghost.png
│   ├── shadow.png
│   └── wave.png
├── roads/                       # 道路纹理
│   ├── iso_dirt.png             # 等距土路 (128×64)
│   ├── iso_asphalt.png          # 等距沥青路 (128×64)
│   ├── iso_highway.png          # 等距高速路 (128×64)
│   ├── dirt_sheet.png           # 平面道路（旧）
│   ├── asphalt_sheet.png
│   └── highway_sheet.png
└── buildings/                   # 建筑精灵
	├── house1.png
	├── house2.png
	├── apartment.png
	├── shop.png
	├── factory.png
	└── office.png
```
