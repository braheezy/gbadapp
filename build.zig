const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    const ziggba_dep = b.dependency("ziggba", .{});
    const gba_mod = ziggba_dep.module("gba");

    _ = ziggba.addGBAExecutable(
        b,
        gba_mod,
        "gbadapp",
        "src/main.zig",
    );

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addFileArg(b.path("zig-out/bin/gbadapp.gba"));
    const run_step = b.step("run", "Runs the program in mGBA");
    if (b.args) |args| {
        mgba.addArgs(args);
    }
    run_step.dependOn(&mgba.step);
    mgba.step.dependOn(b.getInstallStep());
}
