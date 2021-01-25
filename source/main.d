// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify


import std.stdio : stdout;
import verify_godot;
import verify_d_code;


void printErrors(Project project, KlassInfo[] class_infos) {
	import std.stdio : stderr;
	import std.string : format;
	import std.algorithm : canFind;

	// Print out any errors
	foreach (Scene scene ; project._scenes.values()) {
		string[] errors;

		if (scene._error) {
			errors ~= "    error: %s".format(scene._error);
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
						if (! class_info.methods.canFind(method)) {
							errors ~= `    Signal method "%s" not found in class "%s"`.format(method, class_name);
						}
					}
				}
			}
		}

		if (errors.length > 0) {
			stderr.writefln("tscn: %s", scene._path); stderr.flush();
			foreach (error ; errors) {
				stderr.writefln("%s", error); stderr.flush();
			}
		}
	}

	foreach (NativeScript script ; project._scripts.values()) {
		string[] errors;

		if (script._error) {
			errors ~= "    error: %s".format(script._error);
		}

		if (errors.length > 0) {
			stderr.writefln("gdns: %s", script._path); stderr.flush();
			foreach (error ; errors) {
				stderr.writefln("%s", error); stderr.flush();
			}
		}
	}

	foreach (NativeLibrary library ; project._libraries.values()) {
		string[] errors;

		if (errors.length > 0) {
			stderr.writefln("gdnlib: %s", library._path); stderr.flush();
			foreach (error ; errors) {
				stderr.writefln("%s", error); stderr.flush();
			}
		}
	}
}

int main() {
	stdout.writefln("Verifying godot project ..."); stdout.flush();
	string project_path = `C:\Users\matt\Projects\PumaGameGodot\`;

	// Scan the godot.project
	auto project = scanProject(project_path ~ `project\project.godot`);

	//
	auto class_infos = getCodeClasses(project_path ~ `src\`);

	printErrors(project, class_infos);

	return 0;
}
