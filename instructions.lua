local bit = bit or require "bit32"
local path = (...):match("(.-)[^%.]+$")
local opcodes = require(path .. ".opcodes")

local instructions = {}

local cpu, registers

function instructions:init(cpu_, bus_)
    cpu = cpu_
    bus = bus_
    registers = cpu_.registers
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
    local value = bus[registers.pc]
    registers.pc = registers.pc + 1
    return value
end

function instructions:get_16bit_immediate()
    local value = bit.bor(bit.lshift(bus[registers.pc + 1], 8), bus[registers.pc])
    registers.pc = registers.pc + 2
    return value
end

function instructions.NOP()
    return 4
end

function instructions:MOV(op1, op2)
    local value, cycles

    if op2 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op2]
    end

    if op1 == "m" then
        bus[registers.hl] = value
        cycles = 7
    else
        registers[op1] = value
    end

    return cycles or 5
end

function instructions:MVI(op1)
    local cycles
    local value = self:get_8bit_immediate()

    if op1 == "m" then
        bus[registers.hl] = value
        cycles = 10
    else
        registers[op1] = value
    end

    return cycles or 7
end

function instructions:LXI(op1)
    local value = self:get_16bit_immediate()
    registers[op1] = value
    return 10
end

function instructions:LDA()
    local address = self:get_16bit_immediate()
    registers.a = bus[address]
    return 13
end

function instructions:STA()
    local address = self:get_16bit_immediate()
    bus[address] = registers.a
    return 13
end

function instructions:LHLD()
    local address = self:get_16bit_immediate()
    registers.h = bus[address + 1]
    registers.l = bus[address]
    return 16
end

function instructions:SHLD()
    local address = self:get_16bit_immediate()
    bus[address] = registers.l
    bus[address + 1] = registers.h
    return 16
end

function instructions:LDAX(op1)
    registers.a = bus[registers[op1]]
    return 7
end

function instructions:STAX(op1)
    bus[registers[op1]] = registers.a
    return 7
end

function instructions:XCHG()
    registers.de, registers.hl = registers.hl, registers.de
    return 4 -- 5 according to pastraiser, but seems to actually be 4 TODO
end

function instructions:ADD(op1)
    local cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    local result = registers.a + value

    registers.status.c = result > 0xFF
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(registers.a, 0x0F) + bit.band(value, 0x0F) > 0x0F

    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ADC(op1)
    local cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    local c = registers.status.c and 1 or 0
    local result = registers.a + value + c

    registers.status.c = result > 0xFF
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(registers.a, 0x0F) + bit.band(value, 0x0F) + c > 0x0F
    
    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ADI()
    local value = self:get_8bit_immediate()

    local result = registers.a + value

    registers.status.c = result > 0xFF
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(registers.a, 0x0F) + bit.band(value, 0x0F) > 0x0F

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:ACI()
    local value = self:get_8bit_immediate()

    local c = registers.status.c and 1 or 0
    local result = registers.a + value + c

    registers.status.c = result > 0xFF
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(registers.a, 0x0F) + bit.band(value, 0x0F) + c > 0x0F

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:SUB(op1)
    local cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    local result = registers.a - value

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F), 0x10) ~= 0x10

    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:SBB(op1)
    local cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    local c = registers.status.c and 1 or 0
    local result = registers.a - value - c

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F) - c, 0x10) ~= 0x10

    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:SUI(op1)
    local value = self:get_8bit_immediate()

    local result = registers.a - value

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F), 0x10) ~= 0x10

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:SBI()
    local value = self:get_8bit_immediate()

    local c = registers.status.c and 1 or 0
    local result = registers.a - value - c

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F) - c, 0x10) ~= 0x10

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:INR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        result = value + 1
        bus[registers.hl] = bit.band(result, 0xFF)
        cycles = 10
    else
        value = registers[op1]
        result = value + 1
        registers[op1] = bit.band(result, 0xFF)
    end

    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(value, 0x0F) + 1 > 0x0F

    return cycles or 5
end

