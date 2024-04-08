const std = @import ("std");
const toolbox = @import ("toolbox");
const pkg = .{ .name = "spirvtools.zig", .version = "1.3.275", };

const Paths = struct
{
  tmp: [] const u8 = undefined,
  build: [] const u8 = undefined,
};

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

    try std.fs.deleteTreeAbsolute (dest_path);
    try toolbox.make (dest_path);

    dir = try std.fs.openDirAbsolute (src_path, .{ .iterate = true, });
    defer dir.close ();

    walker = try dir.walk (builder.allocator);
    defer walker.deinit();

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
  defer walker.deinit();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .file => if (std.mem.endsWith (u8, entry.basename, ".inc"))
               {
                 try toolbox.copy (
                   try std.fs.path.join (builder.allocator, &.{ path.build, entry.path, }),
                   try std.fs.path.join (builder.allocator, &.{ generated_path, entry.path, }));
               },
      else => {},
    }
  }
}

fn update (builder: *std.Build) !void
{
  var path: Paths = .{};
  path.tmp = try builder.build_root.join (builder.allocator, &.{ "tmp", });
  path.build = try std.fs.path.join (builder.allocator, &.{ path.tmp, "build", });

  std.fs.deleteTreeAbsolute (path.tmp) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone", "https://github.com/KhronosGroup/SPIRV-Tools.git", path.tmp, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "-C", path.tmp, "checkout", "vulkan-sdk-" ++ pkg.version ++ ".0", }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3",
    try std.fs.path.join (builder.allocator, &.{ "utils", "git-sync-deps", }), }, .cwd = path.tmp, });

  try toolbox.make (path.build);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "cmake", "..", }, .cwd = path.build, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "make", }, .cwd = path.build, .wait = wait_20_secs, });

  try update_sources (builder, &path);
  try update_generated (builder, &path);

  try std.fs.deleteTreeAbsolute (path.tmp);
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  if (builder.option (bool, "update", "Update binding") orelse false) try update (builder);

  const spirv_headers = builder.dependency ("spirv_headers", .{});

  const lib = builder.addStaticLibrary (.{
    .name = "spirv_tools",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  var sources = try std.BoundedArray ([] const u8, 256).init (0);

  for ([_] std.Build.LazyPath {
      .{ .path = ".", },
      .{ .path = "include", },
      .{ .path = "include-generated", },
      spirv_headers.path ("include"),
      spirv_headers.path (try std.fs.path.join (builder.allocator, &.{ "include", "spirv", "unified1", })),
    }) |include|
  {
    std.debug.print ("[spirv-tools include] {s}\n", .{ include.getPath (builder), });
    lib.addIncludePath (include);
  }

  lib.installHeadersDirectory (try std.fs.path.join (builder.allocator, &.{ "include", "spirv-tools", }), "spirv-tool");
  std.debug.print ("[spirv-tools headers dir] {s}\n", .{ try builder.build_root.join (builder.allocator, &.{ "spirv-tools", }), });

  lib.linkLibCpp ();

  const source_path = try builder.build_root.join (builder.allocator, &.{ "source", });

  var source_dir = try std.fs.openDirAbsolute (source_path, .{ .iterate = true, });
  defer source_dir.close ();

  var walker = try source_dir.walk (builder.allocator);
  defer walker.deinit();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .file => {
                 const file = try std.fs.path.join (builder.allocator, &.{ source_path, entry.path, });
                 if (std.mem.endsWith (u8, entry.basename, ".cpp"))
                 {
                   if (std.fs.path.dirname (entry.path) == null or
                     std.mem.eql (u8, "opt", std.fs.path.dirname (entry.path) orelse "") or
                     std.mem.eql (u8, "val", std.fs.path.dirname (entry.path) orelse "") or
                     std.mem.eql (u8, "util", std.fs.path.dirname (entry.path) orelse ""))
                   {
                     try sources.append (file);
                     std.debug.print ("[spirv-tools source] {s}\n", .{ file, });
                   } else try std.fs.deleteFileAbsolute (file);
                 }
               },
      else => {},
    }
  }

  walker = try source_dir.walk (builder.allocator);
  defer walker.deinit();

  while (try walker.next ()) |entry|
  {
    switch (entry.kind)
    {
      .directory => std.fs.deleteDirAbsolute (try std.fs.path.join (builder.allocator, &.{ source_path, entry.path, })) catch |err|
                    {
                      if (err != error.DirNotEmpty) return err;
                    },
      else => {},
    }
  }

  lib.addCSourceFiles (.{ .files = sources.slice (), });

  builder.installArtifact (lib);
}
