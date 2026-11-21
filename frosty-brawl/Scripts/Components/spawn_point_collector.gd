class_name SpawnPointCollector
extends RefCounted
## SRP: только собирает и упорядочивает точки спавна.
## OCP: добавишь Spawn_point_5 в сцену — подхватится сам, код менять не надо.

const PATTERN := "Spawn_point_*"

func collect(root: Node) -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for node in root.find_children(PATTERN, "Marker3D", true, false):
		points.append(node as Marker3D)
	# natural-сортировка: Spawn_point_2 < Spawn_point_10 (обычная строковая ошибётся)
	points.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return points
