// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify




int main() {
	import std.stdio : stdout;
	import verify_godot;
	import verify_d_code;

	stdout.writefln("Verifying godot project ..."); stdout.flush();
	string project_path = `C:\Users\matt\Projects\PumaGameGodot\`;

	// Scan the godot.project
	auto project = scanProject(project_path ~ `project\project.godot`);

	// 
	auto class_infos = getCodeClasses(project_path ~ `src\`);

	//printInfo(project);
	//printErrors(project);

	return 0;
}
