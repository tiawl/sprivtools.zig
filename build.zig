const std = @import("std");
const toolbox = @import("toolbox");

const Paths = struct {
    // prefixed attributes
    __tmp: []const u8 = undefined,
    __spirv: []const u8 = undefined,
    __spirv_tools: []const u8 = undefined,
    __spirv_tools_in: []const u8 = undefined,
    __source: []const u8 = undefined,
    __build: []const u8 = undefined,

    // mandatory getters
    pub fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }
    pub fn getSpirv(self: @This()) []const u8 {
        return self.__spirv;
    }
    pub fn getSpirvTools(self: @This()) []const u8 {
        return self.__spirv_tools;
    }
    pub fn getSpirvToolsIn(self: @This()) []const u8 {
        return self.__spirv_tools_in;
    }
    pub fn getSource(self: @This()) []const u8 {
        return self.__source;
    }
    pub fn getBuild(self: @This()) []const u8 {
        return self.__build;
    }

    // mandatory init
    pub fn init(builder: *std.Build) !@This() {
        var self = @This(){
            .__tmp = try builder.build_root.join(builder.allocator, &.{
                "tmp",
            }),
            .__spirv = try builder.build_root.join(builder.allocator, &.{
                "spirv",
            }),
            .__spirv_tools = try builder.build_root.join(builder.allocator, &.{
                "spirv-tools",
            }),
        };

        self.__spirv_tools_in = try std.fs.path.join(builder.allocator, &.{
            self.getSpirvTools(),
            "spirv-tools",
        });
        self.__source = try std.fs.path.join(builder.allocator, &.{
            self.getSpirvTools(),
            "source",
        });
        self.__build = try std.fs.path.join(builder.allocator, &.{
            self.getTmp(),
            "build",
        });

        return self;
    }
};

fn update_headers(builder: *std.Build, path: *const Paths, dependencies: *const toolbox.Dependencies) !void {
    try dependencies.clone(builder, "spirv", path.getTmp());

    const tmp_include_path =
        try std.fs.path.join(builder.allocator, &.{
        path.getTmp(),
        "include",
    });
    var tmp_include_dir =
        try std.fs.openDirAbsolute(tmp_include_path, .{
        .iterate = true,
    });
    defer tmp_include_dir.close();

    var walker = try tmp_include_dir.walk(builder.allocator);
    defer walker.deinit();

    while (try walker.next()) |*entry| {
        const dest =
            try builder.build_root.join(builder.allocator, &.{
            entry.path,
        });
        switch (entry.kind) {
            .file => {
                if (toolbox.isHeader(entry.basename)) try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
                    tmp_include_path,
                    entry.path,
                }), dest);
            },
            .directory => try toolbox.make(dest),
            else => return error.UnexpectedEntryKind,
        }
    }

    try std.fs.deleteTreeAbsolute(path.getTmp());
}

fn update_sources(builder: *std.Build, path: *const Paths) !void {
    var src_path: []const u8 = undefined;
    var dest_path: []const u8 = undefined;
    var src_dir: std.fs.Dir = undefined;
    var walker: std.fs.Dir.Walker = undefined;

    for ([_]struct {
        src: []const u8,
        dest: []const u8,
    }{
        .{ .src = try std.fs.path.join(builder.allocator, &.{
            "include",
            "spirv-tools",
        }), .dest = "spirv-tools" },
        .{
            .src = "source",
            .dest = "source",
        },
    }) |dir_name| {
        src_path =
            try std.fs.path.join(builder.allocator, &.{
            path.getTmp(),
            dir_name.src,
        });
        dest_path = try std.fs.path.join(builder.allocator, &.{
            path.getSpirvTools(),
            dir_name.dest,
        });

        try toolbox.make(dest_path);

        src_dir = try std.fs.openDirAbsolute(src_path, .{
            .iterate = true,
        });
        defer src_dir.close();

        walker = try src_dir.walk(builder.allocator);
        defer walker.deinit();

        while (try walker.next()) |*entry| {
            const dest = try std.fs.path.join(builder.allocator, &.{
                dest_path,
                entry.path,
            });
            switch (entry.kind) {
                .file => try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
                    src_path,
                    entry.path,
                }), dest),
                .directory => try toolbox.make(dest),
                else => return error.UnexpectedEntryKind,
            }
        }
    }
}

fn wait_20_secs() void {
    std.time.sleep(std.time.ns_per_s * 20);
}

