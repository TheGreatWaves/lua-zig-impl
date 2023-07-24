pub const RamError = error{Unknown};
const std = @import("std");

pub const Ram = struct {
    // 64 kb memory
    mem: [1024 * 64]u8,

    pub fn make() Ram {
        return Ram{ .mem = undefined };
    }

    // Dump the memory components from start to end.
    pub fn dump(this: *Ram, start: u16, end: u16) void {
        std.debug.print("======[DUMP]======\n", .{});
        for (this.mem, 0..) |data, position| {
            if (position >= end) break;
            if (position >= start) {
                std.debug.print("0x{x:0>4}| 0x{x:0>2}\n", .{ position, data });
            }
        }
        std.debug.print("\n", .{});
    }
};
