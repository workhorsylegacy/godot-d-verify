// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module scan_godot_project;


import std.stdio : stdout;



class RefConnection {
	string _signal = null;
	string _from = null;
	string _to = null;
	string _method = null;

	this(string line) {
		import std.string : format, strip, split;

		foreach (chunk ; line.split(`]`)[0].split(" ")) {
			string[] pair = chunk.split("=");
			switch (pair[0]) {
				case "signal": this._signal = pair[1].strip(`"`); break;
				case "from": this._from = pair[1].strip(`"`); break;
				case "to": this._to = pair[1].strip(`"`); break;
				case "method": this._method = pair[1].strip(`"`); break;
				default: break;
			}
		}
	}

	bool isValid() {
		return (
			_signal &&
			_from &&
			_to &&
			_method);
	}
}

class RefExtResource {
	string _path = null;
	string _type = null;

	this(string line) {
		import std.string : format, strip, split;

		foreach (chunk ; line.split(`]`)[0].split(" ")) {
			string[] pair = chunk.split("=");
			switch (pair[0]) {
				case "path": this._path = pair[1].strip(`"`).split(`res://`)[1]; break;
				case "type": this._type = pair[1].strip(`"`); break;
				default: break;
			}
		}
	}

	bool isValid() {
		return (
			_path &&
			_type);
	}
}

class Project {
	string main_scene_path = null;
	string _path = null;
	string _error = null;
	Scene[string] _scenes;
	GDScript[string] _gdscripts;
	NativeScript[string] _scripts;
	NativeLibrary[string] _libraries;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Read the project.godot file to find the main .tscn
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = cast(string)read(file_name);
		string section = null;
		foreach (line ; data.splitLines) {
			if (matchFirst(line, r"^\[\w+\]$")) {
				section = line;
			}

			if (section == "[application]" && line.startsWith("run/main_scene=")) {
				this.main_scene_path = line.split("run/main_scene=")[1].strip(`"`).split(`res://`)[1];
			}
		}
	}
}

class Scene {
	string _path = null;
	string _error = null;
	RefExtResource[] _resources;
	RefConnection[] _connections;

	this(string file_name) {
		import std.string : format, splitLines, startsWith;
		import std.file : read, exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = cast(string)read(file_name);
		foreach (line ; data.splitLines) {
			if (line.startsWith("[ext_resource ")) {
				auto res = new RefExtResource(line);
				if (res.isValid) {
					this._resources ~= res;
				}
			} else if (line.startsWith("[connection ")) {
				auto con = new RefConnection(line);
				if (con.isValid) {
					this._connections ~= con;
				}
			}
		}
	}
}

class GDScript {
	string _path = null;
	string _error = null;

	this(string file_name) {
		import std.string : format;
		import std.file : exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}
	}
}

class NativeScript {
	string _path = null;
	string _error = null;
	string _class_name = null;
	RefExtResource _native_library = null;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = cast(string)read(this._path);
		string section = null;
		foreach (line ; data.splitLines) {
			if (line.startsWith("[ext_resource ")) {
				auto res = new RefExtResource(line);
				if (res.isValid) {
					switch (res._type) {
						case "GDNativeLibrary": this._native_library = res; break;
						default: break;
					}
				}
			}

			if (matchFirst(line, r"^\[\w+\]$")) {
				section = line;
			}

			if (section == "[resource]" && line.startsWith("class_name = ")) {
				this._class_name = line.split("class_name = ")[1].strip(`"`);
			}
		}
	}
}

class NativeLibrary {
	string _path = null;
	string _error = null;
	string _dll_windows_path = null;
	string _dll_linux_path = null;
	string _symbol_prefix = null;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Make sure the file exists
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = cast(string)read(this._path);
		string section = null;
		foreach (line ; data.splitLines) {
			if (matchFirst(line, r"^\[\w+\]$")) {
				section = line;
			}

			if (section == "[general]" && line.startsWith("symbol_prefix=")) {
				this._symbol_prefix = line.split("symbol_prefix=")[1].strip(`"`);
			} else if (section == "[entry]" && line.startsWith("Windows.64=")) {
				this._dll_windows_path = line.split("Windows.64=")[1].strip(`"`).split(`res://`)[1];
			} else if (section == "[entry]" && line.startsWith("X11.64=")) {
				this._dll_linux_path = line.split("X11.64=")[1].strip(`"`).split(`res://`)[1];
			}
		}
	}
}