function instructions:DCR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        result = value - 1
        bus[registers.hl] = bit.band(result, 0xFF)
        cycles = 10
    else
        value = registers[op1]
        result = value - 1
        registers[op1] = bit.band(result, 0xFF)
    end

    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(value, 0x0F) - 1, 0x100) ~= 0x100

    return cycles or 5
end

function instructions:INX(op1)
    registers[op1] = bit.band(registers[op1] + 1, 0xFFFF)
    return 5
end

function instructions:DCX(op1)
    registers[op1] = bit.band(registers[op1] - 1, 0xFFFF)
    return 5
end

function instructions:DAD(op1)
    local result = registers.hl + registers[op1]

    registers.status.c = result > 0xFFFF

    registers.hl = bit.band(result, 0xFFFF)

    return 10
end

function instructions:DAA()
    local low = bit.band(registers.a, 0x0F)

    if registers.status.h or low > 9 then
        low = low + 6
    end

    registers.status.h = low > 0x0F

    registers.a = bit.band(registers.a, 0xF0) + low
    local hi = bit.band(registers.a, 0xF0)

    if registers.status.c or hi > 0x90 then
        hi = hi + 0x60
    end

    if hi > 0xF0 then
        registers.status.c = true
    end

    local result = bit.band(bit.band(registers.a, 0x0F) + hi, 0xFF)

    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.z = result == 0

    registers.a = result

    return 4
end

function instructions:ANA(op1)
    local cycles, result, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    result = bit.band(registers.a, value)

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.bor(registers.a, value), 0x08) ~= 0

    registers.a = result

    return cycles or 4
end

function instructions:ORA(op1)
    local cycles, result

    if op1 == "m" then
        result = bit.bor(registers.a, bus[registers.hl])
        cycles = 7
    else
        result = bit.bor(registers.a, registers[op1])
    end

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = false

    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:XRA(op1)
    local cycles, result

    if op1 == "m" then
        result = bit.bxor(registers.a, bus[registers.hl])
        cycles = 7
    else
        result = bit.bxor(registers.a, registers[op1])
    end

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = false

    registers.a = bit.band(result, 0xFF)

    return cycles or 4
end

function instructions:ANI()
    local value = self:get_8bit_immediate()
    local result = bit.band(registers.a, value)

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.bor(registers.a, value), 0x08) ~= 0

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:ORI()
    local result = bit.bor(registers.a, self:get_8bit_immediate())

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = false

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:XRI()
    local result = bit.bxor(registers.a, self:get_8bit_immediate())

    registers.status.c = false
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = false

    registers.a = bit.band(result, 0xFF)

    return 7
end

function instructions:CMP(op1)
    local cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        cycles = 7
    else
        value = registers[op1]
    end

    local result = registers.a - value

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    return cycles or 4

end

function instructions:CPI()
    local value = self:get_8bit_immediate()

    local result = registers.a - value

    registers.status.c = bit.band(result, 0x100) == 0x100
    registers.status.n = bit.band(result, 0x80) == 0x80
    registers.status.z = bit.band(result, 0xFF) == 0
    registers.status.p = self.get_parity(bit.band(result, 0xFF))
    registers.status.h = bit.band(bit.band(registers.a, 0x0F) - bit.band(value, 0x0F), 0x100) ~= 0x100

    return 7
end

function instructions:RLC()
    local result = bit.lshift(registers.a, 1)
    result = bit.bor(result, bit.rshift(registers.a, 7))
    registers.a = bit.band(result, 0xFF)

    registers.status.c = result > 0xFF

    return 4
end

function instructions:RRC()
    local result = bit.rshift(registers.a, 1)
    result = bit.bor(result, bit.lshift(registers.a, 7))

    registers.status.c = bit.band(registers.a, 1) == 1

    registers.a = bit.band(result, 0xFF)

    return 4
end

function instructions:RAL()
    local result = bit.lshift(registers.a, 1)
    result = bit.bor(result, registers.status.c and 1 or 0)
    registers.a = bit.band(result, 0xFF)

    registers.status.c = result > 0xFF

    return 4
end

