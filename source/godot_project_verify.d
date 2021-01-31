// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module godot_project_verify;

import std.stdio : stdout, stderr;
import scan_d_code : KlassInfo;
import godot_project;
import godot_project_parse;



string[][string] verifyProject(string project_path, Project project, KlassInfo[] class_infos) {
	import std.string : format;
	import std.algorithm : filter;
	import std.array : assocArray, byPair;

	string[][string] retval;

	// Check projects
	foreach (Project proj ; [project]) {
		if (proj._error) continue;
		string[] errors;
		errors ~= new MainSceneVerifyProjectVisitor().visit(project_path, proj, class_infos);
		if (errors.length) retval[proj._path] = errors;
	}

	// Check scenes
	foreach (scene ; project._scenes.values.sortBy!(Scene, "_path")) {
		if (scene._error) continue;
		string[] errors;
		errors ~= new ResourceVerifySceneVisitor().visit(scene, project_path, project, class_infos);
		errors ~= new SignalMethodInCodeVerifySceneVisitor().visit(scene, project_path, project, class_infos);
		if (errors.length) retval["tscn: %s".format(scene._path)] = errors;
	}

	// Check scripts
	foreach (script ; project._scripts.values.sortBy!(NativeScript, "_path")) {
		if (script._error) continue;
		string[] errors;
		errors ~= new NativeLibraryVerifyScriptVisitor().visit(script, project_path, project, class_infos);
		errors ~= new ClassNameVerifyScriptVisitor().visit(script, project_path, project, class_infos);
		errors ~= new ScriptClassInCodeVerifyScriptVisitor().visit(script, project_path, project, class_infos);
		if (errors.length) retval["gdns: %s".format(script._path)] = errors;
	}

	// Check libraries
	foreach (library ; project._libraries.values.sortBy!(NativeLibrary, "_path")) {
		if (library._error) continue;
		string[] errors;
		errors ~= new SymbolPrefixVerifyLibraryVisitor().visit(library, project_path, project, class_infos);
		errors ~= new DllPathVerifyLibraryVisitor().visit(library, project_path, project, class_infos);
		if (errors.length) retval["gdnlib: %s".format(library._path)] = errors;
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

	import godot_project_parse : parseProject;
	import scan_d_code : getCodeClasses;

	string[][string] setupTest(string project_path) {
		project_path = absolutePath(project_path);
		auto project = parseProject(project_path ~ `project/project.godot`);
		auto class_infos = getCodeClasses(project_path ~ `src/`);
		return verifyProject(project_path ~ `project/`, project, class_infos);
	}

	describe("godot_project_verify#project",
		it("Should succeed on working project", () {
			auto errors = setupTest(`test/project_normal/`);
			errors.shouldEqual((string[][string]).init);
		}),
		it("Should fail when project main scene is not specified", () {
			auto errors = setupTest(`test/project_main_scene_no_entry/`);
			errors.shouldEqual([`project.godot`:
				[`Project missing main scene`]
			]);
		}),
		it("Should fail when project main scene file is not found", () {
			auto errors = setupTest(`test/project_main_scene_no_file/`);
			errors.shouldEqual([`project.godot`:
				[`Project main scene file not found: "Level/XXX.tscn"`]
			]);
		})
	);

	describe("godot_project_verify#scene",
		it("Should fail when scene resource file is not found", () {
			auto errors = setupTest(`test/project_scene_resource_missing/`);
			errors.shouldEqual([`tscn: Level/Level.tscn`:
				[`Scene resource file not found: "Player/XXX.tscn"`]
			]);
		}),
		it("Should fail when signal method doesn't exists in code", () {
			auto errors = setupTest(`test/project_scene_signal_no_code_method/`);
			errors.shouldEqual([`tscn: Level/Level.tscn`:
				[`Signal method "xxx" not found in class "level.Level"`]
			]);
		}),
		it("Should fail when signal method exists but missing Method attribute", () {
			auto errors = setupTest(`test/project_scene_signal_no_method_attribute/`);
			errors.shouldEqual([`tscn: Level/Level.tscn`:
				[`Signal method "on_button_pressed" found in class "level.Level" but missing @Method attribute`]
			]);
		})
	);

	describe("godot_project_verify#script",
		it("Should fail when script native library is not specified", () {
			auto errors = setupTest(`test/project_script_resource_no_entry/`);
			errors.shouldEqual([`gdns: Player/Player.gdns`:
				[`Script missing native library`]
			]);
		}),
		it("Should fail when script native library file is not found", () {
			auto errors = setupTest(`test/project_script_resource_no_file/`);
			errors.shouldEqual([`gdns: Player/Player.gdns`:
				[`Script resource file not found: "XXX.gdnlib"`]
			]);
		}),
		it("Should fail when script class_name is not specified", () {
			auto errors = setupTest(`test/project_script_no_class_name/`);
			errors.shouldEqual([`gdns: Player/Player.gdns`:
				[`Script missing class_name`]
			]);
		}),
		it("Should fail when script class does not exist in code", () {
			auto errors = setupTest(`test/project_script_no_code_class/`);
			errors.shouldEqual([`gdns: Player/Player.gdns`:
				[`Script missing class "player.Player"`]
			]);
		})
	);

	describe("godot_project_verify#library",
		it("Should fail when native library symbol_prefix is not specified", () {
			auto errors = setupTest(`test/project_library_no_symbol_prefix_entry/`);
			errors.shouldEqual([`gdnlib: libsimple.gdnlib`:
				[`Library missing symbol_prefix`]
			]);
		}),
		it("Should fail when native library dll/so file is not specified", () {
			auto errors = setupTest(`test/project_library_no_dll_entry/`);

			version (Windows) {
				errors.shouldEqual([`gdnlib: libsimple.gdnlib`:
					[`Library missing Windows.64`]
				]);
			} else version (linux) {
				errors.shouldEqual([`gdnlib: libsimple.gdnlib`:
					[`Library missing X11.64`]
				]);
			}
		})
	);
}

private:

T[] sortBy(T, string field_name)(T[] things) {
	import std.algorithm : sort;
	import std.array : array;

	alias sortFilter = (a, b) => mixin("a." ~ field_name ~ " < b." ~ field_name);

	return things.sort!(sortFilter).array;
}

string absolutePath(string path) {
	import std.path : absolutePath;
	import std.array : replace;
	return absolutePath(path).replace(`\`, `/`);
}

abstract class VerifyProjectVisitor {
	string[] visit(string project_path, Project project, KlassInfo[] class_infos);
}

abstract class VerifySceneVisitor {
	string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos);
}

abstract class VerifyScriptVisitor {
	string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos);
}

abstract class VerifyLibraryVisitor {
	string[] visit(NativeLibrary library, string project_path, Project project, KlassInfo[] class_infos);
}

class MainSceneVerifyProjectVisitor : VerifyProjectVisitor {
	override string[] visit(string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		string[] errors;

		if (project._main_scene_path == null) {
			errors ~= `Project missing main scene`;
		} else if (! exists(project_path ~ project._main_scene_path)) {
			auto scene = project._scenes[project._main_scene_path];
			errors ~= `Project main scene file not found: "%s"`.format(scene._path);
		}

		return errors;
	}
}

class ResourceVerifySceneVisitor : VerifySceneVisitor {
	override string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		string[] errors;

		// Make sure the resource files exists
		foreach (resource ; scene._resources.sortBy!(RefExtResource, "_path")) {
			if (! exists(project_path ~ resource._path)) {
				errors ~= `Scene resource file not found: "%s"`.format(resource._path);
			}
		}

		return errors;
	}
}

class SignalMethodInCodeVerifySceneVisitor : VerifySceneVisitor {
	override string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.algorithm : canFind;
		import std.path : extension;
		string[] errors;

		// Get the class name from .tscn -> .gdns -> class_name
		string class_name = null;
		foreach (resource ; scene._resources.sortBy!(RefExtResource, "_path")) {
			if (resource._type == "Script" && extension(resource._path) == ".gdns") {
				NativeScript script = project._scripts[resource._path];
				class_name = script._class_name;
			}
		}

		// Just return if there is no class name
		if (class_name == null) return errors;

		// Get the signal method names
		string[] methods;
		foreach (RefConnection connection ; scene._connections) {
			methods ~= connection._method;
		}

		// Make sure the classes have the methods
		foreach (class_info ; class_infos.sortBy!(KlassInfo, "class_name")) {
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
						errors ~= `Signal method "%s" found in class "%s" but missing @Method attribute`.format(method, class_name);
					// not found
					} else if (! is_method_found) {
						errors ~= `Signal method "%s" not found in class "%s"`.format(method, class_name);
					}
				}
			}
		}

		return errors;
	}
}

class NativeLibraryVerifyScriptVisitor : VerifyScriptVisitor {
	override string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		string[] errors;

		// Make sure the resource files exists
		if (script._native_library is null) {
			errors ~= `Script missing native library`;
		} else {
			if (! exists(project_path ~ script._native_library._path)) {
				errors ~= `Script resource file not found: "%s"`.format(script._native_library._path);
			}
		}

		return errors;
	}
}

class ClassNameVerifyScriptVisitor : VerifyScriptVisitor {
	override string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos) {
		string[] errors;

		// Make sure script has a class name
		if (script._class_name == null) {
			errors ~= `Script missing class_name`;
		}

		return errors;
	}
}

class ScriptClassInCodeVerifyScriptVisitor : VerifyScriptVisitor {
	override string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		string[] errors;

		// Make sure the script class is in the D code
		if (script._class_name) {
			bool has_class = false;
			foreach (class_info ; class_infos.sortBy!(KlassInfo, "class_name")) {
				if (script._class_name == "%s.%s".format(class_info._module, class_info.class_name)) {
					has_class = true;
				}
			}

			if (! has_class) {
				errors ~= `Script missing class "%s"`.format(script._class_name);
			}
		}

		return errors;
	}
}

class SymbolPrefixVerifyLibraryVisitor : VerifyLibraryVisitor {
	override string[] visit(NativeLibrary library, string project_path, Project project, KlassInfo[] class_infos) {
		string[] errors;

		// Make sure library has symbol_prefix
		if (library._symbol_prefix == null) {
			errors ~= `Library missing symbol_prefix`;
		}

		return errors;
	}
}

class DllPathVerifyLibraryVisitor : VerifyLibraryVisitor {
	override string[] visit(NativeLibrary library, string project_path, Project project, KlassInfo[] class_infos) {
		string[] errors;

		// Make sure the dll/so is specified
		version (Windows) {
			if (library._dll_windows_path == null) {
				errors ~= `Library missing Windows.64`;
			}
		} else version (linux) {
			if (library._dll_linux_path == null) {
				errors ~= `Library missing X11.64`;
			}
		}

		return errors;
	}
}
