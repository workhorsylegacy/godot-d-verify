// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify




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
