// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module verify_godot;


import std.stdio : stdout;



class RefConnection {
	string _signal = null;
	string _from = null;
	string _to = null;
	string _method = null;

	this(string line) {
		import std.stdio : writefln;
		import std.string : format, strip, split, splitLines, startsWith;

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
/*
		if (this.is_valid) {
			writefln("## signal:%s, from:%s, to:%s, method:%s", _signal, _from, _to, _method);
		}
*/
	}

	bool is_valid() {
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
		import std.stdio : writefln;
		import std.string : format, strip, split, splitLines, startsWith;

		foreach (chunk ; line.split(`]`)[0].split(" ")) {
			string[] pair = chunk.split("=");
			switch (pair[0]) {
				case "path": this._path = pair[1].strip(`"`).split(`res://`)[1]; break;
				case "type": this._type = pair[1].strip(`"`); break;
				default: break;
			}
		}
/*
		if (this.is_valid) {
			writefln("## path:%s, type:%s", _path, _type);
		}
*/
	}

	bool is_valid() {
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
	NativeScript[string] _scripts;
	NativeLibrary[string] _libraries;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith;
		import std.stdio : stdout, stderr, writefln;
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
//	string _resource_type = null;
	RefExtResource[] _resources;
	RefConnection[] _connections;

	this(string file_name/*, string resource_type*/) {
		import std.string : format, strip, split, splitLines, startsWith;
		import std.stdio : stdout, stderr, writefln;
		import std.file : read, exists;

		this._path = file_name;
//		this._resource_type = resource_type;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = cast(string)read(file_name);
		foreach (line ; data.splitLines) {
			if (line.startsWith("[ext_resource ")) {
				auto res = new RefExtResource(line);
				if (res.is_valid) {
					this._resources ~= res;
				}
			} else if (line.startsWith("[connection ")) {
				auto con = new RefConnection(line);
				if (con.is_valid) {
					this._connections ~= con;
				}
			}
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
		import std.stdio : stdout, stderr, writefln;
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
				if (res.is_valid) {
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
		import std.stdio : stdout, stderr, writefln;
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

Project scanProject(string full_project_path) {
	import std.file : chdir, getcwd;
	import std.path : baseName, dirName;

	string prev_dir = getcwd();
	string project_file = baseName(full_project_path);
	string project_dir = dirName(full_project_path);
	chdir(project_dir);

	auto project = new Project(project_file);
	if (project) {
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
							project._scripts[resource._path] = new NativeScript(resource._path);
							is_scanning = true;
						}
						break;
					default:
						break;
				}
			}
		}

		foreach (NativeScript script ; project._scripts.values()) {
			RefExtResource resource = script._native_library;
			if (resource._path !in project._libraries) {
				project._libraries[resource._path] = new NativeLibrary(resource._path);
				is_scanning = true;
			}
		}
	}

	chdir(prev_dir);

	return project;
}

void printInfo(Project project) {
	import std.stdio : stdout;

	// Print out everything
	stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); stdout.flush();
	stdout.writefln(".project %s", project._path); stdout.flush();
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

void printErrors(Project project) {
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

		foreach (RefConnection connection ; scene._connections) {
			connection._signal.shouldEqual("pressed");
			connection._from.shouldEqual("Button");
			connection._to.shouldEqual(".");
			connection._method.shouldEqual("on_button_pressed"); // FIXME: onButtonPressed
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
