// Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// MIT License
// Verify Godot projects that use the D Programming Language
// https://github.com/workhorsy/godot-d-verify

module read_xml;

import std.stdio : stdout;
import dxml.dom : DOMEntity;


class Node {
	DOMEntity!string entity;
	Node parent_node = null;
	string path = null;

	this(DOMEntity!string entity, string path, Node parent_node) {
		this.entity = entity;
		this.path = path;
		this.parent_node = parent_node;
	}
}

Node readNodes(string file_name) {
	import std.file : read, exists;
	import dxml.dom : parseDOM;

	auto data = cast(string)read(file_name);
	auto dom = parseDOM(data);
	Node node = new Node(dom, dom.name ~ `/`, null);
	return node;
}

Node[] getNodes(Node dom, string node_path_to_find, bool is_printing=false) {
	import dxml.dom : EntityType;

	Node[] retval;

	Node[] nodes = [new Node(dom.entity, dom.entity.name ~ `/`, dom.parent_node)];
	while (nodes.length > 0) {
		Node node = nodes[0];
		nodes = nodes[1 .. $];
		if (is_printing) {
			stdout.writefln("!!!!!!!!!!!!!!!!!!!!!!! node.path: %s", node.path); stdout.flush();
		}

		if (node.path == node_path_to_find) {
			retval ~= node;
		}

		if (node.entity.type != EntityType.elementEmpty) {
			foreach (child ; node.entity.children) {
				if (child.type != EntityType.text) {
					nodes ~= new Node(child, node.path ~ child.name ~ `/`, node);
				}
			}
		}
	}

	return retval;
}

Node getNode(Node node, string node_path_to_find, bool is_printing=false) {
	Node[] retval = node.getNodes(node_path_to_find, is_printing);
	if (retval.length > 0) {
		return retval[0];
	}

	return null;
}

string getNodeText(Node node) {
	foreach (child ; node.entity.children) {
		return child.text;
	}

	return "";
}
