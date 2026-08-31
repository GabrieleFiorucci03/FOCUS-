extends Node3D


func _ready() -> void:
	var ambiente := WorldEnvironment.new()
	var mondo := Environment.new()
	mondo.background_mode = Environment.BG_COLOR
	mondo.background_color = Color(0.35, 0.50, 0.68)
	mondo.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mondo.ambient_light_color = Color(0.72, 0.78, 0.86)
	mondo.ambient_light_energy = 0.45
	mondo.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = mondo
	add_child(ambiente)

	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sole.light_energy = 0.95
	add_child(sole)

	var semi := [467268810, 12345, 777777, 2024]
	for i in semi.size():
		var terreno := CityTerrain.new(Vector2i(32, 32), int(semi[i]))
		var suolo := MeshInstance3D.new()
		suolo.mesh = TerrainMesh.costruisci_terreno(terreno)
		suolo.position = Vector3(float(i % 2) * 70.0, 0.0, float(i / 2) * 70.0)
		add_child(suolo)
		var acqua := MeshInstance3D.new()
		acqua.mesh = TerrainMesh.costruisci_acqua(terreno)
		acqua.position = suolo.position
		add_child(acqua)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 122.0
	camera.position = Vector3(35.0, 90.0, 125.0)
	camera.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	add_child(camera)
	camera.make_current()
