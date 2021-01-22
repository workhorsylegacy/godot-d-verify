
module generate_script_class_names;

import dxml.dom;

class Node {
	DOMEntity!string entity;
	string path = null;

	this(DOMEntity!string entity, string path) {
		this.entity = entity;
		this.path = path;
	}
}

import std.stdio : stdout;

Node readNodes(string file_name) {
	import std.file : read, exists;

	auto data = cast(string)read(file_name);
	auto dom = parseDOM(data);
	Node node = new Node(dom, dom.name ~ `/`);
	return node;
}

// FIXME: Change to use Node rather than DOMEntity!string
Node[] getNodes(DOMEntity!string dom, string node_path_to_find, bool is_printing=false) {
	Node[] retval;

	Node[] nodes = [new Node(dom, dom.name ~ `/`)];
	while (nodes.length > 0) {
		Node node = nodes[0];
		nodes = nodes[1 .. $];
		if (is_printing) {
			stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!! node.path: %s", node.path); stdout.flush();
		}

		if (node.path == node_path_to_find) {
			retval ~= node;
		}

		if (node.entity.type != EntityType.elementEmpty) {
			foreach (child ; node.entity.children) {
				if (child.type != EntityType.text) {
					nodes ~= new Node(child, node.path ~ child.name ~ `/`);
				}
			}
		}
	}

	return retval;
}

Node getNode(Node node, string node_path_to_find, bool is_printing=false) {
	Node[] retval = node.entity.getNodes(node_path_to_find, is_printing);
	if (retval.length > 0) {
		return retval[0];
	}

	return null;
}

string getNodeText(Node node) {
	foreach (child ; node.entity.children) {
		return child.text;
	}

	return "";
}

void getCodeClasses() {
	import std.file : read, exists, getcwd, chdir;
	import std.process : executeShell;
	import std.file : dirEntries, SpanMode;
	import std.path : baseName, dirName;
	import std.string : format, endsWith;
	import std.algorithm : filter;

	chdir("../../../");
	//stdout.writefln("????????? getcwd: %s", getcwd()); stdout.flush();

	try {

		auto file_names = dirEntries("test/project_signal/src/", SpanMode.shallow, false).filter!(f => f.name.endsWith(".d"));


		foreach (entry ; file_names) {
			//stdout.writefln("######### entry: %s", entry); stdout.flush();

			//auto full_name = dirName(entry);
			auto full_name = entry;
			auto file_name = baseName(entry);
			auto command = `dscanner.exe --ast %s > %s.xml`.format(full_name, file_name);
			//stdout.writefln("######### command: %s", command); stdout.flush();

			auto dscanner = executeShell(command);
			if (dscanner.status != 0) {
				stdout.writeln("Dscanner failed:\n", dscanner.output); stdout.flush();
				return;
			}

			auto root_node = readNodes(`%s.xml`.format(file_name));
			foreach (klass ; root_node.entity.getNodes("/module/declaration/classDeclaration/")) {
				auto class_name = klass.getNode("classDeclaration/name/").getNodeText();
				auto base_class_name = klass.getNode("classDeclaration/baseClassList/baseClass/type2/typeIdentifierPart/identifierOrTemplateInstance/templateInstance/identifier/").getNodeText();

				stdout.writefln("        class_name: %s", class_name); stdout.flush();
				stdout.writefln("        base_class_name: %s", base_class_name); stdout.flush();
			}
		}
	} catch (Throwable err) {
		stdout.writefln("?????????????????????? err: %s", err); stdout.flush();
	}
}

/*
TODO:
. Make sure image resources are present too
*/


Scene[string] g_scenes;
NativeScript[string] g_scripts;
NativeLibrary[string] g_libraries;

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

Project scanProject(string file_name) {
	auto project = new Project(file_name);
	if (project) {
		auto scene = new Scene(project.main_scene_path);
		g_scenes[project.main_scene_path] = scene;
	}

	// Scan all the scenes, scripts, and libraries
	bool is_scanning = true;
	while (is_scanning) {
		is_scanning = false;
		foreach (Scene scene ; g_scenes.values()) {
			foreach (RefExtResource resource ; scene._resources) {
				switch (resource._type) {
					case "PackedScene":
						if (resource._path !in g_scenes) {
							g_scenes[resource._path] = new Scene(resource._path);
							is_scanning = true;
						}
						break;
					case "Script":
						if (resource._path !in g_scripts) {
							g_scripts[resource._path] = new NativeScript(resource._path);
							is_scanning = true;
						}
						break;
					default:
						break;
				}
			}
		}

		foreach (NativeScript script ; g_scripts.values()) {
			RefExtResource resource = script._native_library;
			if (resource._path !in g_libraries) {
				g_libraries[resource._path] = new NativeLibrary(resource._path);
				is_scanning = true;
			}
		}
	}

	return project;
}

