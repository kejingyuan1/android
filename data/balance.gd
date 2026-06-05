# Balance.gd — 游戏平衡性参数
# 所有数值配置集中在此，方便调整

extends Node

## 经济参数
const INITIAL_MONEY := 100000.0
const TAX_RATE := 2.0          # 每人每 tick
const ROAD_BUILD_COST := 50.0  # 每格建设费
const ROAD_MAINTENANCE := 1.0  # 每格每 tick
const BUILD_COST := 100.0      # 新建建筑费用
const UPGRADE_COST_MULT := 3.0 # 升级费用倍数

## 人口参数
const LV1_POPULATION := 10
const LV2_POPULATION := 40
const LV3_POPULATION := 100

## Sim Tick
const TICK_INTERVAL_NORMAL := 2.0  # 秒
const TICK_INTERVAL_FAST := 1.0    # 秒

## 存档
const AUTOSAVE_INTERVAL := 30.0  # 秒

## 网格
const GRID_WIDTH := 240
const GRID_HEIGHT := 160
const CELL_SIZE := 32

## RCI 需求参数
const RCI_BASE_RESIDENTIAL := 50.0
const RCI_BASE_COMMERCIAL := 30.0
const RCI_BASE_INDUSTRIAL := 20.0
const RCI_SUPPRESS_PER_BUILDING := 2.0
const RCI_BOOST_PER_JOB := 3.0

## 建筑升级条件
const UPGRADE_POP_REQ_BASE := 50  # 升 L2 所需总人口
const UPGRADE_POP_REQ_PER_LV := 50
