// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify


import global;
import helpers;
import std.stdio : stdout, stderr;

import std.concurrency : Tid, thisTid, spawn, receive, receiveTimeout;
import std.variant : Variant;
import core.thread : msecs;

import godot_project;

struct EncodedMessage {
	string message_type;
	ubyte[] message;
	size_t mid;
	string from_tid;
	string to_tid;

	// FIXME: Move this to be next to encode
	T decodeMessage(T)() {
		import cbor : decodeCborSingle;

		return decodeCborSingle!T(message);
	}
}

// FIXME: Move these structs out of this module, because they
// are app specific
struct MessageParseProject {
	string full_project_path;
}

struct MessageParseProjectFile {
	string full_path;
}

struct MessageParseProjectDone {
	Project project;
}
struct MessageParseSceneDone {
	Scene scene;
}
struct MessageParseNativeScriptDone {
	NativeScript native_script;
}
struct MessageParseGDScriptDone {
	GDScript gd_script;
}
struct MessageParseNativeLibraryDone {
	NativeLibrary native_library;
}



struct MessageStop {
}

struct MessageTaskDone {
	string receipt;
	size_t mid;
	string from_tid;
	string to_tid;
}
/*
struct MessageMonitorMemoryUsage {
	string exe_name;
	int pid;
}
*/
__gshared Tid[string] _tid_names;

void setThreadName(string name, Tid tid) {
	synchronized {
		_tid_names[name] = tid;
	}
}

void removeThreadName(string name) {
	synchronized {
		_tid_names.remove(name);
	}
}

Tid getThreadTid(string name) {
	synchronized {
		if (name in _tid_names) {
			return _tid_names[name];
		}
	}

	return Tid.init;
}

size_t sendThreadMessage(MessageType)(string from_thread_name, string to_thread_name, MessageType message) {
	import std.concurrency : send, Tid;
	import core.atomic : atomicOp;
	import std.string : format;
	import std.array : appender;
	import std.base64 : Base64;
	import cbor : encodeCbor;

	Tid target_thread = getThreadTid(to_thread_name);
	if (target_thread == Tid.init) {
		throw new Exception(`No thread with name "%s" found`.format(to_thread_name));
	}

	// Message -> message cbor
	auto message_buffer = appender!(ubyte[])();
	encodeCbor(message_buffer, message);
	ubyte[] message_cbor = message_buffer.data;

	// message cbor -> EncodedMessage
	size_t mid = _next_message_id.atomicOp!"+="(1);
	string from_tid = from_thread_name;
	string message_type = MessageType.stringof;
	auto encoded = EncodedMessage(message_type, message_cbor, mid, from_tid);

	// EncodedMessage -> encoded cbor
	auto encoded_buffer = appender!(ubyte[])();
	encodeCbor(encoded_buffer, encoded);
	ubyte[] encoded_cbor = encoded_buffer.data;

	// encoded cbor -> base64ed encoded cbor
	string b64ed = Base64.encode(encoded_cbor);

	// base64ed encoded cbor -> encoded message
	string encoded_message = `%.5s:%s`.format(cast(u16) b64ed.length, b64ed);

	send(target_thread, encoded_message);
	return mid;
}

void sendThreadMessageUnconfirmed(MessageType)(string to_thread_name, MessageType message) {
	import std.concurrency : send, Tid;
	import core.atomic : atomicOp;
	import std.string : format;
	import std.array : appender;
	import std.base64 : Base64;
	import cbor : encodeCbor;

	// Message -> message cbor
	auto message_buffer = appender!(ubyte[])();
	encodeCbor(message_buffer, message);
	ubyte[] message_cbor = message_buffer.data;

	// message cbor -> EncodedMessage
	string message_type = MessageType.stringof;
	auto encoded = EncodedMessage(message_type, message_cbor);

	// EncodedMessage -> encoded cbor
	auto encoded_buffer = appender!(ubyte[])();
	encodeCbor(encoded_buffer, encoded);
	ubyte[] encoded_cbor = encoded_buffer.data;

	// encoded cbor -> base64ed encoded cbor
	string b64ed = Base64.encode(encoded_cbor);

	// base64ed encoded cbor -> encoded message
	string encoded_message = `%.5s:%s`.format(cast(u16) b64ed.length, b64ed);

	try {
		send(getThreadTid(to_thread_name), encoded_message);
	} catch (Throwable err) {
		stderr.writefln("Failed to send message to %s, %s", to_thread_name, err); stderr.flush();
		stderr.writefln("Message: %s", message); stderr.flush();
	}
}

EncodedMessage getThreadMessage(Variant data) {
	import cbor : decodeCborSingle;
	import std.base64 : Base64;
	import std.conv : to;
	import std.algorithm : canFind;

	// NOTE: data may be string, char[], or immutable(char[]), so just assume string
	string encoded = data.to!string;

	// Length < "00000:A"
	if (encoded.length < 7) {
		return EncodedMessage.init;
	// Missing :
	} else if (encoded[5] != ':') {
		return EncodedMessage.init;
	}

	// Validate size prefix
	immutable char[] NUMBERS = "0123456789";
	foreach (n ; encoded[0 .. 5]) {
		if (! NUMBERS.canFind(n)) {
			return EncodedMessage.init;
		}
	}

	// Validate base64 payload
	immutable char[] CODES = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	foreach (n ; encoded[6 .. $]) {
		if (! CODES.canFind(n)) {
			return EncodedMessage.init;
		}
	}

	int len = encoded[0 .. 5].to!int;
	//print("!!!!!!!!!!<<<<<<<< len: %s", len);
	ubyte[] b64ed = cast(ubyte[]) encoded[6 .. $];
	//print("!!!!!!!!!!<<<<<<<< b64ed: %s", b64ed);

	if (len != b64ed.length) {
		return EncodedMessage.init;
	}

	// UnBase64 the blob
	ubyte[] blob = cast(ubyte[]) Base64.decode(b64ed);

	auto encoded_message = decodeCborSingle!EncodedMessage(blob);
	return encoded_message;
}

interface IMessageThread {
	bool onMessage(EncodedMessage encoded);
}

void startMessageThread(string name, ulong receive_ms, IMessageThread message_thread) {
	spawn(function(string _name, ulong _receive_ms, size_t _ptr) {
		stdout.writefln("!!!!!!!!!!!!!!!! %s started ...............", _name); stdout.flush();

		try {
			setThreadName(_name, thisTid());
			scope (exit) removeThreadName(_name);

			bool is_running = true;
			while (is_running) {

				// Get the actual message thread from the pointer
				void* ptr = cast(void*) _ptr;
				IMessageThread message_thread = cast(IMessageThread) ptr;

				// Get a cb to run the onMessage
				auto cb = delegate(Variant data) {
					EncodedMessage encoded = getThreadMessage(data);
					if (encoded is EncodedMessage.init) return;

					//prints("!!!!!!!! got message %s", message_type);
					is_running = message_thread.onMessage(encoded);
				};

				// If ms is max, then block forever waiting for messages
				if (_receive_ms == ulong.max) {
					receive(cb);
				// Otherwise only block for the ms
				} else {
					receiveTimeout(_receive_ms.msecs, cb);
				}
			}
		} catch (Throwable err) {
			stderr.writefln("(%s) thread threw: %s", _name, err); stderr.flush();
		}
	}, name, receive_ms, cast(size_t) (cast(void*) message_thread));
}

private:

shared size_t _next_message_id;
