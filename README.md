# Nim `stack_strings` Module

The `stack_strings` module provides a string implementation that works with 100% stack memory.

This module is primarily meant for programs that want to avoid any and all heap allocation, such as code for embedded targets.
If you use `--mm:arc` and `-d:useMalloc` in tandem with this module, your program will be able to do string operations without allocating any memory at runtime.

# Documentation

To generate documentation, clone this repository and then run `nimble docgen`.
The generated HTML docs will be available in the `docs` directory in the project root.

# Nim Version Support

Only Nim `2.0.0`+ is supported because the module takes advantage of various type system improvements introduced in `2.0.0`.
