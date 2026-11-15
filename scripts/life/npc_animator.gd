class_name LifeAnimator
extends RefCounted
## Mapa atividade -> apresentação, usando SÓ os sprites existentes
## (idle_*, walk_*, talk, study). O que não tem sprite próprio (sentar, dormir,
## comer...) é mostrado por pose + balão de emoção + leve animação procedural.
## Ver dependências de sprites em docs/VIDA_DOS_NPCS.md.

## activity -> {special: animação especial se existir, emote, interval (s), bob (px), face_down}
const STYLES := {
	"estudar": {"special": "study", "emote": "estudo", "interval": 14.0, "bob": 0},
	"conversar": {"special": "", "emote": "conversa", "interval": 16.0, "bob": 0},
	"trabalhar": {"special": "", "emote": "trabalho", "interval": 9.0, "bob": 1},
	"comer": {"special": "", "emote": "comida", "interval": 8.0, "bob": 0},
	"descansar": {"special": "", "emote": "musica", "interval": 22.0, "bob": 0},
	"sentado": {"special": "", "emote": "", "interval": 0.0, "bob": 0},
	"passear": {"special": "", "emote": "", "interval": 0.0, "bob": 0},
	"reuniao": {"special": "", "emote": "estudo", "interval": 18.0, "bob": 0},
	"prece": {"special": "", "emote": "prece", "interval": 12.0, "bob": 0, "face_down": true},
	"brincar": {"special": "", "emote": "musica", "interval": 10.0, "bob": 2},
	"cuidar_casa": {"special": "", "emote": "trabalho", "interval": 12.0, "bob": 1},
	"dormir": {"special": "", "emote": "sono", "interval": 5.0, "bob": 0},
}
const DEFAULT := {"special": "", "emote": "", "interval": 0.0, "bob": 0}


static func style_for(activity: String) -> Dictionary:
	return STYLES.get(activity, DEFAULT)


## Aplica a pose da atividade ao NPC parado no destino.
static func apply(npc: NPC, activity: String, facing: Vector2) -> Dictionary:
	var style := style_for(activity)
	if style.get("face_down", false):
		facing = Vector2.DOWN
	if facing != Vector2.ZERO:
		npc.face(facing)
	npc.set_moving(false)
	var special: String = style["special"]
	npc.play_special(special if special != "" and npc.has_animation(special) else "")
	return style


## Animação de fala durante encontros sociais (talk se existir).
static func talk(npc: NPC, on: bool) -> void:
	if on and npc.has_animation("talk") and npc.facing == Vector2.DOWN:
		npc.play_special("talk")
	elif not on and npc.special_animation == "talk":
		npc.play_special("")
