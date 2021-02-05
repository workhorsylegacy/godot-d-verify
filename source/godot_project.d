// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module godot_project;


import std.stdio : stdout;
import helpers;

class ResourceId {
	int id;

	this(int id) {
		this.id = id;
	}
}

class RefNode {
	string _name = null;
	string _type = null;
	string _parent = null;
	ResourceId _instance = null;
	ResourceId _script = null;

	this(string section) {
		import std.string : format, strip, split, splitLines;
		import std.conv : to;
		import std.regex;
		import std.algorithm : map;
		import std.array : array;


		foreach (line ; section.splitLines) {
			// Make sure it is a node
			if (line.matchFirst(r"^\[node (\w|\W)*\]$")) {
	//			stdout.writefln("??????? NOT node, exiting. line: %s", line); stdout.flush();
		//		stdout.writefln("??????? line: %s", line); stdout.flush();
				foreach (match; line.matchAll(regex(`[A-Za-z]*\s*=\s*"(\w|\.)*"`))) {
		//			stdout.writefln(`    match.hit: "%s"`, match.hit); stdout.flush();
					string[] pair = match.hit.split("=").map!(n => n.strip()).array();
					switch (pair[0]) {
						case "name": this._name = pair[1].strip(`"`); break;
						case "type": this._type = pair[1].strip(`"`); break;
						case "parent": this._parent = pair[1].strip(`"`); break;
						default: break;
					}
				}

		//		stdout.writefln("!!!!!!!!!!!!! line: %s", line); stdout.flush();
				foreach (match; line.matchAll(regex(`instance\s*=\s*ExtResource\(\s*\d+\s*\)`))) {
		//			stdout.writefln(`    match.hit: "%s"`, match.hit); stdout.flush();
					string[] pair = match.hit.split("=").map!(n => n.strip()).array();
					int id = pair[1].between("ExtResource(", ")").strip.to!int;
					this._instance = new ResourceId(id);
				}
			} else if (line.matchFirst(`^script\s*=\s*ExtResource\(\s*\d+\s*\)$`)) {
				string[] pair = line.split("=").map!(n => n.strip()).array();
				int id = pair[1].between("ExtResource(", ")").strip.to!int;
				this._script = new ResourceId(id);
			}
		}
	}

	bool isValid() {
		return (
			_name &&
			_type);
	}
}

unittest {
	import BDD;

	describe("godot_project#RefNode",
		it("Should parse node", delegate() {
			auto node = new RefNode(
`[node name ="Level" type = "Spatial" parent="." instance= ExtResource( 27 )]
script = ExtResource( 2 )
`);
			node._name.shouldEqual("Level");
			node._type.shouldEqual("Spatial");
			node._parent.shouldEqual(".");
			node._instance.shouldNotBeNull();
			node._instance.id.shouldEqual(27);
			node._script.shouldNotBeNull();
			node._script.id.shouldEqual(2);
		})
	);
}

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
	int _id = -1;

	this(string line) {
		import std.conv : to;
		import std.string : format, strip, split;

		foreach (chunk ; line.split(`]`)[0].split(" ")) {
			string[] pair = chunk.split("=");
			switch (pair[0]) {
				case "path": this._path = pair[1].strip(`"`).split(`res://`)[1]; break;
				case "type": this._type = pair[1].strip(`"`); break;
				case "id": this._id = pair[1].strip(`"`).to!int; break;
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

unittest {
	import BDD;

	describe("godot_project#RefExtResource",
		it("Should parse ext resource", delegate() {
			auto resource = new RefExtResource(`[ext_resource path="res://src/ClothHolder/ClothHolder.tscn" type="PackedScene" id=21]`);
			resource._path.shouldEqual("src/ClothHolder/ClothHolder.tscn");
			resource._type.shouldEqual("PackedScene");
			resource._id.shouldEqual(21);
		})
	);
}

class Project {
	string _main_scene_path = null;
	string _path = null;
	string _error = null;
	Scene[string] _scenes;
	GDScript[string] _gdscripts;
	NativeScript[string] _scripts;
	NativeLibrary[string] _libraries;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith, replace;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Read the project.godot file to find the main .tscn
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = (cast(string)read(file_name)).replace("\r\n", "\n");
		string section = null;
		foreach (line ; data.splitLines) {
			if (matchFirst(line, r"^\[\w+\]$")) {
				section = line;
			}

			if (section == "[application]" && line.startsWith("run/main_scene=")) {
				this._main_scene_path = line.split("run/main_scene=")[1].strip(`"`).split(`res://`)[1];
			}
		}
	}
}

unittest {
	import BDD;
	import std.file : chdir;

	describe("godot_project#Project",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		after(delegate(){
			chdir(_root_path);
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
}

class Scene {
	string _path = null;
	string _error = null;
	RefNode[] _nodes;
	RefExtResource[] _resources;
	RefConnection[] _connections;

	this(string file_name) {
		import std.string : format, split, splitLines, startsWith, strip, replace;
		import std.file : read, exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		// FIXME Update RefExtResource and RefConnection to use section instead of line
		auto data = (cast(string)read(file_name)).replace("\r\n", "\n");
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

		foreach (section ; data.split("\n\n")) {
			section = section.strip;
			if (section.startsWith("[node ")) {
				auto node = new RefNode(section);
				if (node.isValid) {
					_nodes ~= node;
				}
			}
		}
	}
}

unittest {
	import BDD;
	import std.file : chdir;

	describe("godot_project#Scene",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		after(delegate(){
			chdir(_root_path);
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
		import std.string : format, strip, split, splitLines, startsWith, replace;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = (cast(string)read(this._path)).replace("\r\n", "\n");
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

unittest {
	import BDD;
	import std.file : chdir;

	describe("godot_project#NativeScript",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		after(delegate(){
			chdir(_root_path);
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
}

class NativeLibrary {
	string _path = null;
	string _error = null;
	string _dll_windows_path = null;
	string _dll_linux_path = null;
	string _symbol_prefix = null;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith, replace;
		import std.file : read, exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Make sure the file exists
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		auto data = (cast(string)read(this._path)).replace("\r\n", "\n");
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

unittest {
	import BDD;
	import std.file : chdir;

	describe("godot_project#NativeLibrary",
		before(delegate(){
			reset_path("test/project_normal/project/");
		}),
		after(delegate(){
			chdir(_root_path);
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
}
