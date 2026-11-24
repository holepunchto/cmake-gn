# cmake-gn

Bridging CMake and GN, the meta-build system from Google.

```
npm i cmake-gn
```

```cmake
find_package(cmake-gn REQUIRED PATHS node_modules/cmake-gn)
```

## API

The functions read a GN build that has already been generated and built. `GN_DIR` is the root of the GN project, and `GN_OUT_DIR` is its output directory, either absolute or relative to `GN_DIR`. GN itself is found as `gn`.

#### `add_gn_target(<name> <target>)`

Creates the imported target `<name>` for the GN target `<target>`, such as `//foo:bar`. Only static libraries are supported.

The imported target holds the interface that GN applies to the dependents of `<target>`: the `defines`, `include_dirs`, `cflags`, `cflags_c`, `cflags_cc`, `cflags_objc`, `cflags_objcc`, `ldflags`, `lib_dirs`, `libs`, `frameworks`, and `weak_frameworks` of its `public_configs` and `all_dependent_configs`. The flags that `<target>` itself is compiled with aren't included. Include directories that don't exist, such as generated directories that the build hasn't written, are left out.

#### `add_gn_package(<name> [INSTALL])`

Finds the CMake package `<name>` that the GN build wrote to `${GN_OUT_DIR}/package/<name>` with `find_package(<name> CONFIG REQUIRED)`, and sets `<name>_FOUND` and `<name>_VERSION`. With `INSTALL`, the package is also installed to the root of the installation prefix, so that the packages of the project can find it as a dependency.

Each package is an installable prefix of its own, with its config file at `lib/cmake/<name>/<name>-config.cmake`:

```
<GN_OUT_DIR>/package/
  <name>/
    include/
    lib/
    lib/cmake/<name>/
      <name>-config.cmake
      <name>-config-version.cmake
```

Paths in the config files must be relative to the location of the files, so that the package works both from the GN output directory and after being installed. Packages that depend on each other can find their dependencies in the parent directory of their prefix.

## License

Apache-2.0
