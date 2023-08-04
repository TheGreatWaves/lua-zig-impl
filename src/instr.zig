const std = @import("std");
const cpu = @import("cpu.zig");

pub const Instruction = struct {
    name: *const [3:0]u8,
    operation: *const fn (cpu: *cpu.Cpu) u8,
    cycles: u8,
};
