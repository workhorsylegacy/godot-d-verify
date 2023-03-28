// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

import global;
import helpers;
import messages;
import dispatch;

import godot_project;
import godot_project_parse : parseProject, getProjectFiles;

import core.thread.osthread : Thread;
import core.time : dur;
import std.stdio : stdout, stderr;


class WorkerFS : IMessageThread {
	bool _is_running = false;
	int[] _pids;
	Dispatch _dispatch;
	immutable string _name = "worker_fs";
	Project _project;
	Scene[string] _scenes;
	GDScript[string] _gdscripts;
	NativeScript[string] _scripts;
	NativeLibrary[string] _libraries;

	this() {
		_dispatch = new Dispatch(_name);
		startMessageThread(_name, 0, this);
		_is_running = true;
	}

	bool onMessage(EncodedMessage encoded) {
		switch (encoded.message_type) {
			case MessageParseProject.stringof:
				auto message = encoded.decodeMessage!MessageParseProject();
				//ulong[] ids;
				getProjectFiles(message.full_project_path, (file_name) {
					/*ids ~=*/ _dispatch.parseProjectFile(file_name);
				});
				//_dispatch.await(ids);
				//_dispatch.taskDone(encoded.mid, encoded.from_tid, "parseProject");
				break;
			case MessageParseProjectDone.stringof:
				auto message = encoded.decodeMessage!MessageParseProjectDone();
				_project = message.project;
				stdout.writefln("!!!! project: %s", message.project); stdout.flush();
				break;
			case MessageParseSceneDone.stringof:
				auto message = encoded.decodeMessage!MessageParseSceneDone();
				_scenes[message.scene._path] = message.scene;
				stdout.writefln("!!!! scene: %s, %s", message.scene, GetCpuTicksNS()); stdout.flush();
				break;
			case MessageParseNativeScriptDone.stringof:
				auto message = encoded.decodeMessage!MessageParseNativeScriptDone();
				_scripts[message.native_script._path] = message.native_script;
				stdout.writefln("!!!! native_script: %s", message.native_script); stdout.flush();
				break;
			case MessageParseGDScriptDone.stringof:
				auto message = encoded.decodeMessage!MessageParseGDScriptDone();
				_gdscripts[message.gd_script._path] = message.gd_script;
				stdout.writefln("!!!! gd_script: %s", message.gd_script); stdout.flush();
				break;
			case MessageParseNativeLibraryDone.stringof:
				auto message = encoded.decodeMessage!MessageParseNativeLibraryDone();
				_libraries[message.native_library._path] = message.native_library;
				stdout.writefln("!!!! native_library: %s", message.native_library); stdout.flush();
				break;


			case MessageStop.stringof:
				auto message = encoded.decodeMessage!MessageStop();
				_is_running = false;
				return _is_running;
/*
			case MessageMonitorMemoryUsage.stringof:
				auto message = encoded.decodeMessage!MessageMonitorMemoryUsage();
				_pids ~= message.pid;
				break;
*/
			default:
				stderr.writefln("!!!! (%s) Unexpected message: %s", _name, encoded); stderr.flush();
		}

		return true;
	}
}

