local bit = bit or require "bit32"
local path = (...):match("(.-)[^%.]+$")
local instructions = require(path .. '.instructions')

local cpu = {
    inte = true,
    ports = setmetatable({
        internal = {
            input = {},
            output = {}
        }
    }, {
        __index = function(tbl, index)
            if type(tbl.internal.input[index]) == "function" then
                return tbl.internal.input[index]()
            else
                return tbl.internal.input[index] or 0
            end
        end,
        __newindex = function(tbl, index, value)
            if type(tbl.internal.output[index]) == "function" then
                tbl.internal.output[index](value)
            end
        end
    }),
    registers = setmetatable({
        internal = {
            a = 0,
            b = 0,
            c = 0,
            d = 0,
            e = 0,
            h = 0,
            l = 0,
            sp = 0,
            pc = 0,
            status = {
                c = false,
                z = false,
                n = false,
                h = false,
                p = false
            }
        }
    }, {
        __index = function(tbl, index)
            if index == "bc" then
                return bit.bor(bit.lshift(tbl.internal.b, 8), tbl.internal.c)
            elseif index == "de" then
                return bit.bor(bit.lshift(tbl.internal.d, 8), tbl.internal.e)
            elseif index == "hl" then
                return bit.bor(bit.lshift(tbl.internal.h, 8), tbl.internal.l)
            elseif index == "psw" then
                local f = tbl.status.n and 1 or 0
                f = bit.lshift(f, 1)
                f = bit.bor(f, tbl.status.z and 1 or 0)
                f = bit.lshift(f, 1)
                f = bit.lshift(f, 1)
                f = bit.bor(f, tbl.status.h and 1 or 0)
                f = bit.lshift(f, 1)
                f = bit.lshift(f, 1)
                f = bit.bor(f, tbl.status.p and 1 or 0)
                f = bit.lshift(f, 1)
                f = bit.bor(f, 1)
                f = bit.lshift(f, 1)
                f = bit.bor(f, tbl.status.c and 1 or 0)
                return bit.bor(bit.lshift(tbl.internal.a, 8), f)
            else
                return tbl.internal[index]
            end
        end,
        __newindex = function(tbl, index, value)
            if index == "bc" then
                tbl.internal.c = bit.band(value, 0xFF)
                tbl.internal.b = bit.rshift(bit.band(value, 0xFF00), 8)
            elseif index == "de" then
                tbl.internal.e = bit.band(value, 0xFF)
                tbl.internal.d = bit.rshift(bit.band(value, 0xFF00), 8)
            elseif index == "hl" then
                tbl.internal.l = bit.band(value, 0xFF)
                tbl.internal.h = bit.rshift(bit.band(value, 0xFF00), 8)
            elseif index == "sp" then
                tbl.internal.sp = bit.band(value, 0xFFFF)
            elseif index == "pc" then
                tbl.internal.pc = bit.band(value, 0xFFFF)
            elseif index == "psw" then
                tbl.internal.a = bit.rshift(value, 8)
                tbl.status.c = bit.band(value, 1) ~= 0
                tbl.status.p = bit.band(value, 4) ~= 0
                tbl.status.h = bit.band(value, 16) ~= 0
                tbl.status.z = bit.band(value, 64) ~= 0
                tbl.status.n = bit.band(value, 128) ~= 0
            else
                tbl.internal[index] = bit.band(value, 0xFF)
            end
        end
    })
}

function cpu:init(bus)
    self.bus = bus
    instructions:init(self, bus)
end

function cpu:fetch()
    local opcode = self.bus[self.registers.pc]
    self.registers.pc = self.registers.pc + 1
    return opcode
end

function cpu:decode(opcode)
    return instructions.opcodes[opcode]
end

function cpu:execute(operation)
    return instructions[operation.instruction](instructions, operation.op1, operation.op2, operation.imm)
end

function cpu:cycle()
    return self:execute(self:decode(self:fetch()))
end

return cpu