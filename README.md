# spirv.zig

This is a fork of [hexops/spirv-tools][1] which itself is a fork of [KhronosGroup/SPIRV-Tools][2].

## Why this forkception ?

The intention under this fork is the same as [hexops][11] had when they forked [KhronosGroup/SPIRV-Tools][2]: package the headers for [Zig][4]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`.
However this repository has subtle differences for maintainability tasks:
* No shell scripting,
* A cron runs every day to check [KhronosGroup/SPIRV-Tools][2] and [KhronosGroup/SPIRV-Headers][3]. Then it updates this repository if a new release is available.

Here the repositories' version used by this fork:
* [KhronosGroup/SPIRV-Tools](https://github.com/tiawl/spirv.zig/blob/trunk/.versions/spirv-tools)
* [KhronosGroup/SPIRV-Headers](https://github.com/tiawl/spirv.zig/blob/trunk/.versions/spirv)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/shaderc.zig][5]

This repository is automatically updated when a new release is available from these repositories:
* [KhronosGroup/SPIRV-Tools][2]
* [KhronosGroup/SPIRV-Headers][3]
* [tiawl/toolbox][6]
* [tiawl/spaceporn-action-bot][7]
* [tiawl/spaceporn-action-ci][8]
* [tiawl/spaceporn-action-cd-ping][9]
* [tiawl/spaceporn-action-cd-pong][10]

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .versions folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

The unprotected parts of this repository are under MIT License. For everything else, see with their respective owners.

[1]:https://github.com/hexops/spirv-tools
[2]:https://github.com/KhronosGroup/SPIRV-Tools
[3]:https://github.com/KhronosGroup/SPIRV-Headers
[4]:https://github.com/ziglang/zig
[5]:https://github.com/tiawl/shaderc.zig
[6]:https://github.com/tiawl/toolbox
[7]:https://github.com/tiawl/spaceporn-action-bot
[8]:https://github.com/tiawl/spaceporn-action-ci
[9]:https://github.com/tiawl/spaceporn-action-cd-ping
[10]:https://github.com/tiawl/spaceporn-action-cd-pong
[11]:https://github.com/hexops
