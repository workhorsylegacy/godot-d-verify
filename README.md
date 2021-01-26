# Godot D Verify
Verify a D Godot project



# Setup Windows
```
dub fetch dscanner
dub run dscanner -- --version
cp ../../AppData/Local/dub/packages/dscanner-0.11.0/dscanner/bin/dscanner.exe dscanner.exe
```

# Setup Linux
```
dub fetch dscanner
dub run dscanner -- --version
cp ~/.dub/packages/dscanner-0.11.0/dscanner/bin/dscanner dscanner
```


# Run unit tests

```
dub test --compiler=ldc2
```

# Build

```
dub run --compiler=ldc2 --build=debug
```