fn update_generated(builder: *std.Build, path: *const Paths) !void {
    var build_dir =
        try std.fs.openDirAbsolute(path.getBuild(), .{
        .iterate = true,
    });
    defer build_dir.close();

    var it = build_dir.iterate();
    while (try it.next()) |*entry| {
        switch (entry.kind) {
            .file => {
                if (std.mem.endsWith(u8, entry.name, ".inc")) {
                    try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
                        path.getBuild(),
                        entry.name,
                    }), try std.fs.path.join(builder.allocator, &.{
                        path.getSpirvToolsIn(),
                        entry.name,
                    }));
                }
            },
            else => {},
        }
    }
}

fn update(builder: *std.Build, path: *const Paths, dependencies: *const toolbox.Dependencies) !void {
    std.fs.deleteTreeAbsolute(path.getTmp()) catch |err|
        {
        switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    };

    for ([_][]const u8{
        path.getSpirv(),
        path.getSpirvTools(),
    }) |dest_path| {
        try std.fs.deleteTreeAbsolute(dest_path);
        try toolbox.make(dest_path);
    }

    try update_headers(builder, path, dependencies);

    try dependencies.clone(builder, "spirv-tools", path.getTmp());
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "python3",
            try std.fs.path.join(builder.allocator, &.{
                "utils",
                "git-sync-deps",
            }),
        },
        .cwd = path.getTmp(),
    });

    try toolbox.make(path.getBuild());

    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "cmake",
            "..",
        },
        .cwd = path.getBuild(),
    });
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "make",
        },
        .cwd = path.getBuild(),
        .wait = wait_20_secs,
    });

    try update_sources(builder, path);
    try update_generated(builder, path);

    try std.fs.deleteTreeAbsolute(path.getTmp());

    var source_dir =
        try std.fs.openDirAbsolute(path.getSource(), .{
        .iterate = true,
    });
    defer source_dir.close();

    var walker = try source_dir.walk(builder.allocator);
    defer walker.deinit();

    while (try walker.next()) |*entry| {
        switch (entry.kind) {
            .file => {
                if (std.fs.path.dirname(entry.path)) |dirname| {
                    if (!std.mem.eql(u8, "opt", dirname) and
                        !std.mem.eql(u8, "val", dirname) and
                        !std.mem.eql(u8, "util", dirname))
                        try std.fs.deleteFileAbsolute(try std.fs.path.join(builder.allocator, &.{
                            path.getSource(),
                            entry.path,
                        }));
                }
            },
            else => {},
        }
    }

    try toolbox.clean(builder, &.{
        "spirv",
        "spirv-tools",
    }, &.{
        ".inc",
    });
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const path = try Paths.init(builder);

    const dependencies = try toolbox.Dependencies.init(builder, "spirv.zig", &.{
        "spirv",
        "spirv-tools",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.tag,
        },
    }, .{
        .spirv = .{
            .name = "KhronosGroup/SPIRV-Headers",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
        .@"spirv-tools" = .{
            .name = "KhronosGroup/SPIRV-Tools",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
    });

    if (builder.option(bool, "update", "Update binding") orelse false)
        try update(builder, &path, &dependencies);

    const lib = builder.addStaticLibrary(.{
        .name = "spirv",
        .root_source_file = builder.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    for ([_][]const u8{
        ".", "spirv", "spirv-tools",
        try std.fs.path.join(builder.allocator, &.{
            "spirv-tools",
            "spirv-tools",
        }),
        try std.fs.path.join(builder.allocator, &.{
            "spirv",
            "unified1",
        }),
    }) |include| toolbox.addInclude(lib, include);

    toolbox.addHeader(lib, path.getSpirv(), "spirv", &.{
        ".h",
        ".hpp",
        ".hpp11",
    });
    toolbox.addHeader(lib, path.getSpirvToolsIn(), "spirv-tools", &.{
        ".h",
        ".hpp",
        ".hpp11",
    });

    lib.linkLibCpp();

    var source_dir =
        try std.fs.openDirAbsolute(path.getSource(), .{
        .iterate = true,
    });
    defer source_dir.close();

    var walker = try source_dir.walk(builder.allocator);
    defer walker.deinit();

    while (try walker.next()) |*entry| {
        switch (entry.kind) {
            .file => {
                if (toolbox.isCppSource(entry.basename))
                    try toolbox.addSource(lib, path.getSource(), entry.path, &.{});
            },
            else => {},
        }
    }

    builder.installArtifact(lib);
}
