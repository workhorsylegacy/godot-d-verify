

module verify_godot_ass;

void verify() {
/*
	import std.traits;
	import std.string : format;
	import script_class_names;

	// Import all the classes
	static foreach (file_name, class_name ; getClassNames()) {
		mixin("import %s : %s;".format(file_name, class_name));
	}

	// Make sure the script's D classes exists
	static foreach (path, name ; getScriptClassNames()) {
		static if (! is(mixin(name))) {
			static assert(0, `Script "%s" needs class "%s" which is not loaded!`.format(path, name));
		}
	}

	// Make sure the scene signals have matching D methods
	immutable auto entries = getSceneSignalNames();
	static foreach (path, signals ; entries) {
		static if (signals != SceneSignals.init) {
			static if (! is(mixin(signals.class_name))) {
				static assert(0, `Script "%s" needs class "%s" which is not loaded!`.format(path, signals.class_name));
			}
			static foreach (method ; signals.methods) {
				static if (! hasMember!(mixin(signals.class_name), method)) {
					static assert(0, `Scene "%s" needs method "%s.%s" which is missing!`.format(path, signals.class_name, method));
				}
			}
		}
	}
*/
}
