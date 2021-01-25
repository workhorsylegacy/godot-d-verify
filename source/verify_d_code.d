// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module verify_d_code;

import std.stdio : stdout;
import dxml.dom;


class Node {
	DOMEntity!string entity;
	string path = null;

	this(DOMEntity!string entity, string path) {
		this.entity = entity;
		this.path = path;
	}
}

class ClassInfo {
	string _module = null;
	string class_name = null;
	string base_class_name = null;
	string[] methods;

	bool isValid() {
		return class_name && base_class_name;
	}
}

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

ClassInfo[] getCodeClasses(string path_to_src) {
	import std.file : read, exists, getcwd, chdir;
	import std.process : executeShell;
	import std.file : dirEntries, SpanMode;
	import std.path : baseName, dirName;
	import std.string : format, endsWith, split;
	import std.algorithm : filter;

	string prev_dir = getcwd();
	chdir("../../../");

	ClassInfo[] retval;

//	try {

		// Get all the D files in the src directory
		auto file_names = dirEntries(path_to_src, SpanMode.shallow, false).filter!(f => f.name.endsWith(".d"));

		foreach (full_file_name ; file_names) {
			//stdout.writefln("######### full_file_name: %s", full_file_name); stdout.flush();

			// Use DScanner to generate an XML AST of the D file
			auto file_name = baseName(full_file_name);
			auto command = `dscanner.exe --ast %s > %s.xml`.format(full_file_name, file_name);
			//stdout.writefln("######### command: %s", command); stdout.flush();
			auto dscanner = executeShell(command);
			if (dscanner.status != 0) {
				throw new Exception("DScanner failed: %s".format(dscanner.output));
			}

			// Get all the classes and methods from the XML AST
			auto root_node = readNodes(`%s.xml`.format(file_name));
			foreach (klass ; root_node.entity.getNodes("/module/declaration/classDeclaration/")) {
				auto info = new ClassInfo();
				info._module = file_name.split(".")[0];
				info.class_name = klass.getNode("classDeclaration/name/").getNodeText();
				info.base_class_name = klass.getNode("classDeclaration/baseClassList/baseClass/type2/typeIdentifierPart/identifierOrTemplateInstance/templateInstance/identifier/").getNodeText();

				foreach (method ; klass.entity.getNodes("classDeclaration/structBody/declaration/functionDeclaration/")) {
					info.methods ~= method.getNode("functionDeclaration/name/").getNodeText();
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

	chdir(prev_dir);
	return retval;
}
