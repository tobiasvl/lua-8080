local bit = bit or require "bit32"
local path = (...):match("(.-)[^%.]+$")
local opcodes = require(path .. ".opcodes")

local instructions = {}

function instructions:init(cpu, bus)
    self.cpu = cpu
    self.bus = bus
    self.opcodes = opcodes
end

function instructions.get_parity(number)
    local count = 0
    for i = 0, 7 do
        count = count + bit.band(bit.rshift(number, i), 1)
    end
    return count % 2 == 0
end

function instructions:get_8bit_immediate()
    local value = self.bus[self.cpu.registers.pc]
    self.cpu.registers.pc = self.cpu.registers.pc + 1
    return value
end

function instructions:get_16bit_immediate()
    local value = bit.bor(bit.lshift(self.bus[self.cpu.registers.pc + 1], 8), self.bus[self.cpu.registers.pc])
    self.cpu.registers.pc = self.cpu.registers.pc + 2
    return value
end

function instructions.NOP()
    return 4
end

function instructions:MOV(op1, op2)
    local value, cycles

    if op2 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op2]
    end

    if op1 == "m" then
        self.bus[self.cpu.registers.hl] = value
        cycles = 7
    else
        self.cpu.registers[op1] = value
    end

    return cycles or 5
end

function instructions:MVI(op1)
    local cycles
    local value = self:get_8bit_immediate()

    if op1 == "m" then
        self.bus[self.cpu.registers.hl] = value
        cycles = 10
    else
        self.cpu.registers[op1] = value
    end

    return cycles or 7
end

function instructions:LXI(op1)
    local value = self:get_16bit_immediate()
    self.cpu.registers[op1] = value
    return 10
end

function instructions:LDA()
    local address = self:get_16bit_immediate()
    self.cpu.registers.a = self.bus[address]
    return 13
end

function instructions:STA()
    local address = self:get_16bit_immediate()
    self.bus[address] = self.cpu.registers.a
    return 13
end

function instructions:LHLD()
    local address = self:get_16bit_immediate()
    self.cpu.registers.h = self.bus[address + 1]
    self.cpu.registers.l = self.bus[address]
    return 16
end

function instructions:SHLD()
    local address = self:get_16bit_immediate()
    self.bus[address] = self.cpu.registers.l
    self.bus[address + 1] = self.cpu.registers.h
    return 16
end

function instructions:LDAX(op1)
    self.cpu.registers.a = self.bus[self.cpu.registers[op1]]
    return 7
end

function instructions:STAX(op1)
    self.bus[self.cpu.registers[op1]] = self.cpu.registers.a
    return 7
end

function instructions:XCHG()
    self.cpu.registers.de, self.cpu.registers.hl = self.cpu.registers.hl, self.cpu.registers.de
    return 4 -- 5 according to pastraiser, but seems to actually be 4 TODO
end

function instructions:ADD(op1)
    local cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    local result = self.cpu.registers.a + value

    self.cpu.registers.status.c = result > 0xFF
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(self.cpu.registers.a, 0x0F) + bit.band(value, 0x0F) > 0x0F

    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ADC(op1)
    local cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    local c = self.cpu.registers.status.c and 1 or 0
    local result = self.cpu.registers.a + value + c

    self.cpu.registers.status.c = result > 0xFF
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(self.cpu.registers.a, 0x0F) + bit.band(value, 0x0F) + c > 0x0F
    
    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ADI()
    local value = self:get_8bit_immediate()

    local result = self.cpu.registers.a + value

    self.cpu.registers.status.c = result > 0xFF
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(self.cpu.registers.a, 0x0F) + bit.band(value, 0x0F) > 0x0F

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:ACI()
    local value = self:get_8bit_immediate()

    local c = self.cpu.registers.status.c and 1 or 0
    local result = self.cpu.registers.a + value + c

    self.cpu.registers.status.c = result > 0xFF
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(self.cpu.registers.a, 0x0F) + bit.band(value, 0x0F) + c > 0x0F

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:_SUBTRACT(minuend, subtrahend)
    subtrahend = bit.band(bit.bnot(subtrahend) + 1, 0xFF)
    return self:_add(minuend, subtrahend)
end

function instructions:SUB(op1)
    local cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    local result = self.cpu.registers.a - value

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:SBB(op1)
    local cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    local c = self.cpu.registers.status.c and 1 or 0
    local result = self.cpu.registers.a - value - c

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F) - c, 0x100) ~= 0x100

    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:SUI(op1)
    local value = self:get_8bit_immediate()

    local result = self.cpu.registers.a - value

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:SBI()
    local value = self:get_8bit_immediate()

    local c = self.cpu.registers.status.c and 1 or 0
    local result = self.cpu.registers.a - value - c

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F) - c, 0x100) == 0x100

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:INR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        result = value + 1
        self.bus[self.cpu.registers.hl] = bit.band(result, 0xFF)
        cycles = 10
    else
        value = self.cpu.registers[op1]
        result = value + 1
        self.cpu.registers[op1] = bit.band(result, 0xFF)
    end

    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(value, 0x0F) + 1 > 0x0F

    return cycles or 5
end

