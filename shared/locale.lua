Locales = {}
local currentLocale = Config.Locale or 'es'

local function LoadLocale(locale)
    local resourceName = GetCurrentResourceName()
    local localeFile = ('locales/%s.json'):format(locale)
    local content = LoadResourceFile(resourceName, localeFile)

    if not content then
        print('^1[Banking System] Failed to load locale file: ' .. localeFile .. '^7')
        return {}
    end

    local success, data = pcall(json.decode, content)
    if not success then
        print('^1[Banking System] Failed to parse locale file: ' .. localeFile .. '^7')
        return {}
    end

    return data
end

Locales = LoadLocale(currentLocale)

function Locale(key, ...)
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do
        table.insert(keys, k)
    end

    local value = Locales
    for _, k in ipairs(keys) do
        if type(value) == "table" then
            value = value[k]
        else
            value = nil
            break
        end
    end

    if not value then
        print('^3[Banking System] Missing translation for key: ' .. key .. '^7')
        return key
    end

    local args = { ... }
    if #args > 0 then
        for i, arg in ipairs(args) do
            value = string.gsub(value, '{' .. (i - 1) .. '}', tostring(arg))
        end
        if type(args[1]) == 'table' then
            for k, v in pairs(args[1]) do
                value = string.gsub(value, '{' .. k .. '}', tostring(v))
            end
        end
    end

    return value
end

_G.Locale = Locale
