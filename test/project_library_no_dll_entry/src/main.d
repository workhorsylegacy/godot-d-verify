
import godot;
import std.stdio : writefln, writeln;


import level : Level;

mixin GodotNativeLibrary!(
	"simple",
	Level,

	(GodotInitOptions o) {

	},
	(GodotTerminateOptions o) {

	}
);
