const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const mmutil_dep = b.dependency("mmutil_zig", .{});
    const maxmod_dep = b.dependency("maxmod_zig", .{});
    const maxmod_mod = maxmod_dep.module("maxmod");

    const gbb = ziggba.GbaBuild.create(b);
    const exe = gbb.addExecutable(.{
        .name = "gbadapp",
        .root_source_file = b.path("src/main.zig"),
    });

    const create_soundbank = b.addRunArtifact(mmutil_dep.artifact("mmutil-zig"));
    create_soundbank.addArgs(&.{
        "bad_apple.xm",
        "-osrc/assets/soundbank.bin",
    });

    exe.step.root_module.addImport("maxmod", maxmod_mod);
    // Use the same gba module that addExecutable uses internally
    maxmod_mod.addImport("gba", exe.gba_module);
    exe.step.step.dependOn(&create_soundbank.step);

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addFileArg(b.path("zig-out/bin/gbadapp.gba"));
    const run_step = b.step("run", "Runs the simple version in mGBA");

    mgba.step.dependOn(b.getInstallStep());

    run_step.dependOn(&exe.step.step);
    run_step.dependOn(&mgba.step);
}
