const std = @import ("std");
const toolbox = @import ("toolbox");

const Paths = struct
{
  tmp: [] const u8 = undefined,
  spirv: [] const u8 = undefined,
  spirv_tools: [] const u8 = undefined,
  spirv_tools_in: [] const u8 = undefined,
  source: [] const u8 = undefined,
  build: [] const u8 = undefined,
};

fn update_headers (builder: *std.Build, path: *const Paths,
  dependencies: *const toolbox.Dependencies) !void
{
  try dependencies.clone (builder, "spirv", path.tmp);

  const tmp_include_path =
    try std.fs.path.join (builder.allocator, &.{ path.tmp, "include", });
  var tmp_include_dir =
    try std.fs.openDirAbsolute (tmp_include_path, .{ .iterate = true, });
  defer tmp_include_dir.close ();

  var walker = try tmp_include_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |*entry|
  {
    const dest =
      try builder.build_root.join (builder.allocator, &.{ entry.path, });
    switch (entry.kind)
    {
      .file => {
        if (toolbox.isHeader (entry.basename)) try toolbox.copy (
          try std.fs.path.join (builder.allocator,
            &.{ tmp_include_path, entry.path, }), dest);
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
  var src_dir: std.fs.Dir = undefined;
  var walker: std.fs.Dir.Walker = undefined;

  for ([_] struct { src: [] const u8, dest: [] const u8, } {
    .{ .src = try std.fs.path.join (builder.allocator,
      &.{ "include", "spirv-tools", }), .dest = "spirv-tools" },
    .{ .src = "source", .dest = "source", },
  }) |dir_name| {
    src_path =
      try std.fs.path.join (builder.allocator, &.{ path.tmp, dir_name.src, });
    dest_path = try std.fs.path.join (builder.allocator,
      &.{ path.spirv_tools, dir_name.dest, });

    try toolbox.make (dest_path);

    src_dir = try std.fs.openDirAbsolute (src_path, .{ .iterate = true, });
    defer src_dir.close ();

    walker = try src_dir.walk (builder.allocator);
    defer walker.deinit ();

    while (try walker.next ()) |*entry|
    {
      const dest = try std.fs.path.join (builder.allocator,
        &.{ dest_path, entry.path, });
      switch (entry.kind)
      {
        .file => try toolbox.copy (try std.fs.path.join (builder.allocator,
          &.{ src_path, entry.path, }), dest),
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
  var build_dir =
    try std.fs.openDirAbsolute (path.build, .{ .iterate = true, });
  defer build_dir.close ();

  var it = build_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (std.mem.endsWith (u8, entry.name, ".inc"))
        {
          try toolbox.copy (try std.fs.path.join (builder.allocator,
            &.{ path.build, entry.name, }),
              try std.fs.path.join (builder.allocator,
            &.{ path.spirv_tools_in, entry.name, }));
        }
      },
      else => {},
    }
  }
}

fn update (builder: *std.Build, path: *const Paths,
  dependencies: *const toolbox.Dependencies) !void
{
  std.fs.deleteTreeAbsolute (path.tmp) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  for ([_][] const u8 { path.spirv, path.spirv_tools, }) |dest_path|
  {
    try std.fs.deleteTreeAbsolute (dest_path);
    try toolbox.make (dest_path);
  }

  try update_headers (builder, path, dependencies);

  try dependencies.clone (builder, "spirv-tools", path.tmp);
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3",
    try std.fs.path.join (builder.allocator,
      &.{ "utils", "git-sync-deps", }), }, .cwd = path.tmp, });

  try toolbox.make (path.build);

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "cmake", "..", },
    .cwd = path.build, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "make", },
    .cwd = path.build, .wait = wait_20_secs, });

  try update_sources (builder, path);
  try update_generated (builder, path);

  try std.fs.deleteTreeAbsolute (path.tmp);

  var source_dir =
    try std.fs.openDirAbsolute (path.source, .{ .iterate = true, });
  defer source_dir.close ();

  var walker = try source_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |*entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (std.fs.path.dirname (entry.path)) |dirname|
        {
          if (!std.mem.eql (u8, "opt", dirname) and
            !std.mem.eql (u8, "val", dirname) and
            !std.mem.eql (u8, "util", dirname))
              try std.fs.deleteFileAbsolute (try std.fs.path.join (
                builder.allocator, &.{ path.source, entry.path, }));
        }
      },
      else => {},
    }
  }

  try toolbox.clean (builder, &.{ "spirv", "spirv-tools", }, &.{ ".inc", });
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  var path: Paths = .{};
  path.tmp = try builder.build_root.join (builder.allocator, &.{ "tmp", });
  path.spirv = try builder.build_root.join (builder.allocator, &.{ "spirv", });
  path.spirv_tools =
    try builder.build_root.join (builder.allocator, &.{ "spirv-tools", });
  path.spirv_tools_in = try std.fs.path.join (builder.allocator,
    &.{ path.spirv_tools, "spirv-tools", });
  path.source = try std.fs.path.join (builder.allocator,
    &.{ path.spirv_tools, "source", });
  path.build =
    try std.fs.path.join (builder.allocator, &.{ path.tmp, "build", });

  const dependencies = try toolbox.Dependencies.init (builder, "spirv.zig",
  .{
     .toolbox = .{
       .name = "tiawl/toolbox",
       .api = toolbox.Repository.API.github,
     },
   }, .{
     .spirv = .{
       .name = "KhronosGroup/SPIRV-Headers",
       .api = toolbox.Repository.API.github,
     },
     .@"spirv-tools" = .{
       .name = "KhronosGroup/SPIRV-Tools",
       .api = toolbox.Repository.API.github,
     },
   });

  if (builder.option (bool, "update", "Update binding") orelse false)
    try update (builder, &path, &dependencies);

  const lib = builder.addStaticLibrary (.{
    .name = "spirv",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  for ([_][] const u8 {
    ".", "spirv", "spirv-tools",
    try std.fs.path.join (builder.allocator,
      &.{ "spirv-tools", "spirv-tools", }),
    try std.fs.path.join (builder.allocator, &.{ "spirv", "unified1", }),
  }) |include| toolbox.addInclude (lib, include);

  toolbox.addHeader (lib, path.spirv, "spirv",
    &.{ ".h", ".hpp", ".hpp11", });
  toolbox.addHeader (lib, path.spirv_tools_in, "spirv-tools",
    &.{ ".h", ".hpp", ".hpp11", });

  lib.linkLibCpp ();

  var source_dir =
    try std.fs.openDirAbsolute (path.source, .{ .iterate = true, });
  defer source_dir.close ();

  var walker = try source_dir.walk (builder.allocator);
  defer walker.deinit ();

  while (try walker.next ()) |*entry|
  {
    switch (entry.kind)
    {
      .file => {
        if (toolbox.isCppSource (entry.basename))
          try toolbox.addSource (lib, path.source, entry.path, &.{});
      },
      else => {},
    }
  }

  builder.installArtifact (lib);
}
