pub const std = @import("std");
pub const CpuError = error{ Unknown, InvalidRead, InvalidWrite };
pub const bus = @import("bus.zig");
pub const ram = @import("ram.zig");
pub const instr = @import("instr.zig");

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

// 6502 class.
pub const Cpu = struct {

    // Core registers
    a: u8 = 0, // Accumulator register
    x: u8 = 0, // Index register X
    y: u8 = 0, // Index register Y
    sp: u8 = 0, // Stack pointer
    pc: u16 = PC_START, // Program counter
    status: u8 = 0, // Status register

    cycles: u8 = 0, // The number of cycles the current instruction requires until completion
    fetched: u8 = 0, // The fetched operand

    addr_abs: u16 = 0x0, // Address to fetch data from
    addr_rel: u16 = 0x0, // Relative address to jump to (branch)
    opcode: u8 = 0, // The opcode of the current instruction

    bus: ?*bus.Bus = null, // Communication bus

    pub fn make() Cpu {
        return Cpu{};
    }

    // The data to be fetched can only be retrieved from two sources. It can either come from
    // some memory address, or it can be retrieved directly from the instruction itself.
    pub fn fetch(this: *Cpu) void {
        // TODO! Check the current instruction's addressing mode. If it isn't `implied` then we have to read.
        // Otherwise we can just return what has already been fetched, which should've been handled by the
        // `implied_address_mode` function.
        _ = this;
    }

    pub fn connectBus(this: *Cpu, _bus: ?*bus.Bus) CpuError!void {
        if (_bus != null) {
            this.bus = _bus;
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

    // Read data at address. (byte)
    pub fn read(this: *Cpu, addr: u16) CpuError!u8 {
        if (this.bus != null) {
            return this.bus.?.read(addr);
        } else {
            return CpuError.InvalidRead;
        }
    }

    pub fn clock(this: *Cpu) void {
        if (this.cycles == 0) {
            this.opcode = this.read(this.pc);
            this.pc += 1;

            // Now reset the number of cycles to the number required by the instruction.
            this.cycles = LOOK_UP[this.opcode].cycles;

            var additional_cycles_1 = LOOK_UP[this.opcode].operation(this);
            var additional_cycles_2 = LOOK_UP[this.opcode].addr_mode(this);

            this.cycles += (additional_cycles_1 & additional_cycles_2);
        }

        this.cycles -= 1;
    }

    //////////////////////////////////////////////////////////////////////////////
    // Addressing Modes
    //
    // Note & Remarks:
    // The 16-bit address space available to the 6502 is thought to be 256 `pages`
    // of 256 memory locations. The high order byte tells us the page number and
    // the low order byte tells us the location inside the specified page.

    // Address Mode - Implied
    // There is no additional data required. The accumulator needs to be fetched
    // in order to account for instructions which will implicitly require it.
    pub fn implied(this: *Cpu) u8 {
        this.fetched = this.a;
        return 0;
    }

    // Address Mode - Immediate
    // The required data is taken from the byte following the opcode.
    pub fn immediate(this: *Cpu) u8 {
        this.addr_abs = this.pc;
        this.pc += 1;
        return 0;
    }

    // Address Mode - Absolute
    // The address we want to locate the data from can be constructed by
    // combining the second and third byte of the instruction. The second
    // byte of the instruction specifies the 8 low order bits, the third
    // byte specifies the 8 high order bits.
    pub fn absolute(this: *Cpu) u8 {
        _ = this.bus.?.read(0x0000);
        var lo: u16 = this.read(this.pc) catch unreachable;
        var hi: u16 = this.read(this.pc + 1) catch unreachable;
        this.pc += 2;
        this.addr_abs = (hi << 8) | lo;
        return 0;
    }

    // Address Mode - Zero page X
    // Similar to absolute address mode, the only difference is that this
    // requires the register content of X to be added as an offset.
    pub fn absolute_x(this: *Cpu) u8 {
        var lo = this.read(this.pc);
        var hi = this.read(this.pc + 1);
        this.pc += 2;
        var x_offset = this.x;
        this.addr_abs = ((hi << 8) | lo) + x_offset;

        // Stepped out of page.
        // Crossing the page boundary means that the high order byte
        // needs to be incremented and this takes an additional cycle.
        if ((this.addr_abs & 0xFF00) != (hi << 8)) {
            return 1;
        }
        return 0;
    }

    // Address Mode - Zero page Y
    // Similar to absolute address mode, the only difference is that this
    // requires the register content of y to be added as an offset.
    pub fn absolute_y(this: *Cpu) u8 {
        var lo = this.read(this.pc);
        var hi = this.read(this.pc + 1);
        this.pc += 2;
        var y_offset = this.y;
        this.addr_abs = ((hi << 8) | lo) + y_offset;

        // Stepped out of page.
        // Crossing the page boundary means that the high order byte
        // needs to be incremented and this takes an additional cycle.
        if ((this.addr_abs & 0xFF00) != (hi << 8)) {
            return 1;
        }
        return 0;
    }

    // Address Mode - Accumulator
    pub fn accumulator(this: *Cpu) u8 {
        this.fetch = this.a;
        return 0;
    }

    // Address Mode - Zero page
    // This assumes that the high-byte is 0, we only need to read the second
    // byte and grab the low 8 order bits. This is very similar to the absolute
    // address mode, but since it only requires one less byte to fetch this
    // takes one cycle less to execute.
    pub fn zero_page(this: *Cpu) u8 {
        this.addr_rel = read(this.pc) & 0x00FF;
        this.pc += 1;
        return 0;
    }

    // Address Mode - Zero page X
    // This is basically equivalent to the zero page address mode. The only
    // difference is that we add the content of register X as an offset.
    // Since this is zero page, the high order byte will always be 0, even
    // if we were to increment, we would simply wrap around. This means that
    // we will never have to worry about crossing any page boundary.
    pub fn zero_page_x(this: *Cpu) u8 {
        this.addr_rel = (read(this.pc) + this.x) & 0x00FF;
        this.pc += 1;
        return 0;
    }

    // Address Mode - Zero page Y
    // Equivalent to zero page X, but uses Y register instead. Notably, this
    // is less used than the X alternative.
    pub fn zero_page_y(this: *Cpu) u8 {
        this.addr_rel = (read(this.pc) + this.y) & 0x00FF;
        this.pc += 1;
        return 0;
    }

    // Address Mode - Indirect Addressing
    // Uses the content of the address as the effective address.
    pub fn indirect(this: *Cpu) u8 {

        // First we have to construct the address we want to read from.
        var content_lo_addr = this.read(this.pc);
        var content_hi_addr = this.read(this.pc + 1);
        this.pc += 2;

        var content_addr = (content_hi_addr << 8) | content_lo_addr;

        // Read the first and second byte.
        var effective_lo = this.read(content_addr);
        var effective_hi = this.read(content_addr + 1);

        this.addr_abs = (effective_hi << 8) | effective_lo;

        return 0;
    }

    // Address Mode - Indirect X
    // We read from page 0x00, we get the low bits from the
    // second byte and apply the X offset.
    pub fn indirect_x(this: *Cpu) u8 {
        var content_addr = this.read(this.pc) + this.x;
        this.pc += 1;

        // Read the first and second byte.
        var effective_lo = this.read((content_addr) & 0x00FF);
        var effective_hi = this.read((content_addr + 1) & 0x00FF);

        this.addr_abs = (effective_hi << 8) | effective_lo;

        return 0;
    }

    // Address Mode - Indirect Y
    // First, read from page 0x00, the low order bits are supplied by the second byte.
    // Then we form an address from the two bytes read, then apply a Y offset.
    // The content of the byte at the result is what we return.
    pub fn indirect_y(this: *Cpu) u8 {
        var t = this.read(this.pc);
        this.pc += 1;

        var effective_lo = this.read(t & 0xFF);
        var effective_hi = this.read((t + 1) & 0xFF);
        this.addr_abs = ((effective_hi << 8) | effective_lo) + this.y;

        // Stepped out of page.
        // Crossing the page boundary means that the high order byte
        // needs to be incremented and this takes an additional cycle.
        if ((this.addr_abs & 0xFF00) != (effective_hi << 8)) {
            return 1;
        }

        return 0;
    }

    // Address Mode - Relative
    // This address mode is exclusive to branch instructions.
    // The range of our offset is between [-128, ..., +127].
    pub fn relative(this: *Cpu) u8 {
        this.addr_rel = this.read(this.pc);
        this.pc += 1;

        // Sign extension
        if (this.addr_rel & 0x80) {
            this.addr_rel |= 0xFF00;
        }

        return 0;
    }

    //////////////////////////////////////////////////////////////////////////////
    // Instuctions

    fn ADC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn AND(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn ANS(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BCC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BCS(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn BEQ(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BIT(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BMI(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BNE(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BPL(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn BRK(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn BVC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn BVS(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CLC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CLD(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn CLI(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CLV(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CMP(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CPX(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn CPY(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn DEC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn DEX(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn DEY(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn EOR(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn INC(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn INX(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn INY(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn JMP(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn JSR(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
    fn LDA(this: *Cpu) u8 {
        _ = this;
        return 0;
    }

    fn NOP(this: *Cpu) u8 {
        _ = this;
        return 0;
    }
};

const LOOK_UP = [_]instr.Instruction{
    instr.Instruction{ .name = "BRK", .operation = Cpu.BRK, .cycles = 7 },
};

test "CPU can read, but hub not connected." {
    var _bus = bus.Bus{ .cpu = Cpu.make(), .ram = ram.Ram.make() };
    try std.testing.expectError(CpuError.InvalidRead, _bus.cpu.read(0xFFFF));
}

test "CPU can write, but hub not connected." {
    var _bus = bus.Bus{ .cpu = Cpu.make(), .ram = ram.Ram.make() };
    try std.testing.expectError(CpuError.InvalidWrite, _bus.cpu.write(0xFFFF, 0xab));
}

test "CPU: Addresing mode - Immediate" {
    var _bus = bus.Bus.make() catch unreachable;
    _ = Cpu.immediate(&_bus.cpu);
    try std.testing.expect(_bus.cpu.addr_abs == 0);
    _ = Cpu.immediate(&_bus.cpu);
    try std.testing.expect(_bus.cpu.addr_abs == 1);
    _bus.cpu.pc = 0xfe;
    _ = Cpu.immediate(&_bus.cpu);
    try std.testing.expect(_bus.cpu.addr_abs == 0xfe);
}

test "CPU: Addresing mode - Absolute" {
    var _bus = bus.Bus.make() catch unreachable;
    _bus.connect_components();

    // Write the address in.
    _bus.write(0x0000, 0x10);
    _bus.write(0x0001, 0x30);

    // Write the data at the address in.
    _bus.write(0x3010, 34);

    _ = _bus.cpu.absolute();
    try std.testing.expect(_bus.read(_bus.cpu.addr_abs) == 34);
}
