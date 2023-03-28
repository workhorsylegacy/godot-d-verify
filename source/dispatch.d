// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify


import global;
import helpers;
import messages;
import godot_project;

import std.stdio : stderr;


class Dispatch {
	string _thread_name;
	long _next_worker_id = 0;

	string get_worker_name() {
		import std.string : format;
		_next_worker_id += 1;
		if (_next_worker_id > 15) _next_worker_id = 0;
		string worker_name = "worker_parse%s".format(_next_worker_id);
		return worker_name;
	}

	this(string thread_name) {
		_thread_name = thread_name;
	}

	size_t parseProject(string full_project_path) {
		auto message = MessageParseProject(full_project_path);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}

	size_t parseProjectFile(string full_path) {
		auto message = MessageParseProjectFile(full_path);
		string worker_name = this.get_worker_name();
		return sendThreadMessage(_thread_name, worker_name, message);
	}

	size_t parseProjectDone(Project project) {
		auto message = MessageParseProjectDone(project);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}
	size_t parseSceneDone(Scene scene) {
		auto message = MessageParseSceneDone(scene);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}
	size_t parseNativeScriptDone(NativeScript native_script) {
		auto message = MessageParseNativeScriptDone(native_script);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}
	size_t parseGDScriptDone(GDScript gd_script) {
		auto message = MessageParseGDScriptDone(gd_script);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}
	size_t parseNativeLibraryDone(NativeLibrary native_library) {
		auto message = MessageParseNativeLibraryDone(native_library);
		return sendThreadMessage(_thread_name, "worker_fs", message);
	}

	void taskDone(size_t mid, string from_tid, string receipt) {
		auto message = MessageTaskDone(receipt, mid, from_tid, from_tid);
		sendThreadMessageUnconfirmed(from_tid, message);
	}

	void await(size_t[] awaiting_mids ...) {
		import std.concurrency : receive;
		import std.variant : Variant;
		import std.algorithm : remove;
		import std.string : format;

		while (awaiting_mids.length > 0) {
			receive((Variant data) {
				//print("<<<<<<<<<< Dispatch.await data %s", data.to!string);
				EncodedMessage encoded = getThreadMessage(data);
				if (encoded is EncodedMessage.init) return;

				switch (encoded.message_type) {
					case "MessageTaskDone":
						auto message = encoded.decodeMessage!MessageTaskDone();
						size_t mid = message.mid;
						awaiting_mids = awaiting_mids.remove!(await_mid => await_mid == mid);
						break;
					default:
						stderr.writefln("!!!! (Dispatch.await) Unexpected message: %s", encoded); stderr.flush();
				}
			});
		}
	}
}
