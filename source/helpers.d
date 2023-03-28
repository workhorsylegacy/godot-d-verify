// Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot 3 projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module helpers;

import std.traits : isSomeString;

public import std.file : SpanMode;
public import std.file : DirIterator;

string _root_path = null;

public import core.stdc.stdint :
	u64 = uint64_t,
	u32 = uint32_t,
	u16 = uint16_t,
	u8  = uint8_t,
	s64 = int64_t,
	s32 = int32_t,
	s16 = int16_t,
	s8  = int8_t;

s64 GetCpuTicksNS() {
	import core.time : MonoTime, ticksToNSecs;

	return ticksToNSecs(MonoTime.currTime.ticks);
}

void reset_path(string project_path) {
	import std.file : chdir;
	import helpers : getcwd, buildPath;

	if (! _root_path) {
		_root_path = getcwd();
	}

	chdir(buildPath(_root_path, project_path));
}

// FIXME: Have it change all path seps from \ to /
DirIterator dirEntries(string path, SpanMode mode, bool followSymlink = true) {
	import std.file : dirEntries;
	return dirEntries(path, mode, followSymlink);
}

string absolutePath(string path) {
	import std.path : absolutePath;
	import std.array : replace;
	return absolutePath(path).replace(`\`, `/`);
}

string getcwd() {
	import std.file : getcwd;
	import std.array : replace;
	return getcwd().replace(`\`, `/`);
}

void chdir(string path) {
	import std.file : chdir;
	chdir(path);
}

string buildPath(string[] args ...) {
	import std.path : buildPath;
	import std.array : replace;
	return buildPath(args).replace(`\`, `/`);
}

string baseName(string path) {
	import std.path : baseName;
	import std.array : replace;
	return baseName(path).replace(`\`, `/`);
}

string dirName(string path) {
	import std.path : dirName;
	import std.array : replace;
	return dirName(path).replace(`\`, `/`);
}

string toPosixPath(string path) {
	import std.array : replace;
	import std.algorithm : endsWith;
	path = path.replace(`\`, `/`);
	if (! path.endsWith(`/`)) {
		path ~= `/`;
	}
	return path;
}

auto sortBy(string field_name, T)(T things) {
	import std.algorithm : sort;
	import std.string : format;

	alias sortFilter = (a, b) => mixin("a.%s < b.%s".format(field_name, field_name));

	return things.sort!(sortFilter);
}

S before(S)(S value, S separator) if (isSomeString!S) {
	import std.string : indexOf;
	long i = indexOf(value, separator);

	if (i == -1)
		return value;

	return value[0 .. i];
}

S after(S)(S value, S separator) if (isSomeString!S) {
	import std.string : indexOf;
	long i = indexOf(value, separator);

	if (i == -1)
		return "";

	size_t start = i + separator.length;

	return value[start .. $];
}

S between(S)(S value, S front, S back) if (isSomeString!S) {
	return value.after(front).before(back);
}
