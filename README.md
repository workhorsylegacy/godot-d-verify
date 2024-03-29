# Godot D Verify
Verify Godot 3 projects that use the D Programming Language

:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:
:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:
:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:

!!! WARNING !!!

This project is obsolete. It has been replaced by https://github.com/ImmersiveRPG/super-dlang-godot3-turbo-hyper-fighting-champion-edition

:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:
:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:
:warning: :warning: :warning: :warning: :warning: :warning: :warning: :warning:

# Run unit tests

```
dub test
```

# Build

```
dub build
```

# Run verify

```
godot-d-verify --project game/project/ --source game/src/
```

# Generating GodotNativeLibrary automatically

Normally we would have to call GodotNativeLibrary and manually enter all scene classes

```dlang
// entrypoint.d
import godot;
import std.stdio : writefln;

mixin GodotNativeLibrary!(
	"game",
	Door,   // Manually added
	Enemy,  // Manually added
	Fish,   // Manually added
	Global, // Manually added
	Player, // Manually added
	(GodotInitOptions o) {
		writefln("Library initialized");
	},
	(GodotTerminateOptions o) {
		writefln("Library terminated");
	}
);

```

Instead, we can use godot-d-verify to generate a list of scene classes

```
godot-d-verify --project game/project/ --source game/src/ --generate_script_list
```

```dlang
// entrypoint.d
import godot;
import std.stdio : writefln;

import helpers : generateGodotNativeLibrary;
import generated_script_list : script_list;

mixin generateGodotNativeLibrary!(
	"game",
	script_list, // Get all the scene classes from generated_script_list.d
	(GodotInitOptions o) {
		writefln("Library initialized");
	},
	(GodotTerminateOptions o) {
		writefln("Library terminated");
	}
);
```

```dlang
// generated_script_list.d
// This file was generated by godot-d-verify
enum string[string] script_list = [
	"door" : "Door",
	"enemy" : "Enemy",
	"fish" : "Fish",
	"global" : "Global",
	"player" : "Player",
];
```

```dlang
// helpers.d
import godot : GodotInitOptions, GodotTerminateOptions;

// A helper function to generate the GodotNativeLibrary with the script list
template generateGodotNativeLibrary(
	string symbol_prefix,
	string[string] godot_scripts,
	void function(GodotInitOptions o) func_init = null,
	void function(GodotTerminateOptions o) func_terminate = null) {

	import std.string : format;
	import std.array : join;

	// Import all the classes
	static foreach (mod, klass ; godot_scripts) {
		mixin (`import %s : %s;`.format(mod, klass));
	}

	// Get all the classes
	enum class_list = godot_scripts.values.join(",\n");

	// Generate the GodotNativeLibrary mixin with the prefix, classes, and funcs
	enum string code =
`mixin GodotNativeLibrary!(
"%s",
%s,
(GodotInitOptions o) {
	if (func_init) func_init(o);
},
(GodotTerminateOptions o) {
	if (func_terminate) func_terminate(o);
});`.format(symbol_prefix, class_list);
	//pragma(msg, code);
	mixin (code);
}
```
