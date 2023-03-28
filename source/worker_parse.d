// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

import global;
import helpers;
import messages;
import dispatch;

import godot_project_parse;
import godot_project;

import core.thread.osthread : Thread;
import core.time : dur;
import std.stdio : stdout, stderr;


class WorkerParse : IMessageThread {
	bool _is_running = false;
	Dispatch _dispatch;
	string _name = "worker_parse";

	this(size_t id) {
		import std.string : format;
		_name = "%s%s".format(_name, id);
		_dispatch = new Dispatch(_name);
		startMessageThread(_name, 0, this);
		_is_running = true;
	}

	bool onMessage(EncodedMessage encoded) {
		import std.path : extension;

		switch (encoded.message_type) {
			case MessageParseProjectFile.stringof:
				auto message = encoded.decodeMessage!MessageParseProjectFile();
				//stdout.writefln("!! full_path: %s", message.full_path); stdout.flush();
				//parseProjectFile(message.full_path);
				//_dispatch.taskDone(encoded.mid, encoded.from_tid, "parseProject");

				string full_name = message.full_path;
				//stdout.writefln("!! name: %s", full_name); stdout.flush();
				switch (extension(full_name)) {
					case ".godot":
						auto project = new Project(full_name);
						_dispatch.parseProjectDone(project);
						break;
					case ".tscn":
						auto scene = new Scene(full_name);
						_dispatch.parseSceneDone(scene);
						break;
					case ".gdns":
						auto native_script = new NativeScript(full_name);
						_dispatch.parseNativeScriptDone(native_script);
						break;
					case ".gd":
						auto gd_script = new GDScript(full_name);
						_dispatch.parseGDScriptDone(gd_script);
						break;
					case ".gdnlib":
						auto native_library = new NativeLibrary(full_name);
						_dispatch.parseNativeLibraryDone(native_library);
						break;
					default:
						break;
				}
				break;
			case MessageStop.stringof:
				auto message = encoded.decodeMessage!MessageStop();
				_is_running = false;
				return _is_running;
			default:
				stderr.writefln("!!!! (%s) Unexpected message: %s", _name, encoded); stderr.flush();
		}

		return true;
	}
}

