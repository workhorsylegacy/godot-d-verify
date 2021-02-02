// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify



int main(string[] args) {
	import std.stdio : stdout, stderr;
	import std.file : chdir;
	import std.file : exists;
	import std.getopt : getopt, config, GetOptException;
	import helpers : dirName, buildPath, toPosixPath;
	import godot_project_parse : parseProject;
	import scan_d_code : getCodeClasses;
	import godot_project_verify : verifyProject;

	// Change the dir to the location of the current exe
	chdir(dirName(args[0]));

	// Get the options
	string project_path = null;
	string source_path = null;
	bool is_help = false;
	string getopt_error = null;
	try {
		auto result = getopt(args,
		config.required, "project", &project_path,
		config.required, "source", &source_path);
		is_help = result.helpWanted;
	} catch (Exception err) {
		getopt_error = err.msg;
		is_help = true;
	}

	// If there was an error, print the help and quit
	if (is_help) {
		stderr.writefln(
		"Verify Godot D Project\n" ~
		"--project    Directory containing Godot project. Required:\n" ~
		"--source     Directory containing D source code. Required:\n" ~
		"--help       This help information.\n"); stderr.flush();

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

	source_path = toPosixPath(source_path);
	if (! exists(source_path)) {
		stderr.writefln(`Error: D source code directory not found: %s`, source_path); stderr.flush();
		return 1;
	}

	// Get the project info
	stdout.writefln(`Verifying Godot D Project at "%s"`, project_path); stdout.flush();
	auto project = parseProject(buildPath(project_path, `project.godot`));
	auto class_infos = getCodeClasses(source_path);

	// Find and print any errors
	auto project_errors = verifyProject(project_path, project, class_infos);
	foreach (name, errors ; project_errors) {
		stderr.writeln(name);
		foreach (error ; errors) {
			stderr.writeln("    ", error);
		}
	}

	return project_errors.length == 0 ? 0 : 1;
}
