# Troubleshooting

For bridge loading, runtime bitcode, and backend setup issues, see [Haxe/HashLink troubleshooting](hashlink.md#troubleshooting). For migration from the old Python binding, see [Haxe/HashLink public API](haxe_api.md).

## Cache and generated files

Quadrants writes compiler cache data under `~/.cache/quadrants` by default. If a crash only happens after cached kernels are reused, remove the cache and rebuild the Haxe/HashLink program:

```bash
rm -rf ~/.cache/quadrants
haxe -lib quadrants -main YourMain -hl build/app.hl
```

If the problem remains, open an issue with the CMake configure command, Haxe command, `hl` command, backend selected, and a minimal reproducer.
