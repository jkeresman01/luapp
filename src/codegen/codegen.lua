local codegen = {}

----------------------------------------------------------------------------
--
-- Rewrite bare calls to class methods into 'self:' calls, e.g.
-- "foo(" becomes "self:foo(".
--
-- @param  body         string  Method body source text
-- @param  methodNames  table   List of method names to rewrite
--
-- @return string               Rewritten body
--
----------------------------------------------------------------------------
local function rewriteMethodCalls(body, methodNames)
    for _, name in ipairs(methodNames) do
        body = body:gsub("(%f[%w_])" .. name .. "%s*%(", "self:" .. name .. "(")
    end
    return body
end

----------------------------------------------------------------------------
--
-- Generate the Lua source of a public getter, "Class:get_<name>()".
-- A leading underscore on the field name is dropped from the method name.
--
-- @param  className  string  Name of the class
-- @param  field      table   Field node
--
-- @return string             Lua source for the getter
--
----------------------------------------------------------------------------
local function generatePublicGetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
function %s:get_%s()
    return self.%s
end

]], className, clean, field.name)
end

----------------------------------------------------------------------------
--
-- Generate the Lua source of a public setter, "Class:set_<name>(value)".
-- A leading underscore on the field name is dropped from the method name.
--
-- @param  className  string  Name of the class
-- @param  field      table   Field node
--
-- @return string             Lua source for the setter
--
----------------------------------------------------------------------------
local function generatePublicSetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
function %s:set_%s(value)
    self.%s = value
end

]], className, clean, field.name)
end

----------------------------------------------------------------------------
--
-- Generate the Lua source of a private setter, a file-local function
-- "Class_set_<name>(self, value)" that is not exposed on the class table.
--
-- @param  className  string  Name of the class
-- @param  field      table   Field node
--
-- @return string             Lua source for the setter
--
----------------------------------------------------------------------------
local function generatePrivateSetter(className, field)
    local clean = field.name:gsub("^_", "")
    return string.format([[
local function %s_set_%s(self, value)
    self.%s = value
end

]], className, clean, field.name)
end

----------------------------------------------------------------------------
--
-- Generate Lua source code from a Class AST node. Emits, in order: the
-- class table, the constructor, field accessors, and methods.
--
-- @param  ast  table          Class node produced by the parser
--
-- @return string              Generated Lua source
--
-- @error                      Raised for private getters (unsupported in v0.1)
--
----------------------------------------------------------------------------
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
