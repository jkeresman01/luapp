local Lexer   = require("src.scanner.scanner").Scanner
local Parser  = require("src.parser.parser")
local Codegen = require("src.codegen.codegen")

local compiler = {}

local function readFile(path)
    local file = assert(io.open(path, "r"), "Could not open " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

function compiler.compile(source)
    local scanner = Lexer:new(source)
    local tokens = scanner:scanTokens()

    local parser = Parser:new(tokens)
    local ast = parser:parse()

    local lua = Codegen.generate(ast)
    return lua
end

function compiler.run(args)
    if not args[1] then
        print("Usage: luapp <file.luapp>")
        os.exit(1)
    end

    local path = args[1]
    local source = readFile(path)

    local ok, result = pcall(function()
        return compiler.compile(source)
    end)

    if not ok then
        io.stderr:write("Luapp compile error: " .. tostring(result) .. "\n")
        os.exit(1)
    end

    print(result)
end

return compiler

