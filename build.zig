const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const mmutil_dep = b.dependency("mmutil_zig", .{});
    const ziggba_dep = b.dependency("ziggba", .{});
    const maxmod_dep = b.dependency("maxmod_zig", .{});
    const gba_mod = ziggba_dep.module("gba");
    const maxmod_mod = maxmod_dep.module("maxmod");

    const exe = ziggba.addGBAExecutable(
        b,
        gba_mod,
        "gbadapp",
        "src/main.zig",
    );

    const create_soundbank = b.addRunArtifact(mmutil_dep.artifact("mmutil-zig"));
    create_soundbank.addArgs(&.{
        "bad_apple.xm",
        "-osrc/assets/soundbank.bin",
    });

    exe.root_module.addImport("maxmod", maxmod_mod);

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addFileArg(b.path("zig-out/bin/gbadapp.gba"));
    const run_step = b.step("run", "Runs the simple version in mGBA");

    mgba.step.dependOn(b.getInstallStep());

    run_step.dependOn(&create_soundbank.step);
    run_step.dependOn(&exe.step);
    run_step.dependOn(b.default_step);
    run_step.dependOn(&mgba.step);
}
