// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module scan_d_code;

import std.stdio : stdout;

class MethodInfo {
	string name = null;
	string[] attributes;

	bool isValid() {
		return name != null;
	}
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

string getCodeAstXML(string full_file_name) {
	import std.file : read, exists, remove;
	import std.stdio : File;
	import create_temp_file : createTempFile;
	import dparse.lexer : LexerConfig, StringCache, getTokensForParser;
	import dparse.parser : parseModule;
	import dparse.rollback_allocator : RollbackAllocator;
	import dparse.astprinter : XMLPrinter;
	import helpers : baseName;

	// Generate a temporary file that gets auto deleted
	auto file_name = baseName(full_file_name);
	string temp_file = createTempFile(file_name, ".xml");
	scope(exit) if (exists(temp_file)) remove(temp_file);

	// Use Lib D Parse to generate an XML AST of the D file
	string retval;
	{
		LexerConfig config;
		auto source_code = cast(string) read(full_file_name);
		auto cache = StringCache(StringCache.defaultBucketCount);
		auto tokens = getTokensForParser(source_code, config, &cache);
		RollbackAllocator rba;
		auto mod = parseModule(tokens, file_name, &rba);

		auto temp = File(temp_file, "w");
		scope(exit) temp.close();

		auto visitor = new XMLPrinter();
		visitor.output = temp;
		visitor.visit(mod);
	}

	retval = cast(string) read(temp_file);

	return retval;
}

KlassInfo[] getCodeClasses(string path_to_src) {
	import std.string : endsWith, split;
	import std.algorithm : filter;
	import helpers : baseName, dirEntries, SpanMode;
	import read_xml : Node, readNodes, getNode, getNodes, getNodeText;

	KlassInfo[] retval;


	// Get all the D files in the src directory
	auto file_names = dirEntries(path_to_src, SpanMode.shallow, false).filter!(f => f.name.endsWith(".d"));

	foreach (full_file_name ; file_names) {
		//stdout.writefln("######### full_file_name: %s", full_file_name); stdout.flush();

		auto file_name = baseName(full_file_name);
		string xml_ast = getCodeAstXML(full_file_name);

		// Get all the classes and methods from the XML AST
		Node root_node = readNodes(xml_ast);
		foreach (Node klass ; root_node.getNodes("/module/declaration/classDeclaration/")) {
			// Get module and class name
			auto info = new KlassInfo();
			info._module = file_name.split(".")[0];
			info.class_name = klass.getNode("classDeclaration/name/").getNodeText();

			// Get base class name
			info.base_class_name = klass.getNode("classDeclaration/baseClassList/baseClass/type2/typeIdentifierPart/identifierOrTemplateInstance/templateInstance/identifier/").getNodeText();

			// Get methods
			foreach (Node method_node ; klass.getNodes("classDeclaration/structBody/declaration/functionDeclaration/")) {
				auto method = new MethodInfo();
				method.name = method_node.getNode("functionDeclaration/name/").getNodeText();

				// @Method void blah()
				foreach (Node attribute ; method_node.parent_node.getNodes("declaration/attribute/atAttribute/identifier/")) {
					if (auto text = attribute.getNodeText()) {
						method.attributes ~= text;
					}
				}

				// @Method blah()
				foreach (Node attribute ; method_node.parent_node.getNodes("declaration/functionDeclaration/storageClass/atAttribute/identifier/")) {
					if (auto text = attribute.getNodeText()) {
						method.attributes ~= text;
					}
				}

				if (method.isValid()) {
					info.methods ~= method;
				}
			}

			if (info.isValid()) {
				retval ~= info;
			}
		}
	}

	return retval;
}
