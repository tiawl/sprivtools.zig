const std = @import ("std");
const toolbox = @import ("toolbox");
const pkg = .{ .name = "spirv.zig", .version = "1.3.280", };

const Paths = struct
{
  tmp: [] const u8 = undefined,
  include: [] const u8 = undefined,
  source: [] const u8 = undefined,
  build: [] const u8 = undefined,
};

fn update_headers (builder: *std.Build, path: *const Paths) !void
{
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone", "https://github.com/KhronosGroup/SPIRV-Headers.git", path.tmp, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "-C", path.tmp, "checkout", "vulkan-sdk-" ++ pkg.version ++ ".0", }, });

  const spirv_headers_path = try std.fs.path.join (builder.allocator, &.{ path.tmp, "include", });
  var spirv_headers_dir = try std.fs.openDirAbsolute (spirv_headers_path, .{ .iterate = true, });
  defer spirv_headers_dir.close ();

  var walker = try spirv_headers_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |entry|
  {
    const dest = try std.fs.path.join (builder.allocator, &.{ path.include, entry.path, });
    switch (entry.kind)
    {
      .file => {
        if (toolbox.is_header_file (entry.basename)) try toolbox.copy (
          try std.fs.path.join (builder.allocator, &.{ spirv_headers_path, entry.path, }), dest);
      },
      .directory => try toolbox.make (dest),
      else => return error.UnexpectedEntryKind,
    }
  }

  try std.fs.deleteTreeAbsolute (path.tmp);
}

fn update_sources (builder: *std.Build, path: *const Paths) !void
{
  var src_path: [] const u8 = undefined;
  var dest_path: [] const u8 = undefined;
  var dir: std.fs.Dir = undefined;
  var walker: std.fs.Dir.Walker = undefined;

  for ([_][] const u8 { "include", "source", }) |dir_name|
  {
    src_path = try std.fs.path.join (builder.allocator, &.{ path.tmp, dir_name, });
    dest_path = try builder.build_root.join (builder.allocator, &.{ dir_name, });

    dir = try std.fs.openDirAbsolute (src_path, .{ .iterate = true, });
    defer dir.close ();

    walker = try dir.walk (builder.allocator);
    defer walker.deinit ();

    while (try walker.next ()) |entry|
    {
      const dest = try std.fs.path.join (builder.allocator, &.{ dest_path, entry.path, });
      switch (entry.kind)
      {
        .file => try toolbox.copy (
          try std.fs.path.join (builder.allocator, &.{ src_path, entry.path, }), dest),
        .directory => try toolbox.make (dest),
        else => return error.UnexpectedEntryKind,
      }
    }
  }
}

fn wait_20_secs () void
{
  std.time.sleep (std.time.ns_per_s * 20);
}

fn update_generated (builder: *std.Build, path: *const Paths) !void
{
  const generated_path = try builder.build_root.join (builder.allocator, &.{ "include-generated", });

  try std.fs.deleteTreeAbsolute (generated_path);
  try toolbox.make (generated_path);

  var build_dir = try std.fs.openDirAbsolute (path.build, .{ .iterate = true, });
  defer build_dir.close ();

  var walker = try build_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (std.mem.endsWith (u8, entry.basename, ".inc"))
        {
          try toolbox.copy (
            try std.fs.path.join (builder.allocator, &.{ path.build, entry.path, }),
            try std.fs.path.join (builder.allocator, &.{ generated_path, entry.path, }));
        }
      },
      else => {},
    }
  }
}

