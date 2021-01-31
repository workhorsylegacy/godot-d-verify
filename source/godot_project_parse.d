// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module godot_project_parse;


import std.stdio : stdout;
import godot_project;



Project parseProject(string full_project_path) {
	import std.file : chdir, getcwd;
	import std.path : extension, baseName, dirName;

	string prev_dir = getcwd();
	string project_file = baseName(full_project_path);
	string project_dir = dirName(full_project_path);
	chdir(project_dir);

	auto project = new Project(project_file);
	if (project && project._main_scene_path) {
		auto scene = new Scene(project._main_scene_path);
		project._scenes[project._main_scene_path] = scene;
	}

	// Scan all the scenes, scripts, and libraries
	bool is_scanning = true;
	while (is_scanning) {
		is_scanning = false;
		foreach (Scene scene ; project._scenes.values()) {
			foreach (RefExtResource resource ; scene._resources) {
				switch (resource._type) {
					case "PackedScene":
						if (resource._path !in project._scenes) {
							project._scenes[resource._path] = new Scene(resource._path);
							is_scanning = true;
						}
						break;
					case "Script":
						if (resource._path !in project._scripts) {
							switch (extension(resource._path)) {
								case ".gdns":
									project._scripts[resource._path] = new NativeScript(resource._path);
									is_scanning = true;
									break;
								case ".gd":
									project._gdscripts[resource._path] = new GDScript(resource._path);
									//is_scanning = true;
									break;
								default:
									stdout.writefln("!!!!!! unexpected resource script extension: %s", resource._path); stdout.flush();
									break;
							}
						}
						break;
					default:
						//stdout.writefln("!!!!!! unexpected resource type: %s", resource._type); stdout.flush();
						break;
				}
			}
		}

		foreach (NativeScript script ; project._scripts.values()) {
			RefExtResource resource = script._native_library;
			if (resource && resource._path !in project._libraries) {
				project._libraries[resource._path] = new NativeLibrary(resource._path);
				is_scanning = true;
			}
		}
	}

	chdir(prev_dir);

	return project;
}

unittest {
	import BDD;
	import std.algorithm : map;
	import std.array : array;
	import scan_d_code : getCodeClasses;

	string absolutePath(string path) {
		import std.path : absolutePath;
		import std.array : replace;
		return absolutePath(path).replace(`\`, `/`);
	}

	describe("godot_project_parse#SceneSignal",
		it("Should parse scene with signal", delegate() {
			string project_path = absolutePath(`test/project_signal/`);
			auto project = parseProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);

			project.shouldNotBeNull();
			project._scenes.length.shouldEqual(1);

			// Make sure the scene is valid
			auto scene = project._scenes.values()[0];
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(1);

			// Make sure the scene's script resource is valid
			auto resource = scene._resources[0];
			resource._type.shouldEqual("Script");
			resource._path.shouldEqual("Level/Level.gdns");

			// Make sure the scene's script is valid
			auto script = project._scripts[resource._path];
			script._error.shouldBeNull();
			script._class_name.shouldEqual("level.Level");
			scene._connections.length.shouldEqual(1);

			// Make sure scene's signal connection is valid
			auto connection = scene._connections[0];
			connection._signal.shouldEqual("pressed");
			connection._from.shouldEqual("Button");
			connection._to.shouldEqual(".");
			connection._method.shouldEqual("on_button_pressed"); // FIXME: onButtonPressed
			connection.isValid.shouldEqual(true);

			// Make sure the D code is valid
			class_infos.length.shouldEqual(1);
			auto class_info = class_infos[0];
			class_info._module.shouldEqual("level");
			class_info.class_name.shouldEqual("Level");
			class_info.base_class_name.shouldEqual("GodotScript");
			"_ready".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"_process".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"onButtonPressed".shouldBeIn(class_info.methods.map!(m => m.name).array);
		}),
		it("Should fail to parse scene with missing signal method", delegate() {
			string project_path = absolutePath(`test/project_signal_missing/`);
			auto project = parseProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);

			project.shouldNotBeNull();
			project._scenes.length.shouldEqual(1);

			// Made sure the scene is valid
			auto scene = project._scenes.values[0];
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(1);

			// Make sure the scene's script resource is valid
			auto resource = scene._resources[0];
			resource._type.shouldEqual("Script");
			resource._path.shouldEqual("Level/Level.gdns");

			// Make sure the scene's script is valid
			auto script = project._scripts[resource._path];
			script._error.shouldBeNull();
			script._class_name.shouldEqual("level.Level");
			scene._connections.length.shouldEqual(1);

			// Make sure scene's signal connection is valid
			auto connection = scene._connections[0];
			connection._signal.shouldEqual("pressed");
			connection._from.shouldEqual("Button");
			connection._to.shouldEqual(".");
			connection._method.shouldEqual("xxx"); // FIXME: onButtonPressed
			connection.isValid.shouldEqual(true);

			// Make sure the D code is valid
			class_infos.length.shouldEqual(1);
			auto class_info = class_infos[0];
			class_info._module.shouldEqual("level");
			class_info.class_name.shouldEqual("Level");
			class_info.base_class_name.shouldEqual("GodotScript");
			"_ready".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"_process".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"xxx".shouldNotBeIn(class_info.methods.map!(m => m.name).array);
			"onButtonPressed".shouldNotBeIn(class_info.methods.map!(m => m.name).array);
		})
	);
}
