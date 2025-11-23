local codegen = {}

local function rewriteMethodCalls(body, methodNames)
    for _, name in ipairs(methodNames) do
        body = body:gsub("(%f[%w_])" .. name .. "%s*%(", "self:" .. name .. "(")
    end
    return body
end

local function generatePublicGetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
function %s:get_%s()
    return self.%s
end

]], className, clean, field.name)
end

local function generatePublicSetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
function %s:set_%s(value)
    self.%s = value
end

]], className, clean, field.name)
end

local function generatePrivateSetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
local function %s_set_%s(self, value)
    self.%s = value
end

]], className, clean, field.name)
end

function codegen.generate(ast)
    local out = {}
    local function emit(s) table.insert(out, s) end

    local className = ast.name

    emit(string.format("local %s = {}", className))
    emit(string.format("%s.__index = %s\n", className, className))

    if ast.constructor then
        local c = ast.constructor
        emit(string.format("function %s:new(%s)", 
            className, table.concat(c.params, ", ")))
        emit("    local self = setmetatable({}, " .. className .. ")")

        local body = c.body
        body = rewriteMethodCalls(body, {})

        for line in body:gmatch("[^\n]+") do
            emit("    " .. line)
        end

        emit("    return self")
        emit("end\n")
    end

    local methodNames = {} -- used later for rewriting method calls
    for _, m in ipairs(ast.methods) do table.insert(methodNames, m.name) end

    for _, field in ipairs(ast.fields) do
        if field.get == "public" then
            emit(generatePublicGetter(className, field))
        elseif field.get == "private" then
            error("Private getter not supported in v0.1")
        end

        if field.set == "public" then
            emit(generatePublicSetter(className, field))
        elseif field.set == "private" then
            emit(generatePrivateSetter(className, field))
        end
    end

    for _, m in ipairs(ast.methods) do
        local name = m.name
        local params = table.concat(m.params, ", ")

        if m.private then
            emit(string.format("function %s:%s(%s)", className, name, params))
        else
            emit(string.format("function %s:%s(%s)", className, name, params))
        end

        local body = rewriteMethodCalls(m.body, methodNames)

        for line in body:gmatch("[^\n]+") do
            emit("    " .. line)
        end

        emit("end\n")
    end

    emit("return " .. className .. "\n")

    return table.concat(out, "\n")
end

return codegen

