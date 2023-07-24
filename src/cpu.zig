pub const CpuError = error{Unknown};

const PC_START = 0;

// 6502 emulation.
pub const Cpu = struct {
    PC: u32,

    pub fn make() Cpu {
        return Cpu{
            .PC = PC_START,
        };
    }
};