void printInfo(Project project) {
	import std.stdio : stdout;

	// Print out everything
	stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); stdout.flush();
	stdout.writefln(".project %s", project._path); stdout.flush();
	stdout.writefln("    main_scene_path %s", project.main_scene_path); stdout.flush();
	foreach (path, scene ; g_scenes) {
		stdout.writefln(".tscn %s", path); stdout.flush();
		stdout.writefln("    _error: %s", scene._error); stdout.flush();
	}
	foreach (path, script ; g_scripts) {
		stdout.writefln(".gdns %s", path); stdout.flush();
		stdout.writefln("    _error: %s", script._error); stdout.flush();
	}
	foreach (path, library ; g_libraries) {
		stdout.writefln(".gdnlib %s", path); stdout.flush();
		stdout.writefln("    _error: %s", library._error); stdout.flush();
	}
	stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); stdout.flush();
}

void printErrors(Project project) {
	import std.stdio : stderr;
	import std.string : format;

	// Print out any errors
	foreach (Scene scene ; g_scenes.values()) {
		string[] errors;
		foreach (RefExtResource resource ; scene._resources) {
			switch (resource._type) {
				case "PackedScene":
					Scene child_scene = g_scenes[resource._path];
					if (child_scene._error) {
						errors ~= "    error: %s".format(child_scene._error);
					}
					break;
				case "Script":
					NativeScript child_script = g_scripts[resource._path];
					if (child_script._error) {
						errors ~= "    error: %s".format(child_script._error);
					}
					break;
				default:
					break;
			}
		}

		if (errors.length > 0) {
			stderr.writefln("tscn: %s", scene._path); stderr.flush();
			foreach (error ; errors) {
				stderr.writefln("%s", error); stderr.flush();
			}
		}
	}

	foreach (NativeScript script ; g_scripts.values()) {
		string[] errors;
		NativeLibrary child_library = g_libraries[script._native_library._path];

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

	foreach (NativeLibrary library ; g_libraries.values()) {
		string[] errors;

		if (errors.length > 0) {
			stderr.writefln("gdnlib: %s", library._path); stderr.flush();
			foreach (error ; errors) {
				stderr.writefln("%s", error); stderr.flush();
			}
		}
	}
}

struct SceneSignals {
	string class_name = null;
	string[] methods;
}

void generateCode() {
	import std.stdio : File, writefln;
	import std.string : format, split;
	import std.algorithm.sorting : sort;
	import std.array : array, join;
	import std.algorithm : map;
/*
	foreach (Scene scene ; g_scenes.values()) {
		foreach (RefConnection con ; scene._connections) {
			writefln("############ methods: %s", con._method);
		}
	}
*/
	// Get all the class names
	string[string] class_names;
	foreach (script ; g_scripts.values()) {
		auto pair = script._class_name.split(".");
		string file_name = pair[0];
		string class_name = pair[1];
		class_names[file_name] = class_name;
	}

	// Get all the script classes
	string[string] script_classes;
	foreach (script ; g_scripts.values()) {
		script_classes[script._path] = script._class_name.split(".")[1];
	}

	// Get all the scene signals
	SceneSignals[string] scene_signals;
	foreach (Scene scene ; g_scenes.values()) {
		string class_name = null;
		foreach (RefExtResource resource ; scene._resources) {
			if (resource._type == "Script" && resource._path in g_scripts) {
				auto script = g_scripts[resource._path];
				class_name = script._class_name.split(".")[1];
			}
		}

		string[] methods = scene._connections.map!(con => con._method).array;
		scene_signals[scene._path] = SceneSignals(class_name, methods);
	}

	File file = File("../src/script_class_names.d", "w");
	scope (exit) file.close();

	// Write the getClassNames function
	file.writeln(`
	pure string[string] getClassNames() {
		string[string] retval;`);

	foreach (file_name ; class_names.keys.sort.array) {
		string class_name = class_names[file_name];
		//writefln("???? name: %s, path: %s", name, path);
		file.writefln(`		retval["%s"] = "%s";`, file_name, class_name);
	}

	file.writeln(`
		return retval;
	}`);

	// Write getScriptClassNames function
	file.writeln(`
	pure string[string] getScriptClassNames() {
		string[string] retval;`);

	foreach (path ; script_classes.keys.sort.array) {
		string name = script_classes[path];
		//writefln("???? name: %s, path: %s", name, path);
		file.writefln(`		retval["%s"] = "%s";`, path, name);
	}

	file.writeln(`
		return retval;
	}`);

	// Write getSceneSignalNames function
	file.writeln(`
	struct SceneSignals {
		string class_name = null;
		string[] methods;
	}
	`);

	file.writeln(`
	pure SceneSignals[string] getSceneSignalNames() {
		SceneSignals[string] retval;`);

	foreach (path ; scene_signals.keys.sort.array) {
		auto signal_scene = scene_signals[path];
		if (signal_scene.methods.length == 0) {
			file.writefln(`		retval["%s"] = SceneSignals.init;`, path);
		} else {
			string methods = signal_scene.methods.map!(n => `"%s"`.format(n)).join(", ");
			//writefln("???? methods: %s", methods);
			file.writefln(`		retval["%s"] = SceneSignals("%s", [%s]);`, path, signal_scene.class_name, methods);
		}
	}

	file.writeln(`
		return retval;
	}`);
}
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
	generateCode();

	return 0;
}
*/