fn update (builder: *std.Build, path: *const Paths) !void
{
  std.fs.deleteTreeAbsolute (path.tmp) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  for ([_][] const u8 { path.include, path.source, }) |dest_path|
  {
    try std.fs.deleteTreeAbsolute (dest_path);
    try toolbox.make (dest_path);
  }

  try update_headers (builder, path);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone", "https://github.com/KhronosGroup/SPIRV-Tools.git", path.tmp, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "-C", path.tmp, "checkout", "vulkan-sdk-" ++ pkg.version ++ ".0", }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3",
    try std.fs.path.join (builder.allocator, &.{ "utils", "git-sync-deps", }), }, .cwd = path.tmp, });

  try toolbox.make (path.build);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "cmake", "..", }, .cwd = path.build, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "make", }, .cwd = path.build, .wait = wait_20_secs, });

  try update_sources (builder, path);
  try update_generated (builder, path);

  try std.fs.deleteTreeAbsolute (path.tmp);

  var source_dir = try std.fs.openDirAbsolute (path.source, .{ .iterate = true, });
  defer source_dir.close ();

  var walker = try source_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (std.fs.path.dirname (entry.path)) |dirname|
        {
          if (!std.mem.eql (u8, "opt", dirname) and
            !std.mem.eql (u8, "val", dirname) and !std.mem.eql (u8, "util", dirname))
              try std.fs.deleteFileAbsolute (try std.fs.path.join (builder.allocator, &.{ path.source, entry.path, }));
        }
      },
      else => {},
    }
  }

  var flag = true;

  while (flag)
  {
    flag = false;
    walker = try source_dir.walk (builder.allocator);
    defer walker.deinit ();

    while (try walker.next ()) |entry|
    {
      const entry_path = try std.fs.path.join (builder.allocator, &.{ path.source, entry.path, });
      switch (entry.kind)
      {
        .file => {
          if (std.mem.endsWith (u8, entry.basename, ".txt"))
          {
            try std.fs.deleteFileAbsolute (entry_path);
            flag = true;
          }
        },
        .directory => {
          std.fs.deleteDirAbsolute (entry_path) catch |err|
          {
            if (err == error.DirNotEmpty) continue else return err;
          };
          flag = true;
        },
        else => {},
      }
    }
  }
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  var path: Paths = .{};
  path.tmp = try builder.build_root.join (builder.allocator, &.{ "tmp", });
  path.include = try builder.build_root.join (builder.allocator, &.{ "include", });
  path.source = try builder.build_root.join (builder.allocator, &.{ "source", });
  path.build = try std.fs.path.join (builder.allocator, &.{ path.tmp, "build", });

  if (builder.option (bool, "update", "Update binding") orelse false) try update (builder, &path);

  const lib = builder.addStaticLibrary (.{
    .name = "spirv",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  var sources = try std.BoundedArray ([] const u8, 256).init (0);

  for ([_] std.Build.LazyPath {
      .{ .path = ".", },
      .{ .path = "include", },
      .{ .path = "include-generated", },
      .{ .path = try std.fs.path.join (builder.allocator, &.{ "include", "spirv", "unified1", }), },
    }) |include|
  {
    std.debug.print ("[spirv include] {s}\n", .{ include.getPath (builder), });
    lib.addIncludePath (include);
  }

  const spirv_tools_include_path = try std.fs.path.join (builder.allocator, &.{ "include", "spirv-tools", });
  lib.installHeadersDirectory (.{ .path = spirv_tools_include_path, }, "spirv-tools", .{ .include_extensions = &.{ ".h", ".hpp", ".hpp11", }, });
  std.debug.print ("[spirv headers dir] {s}\n", .{ spirv_tools_include_path, });
  const spirv_headers_include_path = try std.fs.path.join (builder.allocator, &.{ "include", "spirv", });
  lib.installHeadersDirectory (.{ .path = spirv_headers_include_path, }, "spirv", .{ .include_extensions = &.{ ".h", ".hpp", ".hpp11", }, });
  std.debug.print ("[spirv headers dir] {s}\n", .{ spirv_headers_include_path, });

  lib.linkLibCpp ();

  var source_dir = try std.fs.openDirAbsolute (path.source, .{ .iterate = true, });
  defer source_dir.close ();

  var walker = try source_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (toolbox.is_cpp_source_file (entry.basename))
        {
          try sources.append (try std.fs.path.join (builder.allocator, &.{ "source", builder.dupe (entry.path), }));
          std.debug.print ("[spirv source] {s}\n", .{ try std.fs.path.join (builder.allocator, &.{ path.source, entry.path, }), });
        }
      },
      else => {},
    }
  }

  lib.addCSourceFiles (.{ .files = sources.slice (), });

  builder.installArtifact (lib);
}
