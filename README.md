# Nim `stack_strings` Module

The `stack_strings` module provides a string implementation that works with 100% stack memory.

This module is primarily meant for programs that want to avoid any and all heap allocation, such as code for embedded targets.
If you use `--mm:arc` and `-d:useMalloc` in tandem with this module, your program will be able to do string operations without allocating any memory at runtime.

# Documentation

You can view the latest documentation online [here](https://docs.termer.net/nim/stack_strings/).

To generate documentation, clone this repository and then run `nimble docgen`.
The generated HTML docs will be available in the `docs` directory in the project root.

# Nim Version Support

Only Nim `1.6.14`+ is supported as there are bugs with `static int` in prior versions.
