pub const std = @import("std");
pub const CpuError = error{Unknown};
pub const Bus = @import("bus.zig");

const PC_START = 0;

// 6502 emulation.
pub const Cpu = struct {
    PC: u32,
    bus: ?*Bus.Bus,

    pub fn make() Cpu {
        return Cpu{ .PC = PC_START, .bus = null };
    }

    pub fn connectBus(this: *Cpu, bus: ?*Bus.Bus) CpuError!void {
        if (bus) |b| {
            this.bus = b;
        } else {
            return CpuError.Unknown;
        }
    }
};