function instructions:RAR()
    local result = bit.rshift(registers.a, 1)
    result = bit.bor(result, registers.status.c and 0x80 or 0)

    registers.status.c = bit.band(registers.a, 1) == 1

    registers.a = bit.band(result, 0xFF)

    return 4
end

function instructions:CMA()
    registers.a = bit.band(bit.bnot(registers.a), 0xFF)
    return 4
end

function instructions:CMC()
    registers.status.c = not registers.status.c
    return 4
end

function instructions:STC()
    registers.status.c = true
    return 4
end

function instructions:JMP()
    registers.pc = self:get_16bit_immediate()
    return 10
end

function instructions:JNZ()
    if not registers.status.z then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JZ()
    if registers.status.z then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JNC()
    if not registers.status.c then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JC()
    if registers.status.c then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JPO()
    if not registers.status.p then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JPE()
    if registers.status.p then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JP()
    if not registers.status.n then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JM()
    if registers.status.n then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:CALL()
    local value = self:get_16bit_immediate()

    bus[bit.band(registers.sp - 1, 0xFFFF)] = bit.rshift(registers.pc, 8)
    bus[bit.band(registers.sp - 2, 0xFFFF)] = bit.band(registers.pc, 0xFF)
    registers.sp = registers.sp - 2

    registers.pc = value
    return 17
end

function instructions:CNZ()
    if not registers.status.z then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CZ()
    if registers.status.z then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CNC()
    if not registers.status.c then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CC()
    if registers.status.c then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CPO()
    if not registers.status.p then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CPE()
    if registers.status.p then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CP()
    if not registers.status.n then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CM()
    if registers.status.n then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:RET()
    registers.pc = bit.bor(bit.lshift(bus[bit.band(registers.sp + 1, 0xFFFF)], 8), bus[registers.sp])
    registers.sp = registers.sp + 2
    return 10
end

function instructions:RNZ()
    if not registers.status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RZ()
    if registers.status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RNC()
    if not registers.status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RC()
    if registers.status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPO()
    if not registers.status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPE()
    if registers.status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RP()
    if not registers.status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RM()
    if registers.status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RST(op1)
    bus[bit.band(registers.sp - 1, 0xFFFF)] = bit.rshift(registers.pc, 8)
    bus[bit.band(registers.sp - 2, 0xFFFF)] = bit.band(registers.pc, 0xFF)
    registers.sp = registers.sp - 2

    registers.pc = op1 * 8
    return 11
end

function instructions:PCHL()
    registers.pc = bit.bor(bit.lshift(registers.h, 8), registers.l)
    return 5
end

function instructions:PUSH(op1)
    local rp

    if op1 == "sp" then
        rp = registers.psw
    else
        rp = registers[op1]
    end

    bus[bit.band(registers.sp - 1, 0xFFFF)] = bit.rshift(rp, 8)
    bus[bit.band(registers.sp - 2, 0xFFFF)] = bit.band(rp, 0xFF)
    registers.sp = registers.sp - 2

    return 11
end

function instructions:POP(op1)
    local rp = bit.lshift(bus[registers.sp + 1], 8)
    rp = bit.bor(rp, bus[registers.sp])
    registers.sp = registers.sp + 2

    if op1 == "sp" then
        registers.psw = rp
    else
        registers[op1] = rp
    end

    return 10
end

function instructions:XTHL()
    local result = registers.hl
    self:POP("hl")
    result, registers.hl = registers.hl, result
    self:PUSH("hl")
    registers.hl = result
    return 18
end

function instructions:SPHL()
    registers.sp = registers.hl
    return 5
end

function instructions:EI()
    cpu.inte = true
    return 4
end

function instructions:DI()
    cpu.inte = false
    return 4
end

function instructions:HLT()
    registers.pc = registers.pc + 1
    cpu.halt = true
    return 7
end

function instructions:IN(op1)
    registers.a = cpu.ports[self:get_8bit_immediate()]
    return 10
end

function instructions:OUT(op1)
    cpu.ports[self:get_8bit_immediate()] = registers.a
    return 10
end

return instructions
