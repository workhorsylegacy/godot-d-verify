// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

import helpers;
import godot_project;
import godot_project_parse;
import godot_project_verify : verifyProject;
import scan_d_code : getGodotScriptClasses;

import std.stdio : stdout, stderr, File;

bool is_printing_time = false;

int main(string[] args) {
	import std.file : chdir, exists;
	import std.getopt : getopt, config;
	import std.parallelism : Task, task, TaskPool, totalCPUs;
	import std.sumtype : SumType, match;
	import std.algorithm.comparison : clamp;

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
	if (is_printing_time) {
		stdout.writefln(`!!!! setup time: %s`, end - start); stdout.flush();
	}

	start = GetCpuTicksNS();

	alias GodotFile = SumType!(Project, Scene, NativeScript, GDScript, NativeLibrary);

	static immutable auto parse_godot_file = function(string name) {
		import std.string : format;
		import std.path : extension;

		switch (extension(name)) {
			case ".godot":
				return GodotFile(new Project(name));
			case ".tscn":
				return GodotFile(new Scene(name));
			case ".gdns":
				return GodotFile(new NativeScript(name));
			case ".gd":
				return GodotFile(new GDScript(name));
			case ".gdnlib":
				return GodotFile(new NativeLibrary(name));
			default:
				throw new Exception(`Unexpected file type: "%s"`.format(name));
		}
	};

	// Setup task pool to use 1 to 4 threads
	u32 cpu_count = clamp(totalCPUs, 1, 4);
	auto task_pool = new TaskPool(cpu_count);
	scope(exit) task_pool.stop();

	// Start parsing each file in a task pool
	Task!(parse_godot_file, string)*[] _parse_tasks;
	getProjectFiles(project_path, (string name) {
		//stdout.writefln(`!!!! name: %s`, name); stdout.flush();
		auto t = task!(parse_godot_file)(name);
		_parse_tasks ~= t;
		task_pool.put(t);
	});

	// Complete all tasks in the pool
	task_pool.finish();

	// Copy all parsed files into project
	Project project;
	foreach (t ; _parse_tasks) {
		GodotFile godot_file = t.yieldForce();
		godot_file.match!(
			(Project p) { project = p; },
			(Scene s) { project._scenes[s._path] = s; },
			(NativeScript ns) { project._scripts[ns._path] = ns; },
			(GDScript gs) { project._gdscripts[gs._path] = gs; },
			(NativeLibrary nl) { project._libraries[nl._path] = nl; }
		);
	}

	end = GetCpuTicksNS();
	if (is_printing_time) {
		stdout.writefln(`!!!! parse time: %s`, end - start); stdout.flush();
	}

	start = GetCpuTicksNS();
	auto class_infos = getGodotScriptClasses(source_path);
	end = GetCpuTicksNS();
	if (is_printing_time) {
		stdout.writefln(`!!!! get script classes time: %s`, end - start); stdout.flush();
	}

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
	if (is_printing_time) {
		stdout.writefln(`!!!! verify time: %s`, end - start); stdout.flush();
	}

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
	if (is_printing_time) {
		stdout.writefln(`!!!! generated_script_list time: %s`, end - start); stdout.flush();
	}

	stdout.writefln(`All verification checks were successful.`); stdout.flush();
	return 0;
}
