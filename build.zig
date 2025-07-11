const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const ziggba_dep = b.dependency("ziggba", .{});
    const gba_mod = ziggba_dep.module("gba");

    _ = ziggba.addGBAExecutable(b, gba_mod, "tonc_tutor", "src/main.zig");

    const mode4flip = ziggba.addGBAExecutable(b, gba_mod, "mode4flip", "examples/mode4flip/main.zig");
    ziggba.convertMode4Images(mode4flip, &[_]ziggba.ImageSourceTarget{
        .{
            .source = "examples/mode4flip/front.bmp",
            .target = "examples/mode4flip/front.agi",
        },
        .{
            .source = "examples/mode4flip/back.bmp",
            .target = "examples/mode4flip/back.agi",
        },
    }, "examples/mode4flip/mode4flip.agp");

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    // mgba.addFileArg(first_exe.getEmittedBin());

    const run_step = b.step("run", "Runs the program in mGBA");
    if (b.args) |args| {
        mgba.addArgs(args);
    }
    // run_step.dependOn(&first_exe.step);
    run_step.dependOn(&mgba.step);
}
