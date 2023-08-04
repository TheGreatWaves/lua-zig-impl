const bus = @import("bus.zig");
const cpu = @import("cpu.zig");

pub fn main() !void {
    var system = bus.Bus.make() catch unreachable;
    system.ram.dump(5, 10);
    system.write(0x00FF, 0xfe);
    system.ram.dump(0x00F0, 0x0100);
}
