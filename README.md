# Catalog

A simple, powerful, versatile, and fast package manager for CMake.

Catalog manages your project's third-party dependencies without causing a mild
aneurysm. It acts as a dynamic middleman for your build, wrapping system
packages, prebuilt binaries, and raw source code into clean and consistant
`deps::` targets.

By using a decentralized recipe model, Catalog gives you the flexibility of a
full package manager without any of the configuration-time bloat.

## Why Catalog?

Different package managers prioritize different workflows. Catalog is designed
for ease of use by combining dependencies from multiple sources depending on the
system and configuration options. If you're project needs fully consistant
builds, Catalog may not be the best pick (but it is fully capable of doing so).

- **vs. CPM / FetchContent:** Great for consistant and airtight builds, but
  relying entirely on downloading and compiling from source greatly increases
  configuration times. Catalog is fast because it checks for native system
  packages and prebuilts _before_ resorting to a git clone.
- **vs. vcpkg / Conan:** Powerful, but monolithic. They require massive central
  registries, external binaries, and strict environment setups. Additionally
  they have little compatibility with cross-compilation. Catalog is lightweight,
  completely decentralized, and requires absolutely zero external binaries to
  work—it's just pure CMake.
- **vs. Hunter:** While Hunter is also pure CMake, it is heavily centralized and
  builds everything from source. Catalog decentralizes the recipe index and
  explicitly prioritizes faster resolution methods over source compilation.
- **vs. Spack / Conda:** Designed to build massive, isolated scientific stacks
  from the ground up, often bypassing the host OS entirely. Catalog respects
  your system, happily utilizing native package managers like `pacman`, `apt`,
  or `brew` to keep your workflow native.

## Features

- **5-Stage Fallback Pipeline:** Automatically tries to resolve dependencies in
  a logical order:
  1. Built-in toolchain packages (e.g. from Emscripten)
  2. Local System (via `find_package`, `pkg-config`, or similar)
  3. Native Package Manager (Pops an interactive prompt for `apt`, `pacman`,
     `brew`, etc.)
  4. Prebuilt Binaries (Direct tarball downloads for specific architectures,
     this is most commonly used for Windows)
  5. Source Compilation (Fallback source download and build)
- **Toolchain Aware:** Recipes can specify precise compiler flags and
  configurations for complex cross-compilation environments (like Emscripten,
  consoles, or specific architectures).
- **Unified Targets:** No matter how a library is resolved—whether it came from
  `pacman`, a prebuilt tarball, or was compiled from source, it always links to
  your project via a clean `deps::library_name` alias.
- **Granular Control:** Explicitly force source builds, disable prebuilts, or
  force system-level resolution on a per-dependency basis using standard CMake
  variables or global environment variables.

## Command line interface

`catalog` can be used to install recipes system-wide from the command line.

**Install it**

```sh
curl -fsSL https://raw.githubusercontent.com/catalog-cmake/catalog/main/install.sh | sh
```

**Build it yourself**: `./bundle-cli.sh [--version STRING] [dist/catalog]`
bundles `cli/catalog.cmake`, its modules, and the (minified) library into one
file. From a checkout you can also run `./cli/catalog` directly.

**Use it**

```sh
catalog install SDL2                      # system -> package manager -> source
catalog install 'fmt@>=10' --static
catalog install gh:owner/repo             # recipe.cmake at the root of a GitHub repo
catalog install https://example.com/owner/repo@v1.2
catalog install foo --repo owner/recipes  # extra recipe repository
catalog check zlib                        # read-only
catalog list
catalog remove fmt
eval "$(catalog env)"                     # CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, ...
```

`install` tries, in order: the toolchain, the system (the recipe's `system`
stage), your package manager (it asks first, or pass `--yes`; never in a cross
build), then a source build that is installed into the prefix. The prebuilt
stage is not used by the CLI yet (as of writing).

## Documentation & Usage

For installation, usage, and recipe authoring instructions please visit our docs
site:

**[Link to Documentation](#)**

<!-- TODO: yk like actually make documentation... -->
