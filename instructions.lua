local bit = bit or require "bit32"
local path = (...):match("(.-)[^%.]+$")
local opcodes = require(path .. ".opcodes")

local instructions = {}

local cpu, registers, status, bus

local band, bor, bxor, rshift, lshift, bnot = bit.band, bit.bor, bit.bxor, bit.rshift, bit.lshift, bit.bnot

function instructions:init(cpu_, bus_)
    cpu = cpu_
    bus = bus_
    registers = cpu_.registers
    status = registers.status
    self.opcodes = opcodes
end

local function get_parity(number)
    local temp = bxor(number, rshift(number, 4))
    temp = bxor(temp, rshift(temp, 2))
    temp = bxor(temp, rshift(temp, 1))
    return band(temp, 1) == 0
end

function instructions:get_8bit_immediate()
    local value = bus[registers.pc]
    registers.pc = registers.pc + 1
    return value
end

function instructions:get_16bit_immediate()
    local value = lshift(bus[registers.pc + 1], 8) + bus[registers.pc]
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

    status.c = result > 0xFF
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(registers.a, 0x0F) + band(value, 0x0F) > 0x0F

    registers.a = band(result, 0xFF)

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

    local c = status.c and 1 or 0
    local result = registers.a + value + c

    status.c = result > 0xFF
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(registers.a, 0x0F) + band(value, 0x0F) + c > 0x0F
    
    registers.a = band(result, 0xFF)

    return cycles or 4
end

function instructions:ADI()
    local value = self:get_8bit_immediate()

    local result = registers.a + value

    status.c = result > 0xFF
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(registers.a, 0x0F) + band(value, 0x0F) > 0x0F

    registers.a = band(result, 0xFF)

    return 7
end

function instructions:ACI()
    local value = self:get_8bit_immediate()

    local c = status.c and 1 or 0
    local result = registers.a + value + c

    status.c = result > 0xFF
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(registers.a, 0x0F) + band(value, 0x0F) + c > 0x0F

    registers.a = band(result, 0xFF)

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

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F), 0x10) ~= 0x10

    registers.a = band(result, 0xFF)

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

    local c = status.c and 1 or 0
    local result = registers.a - value - c

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F) - c, 0x10) ~= 0x10

    registers.a = band(result, 0xFF)

    return cycles or 4
end

function instructions:SUI(op1)
    local value = self:get_8bit_immediate()

    local result = registers.a - value

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F), 0x10) ~= 0x10

    registers.a = band(result, 0xFF)

    return 7
end

function instructions:SBI()
    local value = self:get_8bit_immediate()

    local c = status.c and 1 or 0
    local result = registers.a - value - c

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F) - c, 0x10) ~= 0x10

    registers.a = band(result, 0xFF)

    return 7
end

function instructions:INR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        result = value + 1
        bus[registers.hl] = band(result, 0xFF)
        cycles = 10
    else
        value = registers[op1]
        result = value + 1
        registers[op1] = band(result, 0xFF)
    end

    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(value, 0x0F) + 1 > 0x0F

    return cycles or 5
end

function instructions:DCR(op1)
    local result, cycles, value

    if op1 == "m" then
        value = bus[registers.hl]
        result = value - 1
        bus[registers.hl] = band(result, 0xFF)
        cycles = 10
    else
        value = registers[op1]
        result = value - 1
        registers[op1] = band(result, 0xFF)
    end

    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(value, 0x0F) - 1, 0x100) ~= 0x100

    return cycles or 5
end

function instructions:INX(op1)
    registers[op1] = band(registers[op1] + 1, 0xFFFF)
    return 5
end

function instructions:DCX(op1)
    registers[op1] = band(registers[op1] - 1, 0xFFFF)
    return 5
end

function instructions:DAD(op1)
    local result = registers.hl + registers[op1]

    status.c = result > 0xFFFF

    registers.hl = band(result, 0xFFFF)

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

    result = band(registers.a, value)

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(bor(registers.a, value), 0x08) ~= 0

    registers.a = result

    return cycles or 4
end

function instructions:ORA(op1)
    local cycles, result

    if op1 == "m" then
        result = bor(registers.a, bus[registers.hl])
        cycles = 7
    else
        result = bor(registers.a, registers[op1])
    end

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = false

    registers.a = band(result, 0xFF)

    return cycles or 4
end

function instructions:XRA(op1)
    local cycles, result

    if op1 == "m" then
        result = bxor(registers.a, bus[registers.hl])
        cycles = 7
    else
        result = bxor(registers.a, registers[op1])
    end

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = false

    registers.a = band(result, 0xFF)

    return cycles or 4
end