Project getGodotProject(string full_project_path) {
	import std.file : chdir, getcwd;
	import std.path : extension, baseName, dirName;

	string prev_dir = getcwd();
	string project_file = baseName(full_project_path);
	string project_dir = dirName(full_project_path);
	chdir(project_dir);

	auto project = new Project(project_file);
	if (project && project.main_scene_path) {
		auto scene = new Scene(project.main_scene_path);
		project._scenes[project.main_scene_path] = scene;
	}

	// Scan all the scenes, scripts, and libraries
	bool is_scanning = true;
	while (is_scanning) {
		is_scanning = false;
		foreach (Scene scene ; project._scenes.values()) {
			foreach (RefExtResource resource ; scene._resources) {
				switch (resource._type) {
					case "PackedScene":
						if (resource._path !in project._scenes) {
							project._scenes[resource._path] = new Scene(resource._path);
							is_scanning = true;
						}
						break;
					case "Script":
						if (resource._path !in project._scripts) {
							switch (extension(resource._path)) {
								case ".gdns":
									project._scripts[resource._path] = new NativeScript(resource._path);
									is_scanning = true;
									break;
								case ".gd":
									project._gdscripts[resource._path] = new GDScript(resource._path);
									//is_scanning = true;
									break;
								default:
									stdout.writefln("!!!!!! unexpected resource script extension: %s", resource._path); stdout.flush();
									break;
							}
						}
						break;
					default:
						//stdout.writefln("!!!!!! unexpected resource type: %s", resource._type); stdout.flush();
						break;
				}
			}
		}

		foreach (NativeScript script ; project._scripts.values()) {
			RefExtResource resource = script._native_library;
			if (resource && resource._path !in project._libraries) {
				project._libraries[resource._path] = new NativeLibrary(resource._path);
				is_scanning = true;
			}
		}
	}

	chdir(prev_dir);

	return project;
}

void printInfo(Project project) {
	// Print out everything
	stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); stdout.flush();
	stdout.writefln(".godot %s", project._path); stdout.flush();
	stdout.writefln("    main_scene_path %s", project.main_scene_path); stdout.flush();
	foreach (path, scene ; project._scenes) {
		stdout.writefln(".tscn %s", path); stdout.flush();
		stdout.writefln("    _error: %s", scene._error); stdout.flush();
	}
	foreach (path, script ; project._scripts) {
		stdout.writefln(".gdns %s", path); stdout.flush();
		stdout.writefln("    _error: %s", script._error); stdout.flush();
	}
	foreach (path, library ; project._libraries) {
		stdout.writefln(".gdnlib %s", path); stdout.flush();
		stdout.writefln("    _error: %s", library._error); stdout.flush();
	}
	stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); stdout.flush();
}

