pub const std = @import("std");
pub const CpuError = error{ Unknown, InvalidRead, InvalidWrite };
pub const bus = @import("bus.zig");
pub const ram = @import("ram.zig");

const PC_START = 0;

const CPU_F = enum(u8) {
    C = (1 << 0),
    Z = (1 << 1),
    I = (1 << 2),
    D = (1 << 3),
    V = (1 << 4),
    N = (1 << 5),
    B = (1 << 6),
    U = (1 << 7),
};

// 6502 emulation.
pub const Cpu = struct {
    PC: u32,
    bus: ?*bus.Bus,

    pub fn make() Cpu {
        return Cpu{ .PC = PC_START, .bus = null };
    }

    pub fn connectBus(this: *Cpu, _bus: ?*bus.Bus) CpuError!void {
        if (_bus) |b| {
            this.bus = b;
        } else {
            return CpuError.Unknown;
        }
    }

    // Write data to the address.
    pub fn write(this: *Cpu, addr: u16, data: u8) CpuError!void {
        if (this.bus) |b| {
            return b.write(addr, data);
        } else {
            return CpuError.InvalidWrite;
        }
    }

    // Read data at address.
    pub fn read(this: *Cpu, addr: u16) CpuError!u8 {
        if (this.bus) |b| {
            return b.read(addr);
        } else {
            return CpuError.InvalidRead;
        }
    }
};

test "CPU can read, but hub not connected." {
    var _bus = bus.Bus{ .cpu = Cpu.make(), .ram = ram.Ram.make() };
    try std.testing.expectError(CpuError.InvalidRead, _bus.cpu.read(0xFFFF));
}

test "CPU can write, but hub not connected." {
    var _bus = bus.Bus{ .cpu = Cpu.make(), .ram = ram.Ram.make() };
    try std.testing.expectError(CpuError.InvalidWrite, _bus.cpu.write(0xFFFF, 0xab));
}
