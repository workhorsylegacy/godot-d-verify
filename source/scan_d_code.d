// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module scan_d_code;

import std.stdio : stdout;
import std.experimental.lexer : TokenStructure;
import dparse.ast : ASTVisitor, ModuleDeclaration, ClassDeclaration, FunctionDeclaration, TemplateSingleArgument, Declaration;

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

private class KlassInfoVisitor : ASTVisitor {
	alias visit = ASTVisitor.visit;

	string _file_name;
	KlassInfo[] _klass_infos;
	KlassInfo _current_klass_info = null;
	Declaration _current_declaration = null;

	override void visit(in ModuleDeclaration m) {
		//moduleName = m.moduleName.identifiers.map!(t => cast(string) t.text).array;
		super.visit(m);
	}

	override void visit(in Declaration d) {
		_current_declaration = cast(Declaration) d;
		super.visit(d);
		_current_declaration = null;
	}

	override void visit(in FunctionDeclaration f) {
		if (_current_klass_info !is null) {
//			stdout.writefln("!!    FunctionDeclaration: %s", f.name.text.dup); stdout.flush();

			auto method = new MethodInfo();
			method.name = f.name.text.dup;

			// @Method void blah() in FunctionDeclaration attributes
			foreach (attribute ; f.attributes) {
//				stdout.writefln("???????        attribute1:%s", attribute); stdout.flush();
				if (auto text = attribute.atAttribute.identifier.text) {
					method.attributes ~= text.dup;
//					stdout.writefln("!!        attribute:%s", text.dup); stdout.flush();
				}
			}

			// @Method void blah() in Declaration attributes
			if (_current_declaration) {
				foreach (attribute ; _current_declaration.attributes) {
					if (auto text = attribute.atAttribute.identifier.text) {
						method.attributes ~= text.dup;
//						stdout.writefln("!!        attribute2:%s", text.dup); stdout.flush();
					}
				}
			}

			// @Method blah() in FunctionDeclaration StorageClasses
			foreach (storage_class ; f.storageClasses) {
//				stdout.writefln("???????        storage_class:%s", storage_class); stdout.flush();
				if (storage_class && storage_class.atAttribute) {
					if (auto text = storage_class.atAttribute.identifier.text) {
						method.attributes ~= text.dup;
//						stdout.writefln("!!        atAttribute3:%s", text.dup); stdout.flush();
					}
				}
			}

			if (method.isValid()) {
				_current_klass_info.methods ~= method;
			}
		}

		super.visit(f);
	}

	override void visit(in ClassDeclaration c) {
		import std.string : split;

		// Get module and class name
		auto info = new KlassInfo();
		info._module = _file_name.split(".")[0];
		info.class_name = c.name.text.dup;
		_current_klass_info = info;
//		stdout.writefln("!! class_name: %s", info.class_name); stdout.flush();

		// Get base class names
		foreach (base_class ; c.baseClassList.items) {
			auto ioti = base_class.type2.typeIdentifierPart.identifierOrTemplateInstance;

			// Uses template like: class Dog : GodotScript!Area
			if (auto text = ioti.templateInstance.identifier.text) {
				//stdout.writefln("!!    base_class_name: %s", text); stdout.flush();
				info.base_class_name = text.dup; //FIXME: make base_class_name an array for classes with multiple inheritance
			// Does not use template like: class Animal : GodotScript
			} else if (auto text = ioti.identifier.text) {
//				stdout.writefln("!!    base_class_name2: %s", text); stdout.flush();
				info.base_class_name = text.dup; //FIXME: make base_class_name an array for classes with multiple inheritance
			}

/*
			// Template with multiple arguments
			auto templ_arg_list = ioti.templateInstance.templateArguments.templateArgumentList;
			stdout.writefln("!!    XX: %s", templ_arg_list); stdout.flush();
			if (templ_arg_list) {
				foreach (arg ; templ_arg_list.items) {
					stdout.writefln("XXXXXXX        arg: %s", arg); stdout.flush();
				}
			}
*/
			// Get base class template name
			// class Dog : GodotScript!Spatial
			// Template with one argument
			auto templ_arg_single = ioti.templateInstance.templateArguments.templateSingleArgument;
			foreach (token ; templ_arg_single.tokens) {
//				stdout.writefln("!!    base_class_template: %s", token.text); stdout.flush();
				info.base_class_template = token.text.dup;
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
//			stdout.writefln("!!    base_class: %s", info.class_name); stdout.flush();
			if (info.base_class_name == "GodotScript") {
				retval ~= info;
			}
		}
	}

	return retval;
}