function instructions:DCR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        result = value - 1
        self.bus[self.cpu.registers.hl] = bit.band(result, 0xFF)
        cycles = 10
    else
        value = self.cpu.registers[op1]
        result = value - 1
        self.cpu.registers[op1] = bit.band(result, 0xFF)
    end

    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(value, 0x0F) - 1, 0x100) ~= 0x100

    return cycles or 5
end

function instructions:INX(op1)
    self.cpu.registers[op1] = bit.band(self.cpu.registers[op1] + 1, 0xFFFF)
    return 5
end

function instructions:DCX(op1)
    self.cpu.registers[op1] = bit.band(self.cpu.registers[op1] - 1, 0xFFFF)
    return 5
end

function instructions:DAD(op1)
    local result = self.cpu.registers.hl + self.cpu.registers[op1]

    self.cpu.registers.status.c = result > 0xFFFF

    self.cpu.registers.hl = bit.band(result, 0xFFFF)

    return 10
end

function instructions:DAA()
    local low = bit.band(self.cpu.registers.a, 0x0F)

    if self.cpu.registers.status.h or low > 9 then
        low = low + 6
    end

    self.cpu.registers.status.h = low > 0x0F

    self.cpu.registers.a = bit.band(self.cpu.registers.a, 0xF0) + low
    local hi = bit.band(self.cpu.registers.a, 0xF0)

    if self.cpu.registers.status.c or hi > 0x90 then
        hi = hi + 0x60
    end

    if hi > 0xF0 then
        self.cpu.registers.status.c = true
    end

    local result = bit.band(bit.band(self.cpu.registers.a, 0x0F) + hi, 0xFF)

    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.z = result == 0

    self.cpu.registers.a = result

    return 4
end

function instructions:ANA(op1)
    local cycles, result, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    result = bit.band(self.cpu.registers.a, value)

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.bor(self.cpu.registers.a, value), 0x08) ~= 0

    self.cpu.registers.a = result

    return cycles or 4
end

function instructions:ORA(op1)
    local cycles, result

    if op1 == "m" then
        result = bit.bor(self.cpu.registers.a, self.bus[self.cpu.registers.hl])
        cycles = 7
    else
        result = bit.bor(self.cpu.registers.a, self.cpu.registers[op1])
    end

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = false

    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:XRA(op1)
    local cycles, result

    if op1 == "m" then
        result = bit.bxor(self.cpu.registers.a, self.bus[self.cpu.registers.hl])
        cycles = 7
    else
        result = bit.bxor(self.cpu.registers.a, self.cpu.registers[op1])
    end

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = false

    self.cpu.registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ANI()
    local value = self:get_8bit_immediate()
    local result = bit.band(self.cpu.registers.a, value)

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.bor(self.cpu.registers.a, value), 0x08) ~= 0

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:ORI()
    local result = bit.bor(self.cpu.registers.a, self:get_8bit_immediate())

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = false

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:XRI()
    local result = bit.bxor(self.cpu.registers.a, self:get_8bit_immediate())

    self.cpu.registers.status.c = false
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = false

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:CMP(op1)
    local cycles, value

    if op1 == "m" then
        value = self.bus[self.cpu.registers.hl]
        cycles = 7
    else
        value = self.cpu.registers[op1]
    end

    local result = self.cpu.registers.a - value

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    return cycles or 4

end

