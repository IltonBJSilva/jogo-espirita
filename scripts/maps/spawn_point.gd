@tool
class_name SpawnPoint
extends Marker2D
## Ponto de entrada em um mapa. O nome do no e o identificador usado pela
## acao {"type": "change_map", "map": "...", "spawn": "<nome>"}.

## Direcao para a qual o jogador fica virado ao surgir.
@export var facing := Vector2.DOWN
