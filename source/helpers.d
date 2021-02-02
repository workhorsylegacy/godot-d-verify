// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module helpers;

public import std.file : SpanMode;
public import std.file : DirIterator;

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

T[] sortBy(T, string field_name)(T[] things) {
	import std.algorithm : sort;
	import std.array : array;

	alias sortFilter = (a, b) => mixin("a." ~ field_name ~ " < b." ~ field_name);

	return things.sort!(sortFilter).array;
}
