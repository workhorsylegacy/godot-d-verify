
import godot;
import std.stdio : writefln, writeln;


import player : Player;

mixin GodotNativeLibrary!(
	"game",
	Player,

	(GodotInitOptions o) {
		writeln("Library initialized");
	},
	(GodotTerminateOptions o) {
		writeln("Library terminated");
	}
);
