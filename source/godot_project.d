// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
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

	this(string section) {
		import std.string : strip, splitLines;
		import std.conv : to;

		bool got_heading = false;
		foreach (line ; section.splitLines) {
			// Node heading
			// [node name="AnimationPlayer" type="AnimationPlayer" parent="." instance=ExtResource( 3 )]
			if (! got_heading && SectionType.Node == getSectionType(line)) {
				got_heading = true;
				foreach (key, value ; parseKeyValues(line)) {
					switch (key) {
						case "name": this._name = value; break;
						case "type": this._type = value; break;
						case "parent": this._parent = value; break;
						case "instance":
							int id = value.between("ExtResource(", ")").strip.to!int;
							this._instance = new EntryExtResource(id);
							break;
						default: break;
					}
				}
			}

			// Key value pairs under heading
			// script = ExtResource( 2 )
			if (got_heading) {
				foreach (key, value ; parseKeyValues(line)) {
					switch (key) {
						case "script":
							int id = value.between("ExtResource(", ")").strip.to!int;
							this._script = new EntryExtResource(id);
							break;
						default: break;
					}
				}
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

	this(string section) {
		import std.string : splitLines;
		import std.conv : to;

		bool got_heading = false;
		foreach (line ; section.splitLines) {
			// Connection heading
			// [connection signal="pressed" from="Button" to="." method="on_button_pressed"]
			if (! got_heading && SectionType.Connection == getSectionType(line)) {
				got_heading = true;
				foreach (key, value ; parseKeyValues(line)) {
					switch (key) {
						case "signal": this._signal = value; break;
						case "from": this._from = value; break;
						case "to": this._to = value; break;
						case "method": this._method = value; break;
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

	this(string section) {
		import std.conv : to;
		import std.string : splitLines;

		bool got_heading = false;
		foreach (line ; section.splitLines) {
			// ExtResource heading
			// [ext_resource path="res://src/ClothHolder/ClothHolder.tscn" type="PackedScene" id=21]
			if (! got_heading && SectionType.ExtResource == getSectionType(line)) {
				got_heading = true;
				foreach (key, value ; parseKeyValues(line)) {
					switch (key) {
						case "path": this._path = value.after(`res://`); break;
						case "type": this._type = value; break;
						case "id": this._id = value.to!int; break;
						default: break;
					}
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
		import std.string : format;
		import std.file : exists;

		this._path = file_name;

		// Read the project.godot file to find the main .tscn
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(file_name)) {
			auto data = parseAllSectionKeyValues(section);
			// [application]
			// run/main_scene="res://src/Level/Level.tscn"
			if (auto heading = data.get("[application]", null)) {
				if (auto entry = heading.get("run/main_scene", null)) {
					this._main_scene_path = entry.after(`res://`);
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
		import std.string : format;
		import std.file : exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(file_name)) {
			final switch(getSectionType(section)) {
				case SectionType.Unknown:
					break;
				// [node name="Level" type="Spatial"]
				case SectionType.Node:
					auto node = new HeadingNode(section);
					if (node.isValid) {
						_nodes ~= node;
					}
					break;
				// [connection signal="area_exited" from="ScreenBox" to="." method="on_screen_box_area_exited"]
				case SectionType.Connection:
					auto conn = new HeadingConnection(section);
					if (conn.isValid) {
						_connections ~= conn;
					}
					break;
				// [ext_resource path="res://src/ClothHolder/ClothHolder.tscn" type="PackedScene" id=21]
				case SectionType.ExtResource:
					auto resource = new HeadingExtResource(section);
					if (resource.isValid) {
						_resources ~= resource;
					}
					break;
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
		import std.string : format, splitLines;
		import std.file : exists;

		this._path = file_name;

		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(this._path)) {
			// [ext_resource path="res://libgame.gdnlib" type="GDNativeLibrary" id=1]
			switch (getSectionType(section)) {
				case SectionType.ExtResource:
					auto resource = new HeadingExtResource(section);
					if (resource.isValid && resource._type == "GDNativeLibrary") {
						this._native_library = resource;
					}
					break;
				default:
					break;
			}

			// [resource]
			// class_name = "player.Player"
			auto data = parseAllSectionKeyValues(section);
			if (auto heading = data.get("[resource]", null)) {
				if (auto entry = heading.get("class_name", null)) {
					this._class_name = entry;
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
		import std.string : format;
		import std.file : exists;

		this._path = file_name;

		// Make sure the file exists
		if (! exists(file_name)) {
			this._error = "Failed to find %s file ...".format(file_name);
			return;
		}

		foreach (section ; readFileSections(this._path)) {
			auto data = parseAllSectionKeyValues(section);
			// [general]
			// symbol_prefix="game"
			if (auto heading = data.get("[general]", null)) {
				if (auto entry = heading.get("symbol_prefix", null)) {
					this._symbol_prefix = entry;
				}
			// [entry]
			// Windows.64="res://game.dll"
			// X11.64="res://libgame.so"
			} else if (auto heading = data.get("[entry]", null)) {
				if (auto entry = heading.get("Windows.64", null)) {
					this._dll_windows_path = entry.after(`res://`);
				}
				if (auto entry = heading.get("X11.64", null)) {
					this._dll_linux_path = entry.after(`res://`);
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

enum SectionType {
	Unknown,
	Node,
	Connection,
	ExtResource,
}

SectionType getSectionType(string section) {
	import std.regex : matchFirst;
	if (section.matchFirst(r"^\[node (\w|\W)*\]")) {
		return SectionType.Node;
	} else if (section.matchFirst(r"^\[connection (\w|\W)*\]$")) {
		return SectionType.Connection;
	} else if (section.matchFirst(r"^\[ext_resource (\w|\W)*\]")) {
		return SectionType.ExtResource;
	}

	return SectionType.Unknown;
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

string[string][string] parseAllSectionKeyValues(string section) {
	import std.string : splitLines;
	import std.regex : matchFirst;
	import std.algorithm : canFind;

	string[string][string] retval;
	string heading = null;
	foreach (line ; section.splitLines) {
		if (line.matchFirst(r"^\[\w+\]$")) {
			heading = line;
		} else if (heading && line.canFind("=")) {
			foreach (key, value ; parseKeyValues(line)) {
				retval[heading][key] = value;
			}
		}
	}
	return retval;
}

string[string] parseKeyValues(string line) {
	import std.string : strip, split;
	import std.regex : regex, matchAll;
	import std.algorithm : map;

	string[string] retval;

	// name = "Level"
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*"[\s\w\.]*"`))) {
		auto pair = match.hit.split("=").map!(n => n.strip.strip(`"`));
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	// singleton = false
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*(false|true)`))) {
		auto pair = match.hit.split("=").map!(n => n.strip.strip(`"`));
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	// id = 9
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*\d+`))) {
		auto pair = match.hit.split("=").map!(n => n.strip());
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	// total=3.97
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*\d+\.\d+`))) {
		auto pair = match.hit.split("=").map!(n => n.strip());
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	// instance = ExtResource( 27 )
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*[A-Za-z]+\(\s*\d+\s*\)`))) {
		auto pair = match.hit.split("=").map!(n => n.strip());
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	// path = "res://assets/player.png"
	foreach (match; line.matchAll(regex(`[\w_/\.]+\s*=\s*"res://[\w/\.:]*"`))) {
		auto pair = match.hit.split("=").map!(n => n.strip.strip(`"`));
		if (pair.length >= 2) {
			retval[pair[0]] = pair[1];
		}
	}

	return retval;
}

unittest {
	import BDD;

	describe("godot_project#parseKeyValues",
		it("Should parse key values", delegate() {
			auto data = `[ext_resource path="res://aaa/bbb.thing965/blah.jpg" singleton = false dot.67.name="res://game.dll" type="Texture" total=8.45 has_space="Bob Smith" is_empty="" id=1]`;
			auto result = parseKeyValues(data);
			auto expected = [
				`type`: `Texture`,
				`path`: `res://aaa/bbb.thing965/blah.jpg`,
				`id`: `1`,
				`total`: `8.45`,
				`has_space`: `Bob Smith`,
				`is_empty`: ``,
				`singleton`: `false`,
				`dot.67.name`: `res://game.dll`
			];
			result.shouldEqual(expected);
		})
	);
}
