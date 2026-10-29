local Lexer   = require("src.scanner.scanner").Scanner
local Parser  = require("src.parser.parser")
local Codegen = require("src.codegen.codegen")

local compiler = {}

----------------------------------------------------------------------------
--
-- Read the entire contents of a file.
--
-- @param  path  string        Path of the file to read
--
-- @return string              File contents
--
-- @error                      Raised if the file cannot be opened
--
----------------------------------------------------------------------------
local function readFile(path)
    local file = assert(io.open(path, "r"), "Could not open " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

----------------------------------------------------------------------------
--
-- Compile Luapp source code into Lua source code by running the scanner,
-- parser and code generator in sequence.
--
-- @param  source  string      Luapp source code
--
-- @return string              Generated Lua source code
--
----------------------------------------------------------------------------
function compiler.compile(source)
    local scanner = Lexer:new(source)
    local tokens = scanner:scanTokens()

    local parser = Parser:new(tokens)
    local ast = parser:parse()

    local lua = Codegen.generate(ast)
    return lua
end

----------------------------------------------------------------------------
--
-- Command-line entry point. Compiles the file given as the first argument
-- and prints the generated Lua to stdout. On failure, writes the error to
-- stderr and exits with status 1.
--
-- @param  args  table         Command-line arguments; args[1] is the .luapp path
--
----------------------------------------------------------------------------
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
