return function(rom)
    return setmetatable({
        size = #rom + 1 -- TODO
    }, {
        __index = rom,
        __newindex = function(_, address, newValue)
            print("Attempted write at ROM address " .. string.format("%04X", address) .. " with value " .. newValue)
        end
    })
end