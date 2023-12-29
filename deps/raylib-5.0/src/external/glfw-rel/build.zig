const builtin = @import("std");

pub fn build(b: *std.Build) void {
    //glfw.build(b);
}

pub fn addGLFW(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, options: Options) *std.Build.CompileStep {
    const glfw_flags = &[_][]const u8{
        "-std=gnu99",
        "-D_GNU_SOURCE",
        "-DGL_SILENCE_DEPRECATION=199309l",
    };
    const glfw = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });
    glfw.linkLibC();
}
