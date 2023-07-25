pub const std = @import("std");
pub const CpuError = error{ Unknown, InvalidRead, InvalidWrite };
pub const bus = @import("bus.zig");
pub const ram = @import("ram.zig");

const PC_START = 0;

fn shiftRight(n: u8) u8 {
    return (1 << n);
}

// CPU Flags
const CPU_F = enum(u8) {
    C = shiftRight(0), // Carry flag.
    Z = shiftRight(1), // Zero flag.
    I = shiftRight(2), // Interrupt Disable flag.
    D = shiftRight(3), // Decimal flag. (Unused)
    V = shiftRight(4), // Overflow flag.
    N = shiftRight(5), // Negative flag.
    B = shiftRight(6), // Bit branches.
    U = shiftRight(7), // Unused/Unknown flag.
};

// 6502 chip.
pub const Cpu = struct {
    a: u8 = 0, // Accumulator register
    y: u8 = 0, // Index register Y
    x: u8 = 0, // Index register X

    pc: u16 = PC_START, // Program counter
    sp: u8 = 0, // Stack pointer

    status: u8 = 0, // Processor Status

    bus: ?*bus.Bus = null, // The bus the cpu is connected to

    pub fn make() Cpu {
        return Cpu{};
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
