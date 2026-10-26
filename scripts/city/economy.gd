# Règles de l'économie de la ville, sans rien d'affichage (comme le moteur de nos autres jeux).
# Chaque heure de jeu : électricité, emplois, bonheur, habitants qui arrivent ou partent, argent.
extends RefCounted

var rules := {}
var money := 0.0
var population := 0.0
var workers := 0.0
var jobs := 0.0
var capacity := 0.0
var happiness := 60.0
var power_prod := 0.0
var power_use := 0.0
var power_ratio := 1.0
var income := 0.0            # par heure de jeu
var upkeep := 0.0            # par heure de jeu
var wind_factor := 1.0
var breakdown := {}          # détail affiché au survol


func setup(economy_rules: Dictionary) -> void:
	rules = economy_rules
	money = float(rules.get("start_money", 50000))


# buildings : liste de { type, def, active, happy_bonus, pollution }
# daylight : 0 la nuit, 1 en plein soleil
func tick_hour(buildings: Array, daylight: float) -> void:
	power_prod = 0.0
	power_use = 0.0
	capacity = 0.0
	var raw_jobs := 0.0
	var tax_jobs := 0.0
	upkeep = 0.0
	var happy_sum := 0.0
	var happy_weight := 0.0
	var prod_wind := 0.0
	var prod_solar := 0.0
	for b in buildings:
		var def: Dictionary = b["def"]
		upkeep += float(def.get("upkeep", 0.0))
		if not b["active"]:
			continue
		var p := float(def.get("power", 0.0))
		if p > 0.0:
			if b["type"] == "solar":
				prod_solar += p * daylight
			else:
				prod_wind += p * wind_factor
		else:
			power_use += -p
		var res := float(def.get("residents", 0.0))
		capacity += res
		var j := float(def.get("jobs", 0.0))
		raw_jobs += j
		tax_jobs += j * float(def.get("tax_per_worker", 0.0))
		if res > 0.0:
			var local := 60.0 + float(b["happy_bonus"]) - float(b["pollution"])
			happy_sum += local * res
			happy_weight += res
	power_prod = prod_wind + prod_solar
	power_ratio = 1.0 if power_use <= 0.0 else clampf(power_prod / power_use, 0.0, 1.0)
	jobs = raw_jobs * power_ratio

	var active_pop := population * 0.55
	workers = minf(active_pop, jobs)
	var unemployment := 0.0 if active_pop < 1.0 else 1.0 - workers / active_pop
	var base_happy := 60.0 if happy_weight <= 0.0 else happy_sum / happy_weight
	var unemployment_malus := unemployment * float(rules.get("unemployment_happiness", 25))
	var blackout_malus := (1.0 - power_ratio) * float(rules.get("blackout_happiness", 30))
	happiness = clampf(base_happy - unemployment_malus - blackout_malus, 0.0, 100.0)

	# Les habitants arrivent tant que la ville est attirante
	var target := capacity * clampf(0.35 + happiness / 100.0 * 0.75, 0.0, 1.0) * lerpf(0.5, 1.0, power_ratio)
	population += (target - population) * float(rules.get("move_in_rate", 0.12))
	if absf(target - population) < 0.5:
		population = target
	population = maxf(population, 0.0)

	var avg_tax := 0.0 if raw_jobs <= 0.0 else tax_jobs / raw_jobs
	var tax_res := population * float(rules.get("tax_per_resident", 0.35))
	var tax_work := workers * avg_tax
	income = tax_res + tax_work
	money += income - upkeep
	breakdown = {
		"tax_res": tax_res, "tax_work": tax_work, "upkeep": upkeep,
		"wind": prod_wind, "solar": prod_solar, "unemployment": unemployment,
		"unemployment_malus": unemployment_malus, "blackout_malus": blackout_malus,
		"base_happy": base_happy, "target": target,
	}
