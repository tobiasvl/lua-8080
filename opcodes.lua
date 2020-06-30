local bit = bit or require "bit32"

local opcodes = {}

opcodes[0xD3] = {instruction = "OUT", imm = 1}
opcodes[0xDB] = {instruction = "IN", imm = 1}

-- http://www.classiccmp.org/dunfield/r/8080.txt

local registers = {
[0]="b",
    "c",
    "d",
    "e",
    "h",
    "l",
    "m",
    "a"
}

local register_pairs = {
[0]="bc",
    "de",
    "hl",
    "sp"
}

local condition_codes = {
[0]="NZ",
    "Z",
    "NC",
    "C",
    "PO",
    "PE",
    "P",
    "M"
}

for opcode = 0x00, 0xFF do
    local d = registers[bit.rshift(bit.band(opcode, 0x38), 3)]
    local rp = register_pairs[bit.rshift(bit.band(opcode, 0x30), 4)]
    local s = registers[bit.band(opcode, 0x07)]

    local foo = {}

    if bit.band(opcode, 0xC0) == 0x00 then
        if opcode == 0x00 then
            foo.instruction = "NOP"
        elseif bit.band(opcode, 0x07) == 0x06 then
            foo.instruction = "MVI"
            foo.op1 = d
            foo.imm = 1
        elseif bit.band(opcode, 0x07) == 0x01 then
            if bit.band(opcode, 0x08) == 0x00 then
                foo.instruction = "LXI"
                foo.op1 = rp
                foo.imm = 2
            else
                foo.instruction = "DAD"
                foo.op1 = rp
            end
        elseif bit.band(opcode, 0x07) == 0x02 then
            if opcode == 0x22 then
                foo.instruction = "SHLD"
                foo.imm = 2
            elseif opcode == 0x2A then
                foo.instruction = "LHLD"
                foo.imm = 2
            elseif opcode == 0x32 then
                foo.instruction = "STA"
                foo.imm = 2
            elseif opcode == 0x3A then
                foo.instruction = "LDA"
                foo.imm = 2
            elseif bit.band(opcode, 0x08) == 0x08 then
                foo.instruction = "LDAX"
                foo.op1 = rp
                -- TODO only BC and DE are allowed
                assert(rp == "bc" or rp == "de")
            elseif bit.band(opcode, 0x08) == 0x00 then
                foo.instruction = "STAX"
                foo.op1 = rp
                -- TODO only BC and DE are allowed
                assert(rp == "bc" or rp == "de")
            end
        elseif bit.band(opcode, 0x07) == 0x03 then
            if bit.band(opcode, 0x08) == 0x00 then
                foo.instruction = "INX"
                foo.op1 = rp
            else
                foo.instruction = "DCX"
                foo.op1 = rp
            end
        elseif bit.band(opcode, 0x07) == 0x04 then
            foo.instruction = "INR"
            foo.op1 = d
        elseif bit.band(opcode, 0x07) == 0x05 then
            foo.instruction = "DCR"
            foo.op1 = d
        elseif bit.band(opcode, 0x07) == 0x06 then
            -- none?
        elseif bit.band(opcode, 0x07) == 0x07 then
            local op = bit.rshift(opcode, 3)
            if op == 0 then
                foo.instruction = "RLC"
            elseif op == 1 then
                foo.instruction = "RRC"
            elseif op == 2 then
                foo.instruction = "RAL"
            elseif op == 3 then
                foo.instruction = "RAR"
            elseif op == 4 then
                foo.instruction = "DAA"
            elseif op == 5 then
                foo.instruction = "CMA"
            elseif op == 6 then
                foo.instruction = "STC"
            elseif op == 7 then
                foo.instruction = "CMC"
            end
        end
    elseif bit.band(opcode, 0xC0) == 0x40 then
        if opcode == 0x76 then
            foo.instruction = "HLT"
        else
            foo.instruction = "MOV"
            foo.op1 = d
            foo.op2 = s
        end
    elseif bit.band(opcode, 0xC0) == 0x80 then
        local op = bit.rshift(opcode - 0x80, 3)
        if op == 0 then
            foo.instruction = "ADD"
            foo.op1 = s
        elseif op == 1 then
            foo.instruction = "ADC"
            foo.op1 = s
        elseif op == 2 then
            foo.instruction = "SUB"
            foo.op1 = s
        elseif op == 3 then
            foo.instruction = "SBB"
            foo.op1 = s
        elseif op == 4 then
            foo.instruction = "ANA"
            foo.op1 = s
        elseif op == 5 then
            foo.instruction = "XRA"
            foo.op1 = s
        elseif op == 6 then
            foo.instruction = "ORA"
            foo.op1 = s
        elseif op == 7 then
            foo.instruction = "CMP"
            foo.op1 = s
        end
    elseif bit.band(opcode, 0xC0) == 0xC0 then
        local op = bit.rshift(opcode - 0xC0, 3)
        if bit.band(opcode, 0x07) == 0x00 then
            foo.instruction = "R" .. condition_codes[op]
        elseif bit.band(opcode, 0x07) == 0x01 then
            if bit.band(opcode, 0x08) == 0x00 then
                foo.instruction = "POP"
                foo.op1 = rp
                if rp == "sp" then
                    foo.op1 = "psw"
                end
            else
                if op == 1 then
                    foo.instruction = "RET"
                elseif op == 5 then
                    foo.instruction = "PCHL"
                elseif op == 7 then
                    foo.instruction = "SPHL"
                end
            end
        elseif bit.band(opcode, 0x07) == 0x02 then
            foo.instruction = "J" .. condition_codes[op]
            foo.imm = 2
        elseif bit.band(opcode, 0x07) == 0x03 then
            if op == 0 then
                foo.instruction = "JMP"
                foo.imm = 2
            elseif op == 2 then
                foo.instruction = "OUT"
                foo.imm = 1
            elseif op == 3 then
                foo.instruction = "IN"
                foo.imm = 1
            elseif op == 4 then
                foo.instruction = "XTHL"
            elseif op == 5 then
                foo.instruction = "XCHG"
            elseif op == 6 then
                foo.instruction = "DI"
            elseif op == 7 then
                foo.instruction = "EI"
            end
        elseif bit.band(opcode, 0x07) == 0x04 then
            foo.instruction = "C" .. condition_codes[op]
            foo.imm = 2
        elseif bit.band(opcode, 0x07) == 0x05 then
            if bit.band(opcode, 0x08) == 0x00 then
                foo.instruction = "PUSH"
                foo.op1 = rp
                if rp == "sp" then
                    foo.op1 = "psw"
                end
            else
                foo.instruction = "CALL"
                foo.imm = 2
            end
        elseif bit.band(opcode, 0x07) == 0x06 then
            if op == 0 then
                foo.instruction = "ADI"
                foo.imm = 1
            elseif op == 1 then
                foo.instruction = "ACI"
                foo.imm = 1
            elseif op == 2 then
                foo.instruction = "SUI"
                foo.imm = 1
            elseif op == 3 then
                foo.instruction = "SBI"
                foo.imm = 1
            elseif op == 4 then
                foo.instruction = "ANI"
                foo.imm = 1
            elseif op == 5 then
                foo.instruction = "XRI"
                foo.imm = 1
            elseif op == 6 then
                foo.instruction = "ORI"
                foo.imm = 1
            elseif op == 7 then
                foo.instruction = "CPI"
                foo.imm = 1
            end
        elseif bit.band(opcode, 0x07) == 0x07 then
            foo.instruction = "RST"
            foo.op1 = op
        end
    end

    if not opcodes[opcode] then
        opcodes[opcode] = foo
    end
end

-- Undocumented opcodes
opcodes[0x10] = {instruction = "NOP"}
opcodes[0x20] = {instruction = "NOP"}
opcodes[0x30] = {instruction = "NOP"}
opcodes[0x08] = {instruction = "NOP"}
opcodes[0x18] = {instruction = "NOP"}
opcodes[0x28] = {instruction = "NOP"}
opcodes[0x38] = {instruction = "NOP"}
opcodes[0xD9] = {instruction = "RET"}
opcodes[0xCB] = {instruction = "JMP"}
opcodes[0xDD] = {instruction = "CALL"}
opcodes[0xED] = {instruction = "CALL"}
opcodes[0xFD] = {instruction = "CALL"}

return opcodes
