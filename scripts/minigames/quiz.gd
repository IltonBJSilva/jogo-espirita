extends Minigame
## Minigame genérico de perguntas (Questionário doutrinário, Debate filosófico...).
##
## Parâmetros (data/minigames.json -> "params"):
##   "questions_file": "res://data/quizzes/<id>.json"  com
##       {"intro": "...", "pass_score": 3,
##        "questions": [{"question", "options": [..], "answer": índice,
##                       "explanation", "source"}]}
## Cada resposta mostra a explicação (e a fonte). Passa quem acertar pass_score.

var _questions: Array = []
var _intro := ""
var _pass_score := 1
var _index := -1
var _score := 0
var _answered := false

@onready var title_label: Label = %Title
@onready var counter_label: Label = %Counter
@onready var question_label: RichTextLabel = %Question
@onready var options_box: VBoxContainer = %Options
@onready var feedback_label: RichTextLabel = %Feedback
@onready var next_button: Button = %NextButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	var params: Dictionary = info.get("params", {})
	var data := DataLoader.load_json(params.get("questions_file", ""))
	_questions = data.get("questions", [])
	_intro = data.get("intro", info.get("description", ""))
	_pass_score = int(data.get("pass_score", ceili(_questions.size() * 0.6)))
	title_label.text = info.get("title", "Questionário")
	next_button.pressed.connect(_on_next)
	quit_button.pressed.connect(finish.bind(false))
	_show_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish(false)
	elif event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused.is_visible_in_tree() and not focused.disabled:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _show_intro() -> void:
	counter_label.text = "%d perguntas · acerte %d para concluir" % [_questions.size(), _pass_score]
	question_label.text = _intro
	feedback_label.text = ""
	_clear_options()
	next_button.text = "Começar"
	next_button.show()
	next_button.grab_focus()


func _on_next() -> void:
	if _index >= _questions.size() - 1 and _index >= 0:
		_show_result()
		return
	if _index == -2:  # tela de resultado: tentar novamente
		_index = -1
		_score = 0
	_index += 1
	_show_question()


func _show_question() -> void:
	var q: Dictionary = _questions[_index]
	_answered = false
	counter_label.text = "Pergunta %d de %d · acertos: %d" % [_index + 1, _questions.size(), _score]
	question_label.text = q.get("question", "")
	feedback_label.text = ""
	next_button.hide()
	_clear_options()
	var options: Array = q.get("options", [])
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_option.bind(i))
		options_box.add_child(b)
	(options_box.get_child(0) as Button).grab_focus()


func _on_option(choice: int) -> void:
	if _answered:
		return
	_answered = true
	var q: Dictionary = _questions[_index]
	var correct := int(q.get("answer", 0))
	for i in options_box.get_child_count():
		var b := options_box.get_child(i) as Button
		b.disabled = true
		if i == correct:
			b.modulate = Color(0.7, 1.0, 0.7)
		elif i == choice:
			b.modulate = Color(1.0, 0.65, 0.6)
	var ok := choice == correct
	if ok:
		_score += 1
	var text := "[color=#8fbf8f]Isso mesmo![/color] " if ok else "[color=#e08a7a]Não exatamente.[/color] "
	text += q.get("explanation", "")
	if q.get("source", "") != "":
		text += "\n[color=#8a7d70][i]%s[/i][/color]" % q["source"]
	feedback_label.text = text
	counter_label.text = "Pergunta %d de %d · acertos: %d" % [_index + 1, _questions.size(), _score]
	next_button.text = "Ver resultado" if _index == _questions.size() - 1 else "Próxima"
	next_button.show()
	next_button.grab_focus()


func _show_result() -> void:
	_clear_options()
	var passed := _score >= _pass_score
	counter_label.text = "Resultado: %d de %d" % [_score, _questions.size()]
	question_label.text = ("Muito bem! Você concluiu a atividade." if passed
			else "Ainda não foi desta vez. Releia com calma e tente de novo.")
	feedback_label.text = ""
	if passed:
		next_button.hide()
		var done := Button.new()
		done.text = "Concluir"
		done.pressed.connect(finish.bind(true))
		options_box.add_child(done)
		done.grab_focus()
	else:
		_index = -2
		next_button.text = "Tentar novamente"
		next_button.show()
		next_button.grab_focus()


func _clear_options() -> void:
	for c in options_box.get_children():
		options_box.remove_child(c)
		c.queue_free()
