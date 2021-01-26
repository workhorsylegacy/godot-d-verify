// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module scan_d_code;

import std.stdio : stdout;

class MethodInfo {
	string name = null;
	string[] attributes;
}

class KlassInfo {
	string _module = null;
	string class_name = null;
	string base_class_name = null;
	MethodInfo[] methods;

	bool isValid() {
		return class_name && base_class_name;
	}
}

KlassInfo[] getCodeClasses(string path_to_src) {
	import std.file : read, exists, remove, getcwd, chdir;
	import std.process : executeShell;
	import std.file : dirEntries, SpanMode;
	import std.path : baseName, dirName, absolutePath;
	import std.string : format, endsWith, split;
	import std.algorithm : filter;
	import create_temp_file : createTempFile;
	import read_xml : Node, readNodes, getNode, getNodes, getNodeText;

//	string prev_dir = getcwd();
//	path_to_src = absolutePath(path_to_src);
//	stdout.writefln("######### prev_dir: %s", prev_dir); stdout.flush();
//	stdout.writefln("######### path_to_src: %s", path_to_src); stdout.flush();
//	chdir(path_to_src);

	KlassInfo[] retval;

//	try {

		// Get all the D files in the src directory
		auto file_names = dirEntries(path_to_src, SpanMode.shallow, false).filter!(f => f.name.endsWith(".d"));

		foreach (full_file_name ; file_names) {
			//stdout.writefln("######### full_file_name: %s", full_file_name); stdout.flush();

			// Generate a temporary file that gets auto deleted
			auto file_name = baseName(full_file_name);
			string temp_file = createTempFile(file_name, ".xml");
			//stdout.writefln("!!!!!!!!!! temp_file: %s", temp_file);
			scope(exit) if (exists(temp_file)) remove(temp_file);

			// Use DScanner to generate an XML AST of the D file
			version (Windows) {
				auto command = `dscanner.exe --ast %s > %s`.format(full_file_name, temp_file);
			} else version (linux) {
				auto command = `./dscanner --ast %s > %s`.format(full_file_name, temp_file);
			} else {
				static assert(0, "Unsupported OS");
			}
			//stdout.writefln("######### command: %s", command); stdout.flush();
			auto dscanner = executeShell(command);
			if (dscanner.status != 0) {
				throw new Exception("DScanner failed: %s".format(dscanner.output));
			}

			// Get all the classes and methods from the XML AST
			Node root_node = readNodes(temp_file);
			foreach (Node klass ; root_node.getNodes("/module/declaration/classDeclaration/")) {
				auto info = new KlassInfo();
				info._module = file_name.split(".")[0];
				info.class_name = klass.getNode("classDeclaration/name/").getNodeText();
				info.base_class_name = klass.getNode("classDeclaration/baseClassList/baseClass/type2/typeIdentifierPart/identifierOrTemplateInstance/templateInstance/identifier/").getNodeText();

				foreach (Node method_node ; klass.getNodes("classDeclaration/structBody/declaration/functionDeclaration/")) {
					auto method = new MethodInfo();
					method.name = method_node.getNode("functionDeclaration/name/").getNodeText();
					foreach (Node attribute ; method_node.parent_node.getNodes("declaration/attribute/atAttribute/identifier/")) {
						method.attributes ~= attribute.getNodeText();
					}
					info.methods ~= method;
				}

				if (info.isValid()) {
					retval ~= info;
				}
			}
		}

/*
		// Print all the class infos
		foreach (info ; retval) {
			stdout.writefln("        module: %s", info._module); stdout.flush();
			stdout.writefln("        class_name: %s", info.class_name); stdout.flush();
			stdout.writefln("        base_class_name: %s", info.base_class_name); stdout.flush();
			foreach (method ; info.methods) {
				stdout.writefln("        method: %s", method); stdout.flush();
			}
		}
*/

//	} catch (Exception err) {
//		stdout.writefln("?????????????????????? err: %s", err); stdout.flush();
//	}

//	chdir(prev_dir);
	return retval;
}
