// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify


import global;
import helpers;
import messages;
import worker_fs;
import worker_parse;
import dispatch;

import std.concurrency : Tid, thisTid;
import core.thread.osthread : Thread;
import core.time : dur;

Dispatch _dispatch;

int main(string[] args) {
	import std.stdio : stdout, stderr, File;
	import std.file : chdir;
	import std.file : exists;
	import std.getopt : getopt, config, GetOptException;
	import helpers : dirName, buildPath, toPosixPath, absolutePath, s64, GetCpuTicksNS;
	import godot_project_parse : parseProject;
	import scan_d_code : getGodotScriptClasses;
	import godot_project_verify : verifyProject;

	setThreadName("main", thisTid());
	scope (exit) removeThreadName("main");

	// Change the dir to the location of the current exe
	chdir(dirName(args[0]));

	// Get the options
	string project_path = null;
	string source_path = null;
	bool generate_script_list = false;
	bool is_help = false;
	string getopt_error = null;
	try {
		auto result = getopt(args,
		config.required, "project", &project_path,
		config.required, "source", &source_path,
		"generate_script_list", &generate_script_list);
		is_help = result.helpWanted;
	} catch (Exception err) {
		getopt_error = err.msg;
		is_help = true;
	}

	// If there was an error, print the help and quit
	if (is_help) {
		stdout.writefln(
		"Verify Godot 3 Dlang project\n" ~
		"--project               Directory containing Godot project file. Required:\n" ~
		"--source                Directory containing D source code. Required:\n" ~
		"--generate_script_list  Will generate a list of classes that are GodotScript. Optional:\n" ~
		"--help                  This help information.\n"); stdout.flush();

		if (getopt_error) {
			stderr.writefln("Error: %s", getopt_error); stderr.flush();
		}
		return 1;
	}

	// Check paths
	project_path = toPosixPath(project_path);
	if (! exists(project_path)) {
		stderr.writefln(`Error: Godot project directory not found: %s`, project_path); stderr.flush();
		return 1;
	}
	project_path = absolutePath(project_path);

	source_path = toPosixPath(source_path);
	if (! exists(source_path)) {
		stderr.writefln(`Error: D source code directory not found: %s`, source_path); stderr.flush();
		return 1;
	}
	source_path = absolutePath(source_path);

	_dispatch = new Dispatch("main");
	auto worker_fs = new WorkerFS();
	WorkerParse[] worker_parse;
	foreach (i ; 0 .. 16) {
		worker_parse ~= new WorkerParse(i);
	}

	// FIXME: Wait for workers to start
	Thread.sleep(dur!("seconds")(3));

	// Get the project info
	s64 start, end;
	stdout.writefln(`Verifying Godot 3 Dlang project:`); stdout.flush();
	stdout.writefln(`Project file path: %s`, project_path); stdout.flush();
	stdout.writefln(`Dlang source path: %s`, source_path); stdout.flush();

	//start = GetCpuTicksNS();
	//auto project = parseProject(buildPath(project_path, `project.godot`));
	//end = GetCpuTicksNS();
	//stdout.writefln("!! parseProject: %s", end - start); stdout.flush();
	stdout.writefln("!! Beforeeeeeeeeee: %s", GetCpuTicksNS()); stdout.flush();
	auto a = _dispatch.parseProject(buildPath(project_path, `project.godot`));
	//_dispatch.await(a);
	Thread.sleep(dur!("seconds")(10));
	/*

	start = GetCpuTicksNS();
	auto class_infos = getGodotScriptClasses(source_path);
	end = GetCpuTicksNS();
	stdout.writefln("!! getGodotScriptClasses: %s", end - start); stdout.flush();

	// Find and print any errors
	start = GetCpuTicksNS();
	auto project_errors = verifyProject(project_path, project, class_infos);
	int error_count;
	end = GetCpuTicksNS();
	stdout.writefln("!! verifyProject: %s", end - start); stdout.flush();
	foreach (name, errors ; project_errors) {
		stdout.writeln(name);
		foreach (error ; errors) {
			error_count++;
			stdout.writeln("    ", error);
		}
	}
	if (error_count > 0) {
		stdout.writefln(`Verification failed! Found %s error(s)!`, error_count); stdout.flush();
		return 1;
	}

	// Generate a list of classes that are GodotScript
	start = GetCpuTicksNS();
	if (generate_script_list) {
		string file_name = "generated_script_list.d";
		string script_list_file = buildPath(source_path, file_name);
		stdout.writefln(`Generating script list file: %s`, script_list_file); stdout.flush();
		File file = File(script_list_file, "w");
		scope (exit) file.close();

		file.writefln("\n\nenum string[string] script_list = [");
		foreach (info ; class_infos) {
			file.writefln(`	"%s" : "%s",`, info._module, info.class_name);
		}
		file.writefln("];\n");
	}
	end = GetCpuTicksNS();
	stdout.writefln("!! generated_script_list: %s", end - start); stdout.flush();

	stdout.writefln(`All verification checks were successful.`); stdout.flush();
*/
	sendThreadMessageUnconfirmed(worker_fs._name, MessageStop());
	foreach (i ; 0 .. worker_parse.length) {
		sendThreadMessageUnconfirmed(worker_parse[i]._name, MessageStop());
	}
	//sendThreadMessageUnconfirmed("manager", MessageStop());

	return 0;
}
