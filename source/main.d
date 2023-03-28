// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

import helpers;
import godot_project;
import godot_project_parse;

import std.stdio : stdout, stderr, File;
import core.thread.osthread : Thread;
import core.time : dur;


int main(string[] args) {
	import std.file : chdir;
	import std.file : exists;
	import std.path : extension;
	import std.getopt : getopt, config, GetOptException;
	import helpers : dirName, buildPath, toPosixPath, absolutePath;
	import scan_d_code : getGodotScriptClasses;
	import godot_project_verify : verifyProject;
	import std.parallelism;

	s64 start, end;
	start = GetCpuTicksNS();

	// Change the dir to the location of the current exe
	chdir(dirName(args[0]));

	// Get the options
	string project_path = null;
	string source_path = null;
	bool generate_script_list = false;
	bool is_help = false;
	string getopt_error = null;
	try {
		auto result = getopt(args,
		config.required, "project", &project_path,
		config.required, "source", &source_path,
		"generate_script_list", &generate_script_list);
		is_help = result.helpWanted;
	} catch (Exception err) {
		getopt_error = err.msg;
		is_help = true;
	}

	// If there was an error, print the help and quit
	if (is_help) {
		stdout.writefln(
		"Verify Godot 3 Dlang project\n" ~
		"--project               Directory containing Godot project file. Required:\n" ~
		"--source                Directory containing D source code. Required:\n" ~
		"--generate_script_list  Will generate a list of classes that are GodotScript. Optional:\n" ~
		"--help                  This help information.\n"); stdout.flush();

		if (getopt_error) {
			stderr.writefln("Error: %s", getopt_error); stderr.flush();
		}
		return 1;
	}

	// Check paths
	project_path = toPosixPath(project_path);
	if (! exists(project_path)) {
		stderr.writefln(`Error: Godot project directory not found: %s`, project_path); stderr.flush();
		return 1;
	}
	project_path = absolutePath(project_path);

	source_path = toPosixPath(source_path);
	if (! exists(source_path)) {
		stderr.writefln(`Error: D source code directory not found: %s`, source_path); stderr.flush();
		return 1;
	}
	source_path = absolutePath(source_path);

	// Get the project info
	stdout.writefln(`Verifying Godot 3 Dlang project:`); stdout.flush();
	stdout.writefln(`Project file path: %s`, project_path); stdout.flush();
	stdout.writefln(`Dlang source path: %s`, source_path); stdout.flush();
	//auto project = parseProject(buildPath(project_path, `project.godot`));
	end = GetCpuTicksNS();
	stdout.writefln(`!!!! setup time: %s`, end - start); stdout.flush();

	start = GetCpuTicksNS();
	auto task_pool = new TaskPool(4);
	scope(exit) task_pool.stop();

	static immutable auto new_project = (string n) => new Project(n);
	static immutable auto new_scene = (string n) => new Scene(n);
	static immutable auto new_native_script = (string n) => new NativeScript(n);
	static immutable auto new_gd_script = (string n) => new GDScript(n);
	static immutable auto new_native_library = (string n) => new NativeLibrary(n);

	Task!(new_project, string)*[] _projects;
	Task!(new_scene, string)*[] _scenes;
	Task!(new_native_script, string)*[] _native_scripts;
	Task!(new_gd_script, string)*[] _gd_scripts;
	Task!(new_native_library, string)*[] _native_libraries;

	// Scan each file
	getProjectFiles(project_path, (string name) {
		//stdout.writefln(`!!!! name: %s`, name); stdout.flush();
		switch (extension(name)) {
			case ".godot":
				auto t = task!(new_project)(name);
				_projects ~= t;
				task_pool.put(t);
				break;
			case ".tscn":
				auto t = task!(new_scene)(name);
				_scenes ~= t;
				task_pool.put(t);
				break;
			case ".gdns":
				auto t = task!(new_native_script)(name);
				_native_scripts ~= t;
				task_pool.put(t);
				break;
			case ".gd":
				auto t = task!(new_gd_script)(name);
				_gd_scripts ~= t;
				task_pool.put(t);
				break;
			case ".gdnlib":
				auto t = task!(new_native_library)(name);
				_native_libraries ~= t;
				task_pool.put(t);
				break;
			default:
				break;
		}
	});

	task_pool.finish();

	Project project;
	foreach (t ; _projects) {
		project = t.yieldForce();
	}

	foreach (t ; _scenes) {
		auto scene = t.yieldForce();
		project._scenes[scene._path] = scene;
	}

	foreach (t ; _native_scripts) {
		auto native_script = t.yieldForce();
		project._scripts[native_script._path] = native_script;
	}

	foreach (t ; _gd_scripts) {
		auto gd_script = t.yieldForce();
		project._gdscripts[gd_script._path] = gd_script;
	}

	foreach (t ; _native_libraries) {
		auto native_library = t.yieldForce();
		project._libraries[native_library._path] = native_library;
	}

	end = GetCpuTicksNS();
	stdout.writefln(`!!!! parse time: %s`, end - start); stdout.flush();
	//Thread.sleep(dur!("seconds")(5));

	start = GetCpuTicksNS();
	auto class_infos = getGodotScriptClasses(source_path);
	end = GetCpuTicksNS();
	stdout.writefln(`!!!! get script classes time: %s`, end - start); stdout.flush();

	// Find and print any errors
	start = GetCpuTicksNS();
	auto project_errors = verifyProject(project_path, project, class_infos);
	int error_count;
	foreach (name, errors ; project_errors) {
		stdout.writeln(name);
		foreach (error ; errors) {
			error_count++;
			stdout.writeln("    ", error);
		}
	}
	if (error_count > 0) {
		stdout.writefln(`Verification failed! Found %s error(s)!`, error_count); stdout.flush();
		return 1;
	}
	end = GetCpuTicksNS();
	stdout.writefln(`!!!! verify time: %s`, end - start); stdout.flush();

	// Generate a list of classes that are GodotScript
	start = GetCpuTicksNS();
	if (generate_script_list) {
		string file_name = "generated_script_list.d";
		string script_list_file = buildPath(source_path, file_name);
		stdout.writefln(`Generating script list file: %s`, script_list_file); stdout.flush();
		File file = File(script_list_file, "w");
		scope (exit) file.close();

		file.writefln("\n\nenum string[string] script_list = [");
		foreach (info ; class_infos) {
			file.writefln(`	"%s" : "%s",`, info._module, info.class_name);
		}
		file.writefln("];\n");
	}
	end = GetCpuTicksNS();
	stdout.writefln(`!!!! generated_script_list time: %s`, end - start); stdout.flush();

	stdout.writefln(`All verification checks were successful.`); stdout.flush();
	return 0;
}
