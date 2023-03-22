// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
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
	import helpers : sortBy;

	string[][string] retval;

	// Check projects
	foreach (Project proj ; [project]) {
		if (proj._error) continue;
		string[] errors;
		errors ~= new VerifyProjectVisitorMainScene().visit(project_path, proj, class_infos);
		if (errors.length) retval[proj._path] = errors;
	}

	// Check scenes
	foreach (scene ; project._scenes.values.sortBy!("_path")) {
		if (scene._error) continue;
		string[] errors;
		errors ~= new VerifySceneVisitorResource().visit(scene, project_path, project, class_infos);
		errors ~= new VerifySceneVisitorSignalMethodInCode().visit(scene, project_path, project, class_infos);
		errors ~= new VerifySceneVisitorSceneTypeClassTypeMismatch().visit(scene, project_path, project, class_infos);
		if (errors.length) retval["tscn: %s".format(scene._path)] = errors;
	}

	// Check scripts
	foreach (script ; project._scripts.values.sortBy!("_path")) {
		if (script._error) continue;
		string[] errors;
		errors ~= new VerifyScriptVisitorNativeLibrary().visit(script, project_path, project, class_infos);
		errors ~= new VerifyScriptVisitorClassName().visit(script, project_path, project, class_infos);
		errors ~= new VerifyScriptVisitorScriptClassInCode().visit(script, project_path, project, class_infos);
		if (errors.length) retval["gdns: %s".format(script._path)] = errors;
	}

	// Check libraries
	foreach (library ; project._libraries.values.sortBy!("_path")) {
		if (library._error) continue;
		string[] errors;
		errors ~= new VerifyLibraryVisitorSymbolPrefix().visit(library, project_path, project, class_infos);
		errors ~= new VerifyLibraryVisitorDllPath().visit(library, project_path, project, class_infos);
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
	import scan_d_code : getGodotScriptClasses;

	string[][string] setupTest(string project_path) {
		import helpers : absolutePath;
		project_path = absolutePath(project_path);
		auto project = parseProject(project_path ~ `project/project.godot`);
		auto class_infos = getGodotScriptClasses(project_path ~ `src/`);
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
		}),
		it("Should fail when scene type is not same as script code type", () {
			auto errors = setupTest(`test/project_script_code_class_wrong_type/`);
			errors.shouldEqual([`tscn: Player/Player.tscn`:
				[`Scene "Player" is type "Spatial" but attached script "Player" is type "GodotScript!Area"`]
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

class VerifyProjectVisitorMainScene : VerifyProjectVisitor {
	override string[] visit(string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		string[] errors;

		if (project._main_scene_path == null) {
			errors ~= `Project missing main scene`;
		} else if (! exists(project_path ~ project._main_scene_path)) {
			errors ~= `Project main scene file not found: "%s"`.format(project._main_scene_path);
		}

		return errors;
	}
}

class VerifySceneVisitorResource : VerifySceneVisitor {
	override string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		import std.algorithm : filter, sort;
		import helpers : sortBy;
		string[] errors;

		// Make sure the resource files exists
		auto resources = scene._resources
			.sort!((a, b) => a._path < b._path)
			.filter!(r => ! exists(project_path ~ r._path));

		foreach (resource ; resources) {
			errors ~= `Scene resource file not found: "%s"`.format(resource._path);
		}

		return errors;
	}
}

class VerifySceneVisitorSignalMethodInCode : VerifySceneVisitor {
	override string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.algorithm : canFind, filter, map;
		import std.array : assocArray, byPair;
		import std.path : extension;
		import helpers : sortBy;
		string[] errors;

		// Get the class name from scene -> node -> resource -> script -> class_name
		string class_name = null;
		{
			// Get all the node script ids
			auto ids = scene._nodes
				.filter!(n => n._script)
				.map!(n => n._script.id);
			if (ids.empty) return errors;

			// Get all the resources with the script id
			int id = ids.front;
			auto resources = scene._resources
				.sortBy!("_path")
				.filter!(r => r._id == id)
				.filter!(r => r._type == "Script")
				.filter!(r => r._path.extension == ".gdns");
			if (resources.empty) return errors;

			// Get all the scripts with the same paths as the resources
			auto resource = resources.front;
			auto scripts = project._scripts
				.byPair
				.filter!(pair => pair.key == resource._path)
				.map!(pair => pair.value);
			if (scripts.empty) return errors;

			auto script = scripts.front;
			class_name = script._class_name;
			if (class_name == null) return errors;
		}

		// Get the signal method names
		auto methods = scene._connections
			.map!(c => c._method);
		if (methods.empty) return errors;

		// Get the classes with the same names
		auto classes = class_infos
			.sortBy!("class_name")
			.filter!(c => c.full_class_name == class_name);
		if (classes.empty) return errors;

		// Make sure the classes have the methods
		foreach (class_info ; classes) {
			foreach (method ; methods) {
				bool is_method_found = ! class_info.methods
					.filter!(m => m.name == method)
					.empty;

				bool is_attribute_found = ! class_info.methods
					.filter!(m => m.name == method)
					.filter!(m => m.attributes.canFind("Method"))
					.empty;

				// found but missing attribute
				if (is_method_found && ! is_attribute_found) {
					errors ~= `Signal method "%s" found in class "%s" but missing @Method attribute`.format(method, class_name);
				// not found
				} else if (! is_method_found) {
					errors ~= `Signal method "%s" not found in class "%s"`.format(method, class_name);
				}
			}
		}

		return errors;
	}
}

class VerifySceneVisitorSceneTypeClassTypeMismatch : VerifySceneVisitor {
	override string[] visit(Scene scene, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.file : exists;
		import std.path : extension;
		import std.algorithm : filter;
		import helpers : sortBy;
		string[] errors;

		// Find all the nodes that have a script
		foreach (node ; scene._nodes.filter!(n => n._script)) {
			// Find all the resources with the same id
			auto resources = scene._resources
				.filter!(r => r._id == node._script.id)
				.filter!(r => r._path.extension == ".gdns")
				.filter!(r => r._path in project._scripts);

			// Make sure the node is referencing an existing resource
			if (resources.empty) {
				//errors ~= `Node script resource %s was not found`.format(node._script.id);
				continue;
			}
			auto resource = resources.front;

			auto script = project._scripts[resource._path];
			string class_name = script._class_name;

			// Find all the classes with same type
			auto classes = class_infos
				.filter!(c => c.base_class_name == "GodotScript")
				.filter!(c => c.full_class_name == class_name);
				//.filter!(c => c.base_class_template == node._type)

			foreach (class_info ; classes) {
				if (class_info.base_class_template != node._type) {
					errors ~= `Scene "%s" is type "%s" but attached script "%s" is type "%s"`
						.format(node._name, node._type, class_info.class_name, class_info.full_base_class_name);
				}
			}
		}

		return errors;
	}
}

class VerifyScriptVisitorNativeLibrary : VerifyScriptVisitor {
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

class VerifyScriptVisitorClassName : VerifyScriptVisitor {
	override string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos) {
		string[] errors;

		// Make sure script has a class name
		if (script._class_name == null) {
			errors ~= `Script missing class_name`;
		}

		return errors;
	}
}

class VerifyScriptVisitorScriptClassInCode : VerifyScriptVisitor {
	override string[] visit(NativeScript script, string project_path, Project project, KlassInfo[] class_infos) {
		import std.string : format;
		import std.algorithm : filter;
		import helpers : sortBy;
		string[] errors;

		// Make sure the script class is in the D code
		if (script._class_name) {
			bool has_class = ! class_infos
				.filter!(c => c.full_class_name == script._class_name)
				.empty;

			if (! has_class) {
				errors ~= `Script missing class "%s"`.format(script._class_name);
			}
		}

		return errors;
	}
}

class VerifyLibraryVisitorSymbolPrefix : VerifyLibraryVisitor {
	override string[] visit(NativeLibrary library, string project_path, Project project, KlassInfo[] class_infos) {
		string[] errors;

		// Make sure library has symbol_prefix
		if (library._symbol_prefix == null) {
			errors ~= `Library missing symbol_prefix`;
		}

		return errors;
	}
}

class VerifyLibraryVisitorDllPath : VerifyLibraryVisitor {
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
