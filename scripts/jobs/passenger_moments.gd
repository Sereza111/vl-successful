extends RefCounted
class_name PassengerMoments

## passenger_type -> moment definition
const MOMENTS: Dictionary = {
	"econom": {
		"text": "«Можно подешевле?»",
		"choice_a": "Отказать",
		"choice_b": "Согласиться",
		"effect_a": {"rating": -0.08, "payout_mult": 1.0},
		"effect_b": {"rating": 0.1, "payout_mult": 0.9},
	},
	"comfort": {
		"text": "«Включите кондиционер, пожалуйста»",
		"choice_a": "Да",
		"choice_b": "Нет",
		"effect_a": {"rating": 0.05, "tip": 80, "fuel": 5},
		"effect_b": {"rating": -0.12, "payout_mult": 1.0},
	},
	"corp": {
		"text": "«Срочно на встречу — опоздаю!»",
		"choice_a": "Быстрее",
		"choice_b": "Спокойно",
		"effect_a": {"rating": 0.05, "payout_mult": 1.15, "fuel": 8},
		"effect_b": {"rating": 0.0, "payout_mult": 1.0},
	},
}


static func get_moment(passenger_type: String) -> Dictionary:
	return MOMENTS.get(passenger_type, MOMENTS["econom"]).duplicate(true)
