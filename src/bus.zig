const cpu = @import("cpu.zig");
const ram = @import("ram.zig");
pub const BusError = error{InvalidMemoryRead};

// The bus holds the whole system. It is nothing more than a series of components connected.
pub const Bus = struct {

    // Devices on the bus.
    cpu: cpu.Cpu,
    ram: ram.Ram,

    // Create the bus and initialize all the components on it.
    pub fn make() Bus {
        return Bus{ .cpu = cpu.Cpu.make(), .ram = ram.Ram.make() };
    }

    // Write data to the address.
    pub fn write(this: *Bus, addr: u16, data: u8) void {
        if (addr >= 0x0000 and addr <= 0xFFFF) {
            this.ram.mem[addr] = data;
        }
    }

    // Read data at address.
    pub fn read(this: *Bus, addr: u16) BusError!u8 {
        if (addr >= 0x0000 and addr <= 0xFFFF) {
            return this.ram.mem[addr];
        }
    }
};
