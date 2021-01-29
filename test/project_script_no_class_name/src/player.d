
import godot;
import godot.object;
import godot.node;
import godot.spatial;


float deg2rad(float degrees) {
	import std.math : PI;
	float radians = (degrees * PI) / 180.0f;
	return radians;
}

float rad2deg(float radians) {
	import std.math : PI;
	float degrees = radians * (180.0f / PI);
	return degrees;
}

class Player : GodotScript!Spatial {
	alias owner this;


	@Method void _init() {

	}

	@Method void _ready() {

	}

	@Method void _physics_process(float _delta) {
		auto rot = this.rotation;
		rot.z += deg2rad(3.0);
		this.rotation = rot;
	}
}
