// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module verify_godot_project;

import std.stdio : stdout, stderr;
import scan_d_code : KlassInfo;
import scan_godot_project : Project;


string[][string] findProjectErrors(Project project, KlassInfo[] class_infos) {
	import std.string : format;
	import std.algorithm : canFind;
	import scan_godot_project;

	string[][string] retval;

	// Check project
	{
		string[] errors;

		if (project._error) {
			errors ~= "error: %s".format(project._error);
		} else {
			if (project.main_scene_path == null) {
				errors ~= `Project missing main scene`;
			}
		}

		if (errors.length > 0) {
			retval[project._path] = errors;
		}
	}

	// Check scenes
	foreach (Scene scene ; project._scenes.values()) {
		string[] errors;

		if (scene._error) {
			errors ~= "error: %s".format(scene._error);
		} else {
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
		}

		if (errors.length > 0) {
			retval["tscn: %s".format(scene._path)] = errors;
		}
	}

	foreach (NativeScript script ; project._scripts.values()) {
		string[] errors;

		if (script._error) {
			errors ~= "    error: %s".format(script._error);
		}

		if (errors.length > 0) {
			retval["gdns: %s".format(script._path)] = errors;
		}
	}

	foreach (NativeLibrary library ; project._libraries.values()) {
		string[] errors;

		if (library._error) {
			errors ~= "    error: %s".format(library._error);
		}

		if (errors.length > 0) {
			retval["gdnlib: %s".format(library._path)] = errors;
		}
	}

	return retval;
}


unittest {
	import BDD;
	import std.path : absolutePath;
	import scan_godot_project : getGodotProject, printInfo;
	import scan_d_code : getCodeClasses;
	//import std.array;
	//import std.file : read, exists, remove, getcwd, chdir;

	//stdout.writefln("!!!!!!!!!!!!!!!!!!!!! getcwd: %s", getcwd());

	describe("verify_godot_project#findProjectErrors",
		it("Should succeed on working project", () {
			string project_path = absolutePath(`test/project_normal/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);
			string[][string] errors = findProjectErrors(project, class_infos);

			errors.length.shouldEqual(0);
		}),
		it("Should fail when project main scene is not specified", () {
			string project_path = absolutePath(`test/project_main_scene_no_entry/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);
			string[][string] errors = findProjectErrors(project, class_infos);

			errors.shouldEqual([`project.godot`: [`Project missing main scene`]]);
		}),
		it("Should fail when project main scene file is not found", () {
			string project_path = absolutePath(`test/project_main_scene_no_file/`);
			auto project = getGodotProject(project_path ~ `project/project.godot`);
			auto class_infos = getCodeClasses(project_path ~ `src/`);

			printInfo(project);

			string[][string] errors = findProjectErrors(project, class_infos);

			errors.shouldEqual([`project.godot`: [`Project main scene file not found: "Level/XXX.tscn"`]]);
			//errors.length.shouldBeGreater(0);
			//errors.keys[0].shouldEqual(`project.godot`);
			//errors[`project.godot`].length.shouldBeGreater(0);
			//errors[`project.godot`][0].shouldEqual(`Project missing main scene`);
		})
	);
}
