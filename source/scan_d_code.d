// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
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
	string base_class_template = null;
	MethodInfo[] methods;

	string full_class_name() {
		import std.string : format;
		return `%s.%s`.format(_module, class_name);
	}

	string full_base_class_name() {
		import std.string : format;
		return `%s!%s`.format(base_class_name, base_class_template);
	}

	bool isValid() {
		return class_name != null;
	}
}

import dparse.ast;
private class KlassInfoVisitor : ASTVisitor {
	alias visit = ASTVisitor.visit;

	string _file_name;
	KlassInfo[] _klass_infos;
	KlassInfo _current_klass_info = null;

	override void visit(in ModuleDeclaration m) {
		//moduleName = m.moduleName.identifiers.map!(t => cast(string) t.text).array;
		super.visit(m);
	}

	override void visit(in FunctionDeclaration f) {
		if (_current_klass_info !is null) {
			stdout.writefln("!!    class:%s, FunctionDeclaration: %s", _current_klass_info.class_name, f.name.text.dup); stdout.flush();

			auto method = new MethodInfo();
			method.name = f.name.text.dup;

			// @Method void blah()
			foreach (attribute ; f.attributes) {
				if (auto text = attribute.atAttribute.identifier.text) {
					method.attributes ~= text;
					stdout.writefln("!!        attribute:%s", text.dup); stdout.flush();
				}
			}

			// @Method blah()
			foreach (storage_class ; f.storageClasses) {
				if (auto text = storage_class.atAttribute.identifier.text) {
					method.attributes ~= text;
					stdout.writefln("!!        attribute2:%s", text.dup); stdout.flush();
				}
			}

			if (method.isValid()) {
				_current_klass_info.methods ~= method;
			}
		}

		super.visit(f);
	}

	override void visit(in ClassDeclaration c) {
		import std.string : endsWith, split;

		// Get module and class name
		auto info = new KlassInfo();
		info._module = _file_name.split(".")[0];
		info.class_name = c.name.text.dup;
		_current_klass_info = info;
		stdout.writefln("!! class: %s", info.class_name); stdout.flush();

		// Get base class names
		foreach (base_class ; c.baseClassList.items) {
			// Uses template like: class Dog : GodotScript!Area
			string name = base_class.type2.typeIdentifierPart.identifierOrTemplateInstance.templateInstance.identifier.text;
			stdout.writefln("!!    base_class1: %s", name); stdout.flush();
			if (name != "") {
				info.base_class_name = name; //FIXME: make this an array for classes with multiple inheritance
			}

			// Does not use template like: class Animal : GodotScript
			string name2 = base_class.type2.typeIdentifierPart.identifierOrTemplateInstance.identifier.text;
			stdout.writefln("!!    base_class2: %s", name2); stdout.flush();
			if (name2 != "") {
				info.base_class_name = name2; //FIXME: make this an array for classes with multiple inheritance
			}

			// Get base class template name
			// class Dog : GodotScript!Spatial
			string name3 = "FIXME";//base_class.type2.typeIdentifierPart.identifierOrTemplateInstance.templateInstance.templateArguments.templateSingleArgument.identifier.text;
			stdout.writefln("!!    base_class3: %s", name3); stdout.flush();
			if (name3 != "") {
				info.base_class_template = name3;
			}
		}

		if (info.isValid()) {
			_klass_infos ~= info;
		}

		super.visit(c);
		_current_klass_info = null;
	}
}

KlassInfo[] getGodotScriptClasses(string path_to_src) {
	import std.algorithm : filter, map;
	import std.array : replace;
	import std.path : extension;
	import helpers : baseName, dirEntries, SpanMode;
	import std.file : read;
	import dparse.lexer : LexerConfig, StringCache, getTokensForParser;
	import dparse.parser : parseModule;
	import dparse.rollback_allocator : RollbackAllocator;

	KlassInfo[] retval;

	// Get all the D files in the src directory
	auto file_names =
		dirEntries(path_to_src, SpanMode.breadth, false)
		.filter!(e => e.isFile)
		.filter!(e => e.name.extension == ".d")
		.map!(e => e.name.replace(`\`, `/`));

	foreach (full_file_name ; file_names) {
		//stdout.writefln("######### full_file_name: %s", full_file_name); stdout.flush();
		// Generate a temporary file that gets auto deleted
		auto file_name = baseName(full_file_name);

		LexerConfig config;
		auto source_code = cast(string) read(full_file_name);
		auto cache = StringCache(StringCache.defaultBucketCount);
		auto tokens = getTokensForParser(source_code, config, &cache);
		RollbackAllocator rba;
		auto mod = parseModule(tokens, file_name, &rba);

		auto visitor = new KlassInfoVisitor();
		visitor._file_name = file_name;
		visitor.visit(mod);
		foreach (info ; visitor._klass_infos) {
			stdout.writefln("!!    base_class: %s", info.class_name); stdout.flush();
			if (info.base_class_name == "GodotScript") {
				retval ~= info;
			}
		}
	}

	return retval;
}
