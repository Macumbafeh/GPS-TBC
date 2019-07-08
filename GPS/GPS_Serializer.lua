GPS_Serializer = {}
GPS_Serializer.types = {
    char = {
        width = 1,
        deserialize = function(match)
            return match
        end,
        serialize = function(value)
            return value
        end
    }
}

for _, v in ipairs({8, 16, 32}) do
    local type_ = 'int' .. v
    GPS_Serializer.types[type_] = {}

    GPS_Serializer.types[type_].width = math.floor(v / 8)
    GPS_Serializer.types[type_].deserialize = function(match)
        local val = 0
        for i=v/8, 1, -1 do
            val = val * 0xff + (match:byte(i) - 1)
        end

        return val
    end
    GPS_Serializer.types[type_].serialize = function(value)
        assert(value <= 0xfe * math.pow(0xff, v/8 - 1))

        local chunks = {}

        for i=1, v/8 do
            chunks[i] = (value % 0xff) + 1
            value = math.floor(value / 0xff)

            if chunks[i] > 0xff then
                chunks[i] = 1
            end

            assert(chunks[i] > 0, 'serialized value is equal to 0')
        end

        return string.char(unpack(chunks))
    end
end

function GPS_Serializer:deserialize(input, ...)
    local index = 1
    local output = {}

    for _, p in pairs({...}) do
        local times = 1
        if type(p) == 'table' then
            p, times = unpack(p)
        end

        for i=1,times do
            if self.types[p] then
                local type_ = self.types[p]
                local match = input:sub(index, index + type_.width - 1)

                if string.len(match) ~= type_.width then
                    return nil
                end

                index = index + type_.width
                output[#output+1] = type_.deserialize(match)
            else
                if input:sub(index, index + string.len(p) - 1) ~= p then
                    return nil
                end

                index = index + string.len(p)
            end
        end
    end

    if index <= string.len(input) then
        output[#output+1] = input:sub(index)
    end

    return unpack(output)
end

function GPS_Serializer:serialize(...)
    local output = {}

    for _, v in pairs({...}) do
        if type(v) == 'table' then
            local v, type_ = unpack(v)
            output[#output+1] = self.types[type_].serialize(v)
        elseif type(v) == 'number' then
            output[#output+1] = self.types.int32.serialize(v)
        else
            output[#output+1] = v
        end
    end

    return table.concat(output)
end
