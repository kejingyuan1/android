# Economy.gd — 经济系统
# 管理资金、税收、建设费用、维护费用

extends Node

const INITIAL_MONEY := 500000.0
const INITIAL_WOOD := 50000.0
const INITIAL_STONE := 30000.0
const TAX_RATE := 2.0
const ROAD_MAINTENANCE := 1.0
const COMMERCIAL_INCOME := 5.0
const INDUSTRIAL_INCOME := 8.0

var money: float = INITIAL_MONEY
var wood: float = INITIAL_WOOD
var stone: float = INITIAL_STONE
var total_income_last_tick: float = 0.0
var total_expense_last_tick: float = 0.0
var total_population: int = 0

var _grid_map: Node = null
var _building_system: Node = null
var _road_system: Node = null
var _service_system: Node = null

signal money_changed(money: float)

func setup(grid_map: Node, building_system: Node, road_system: Node, service_system: Node = null):
	_grid_map = grid_map
	_building_system = building_system
	_road_system = road_system
	_service_system = service_system

## 每 tick 结算
func process_tick():
	total_income_last_tick = 0.0
	total_expense_last_tick = 0.0

	# 住宅税收
	total_population = _building_system.get_residential_population()
	var tax_income = total_population * TAX_RATE
	total_income_last_tick += tax_income

	# 商业收入（作为税收缴给城市）
	var commercial_income = _building_system.get_commercial_count() * COMMERCIAL_INCOME
	total_income_last_tick += commercial_income

	# 工业收入
	var industrial_income = _building_system.get_industrial_count() * INDUSTRIAL_INCOME
	total_income_last_tick += industrial_income

	# 道路维护费
	var road_count = _road_system.get_road_cell_count()
	var road_cost = road_count * ROAD_MAINTENANCE
	total_expense_last_tick += road_cost

	# 公共服务维护费
	if _service_system:
		var svc_upkeep = _service_system.get_total_upkeep()
		total_expense_last_tick += svc_upkeep

	# 结算
	money += total_income_last_tick - total_expense_last_tick
	money = max(money, -5000.0)  # 允许少量负债

	emit_signal("money_changed", money)

## 检查是否支付得起
func can_afford(amount: float) -> bool:
	return money >= amount

## 花费
func spend(amount: float, reason: String = "") -> bool:
	if money < amount:
		return false
	money -= amount
	total_expense_last_tick += amount
	emit_signal("money_changed", money)
	return true

## 是否破产
func is_bankrupt() -> bool:
	return money < -1000.0

## 检查是否支付得起多资源消耗
func can_afford_resources(gold_amount: float, wood_amount: float, stone_amount: float) -> bool:
	return money >= gold_amount and wood >= wood_amount and stone >= stone_amount

## 消耗多资源
func spend_resources(gold_amount: float, wood_amount: float, stone_amount: float, reason: String = "") -> bool:
	if not can_afford_resources(gold_amount, wood_amount, stone_amount):
		return false
	money -= gold_amount
	wood -= wood_amount
	stone -= stone_amount
	total_expense_last_tick += gold_amount + wood_amount + stone_amount
	emit_signal("money_changed", money)
	return true

## 重置经济
func reset():
	money = INITIAL_MONEY
	wood = INITIAL_WOOD
	stone = INITIAL_STONE
	total_income_last_tick = 0.0
	total_expense_last_tick = 0.0
	total_population = 0
