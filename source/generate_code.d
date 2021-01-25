// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module generate_code;

import verify_godot : Scene, NativeScript, NativeLibrary, RefExtResource;

struct SceneSignals {
	string class_name = null;
	string[] methods;
}


void generateCode(Scene[string] g_scenes, NativeScript[string] g_scripts, NativeLibrary[string] g_libraries) {
	import std.stdio : File, writefln;
	import std.string : format, split;
	import std.algorithm.sorting : sort;
	import std.array : array, join;
	import std.algorithm : map;
/*
	foreach (Scene scene ; g_scenes.values()) {
		foreach (RefConnection con ; scene._connections) {
			writefln("############ methods: %s", con._method);
		}
	}
*/
	// Get all the class names
	string[string] class_names;
	foreach (script ; g_scripts.values()) {
		auto pair = script._class_name.split(".");
		string file_name = pair[0];
		string class_name = pair[1];
		class_names[file_name] = class_name;
	}

	// Get all the script classes
	string[string] script_classes;
	foreach (script ; g_scripts.values()) {
		script_classes[script._path] = script._class_name.split(".")[1];
	}

	// Get all the scene signals
	SceneSignals[string] scene_signals;
	foreach (Scene scene ; g_scenes.values()) {
		string class_name = null;
		foreach (RefExtResource resource ; scene._resources) {
			if (resource._type == "Script" && resource._path in g_scripts) {
				auto script = g_scripts[resource._path];
				class_name = script._class_name.split(".")[1];
			}
		}

		string[] methods = scene._connections.map!(con => con._method).array;
		scene_signals[scene._path] = SceneSignals(class_name, methods);
	}

	File file = File("../src/script_class_names.d", "w");
	scope (exit) file.close();

	// Write the getClassNames function
	file.writeln(`
	pure string[string] getClassNames() {
		string[string] retval;`);

	foreach (file_name ; class_names.keys.sort.array) {
		string class_name = class_names[file_name];
		//writefln("???? name: %s, path: %s", name, path);
		file.writefln(`		retval["%s"] = "%s";`, file_name, class_name);
	}

	file.writeln(`
		return retval;
	}`);

	// Write getScriptClassNames function
	file.writeln(`
	pure string[string] getScriptClassNames() {
		string[string] retval;`);

	foreach (path ; script_classes.keys.sort.array) {
		string name = script_classes[path];
		//writefln("???? name: %s, path: %s", name, path);
		file.writefln(`		retval["%s"] = "%s";`, path, name);
	}

	file.writeln(`
		return retval;
	}`);

	// Write getSceneSignalNames function
	file.writeln(`
	struct SceneSignals {
		string class_name = null;
		string[] methods;
	}
	`);

	file.writeln(`
	pure SceneSignals[string] getSceneSignalNames() {
		SceneSignals[string] retval;`);

	foreach (path ; scene_signals.keys.sort.array) {
		auto signal_scene = scene_signals[path];
		if (signal_scene.methods.length == 0) {
			file.writefln(`		retval["%s"] = SceneSignals.init;`, path);
		} else {
			string methods = signal_scene.methods.map!(n => `"%s"`.format(n)).join(", ");
			//writefln("???? methods: %s", methods);
			file.writefln(`		retval["%s"] = SceneSignals("%s", [%s]);`, path, signal_scene.class_name, methods);
		}
	}

	file.writeln(`
		return retval;
	}`);
}
