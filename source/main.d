// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify



/*
int main() {
	import std.stdio : stdout;
	import std.file : chdir;

	// Scan the godot.project file and main scene
	stdout.writefln("Verifying godot project ..."); stdout.flush();
	chdir("project/");

	auto project = scanProject("project.godot");
	printInfo(project);
	printErrors(project);
	generateCode(g_scenes, g_scripts, g_libraries);

	return 0;
}
*/

int main() {
	import std.stdio;
	writeln("Main called ...");
	return 0;
}
