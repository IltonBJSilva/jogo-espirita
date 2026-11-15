class_name Minigame
extends Control
## Classe base de todos os minigames.
##
## Para criar um minigame:
##  1. Crie uma cena em scenes/minigames/ cuja raiz estenda Minigame.
##  2. Registre-a em data/minigames.json ({"id": {"scene", "title", "description"}}).
##  3. Chame finish(true/false) quando terminar.
##  4. Dispare-o com a acao {"type": "start_minigame", "minigame": "id",
##     "on_success": [...], "on_fail": [...]} em qualquer dialogo/objeto.
## O MinigameManager pausa o jogador, mostra a cena e executa as acoes do resultado.

signal finished(success: bool)

## Dados do registro (title, description...) preenchidos pelo MinigameManager.
var info: Dictionary = {}


func setup(minigame_info: Dictionary) -> void:
	info = minigame_info


func finish(success: bool) -> void:
	finished.emit(success)
