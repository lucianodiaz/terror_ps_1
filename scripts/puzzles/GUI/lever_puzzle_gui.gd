class_name LeverPuzzleGUI
extends Control

signal lever_selected(indicator: int)
signal exit_puzzle()


var player: Player = null

@export var indicators: Array[TextureRect]=[]
var current_indicator: int = 0 : 
	set(value):
		current_indicator = value
		if current_indicator < 0:
			current_indicator = indicators.size() - 1
		if current_indicator >= indicators.size():
			current_indicator = 0

func _input(event: InputEvent) -> void:
	if player == null:
		return
		
	if event.is_action_pressed("ui_left"):
		indicators[current_indicator].modulate.a = 0.0
		current_indicator -= 1
		indicators[current_indicator].modulate.a = 1.0
	if event.is_action_pressed("ui_right"):
		indicators[current_indicator].modulate.a = 0.0
		current_indicator += 1
		indicators[current_indicator].modulate.a = 1.0
	

	if event.is_action_pressed("action"):
		lever_selected.emit(current_indicator)
	
	if event.is_action_pressed("run"):
		exit_puzzle.emit()
