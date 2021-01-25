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

	// Print out any errors
	foreach (Scene scene ; project._scenes.values()) {
		string[] errors;
		foreach (RefExtResource resource ; scene._resources) {
			switch (resource._type) {
				case "PackedScene":
					Scene child_scene = project._scenes[resource._path];
					if (child_scene._error) {
						errors ~= "    error: %s".format(child_scene._error);
					}
					break;
				case "Script":
					NativeScript child_script = project._scripts[resource._path];
					if (child_script._error) {
						errors ~= "    error: %s".format(child_script._error);
					}
					break;
				default:
					break;
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
		NativeLibrary child_library = project._libraries[script._native_library._path];

		if (child_library._error) {
			errors ~= "    error: %s".format(child_library._error);
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

	//printInfo(project);
	//printErrors(project);
	printErrors(project, class_infos);
/*
	foreach (info ; class_infos) {
		stdout.writefln("%s.%s : %s", info._module, info.class_name, info.base_class_name); stdout.flush();
		foreach (method ; info.methods) {
			stdout.writefln("    method: %s", method); stdout.flush();
		}
	}
*/
	return 0;
}
