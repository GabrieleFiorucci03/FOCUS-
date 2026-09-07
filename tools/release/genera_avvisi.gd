extends SceneTree
## Estrae gli avvisi dalla versione del motore usata per la build, inclusi i testi integrali
## delle licenze delle dipendenze. Passare il percorso di destinazione dopo --.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Indicare un percorso di destinazione dopo --.")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Impossibile scrivere gli avvisi: " + args[0])
		quit(1)
		return
	file.store_string("FOCUS! - THIRD-PARTY NOTICES\n\n")
	file.store_string("Engine: Godot " + str(Engine.get_version_info()["string"]) + "\n")
	file.store_string("These notices accompany FOCUS.exe and must be preserved when redistributing it.\n")
	file.store_string("FOCUS! is licensed separately under GPL-3.0; see LICENSE.txt.\n")
	file.store_string("Engine and component notices below retain their original licenses.\n")
	file.store_string("https://godotengine.org/license/\n\n")
	file.store_string("GODOT ENGINE - MIT LICENSE\n\n" + Engine.get_license_text() + "\n\n")
	file.store_string("COMPONENT COPYRIGHT NOTICES\n\n")
	var components := Engine.get_copyright_info()
	for component in components:
		file.store_string("=== " + str(component["name"]) + " ===\n")
		for part in component["parts"]:
			file.store_string("Files:\n")
			for path in part["files"]:
				file.store_string("  " + str(path) + "\n")
			file.store_string("Copyright:\n")
			for notice in part["copyright"]:
				file.store_string("  " + str(notice) + "\n")
			file.store_string("License: " + str(part["license"]) + "\n\n")
	file.store_string("FULL LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		file.store_string("=== " + str(name) + " ===\n\n" + str(licenses[name]) + "\n\n")
	file.close()
	print("Avvisi esportati: %d componenti, %d testi di licenza." % [components.size(), licenses.size()])
	quit()
