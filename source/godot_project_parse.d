// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module godot_project_parse;


import std.stdio : stdout;
import godot_project;

void getProjectFiles(string full_project_path, void delegate(string full_file_path) cb) {
	import std.path : extension;
	import std.array : replace, array;
	import std.algorithm : canFind;
	import std.string : chompPrefix, stripLeft;
	import helpers : getcwd, chdir, baseName, dirName, dirEntries, SpanMode;

	string prev_dir = getcwd();
	scope (exit) chdir(prev_dir);

	// Get the directory path
	string project_file = baseName(full_project_path);
	string project_dir = dirName(full_project_path);
	chdir(project_dir);

	// Get the paths of all the files to scan
	immutable string[] extensions = [".gdns", ".tscn", ".gdnlib", ".gd"];
	auto entries = dirEntries(project_dir, SpanMode.breadth);

	cb("project.godot");
	foreach (e ; entries) {
		if (! e.isFile || ! extensions.canFind(e.name.extension)) continue;

		auto f = e.name
			.replace(`\`, `/`)
			.chompPrefix(project_dir)
			.stripLeft(`/`);
		cb(f);
	}
}

Project parseProject(string full_project_path) {
	import std.path : extension;
	import std.array : replace, array;
	import std.algorithm : filter, map, canFind;
	import std.string : chompPrefix, stripLeft;
	import helpers : getcwd, chdir, baseName, dirName, dirEntries, SpanMode;

	string prev_dir = getcwd();
	scope (exit) chdir(prev_dir);

	// Get the directory path
	string project_file = baseName(full_project_path);
	string project_dir = dirName(full_project_path);
	chdir(project_dir);

	// Get the paths of all the files to scan
	immutable string[] extensions = [".gdns", ".tscn", ".gdnlib", ".gd"];
	string[] files_to_scan = "project.godot" ~
			dirEntries(project_dir, SpanMode.breadth)
			.filter!(e => extensions.canFind(e.name.extension))
			.filter!(e => e.isFile)
			.map!(e => e.name.replace(`\`, `/`))
			.map!(e => e.chompPrefix(project_dir))
			.map!(e => e.stripLeft(`/`))
			.array;

	// Scan each file
	Project project;
	foreach (name ; files_to_scan) {
		switch (extension(name)) {
			case ".godot":
				project = new Project(name);
				break;
			case ".tscn":
				project._scenes[name] = new Scene(name);
				break;
			case ".gdns":
				project._scripts[name] = new NativeScript(name);
				break;
			case ".gd":
				project._gdscripts[name] = new GDScript(name);
				break;
			case ".gdnlib":
				project._libraries[name] = new NativeLibrary(name);
				break;
			default:
				break;
		}
	}

	return project;
}

unittest {
	import BDD;
	import std.algorithm : map;
	import std.array : array;
	import helpers : absolutePath;
	import scan_d_code : getGodotScriptClasses;

	describe("godot_project_parse#SceneSignal",
		it("Should parse basic project", delegate() {
			string project_path = absolutePath(`test/project_signal/`);

			// Make sure there is a project
			auto project = parseProject(project_path ~ `project/project.godot`);
			project.shouldNotBeNull();

			// Make sure there is a scene
			project._scenes.keys.shouldEqual(["Level/Level.tscn"]);
			auto scene = project._scenes["Level/Level.tscn"];
			scene.shouldNotBeNull();

			// Make sure the scene has a signal
			scene._connections.length.shouldEqual(1);
			auto connection = scene._connections[0];
			connection.isValid.shouldEqual(true);

			// Make sure the scene has a resource
			scene._resources.map!(r => r._path).array.shouldEqual(["Level/Level.gdns"]);
			auto resource = scene._resources[0];

			// Make sure the scene has a script
			project._scripts.keys.shouldEqual(["Level/Level.gdns"]);
			auto script = project._scripts["Level/Level.gdns"];
			scene._connections.length.shouldEqual(1);

			// Make sure there is D code
			auto class_infos = getGodotScriptClasses(project_path ~ `src/`);
			class_infos.map!(c => c.class_name).array.shouldEqual(["Level"]);
		}),
		it("Should parse project with unreferenced files", delegate() {
			string project_path = absolutePath(`test/project_unreferenced_files/`);

			// Make sure there is a project
			auto project = parseProject(project_path ~ `project/project.godot`);
			project.shouldNotBeNull();

			// Make sure all scenes, scripts, and libraries were found
			project._scenes.keys.shouldEqual(["Player/Player.tscn", "Box2/Box2.tscn", "Level/Level.tscn"]);
			project._gdscripts.keys.shouldEqual(["Box2/Box2.gd"]);
			project._scripts.keys.shouldEqual(["Player/Player.gdns"]);
			project._libraries.keys.shouldEqual(["libgame.gdnlib"]);

			// Make sure the D code was found
			auto class_infos = getGodotScriptClasses(project_path ~ `src/`);
			class_infos.map!(c => c.class_name).array.shouldEqual(["Player"]);
		})
	);
}
