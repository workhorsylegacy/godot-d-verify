// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module godot_project;


import std.stdio : stdout;
import helpers;

class EntryExtResource {
	int id;

	this(int id) {
		this.id = id;
	}
}

class HeadingNode {
	string _name = null;
	string _type = null;
	string _parent = null;
	EntryExtResource _instance = null;
	EntryExtResource _script = null;

	static bool isHeading(string line) {
		import std.regex : matchFirst;
		return ! line.matchFirst(r"^\[node (\w|\W)*\]").empty;
	}

	this(string section) {
		import std.string : format, strip, split, splitLines;
		import std.conv : to;
		import std.regex;
		import std.algorithm : map;

		foreach (line ; section.splitLines) {
			// Make sure it is a node
			if (HeadingNode.isHeading(line)) {
				foreach (match; line.matchAll(regex(`[A-Za-z]*\s*=\s*"(\w|\.)*"`))) {
					auto pair = match.hit.split("=").map!(n => n.strip().strip(`"`));
					switch (pair[0]) {
						case "name": this._name = pair[1]; break;
						case "type": this._type = pair[1]; break;
						case "parent": this._parent = pair[1]; break;
						default: break;
					}
				}

				foreach (match; line.matchAll(regex(`instance\s*=\s*ExtResource\(\s*\d+\s*\)`))) {
					auto pair = match.hit.split("=").map!(n => n.strip());
					int id = pair[1].between("ExtResource(", ")").strip.to!int;
					this._instance = new EntryExtResource(id);
				}
			} else if (line.matchFirst(`^script\s*=\s*ExtResource\(\s*\d+\s*\)$`)) {
				auto pair = line.split("=").map!(n => n.strip());
				int id = pair[1].between("ExtResource(", ")").strip.to!int;
				this._script = new EntryExtResource(id);
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

	describe("godot_project#HeadingNode",
		it("Should parse node", delegate() {
			auto node = new HeadingNode(
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

class HeadingConnection {
	string _signal = null;
	string _from = null;
	string _to = null;
	string _method = null;

	static bool isHeading(string line) {
		import std.regex : matchFirst;
		return ! line.matchFirst(r"^\[connection (\w|\W)*\]$").empty;
	}

	this(string section) {
		import std.string : format, strip, split, splitLines;
		import std.conv : to;
		import std.regex;
		import std.algorithm : map;

		foreach (line ; section.splitLines) {
			// Make sure it is a node
			if (HeadingConnection.isHeading(line)) {
				foreach (match; line.matchAll(regex(`[A-Za-z]*\s*=\s*"(\w|\.)*"`))) {
					auto pair = match.hit.split("=").map!(n => n.strip().strip(`"`));
					switch (pair[0]) {
						case "signal": this._signal = pair[1]; break;
						case "from": this._from = pair[1]; break;
						case "to": this._to = pair[1]; break;
						case "method": this._method = pair[1]; break;
						default: break;
					}
				}
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

unittest {
	import BDD;

	describe("godot_project#HeadingConnection",
		it("Should parse connection", delegate() {
			auto conn = new HeadingConnection(
`[connection signal="pressed" from="Button" to="." method="on_button_pressed"]
`);
			conn._signal.shouldEqual("pressed");
			conn._from.shouldEqual("Button");
			conn._to.shouldEqual(".");
			conn._method.shouldEqual("on_button_pressed");
		})
	);
}

class HeadingExtResource {
	string _path = null;
	string _type = null;
	int _id = -1;

	static bool isHeading(string line) {
		import std.regex : matchFirst;
		return ! line.matchFirst(r"^\[ext_resource (\w|\W)*\]").empty;
	}

	this(string section) {
		import std.conv : to;
		import std.string : format, strip, split, splitLines;
		import std.algorithm : map;

		foreach (line ;  section.splitLines) {
			foreach (chunk ; line.before(`]`).split(" ")) {
				auto pair = chunk.split("=").map!(n => n.strip().strip(`"`));
				switch (pair[0]) {
					case "path": this._path = pair[1].after(`res://`); break;
					case "type": this._type = pair[1]; break;
					case "id": this._id = pair[1].to!int; break;
					default: break;
				}
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

	describe("godot_project#HeadingExtResource",
		it("Should parse ext resource", delegate() {
			auto resource = new HeadingExtResource(`[ext_resource path="res://src/ClothHolder/ClothHolder.tscn" type="PackedScene" id=21]`);
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
		import std.file : exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Read the project.godot file to find the main .tscn
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		string heading = null;
		foreach (section ; readFileSections(file_name)) {
			foreach (line ; section.splitLines) {
				if (matchFirst(line, r"^\[\w+\]$")) {
					heading = line;
				}

				if (heading == "[application]" && line.startsWith("run/main_scene=")) {
					this._main_scene_path = line.after("run/main_scene=").strip(`"`).after(`res://`);
				}
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
	HeadingNode[] _nodes;
	HeadingExtResource[] _resources;
	HeadingConnection[] _connections;

	this(string file_name) {
		import std.string : format, split, splitLines, startsWith, strip, replace;
		import std.file : exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(file_name)) {
			if (auto node = tryParseHeading!HeadingNode(section)) {
				_nodes ~= node;
			} else if (auto con = tryParseHeading!HeadingConnection(section)) {
				this._connections ~= con;
			} else if (auto res = tryParseHeading!HeadingExtResource(section)) {
				this._resources ~= res;
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
	HeadingExtResource _native_library = null;

	this(string file_name) {
		import std.string : format, strip, split, splitLines, startsWith, replace;
		import std.file : exists;
		import std.regex : matchFirst;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		string heading = null;
		foreach (section ; readFileSections(this._path)) {
			foreach (line ; section.splitLines) {
				if (auto res = tryParseHeading!HeadingExtResource(line)) {
					switch (res._type) {
						case "GDNativeLibrary": this._native_library = res; break;
						default: break;
					}
				}

				if (matchFirst(line, r"^\[\w+\]$")) {
					heading = line;
				}

				if (heading == "[resource]" && line.startsWith("class_name = ")) {
					this._class_name = line.after("class_name = ").strip(`"`);
				}
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
		import std.file : exists;
		import std.regex : matchFirst;

		this._path = file_name;

		// Make sure the file exists
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(this._path)) {
			string heading = null;
			foreach (line ; section.splitLines) {
				if (matchFirst(line, r"^\[\w+\]$")) {
					heading = line;
				}

				if (heading == "[general]" && line.startsWith("symbol_prefix=")) {
					this._symbol_prefix = line.after("symbol_prefix=").strip(`"`);
				} else if (heading == "[entry]" && line.startsWith("Windows.64=")) {
					this._dll_windows_path = line.after("Windows.64=").strip(`"`).after(`res://`);
				} else if (heading == "[entry]" && line.startsWith("X11.64=")) {
					this._dll_linux_path = line.after("X11.64=").strip(`"`).after(`res://`);
				}
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

private

T tryParseHeading(T)(string section) {
	if (T.isHeading(section)) {
		auto node = new T(section);
		if (node.isValid) {
			return node;
		}
	}
	return null;
}

string[] readFileSections(string file_name) {
	import std.string : split, startsWith, strip, replace;
	import std.file : read;
	import std.array : array;
	import std.algorithm : map;

	string[] sections =
		(cast(string) read(file_name))
		.replace("\r\n", "\n")
		.split("\n[")
		.map!(sec => ("[" ~ sec).strip)
		.array;

	// Remove the extra "[" from the start of the first section
	if (sections.length > 0 && sections[0].startsWith("[")) {
		sections[0] = sections[0][1 .. $];
	}

	return sections;
}
