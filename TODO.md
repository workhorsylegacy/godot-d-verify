



# TESTS:

## Project
* [X] Should succeed on working project
* [X] Should fail when project main scene is not specified
* [X] Should fail when project main scene file is not found

## Scene
* [X] Should fail when scene resource file is not found
* [X] Should fail when signal method doesn't exists in code
* [X] Should fail when signal method exists but missing Method attribute

## Script
* [X] Should fail when script native library is not specified
* [X] Should fail when script native library file is not found
* [X] Should fail when script class_name is not specified
* [X] Should fail when script class does not exist in code

## Library
* [X] Should fail when native library symbol_prefix is not specified
* [X] Should fail when native library dll/so file is not specified




# TODO:

* [ ] Make sure it scans all scenes in folder, instead of just the ones referenced in scripts.
* [ ] Make sure GDscript resources exists too

* [ ] Make sure image resources are present too
