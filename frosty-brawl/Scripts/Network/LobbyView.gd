class_name LobbyView
extends RefCounted
## SRP: только отрисовка состава лобби. Данные не хранит, сеть не трогает.

var _catalog: CharacterCatalog
var _label: Label

func _init(catalog: CharacterCatalog, label: Label) -> void:
	_catalog = catalog
	_label = label

func render(players: Dictionary, local_peer_id: int) -> void:
	var lines: Array[String] = []
	for peer_id: int in players:
		var p: Dictionary = players[peer_id]
		var char_name: String = _catalog.get_display_name(p.character_id) \
			if p.character_id != &"" else "выбирает..."
		var me := " (вы)" if peer_id == local_peer_id else ""
		var ready := " ✔ готов" if p.ready else ""
		lines.append("%s%s — %s%s" % [p.name, me, char_name, ready])
	_label.text = "\n".join(lines) if not lines.is_empty() else "Ждём игроков..."