function instructions:ANI()
    local value = self:get_8bit_immediate()
    local result = band(registers.a, value)

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(bor(registers.a, value), 0x08) ~= 0

    registers.a = band(result, 0xFF)

    return 7
end

function instructions:ORI()
    local result = bor(registers.a, self:get_8bit_immediate())

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = false

    registers.a = band(result, 0xFF)

    return 7
end

function instructions:XRI()
    local result = bxor(registers.a, self:get_8bit_immediate())

    status.c = false
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = false

    registers.a = band(result, 0xFF)

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

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F), 0x100) ~= 0x100

    return cycles or 4

end

function instructions:CPI()
    local value = self:get_8bit_immediate()

    local result = registers.a - value

    status.c = band(result, 0x100) == 0x100
    status.n = band(result, 0x80) == 0x80
    status.z = band(result, 0xFF) == 0
    status.p = get_parity(band(result, 0xFF))
    status.h = band(band(registers.a, 0x0F) - band(value, 0x0F), 0x100) ~= 0x100

    return 7
end

function instructions:RLC()
    local result = lshift(registers.a, 1)
    result = bor(result, rshift(registers.a, 7))
    registers.a = band(result, 0xFF)

    status.c = result > 0xFF

    return 4
end

function instructions:RRC()
    local result = rshift(registers.a, 1)
    result = bor(result, lshift(registers.a, 7))

    status.c = band(registers.a, 1) == 1

    registers.a = band(result, 0xFF)

    return 4
end

function instructions:RAL()
    local result = lshift(registers.a, 1)
    result = bor(result, status.c and 1 or 0)
    registers.a = band(result, 0xFF)

    status.c = result > 0xFF

    return 4
end

function instructions:RAR()
    local result = rshift(registers.a, 1)
    result = bor(result, status.c and 0x80 or 0)

    status.c = band(registers.a, 1) == 1

    registers.a = band(result, 0xFF)

    return 4
end

function instructions:CMA()
    registers.a = band(bnot(registers.a), 0xFF)
    return 4
end

function instructions:CMC()
    status.c = not status.c
    return 4
end

function instructions:STC()
    status.c = true
    return 4
end

function instructions:JMP()
    registers.pc = self:get_16bit_immediate()
    return 10
end

function instructions:JNZ()
    if not status.z then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JZ()
    if status.z then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JNC()
    if not status.c then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JC()
    if status.c then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JPO()
    if not status.p then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JPE()
    if status.p then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JP()
    if not status.n then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:JM()
    if status.n then
        self:JMP()
    else
        registers.pc = registers.pc + 2
    end
    return 10
end

function instructions:CALL()
    local value = self:get_16bit_immediate()

    bus[band(registers.sp - 1, 0xFFFF)] = rshift(registers.pc, 8)
    bus[band(registers.sp - 2, 0xFFFF)] = band(registers.pc, 0xFF)
    registers.sp = registers.sp - 2

    registers.pc = value
    return 17
end

function instructions:CNZ()
    if not status.z then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CZ()
    if status.z then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CNC()
    if not status.c then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CC()
    if status.c then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CPO()
    if not status.p then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CPE()
    if status.p then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CP()
    if not status.n then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:CM()
    if status.n then
        self:CALL()
        return 17
    else
        registers.pc = registers.pc + 2
    end
    return 11
end

function instructions:RET()
    registers.pc = bor(lshift(bus[band(registers.sp + 1, 0xFFFF)], 8), bus[registers.sp])
    registers.sp = registers.sp + 2
    return 10
end

function instructions:RNZ()
    if not status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RZ()
    if status.z then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RNC()
    if not status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RC()
    if status.c then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPO()
    if not status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RPE()
    if status.p then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RP()
    if not status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RM()
    if status.n then
        self:RET()
        return 11
    end
    return 5
end

function instructions:RST(op1)
    bus[band(registers.sp - 1, 0xFFFF)] = rshift(registers.pc, 8)
    bus[band(registers.sp - 2, 0xFFFF)] = band(registers.pc, 0xFF)
    registers.sp = registers.sp - 2

    registers.pc = op1 * 8
    return 11
end

function instructions:PCHL()
    registers.pc = bor(lshift(registers.h, 8), registers.l)
    return 5
end

function instructions:PUSH(op1)
    local rp

    if op1 == "sp" then
        rp = registers.psw
    else
        rp = registers[op1]
    end

    bus[band(registers.sp - 1, 0xFFFF)] = rshift(rp, 8)
    bus[band(registers.sp - 2, 0xFFFF)] = band(rp, 0xFF)
    registers.sp = registers.sp - 2

    return 11
end

function instructions:POP(op1)
    local rp = lshift(bus[registers.sp + 1], 8)
    rp = bor(rp, bus[registers.sp])
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
