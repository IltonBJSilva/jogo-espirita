extends Node
## InteractionManager (autoload): decide com qual objeto o jogador interage.
##
## Cada Interactable avisa quando o jogador entra/sai do seu alcance. Aqui
## escolhemos o mais proximo, avisamos o HUD (para o indicador "[E] ...") e
## disparamos a interacao quando a tecla "interact" (E) e pressionada.

signal focus_changed(interactable: Interactable)

## Evita que a mesma tecla que fecha um dialogo abra outro imediatamente.
const COOLDOWN := 0.2

var focused: Interactable = null
var _candidates: Array[Interactable] = []
var _cooldown := 0.0


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(func(_id): _cooldown = COOLDOWN)
	GameManager.state_changed.connect(func(_n, _o): _cooldown = COOLDOWN)


func register_candidate(interactable: Interactable) -> void:
	if not interactable in _candidates:
		_candidates.append(interactable)


func unregister_candidate(interactable: Interactable) -> void:
	_candidates.erase(interactable)
	if focused == interactable:
		_set_focus(null)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not GameManager.is_playing():
		_set_focus(null)
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best: Interactable = null
	var best_dist := INF
	if player:
		for candidate in _candidates:
			if not is_instance_valid(candidate) or not candidate.enabled:
				continue
			var dist := player.global_position.distance_squared_to(candidate.global_position)
			if dist < best_dist:
				best_dist = dist
				best = candidate
	_set_focus(best)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if focused and GameManager.is_playing() and _cooldown <= 0.0:
		get_viewport().set_input_as_handled()
		focused.interact()


func _set_focus(interactable: Interactable) -> void:
	if interactable == focused:
		return
	focused = interactable
	focus_changed.emit(interactable)
