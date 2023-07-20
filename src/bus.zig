const cpu = @import("cpu.zig");
const ram = @import("ram.zig");
pub const BusError = error{InvalidMemoryRead};

// The bus represents the whole
pub const Bus = struct {
    // Devices on the bus
    cpu: cpu.Cpu,
    ram: ram.Ram,

    pub fn make() Bus {
        return Bus{ .cpu = cpu.Cpu{}, .ram = ram.Ram.make() };
    }

    pub fn write(this: *Bus, addr: u16, data: u8) void {
        this.ram[addr] = data;
    }
    pub fn read(this: *Bus, addr: u16) BusError!u8 {
        return this.ram[addr];
    }
};
