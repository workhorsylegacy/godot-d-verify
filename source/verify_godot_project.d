// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module verify_godot_project;

import std.stdio : stdout, stderr;
import scan_d_code : KlassInfo;
import scan_godot_project : Project;


string absolutePath(string path) {
	import std.path : absolutePath;
	import std.array : replace;
	return absolutePath(path).replace(`\`, `/`);
}

string[][string] findProjectErrors(string project_path, Project project, KlassInfo[] class_infos) {
	import std.string : format;
	import std.algorithm : canFind, filter;
	import std.array : assocArray, byPair;
	import std.file : read, exists, remove, getcwd, chdir;
	import scan_godot_project;

	string[][string] retval;

	// Check projects
	foreach (Project proj ; [project]) {
		if (proj._error) continue;

		string[] errors;
		if (proj.main_scene_path == null) {
			errors ~= `Project missing main scene`;
		} else if (! exists(project_path ~ proj.main_scene_path)) {
			auto scene = proj._scenes[proj.main_scene_path];
			errors ~= `Project main scene file not found: "%s"`.format(scene._path);
			//if (scene._error) {
			//	errors ~= "%s".format(scene._error);
			//}
		}

		if (errors.length > 0) {
			retval[proj._path] = errors;
		}
	}

	// Check scenes
	foreach (Scene scene ; project._scenes.values()) {
		if (scene._error) continue;

		string[] errors;

		// Make sure the resource files exists
		foreach (RefExtResource resource ; scene._resources) {
			if (! exists(project_path ~ resource._path)) {
				errors ~= `Scene resource file not found: "%s"`.format(resource._path);
			}
		}

		// Get the class name from .tscn -> .gdns -> class_name
		string class_name = null;
		foreach (RefExtResource resource ; scene._resources) {
			if (resource._type == "Script") {
				NativeScript script = project._scripts[resource._path];
				class_name = script._class_name;
			}
		}

		// Get the signal method names
		string[] methods;
		foreach (RefConnection connection ; scene._connections) {
			methods ~= connection._method;
		}

		// Make sure the classes have the methods
		foreach (class_info ; class_infos) {
			if (class_name == "%s.%s".format(class_info._module, class_info.class_name)) {
				foreach (method ; methods) {
					bool is_method_found = false;
					bool is_attribute_found = false;
					foreach (method_info ; class_info.methods) {
						if (method_info.name == method) {
							is_method_found = true;

							if (method_info.attributes.canFind("Method")) {
								is_attribute_found = true;
							}
						}
					}

					// found but missing attribute
					if (is_method_found && ! is_attribute_found) {
						errors ~= `    Signal method "%s" found in class "%s" but missing @Method attribute`.format(method, class_name);
					// not found
					} else if (! is_method_found) {
						errors ~= `    Signal method "%s" not found in class "%s"`.format(method, class_name);
					}
				}
			}
		}

		if (errors.length > 0) {
			retval["tscn: %s".format(scene._path)] = errors;
		}
	}

	// Check scripts
	foreach (NativeScript script ; project._scripts.values()) {
		if (script._error) continue;

		string[] errors;

		if (errors.length > 0) {
			retval["gdns: %s".format(script._path)] = errors;
		}
	}

	// Check libraries
	foreach (NativeLibrary library ; project._libraries.values()) {
		if (library._error) continue;

		string[] errors;

		if (errors.length > 0) {
			retval["gdnlib: %s".format(library._path)] = errors;
		}
	}

	// Remove any empty error arrays
	retval = retval
			.byPair
			.filter!(pair => pair.value.length > 0)
			.assocArray;

	return retval;
}


unittest {
	import BDD;

	import scan_godot_project : getGodotProject, printInfo;
	import scan_d_code : getCodeClasses;
	import std.file : getcwd, chdir;

	//stdout.writefln("!!!!!!!!!!!!!!!!!!!!! getcwd: %s", getcwd());

	describe("verify_godot_project#project",
		it("Should succeed on working project", () {
			string project_path = absolutePath(`test/project_normal/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);
			string[][string] errors = findProjectErrors(project_path ~ `project/`, project, class_infos);

			errors.shouldEqual((string[][string]).init);
		}),
		it("Should fail when project main scene is not specified", () {
			string project_path = absolutePath(`test/project_main_scene_no_entry/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);
			string[][string] errors = findProjectErrors(project_path ~ `project/`, project, class_infos);

			errors.shouldEqual([`project.godot`: [`Project missing main scene`]]);
		}),
		it("Should fail when project main scene file is not found", () {
			string project_path = absolutePath(`test/project_main_scene_no_file/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);

//			printInfo(project);
			string[][string] errors = findProjectErrors(project_path ~ `project/`, project, class_infos);

			errors.shouldEqual([`project.godot`: [`Project main scene file not found: "Level/XXX.tscn"`]]);
		})
	);

	describe("verify_godot_project#scene",
		it("Should fail when scene resource file is not found", () {
			string project_path = absolutePath(`test/project_scene_resource_missing/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);
			string[][string] errors = findProjectErrors(project_path ~ `project/`, project, class_infos);

			errors.shouldEqual([`tscn: Level/Level.tscn`: [`Scene resource file not found: "Player/XXX.tscn"`]]);
		})
	);
}
