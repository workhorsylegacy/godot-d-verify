// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify



int main(string[] args) {
	import std.stdio : stdout, stderr;
	import std.algorithm : canFind, endsWith;
	import std.file : chdir;
	import godot_project_parse : parseProject;
	import scan_d_code : getCodeClasses;
	import godot_project_verify : verifyProject;

	// Change the dir to the location of the current exe
	chdir(dirName(args[0]));
	//stdout.writefln("getcwd: %s", getcwd()); stdout.flush();

	// Get the project path
	string project_path;
	if (args.length == 3 && ["--project", "-p"].canFind(args[1])) {
		project_path = args[2];
	} else {
		stderr.writefln(
		"Verify Godot D Project\n" ~
		"-p --project Required:\n" ~
		"-h    --help           This help information.\n"); stderr.flush();
		return 1;
	}
	//stdout.writefln("args: %s", args); stdout.flush();

	// Add a / to the path if missing
	if (! project_path.endsWith(`/`)) {
		project_path ~= `/`;
	}

	// Verify
	stdout.writefln("Verifying %s ...", project_path); stdout.flush();

	// Get the godot project info
	auto project = parseProject(buildPath(project_path, `project/project.godot`));

	// Get the D class info
	auto class_infos = getCodeClasses(buildPath(project_path, `src/`));

	// Find and print any errors
	auto project_errors = verifyProject(project_path ~ `project/`, project, class_infos);
	foreach (name, errors ; project_errors) {
		stderr.writeln(name);
		foreach (error ; errors) {
			stderr.writeln("    ", error);
		}
	}

	return project_errors.length == 0 ? 0 : 1;
}
