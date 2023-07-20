const bus = @import("bus.zig");

pub fn main() !void {
    var system = bus.Bus.make();
    system.ram.dump(5, 10);
}
