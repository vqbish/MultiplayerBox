local TableHelpers = {}

function TableHelpers.contains(t, element)
    return TableHelpers.indexOf(t, element) ~= nil
end

function TableHelpers.indexOf(t, element)
    for index, value in tableIterators.ipairs(t) do
        if value == element then
            return index
        end
    end
    return nil
end

return TableHelpers