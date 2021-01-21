# Godot D Verify
Verify a D Godot project



```
dub fetch dscanner
cp ../../AppData/Local/dub/packages/dscanner-0.11.0/dscanner/bin/dscanner.exe dscanner.exe
./dscanner.exe --ast test/project_signal/src/level.d > level.d.xml
```

# Run unit tests

```
dub test --compiler=ldc2
```
