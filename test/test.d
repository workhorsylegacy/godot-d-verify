

import std.stdio;
import verify_d_code : getCodeClasses;
import verify_godot : Project, Scene, NativeScript, NativeLibrary;

string _root_path = null;

void reset_path(string project_path) {
	import std.path : absolutePath;
	import std.file : chdir, getcwd;
	import std.path : buildPath;

	if (! _root_path) {
		_root_path = getcwd();
	}
	//writefln(_root_path);
	//writefln(buildPath(_root_path, project_path));
	chdir(buildPath(_root_path, project_path));
}

/* FIXME
. delete code generation?
. Add testing of signals
. Add testing for complete project
. Add compile test for valididy

*/

unittest {
	import BDD;

	describe("godot_verify#Project",
		it("Should parse project", delegate() {
			reset_path("test/project_normal/project/");
			auto project = new Project("project.godot");
			project._path.shouldEqual("project.godot");
			project._error.shouldBeNull();
		}),
		it("Should fail to parse invalid project", delegate() {
			reset_path("test/project_normal/project/");
			auto project = new Project("XXX.godot");
			project._path.shouldEqual("XXX.godot");
			project._error.shouldNotBeNull();
			project._error.shouldEqual("Failed to find XXX.godot file ...");
		})
	);

	describe("godot_verify#Scene",
		it("Should parse scene with child scene", delegate() {
			reset_path("test/project_normal/project/");
			auto scene = new Scene("Level/Level.tscn");
			scene._path.shouldEqual("Level/Level.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(1);
			foreach (resource ; scene._resources) {
				resource._type.shouldEqual("PackedScene");
				resource._path.shouldEqual("Player/Player.tscn");
				resource.is_valid.shouldEqual(true);
			}
		}),
		it("Should parse scene with child resources", delegate() {
			reset_path("test/project_normal/project/");
			auto scene = new Scene("Player/Player.tscn");
			scene._path.shouldEqual("Player/Player.tscn");
			scene._error.shouldBeNull();
			scene._resources.length.shouldEqual(2);

			scene._resources[0]._type.shouldEqual("Texture");
			scene._resources[0]._path.shouldEqual("icon.png");
			scene._resources[0].is_valid.shouldEqual(true);

			scene._resources[1]._type.shouldEqual("Script");
			scene._resources[1]._path.shouldEqual("Player/Player.gdns");
			scene._resources[1].is_valid.shouldEqual(true);
		}),
		it("Should fail to parse invalid scene", delegate() {
			reset_path("test/project_normal/project/");
			auto scene = new Scene("Level/XXX.tscn");
			scene._path.shouldEqual("Level/XXX.tscn");
			scene._error.shouldNotBeNull();
			scene._error.shouldEqual("Failed to find Level/XXX.tscn file ...");
			scene._resources.length.shouldEqual(0);
		})
	);

	describe("godot_verify#NativeScript",
		it("Should parse native script", delegate() {
			reset_path("test/project_normal/project/");
			auto script = new NativeScript("Player/Player.gdns");
			script._path.shouldEqual("Player/Player.gdns");
			script._error.shouldBeNull();
			script._class_name.shouldEqual("player.Player");

			script._native_library.shouldNotBeNull();
			script._native_library._path.shouldEqual("libgame.gdnlib");
			script._native_library._type.shouldEqual("GDNativeLibrary");
		}),
		it("Should fail to parse invalid native script", delegate() {
			reset_path("test/project_normal/project/");
			auto script = new NativeScript("Player/XXX.gdns");
			script._path.shouldEqual("Player/XXX.gdns");
			script._error.shouldNotBeNull();
			script._error.shouldEqual("Failed to find Player/XXX.gdns file ...");
			script._class_name.shouldBeNull();

			script._native_library.shouldBeNull();
		})
	);

	describe("godot_verify#NativeLibrary",
		it("Should parse native library", delegate() {
			reset_path("test/project_normal/project/");
			auto library = new NativeLibrary("libgame.gdnlib");
			library._path.shouldEqual("libgame.gdnlib");
			library._error.shouldBeNull();
			library._dll_windows_path.shouldEqual("game.dll");
			library._dll_linux_path.shouldEqual("libgame.so");
			library._symbol_prefix.shouldEqual("game");
		}),
		it("Should fail to parse invalid native library", delegate() {
			reset_path("test/project_normal/project/");
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
			connection._method.shouldEqual("on_button_pressed"); // FIXME: onButtonPressed
			connection.is_valid.shouldEqual(true);

			// Make sure the D code is valid
			auto class_infos = getCodeClasses("test/project_signal/src/");
			class_infos.length.shouldEqual(1);
			auto class_info = class_infos[0];
			class_info._module.shouldEqual("level");
			class_info.class_name.shouldEqual("Level");
			class_info.base_class_name.shouldEqual("GodotScript");
			"_ready".shouldBeIn(class_info.methods);
			"_process".shouldBeIn(class_info.methods);
			"onButtonPressed".shouldBeIn(class_info.methods);
		}),
		it("Should fail to parse scene with missing signal method", delegate() {
			reset_path("test/project_signal/project/");

			//getCodeClasses("test/project_signal/src/");

			auto scene = new Scene("Level/Level.tscn");
			scene._path.shouldEqual("Level/Level.tscn");
//			scene._error.shouldNotBeNull();
//			scene._error.shouldEqual(`Script Level/Level.tscn  missing signal on_button_pressed`);
			scene._resources.length.shouldEqual(1);
			foreach (connection ; scene._connections) {
				connection._signal.shouldEqual("pressed");
				connection._from.shouldEqual("Button");
				connection._to.shouldEqual(".");
				connection._method.shouldEqual("xxx");
				connection.is_valid.shouldEqual(true);
			}
		})
	);

/*
	describe("godot_verify#complete_project",
		it("Should parse complete project", delegate() {
			reset_path();
			auto project = scanProject("project.godot");
			printInfo(project);
			printErrors(project);
			generateCode();
		})
	);
*/
}