function instructions:CPI()
    local value = self:get_8bit_immediate()

    local result = self.cpu.registers.a - value

    self.cpu.registers.status.c = bit.band(result, 0x100) == 0x100
    self.cpu.registers.status.n = bit.band(result, 0x80) == 0x80
    self.cpu.registers.status.z = bit.band(result, 0xFF) == 0
    self.cpu.registers.status.p = self.get_parity(bit.band(result, 0xFF))
    self.cpu.registers.status.h = bit.band(bit.band(self.cpu.registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    return 7
end

function instructions:RLC()
    local result = bit.lshift(self.cpu.registers.a, 1)
    result = bit.bor(result, bit.rshift(self.cpu.registers.a, 7))
    self.cpu.registers.a = bit.band(result, 0xFF)

    self.cpu.registers.status.c = result > 0xFF

    return 4
end

function instructions:RRC()
    local result = bit.rshift(self.cpu.registers.a, 1)
    result = bit.bor(result, bit.lshift(self.cpu.registers.a, 7))

    self.cpu.registers.status.c = bit.band(self.cpu.registers.a, 1) == 1

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 4
end

function instructions:RAL()
    local result = bit.lshift(self.cpu.registers.a, 1)
    result = bit.bor(result, self.cpu.registers.status.c and 1 or 0)
    self.cpu.registers.a = bit.band(result, 0xFF)

    self.cpu.registers.status.c = result > 0xFF

    return 4
end

function instructions:RAR()
    local result = bit.rshift(self.cpu.registers.a, 1)
    result = bit.bor(result, self.cpu.registers.status.c and 0x80 or 0)

    self.cpu.registers.status.c = bit.band(self.cpu.registers.a, 1) == 1

    self.cpu.registers.a = bit.band(result, 0xFF)

    return 4
end

function instructions:CMA()
    self.cpu.registers.a = bit.band(bit.bnot(self.cpu.registers.a), 0xFF)
    return 4
end

function instructions:CMC()
    self.cpu.registers.status.c = not self.cpu.registers.status.c
    return 4
end

function instructions:STC()
    self.cpu.registers.status.c = true
    return 4
end

function instructions:JMP()
    self.cpu.registers.pc = self:get_16bit_immediate()
    return 10
end

function instructions:JNZ()
    if not self.cpu.registers.status.z then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JZ()
    if self.cpu.registers.status.z then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JNC()
    if not self.cpu.registers.status.c then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JC()
    if self.cpu.registers.status.c then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JPO()
    if not self.cpu.registers.status.p then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JPE()
    if self.cpu.registers.status.p then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JP()
    if not self.cpu.registers.status.n then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:JM()
    if self.cpu.registers.status.n then
        self:JMP()
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 10
end

function instructions:CALL()
    local value = self:get_16bit_immediate()

    self.bus[bit.band(self.cpu.registers.sp - 1, 0xFFFF)] = bit.rshift(self.cpu.registers.pc, 8)
    self.bus[bit.band(self.cpu.registers.sp - 2, 0xFFFF)] = bit.band(self.cpu.registers.pc, 0xFF)
    self.cpu.registers.sp = self.cpu.registers.sp - 2

    self.cpu.registers.pc = value
    return 17
end

function instructions:CNZ()
    if not self.cpu.registers.status.z then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CZ()
    if self.cpu.registers.status.z then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CNC()
    if not self.cpu.registers.status.c then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CC()
    if self.cpu.registers.status.c then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CPO()
    if not self.cpu.registers.status.p then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CPE()
    if self.cpu.registers.status.p then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CP()
    if not self.cpu.registers.status.n then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:CM()
    if self.cpu.registers.status.n then
        self:CALL()
        return 17
    else
        self.cpu.registers.pc = self.cpu.registers.pc + 2
    end
    return 11
end

function instructions:RET()
    self.cpu.registers.pc = bit.bor(bit.lshift(self.bus[bit.band(self.cpu.registers.sp + 1, 0xFFFF)], 8), self.bus[self.cpu.registers.sp])
    self.cpu.registers.sp = self.cpu.registers.sp + 2
    return 10
end

function instructions:RNZ()
    if not self.cpu.registers.status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RZ()
    if self.cpu.registers.status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RNC()
    if not self.cpu.registers.status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RC()
    if self.cpu.registers.status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPO()
    if not self.cpu.registers.status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPE()
    if self.cpu.registers.status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RP()
    if not self.cpu.registers.status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RM()
    if self.cpu.registers.status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RST(op1)
    self.bus[bit.band(self.cpu.registers.sp - 1, 0xFFFF)] = bit.rshift(self.cpu.registers.pc, 8)
    self.bus[bit.band(self.cpu.registers.sp - 2, 0xFFFF)] = bit.band(self.cpu.registers.pc, 0xFF)
    self.cpu.registers.sp = self.cpu.registers.sp - 2

    self.cpu.registers.pc = op1 * 8
    return 11
end

function instructions:PCHL()
    self.cpu.registers.pc = bit.bor(bit.lshift(self.cpu.registers.h, 8), self.cpu.registers.l)
    return 5
end

function instructions:PUSH(op1)
    local rp

    if op1 == "sp" then
        rp = self.cpu.registers.psw
    else
        rp = self.cpu.registers[op1]
    end

    self.bus[bit.band(self.cpu.registers.sp - 1, 0xFFFF)] = bit.rshift(rp, 8)
    self.bus[bit.band(self.cpu.registers.sp - 2, 0xFFFF)] = bit.band(rp, 0xFF)
    self.cpu.registers.sp = self.cpu.registers.sp - 2

    return 11
end

function instructions:POP(op1)
    local rp = bit.lshift(self.bus[self.cpu.registers.sp + 1], 8)
    rp = bit.bor(rp, self.bus[self.cpu.registers.sp])
    self.cpu.registers.sp = self.cpu.registers.sp + 2

    if op1 == "sp" then
        self.cpu.registers.psw = rp
    else
        self.cpu.registers[op1] = rp
    end

    return 10
end

function instructions:XTHL()
    local result = self.cpu.registers.hl
    self:POP("hl")
    result, self.cpu.registers.hl = self.cpu.registers.hl, result
    self:PUSH("hl")
    self.cpu.registers.hl = result
    return 18
end

function instructions:SPHL()
    self.cpu.registers.sp = self.cpu.registers.hl
    return 5
end

function instructions:EI()
    self.cpu.inte = true
    return 4
end

function instructions:DI()
    self.cpu.inte = false
    return 4
end

function instructions:HLT()
    self.cpu.registers.pc = self.cpu.registers.pc + 1
    self.cpu.halt = true
    return 7
end

function instructions:IN(op1)
    self.cpu.registers.a = self.cpu.ports[self:get_8bit_immediate()]
    return 10
end

function instructions:OUT(op1)
    self.cpu.ports[self:get_8bit_immediate()] = self.cpu.registers.a
    return 10
end

return instructions
