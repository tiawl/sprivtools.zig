# spirv.zig

This is a fork of [hexops/spirv-tools][1] which itself is a fork of [KhronosGroup/SPIRV-Tools][2].

## Why this forkception ?

The intention under this fork is the same as [hexops][11] had when they forked [KhronosGroup/SPIRV-Tools][2]: package the headers for [Zig][4]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`.

However this repository has subtle differences for maintainability tasks:
* No shell scripting,
* A cron runs every day to check [KhronosGroup/SPIRV-Tools][2] and [KhronosGroup/SPIRV-Headers][3]. Then it updates this repository if a new release is available.

## How to use it

The current usage of this repository is centered around [tiawl/shaderc.zig][3] compilation. But you could use it for your own projects. Headers are here and there are no planned evolution to modify them. See [tiawl/shaderc.zig][3] to see how you can use it. Maybe for your own need, some headers are missing. If it happens, open an issue: this repository is open to potential usage evolution.

## Dependencies

The [Zig][4] part of this package is relying on the latest [Zig][4] release (0.13.0) and will only be updated for the next one (so for the 0.14.0).

Here the repositories' version used by this fork:
* [KhronosGroup/SPIRV-Tools](https://github.com/tiawl/spirv.zig/blob/trunk/.references/spirv-tools)
* [KhronosGroup/SPIRV-Headers](https://github.com/tiawl/spirv.zig/blob/trunk/.references/spirv)

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
  -Dfetch   Update .references folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

This repository is not subject to a unique License:

The parts of this repository originated from this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is subject to the License restrictions their respective owners choosed. By design, the public domain code is incompatible with the License notion. In this case, the License prevails. So if you have any doubt about a file property, open an issue.**

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
