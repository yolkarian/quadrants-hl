# Migrating Haxe API v2 code to v3

- Replace untyped `Kernel.build`/`Kernel.launch(args:Array<Dynamic>)` usage with typed parameter annotations and typed `launch` calls.
- Use `Kernel.buildRaw` / `KernelRaw` only for low-level migration code.
- Replace `@:qdFlatten` / `@:qdDataOriented` with `@:build(quadrants.macro.QdArgs.build())`.
- Remove `@:template` for primitive QdArgs fields. Primitive members are specialization constants by default. Use an explicit kernel parameter for runtime scalars.
- Replace template dtype helpers with explicit Haxe generic types where possible. Use `Spec<T>` for standalone specialization constants.
- Pass `Field<T>` only to kernels that declare `Field<T>`. The previous implicit Field-to-Tensor mirror path is removed from the v3 launch path.
- Descriptor metadata is QDHL schema version 3. Code that asserted descriptor version 2 should be updated.

This migration guide documents mappings only; it does not imply a runtime compatibility shim.
