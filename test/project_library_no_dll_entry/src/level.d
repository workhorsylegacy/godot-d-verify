import godot;
import godot.object;
import godot.os;
import godot.engine;
import godot.timer;
import godot.node;
import godot.spatial;
import godot.rigidbody;
import godot.control.all;

class Level : GodotScript!Control {
	alias owner this;
	int _click_count = 0;

	@Method _ready() {
	}

	@Method _process(float delta) {
	}

	@Method void on_button_pressed() {
		import std.string : format;
		_click_count++;

		string message = "Button pressed %s times".format(_click_count);
		print(message);
		auto label = getNode(gs!"Label").as!Label;
		label.text = String(message);
	}
}
