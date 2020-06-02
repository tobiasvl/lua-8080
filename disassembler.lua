local path = (...):match("(.-)[^%.]+$")
local opcodes = require(path .. ".opcodes")

local disassembler = {}

disassembler.memory = {}

function disassembler:disassemble(memory)
    local address = 0
    while address <= 0xFFFF do
        local op = opcodes[memory[address]]
        if op and op.instruction then
            local op_address = address
            local s = op.instruction
            if op.op1 then
                s = s .. " " .. op.op1
            end
            if op.op2 then
                s = s .. " " .. op.op2
            end
            if op.imm then
                s = s .. " #"
                for i = 1, op.imm do
                    s = s .. string.format("%02X", memory[op_address + i])
                end
            end
            self.memory[op_address] = s
        end
        address = address + 1
    end
end

return disassembler