unittest {
	import BDD;
	import std.algorithm : map;
	import std.array : array;
	import std.file : chdir, getcwd;
	import scan_d_code : getCodeClasses;
	import scan_godot_project : Project, Scene, NativeScript, NativeLibrary;

	string _root_path = null;

	void reset_path(string project_path) {
		import std.path : absolutePath;
		import std.path : buildPath;

		if (! _root_path) {
			_root_path = getcwd();
		}
		//writefln(_root_path);
		//writefln(buildPath(_root_path, project_path));
		chdir(buildPath(_root_path, project_path));
	}

	describe("godot_verify#Project",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		it("Should parse project", delegate() {
			auto project = new Project("project.godot");
			project._path.shouldEqual("project.godot");
			project._error.shouldBeNull();
		}),
		it("Should fail to parse invalid project", delegate() {
			auto project = new Project("XXX.godot");
			project._path.shouldEqual("XXX.godot");
			project._error.shouldNotBeNull();
			project._error.shouldEqual("Failed to find XXX.godot file ...");
		})
	);

	describe("godot_verify#Scene",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		it("Should parse scene with child scene", delegate() {
			auto scene = new Scene("Level/Level.tscn");
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(2);

			scene._resources[0]._type.shouldEqual("PackedScene");
			scene._resources[0]._path.shouldEqual("Player/Player.tscn");
			scene._resources[0].isValid.shouldEqual(true);

			scene._resources[1]._type.shouldEqual("PackedScene");
			scene._resources[1]._path.shouldEqual("Box2/Box2.tscn");
			scene._resources[1].isValid.shouldEqual(true);
		}),
		it("Should parse scene with child resources", delegate() {
			auto scene = new Scene("Player/Player.tscn");
			scene._path.shouldEqual("Player/Player.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(2);

			scene._resources[0]._type.shouldEqual("Texture");
			scene._resources[0]._path.shouldEqual("icon.png");
			scene._resources[0].isValid.shouldEqual(true);

			scene._resources[1]._type.shouldEqual("Script");
			scene._resources[1]._path.shouldEqual("Player/Player.gdns");
			scene._resources[1].isValid.shouldEqual(true);
		}),
		it("Should fail to parse invalid scene", delegate() {
			auto scene = new Scene("Level/XXX.tscn");
			scene._path.shouldEqual("Level/XXX.tscn");
			scene._error.shouldNotBeNull();
			scene._error.shouldEqual("Failed to find Level/XXX.tscn file ...");
			scene._resources.length.shouldEqual(0);
		})
	);

	describe("godot_verify#NativeScript",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		it("Should parse native script", delegate() {
			auto script = new NativeScript("Player/Player.gdns");
			script._path.shouldEqual("Player/Player.gdns");
			script._error.shouldBeNull();
			script._class_name.shouldEqual("player.Player");

			script._native_library.shouldNotBeNull();
			script._native_library._path.shouldEqual("libgame.gdnlib");
			script._native_library._type.shouldEqual("GDNativeLibrary");
		}),
		it("Should fail to parse invalid native script", delegate() {
			auto script = new NativeScript("Player/XXX.gdns");
			script._path.shouldEqual("Player/XXX.gdns");
			script._error.shouldNotBeNull();
			script._error.shouldEqual("Failed to find Player/XXX.gdns file ...");
			script._class_name.shouldBeNull();

			script._native_library.shouldBeNull();
		})
	);

	describe("godot_verify#NativeLibrary",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		it("Should parse native library", delegate() {
			auto library = new NativeLibrary("libgame.gdnlib");
			library._path.shouldEqual("libgame.gdnlib");
			library._error.shouldBeNull();
			library._dll_windows_path.shouldEqual("game.dll");
			library._dll_linux_path.shouldEqual("libgame.so");
			library._symbol_prefix.shouldEqual("game");
		}),
		it("Should fail to parse invalid native library", delegate() {
			auto library = new NativeLibrary("XXX.gdnlib");
			library._path.shouldEqual("XXX.gdnlib");
			library._error.shouldNotBeNull();
			library._error.shouldEqual("Failed to find XXX.gdnlib file ...");
			library._dll_windows_path.shouldBeNull();
			library._dll_linux_path.shouldBeNull();
			library._symbol_prefix.shouldBeNull();
		})
	);

	describe("godot_verify#SceneSignal",
		it("Should parse scene with signal", delegate() {
			reset_path("test/project_signal/project/");

			// Make sure the scene is valid
			auto scene = new Scene("Level/Level.tscn");
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(1);

			// Make sure the scene's script resource is valid
			auto resource = scene._resources[0];
			resource._type.shouldEqual("Script");
			resource._path.shouldEqual("Level/Level.gdns");

			// Make sure the scene's script is valid
			auto script = new NativeScript(resource._path);
			script._error.shouldBeNull();
			script._class_name.shouldEqual("level.Level");
			scene._connections.length.shouldEqual(1);

			// Make sure scene's signal connection is valid
			auto connection = scene._connections[0];
			connection._signal.shouldEqual("pressed");
			connection._from.shouldEqual("Button");
			connection._to.shouldEqual(".");
			connection._method.shouldEqual("on_button_pressed"); // FIXME: onButtonPressed
			connection.isValid.shouldEqual(true);

			// Make sure the D code is valid
			chdir(_root_path);
			auto class_infos = getCodeClasses("test/project_signal/src/");
			class_infos.length.shouldEqual(1);
			auto class_info = class_infos[0];
			class_info._module.shouldEqual("level");
			class_info.class_name.shouldEqual("Level");
			class_info.base_class_name.shouldEqual("GodotScript");
			"_ready".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"_process".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"onButtonPressed".shouldBeIn(class_info.methods.map!(m => m.name).array);
		}),
		it("Should fail to parse scene with missing signal method", delegate() {
			reset_path("test/project_signal_missing/project/");

			// Made sure the scene is valid
			auto scene = new Scene("Level/Level.tscn");
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(1);

			// Make sure the scene's script resource is valid
			auto resource = scene._resources[0];
			resource._type.shouldEqual("Script");
			resource._path.shouldEqual("Level/Level.gdns");

			// Make sure the scene's script is valid
			auto script = new NativeScript(resource._path);
			script._error.shouldBeNull();
			script._class_name.shouldEqual("level.Level");
			scene._connections.length.shouldEqual(1);

			// Make sure scene's signal connection is valid
			auto connection = scene._connections[0];
			connection._signal.shouldEqual("pressed");
			connection._from.shouldEqual("Button");
			connection._to.shouldEqual(".");
			connection._method.shouldEqual("xxx"); // FIXME: onButtonPressed
			connection.isValid.shouldEqual(true);

			// Make sure the D code is valid
			chdir(_root_path);
			auto class_infos = getCodeClasses("test/project_signal_missing/src/");
			class_infos.length.shouldEqual(1);
			auto class_info = class_infos[0];
			class_info._module.shouldEqual("level");
			class_info.class_name.shouldEqual("Level");
			class_info.base_class_name.shouldEqual("GodotScript");
			"_ready".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"_process".shouldBeIn(class_info.methods.map!(m => m.name).array);
			"xxx".shouldNotBeIn(class_info.methods.map!(m => m.name).array);
			"onButtonPressed".shouldNotBeIn(class_info.methods.map!(m => m.name).array);
		})
	);
}
