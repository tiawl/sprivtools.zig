# spirv.zig

This is a fork of [hexops/spirv-tools](https://github.com/hexops/spirv-tools) which itself is a fork of [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools).

## Why this forkception ?

The intention under this fork is the same as hexops had when they forked [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools): package the headers for @ziglang. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`.
However this repository has subtle differences for maintainability tasks:
* No shell scripting,
* A cron runs every day to check [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools) and [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers). Then it updates this repository if a new release is available.

Here the repositories' version used by this fork:
* [KhronosGroup/SPIRV-Tools](https://github.com/tiawl/spirv.zig/blob/trunk/.versions/spirv-tools)
* [KhronosGroup/SPIRV-Headers](https://github.com/tiawl/spirv.zig/blob/trunk/.versions/spirv)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/shaderc.zig](https://github.com/tiawl/shaderc.zig)

This repository is automatically updated when a new release is available from these repositories:
* [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools)
* [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)
* [tiawl/toolbox](https://github.com/tiawl/toolbox)
* [tiawl/spaceporn-action-bot](https://github.com/tiawl/spaceporn-action-bot)
* [tiawl/spaceporn-action-ci](https://github.com/tiawl/spaceporn-action-ci)
* [tiawl/spaceporn-action-cd-ping](https://github.com/tiawl/spaceporn-action-cd-ping)
* [tiawl/spaceporn-action-cd-pong](https://github.com/tiawl/spaceporn-action-cd-pong)

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .versions folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

The unprotected parts of this repository are under MIT License. For everything else, see with their respective owners.
