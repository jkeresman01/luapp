local Parser = {}
Parser.__index = Parser

local TokenType = require("src.scanner.scanner").TokenType
local ast = require("src.ast.ast")

----------------------------------------------------------------------------
--
-- Create a new parser.
--
-- @param  tokens  table       List of tokens produced by the scanner
-- @param  source  string|nil  Original source text (optional)
--
-- @return Parser              New parser instance
--
----------------------------------------------------------------------------
function Parser:new(tokens, source)
    return setmetatable({
        tokens = tokens,
        source = source,
        current = 1,
    }, Parser)
end

----------------------------------------------------------------------------
--
-- Return the current token without consuming it.
--
-- @return table               Current token
--
----------------------------------------------------------------------------
function Parser:peek()     return self.tokens[self.current] end

----------------------------------------------------------------------------
--
-- Return the most recently consumed token.
--
-- @return table               Previous token
--
----------------------------------------------------------------------------
function Parser:previous() return self.tokens[self.current - 1] end

----------------------------------------------------------------------------
--
-- Check whether the parser has reached the EOF token.
--
-- @return boolean             True if at end of input
--
----------------------------------------------------------------------------
function Parser:isAtEnd()
    return self:peek().type == TokenType.EOF
end

----------------------------------------------------------------------------
--
-- Consume the current token (unless at EOF) and return the previous one.
--
-- @return table               Token that was just consumed
--
----------------------------------------------------------------------------
function Parser:advance()
    if not self:isAtEnd() then self.current = self.current + 1 end
    return self:previous()
end

----------------------------------------------------------------------------
--
-- Check whether the current token has the given type, without consuming it.
--
-- @param  type  string        TokenType value to test for
--
-- @return boolean             True if the current token matches
--
----------------------------------------------------------------------------
function Parser:check(type)
    if self:isAtEnd() then return false end
    return self:peek().type == type
end

----------------------------------------------------------------------------
--
-- Consume the current token only if it has the given type.
--
-- @param  type  string        TokenType value to match
--
-- @return boolean             True if matched (and consumed)
--
----------------------------------------------------------------------------
function Parser:match(type)
    if self:check(type) then
        self:advance()
        return true
    end
    return false
end

----------------------------------------------------------------------------
--
-- Consume a token of the given type, or raise an error.
--
-- @param  type     string     TokenType value expected
-- @param  message  string     Error message if the token does not match
--
-- @return table               The consumed token
--
----------------------------------------------------------------------------
function Parser:consume(type, message)
    if self:check(type) then return self:advance() end
    error(message .. " (line " .. self:peek().line .. ")")
end

----------------------------------------------------------------------------
--
-- Parse the whole token stream. A Luapp file contains a single class.
--
-- @return table               Class node (AST root)
--
----------------------------------------------------------------------------
function Parser:parse()
    return self:classDeclaration()
end

----------------------------------------------------------------------------
--
-- Parse a class declaration:
--
--     class Name
--         local field(get, set)
--         Name(params) ... end
--         [local] function method(params) ... end
--     end
--
-- @return table               Class node
--
----------------------------------------------------------------------------
function Parser:classDeclaration()
    self:consume(TokenType.CLASS, "Expected 'class'")
    local nameTok = self:consume(TokenType.IDENTIFIER, "Expected class name")
    local className = nameTok.lexeme

    local fields = {}
    local constructor = nil
    local methods = {}

    while not self:check(TokenType.END) and not self:isAtEnd() do

        if self:match(TokenType.LOCAL) then
            if self:check(TokenType.IDENTIFIER) then
                table.insert(fields, self:fieldDeclaration())
            elseif self:match(TokenType.FUNCTION) then
                table.insert(methods, self:methodDeclaration(true))
            else
                error("Expected field or 'function' after 'local' (line "
                      .. self:peek().line .. ")")
            end

        elseif self:match(TokenType.FUNCTION) then
            table.insert(methods, self:methodDeclaration(false))

        elseif self:check(TokenType.IDENTIFIER)
            and self:peek().lexeme == className then

            constructor = self:constructorDeclaration(className)

        else
            error("Unexpected token in class body: " .. self:peek().lexeme
                  .. " (line " .. self:peek().line .. ")")
        end
    end

    self:consume(TokenType.END, "Expected 'end' after class body")

    return ast.Class(className, fields, constructor, methods)
end

----------------------------------------------------------------------------
--
-- Parse a field declaration and its accessor list, e.g. "name(get, local set)".
-- The leading 'local' has already been consumed.
--
-- @return table               Field node
--
----------------------------------------------------------------------------
function Parser:fieldDeclaration()
    local nameTok = self:consume(TokenType.IDENTIFIER, "Expected field name")
    local name = nameTok.lexeme

    self:consume(TokenType.LEFT_PAREN, "Expected '(' after field name")

    local access_get = nil
    local access_set = nil

    while not self:check(TokenType.RIGHT_PAREN) do

        if self:match(TokenType.IDENTIFIER) then
            local acc = self:previous().lexeme
            if acc == "get" then access_get = "public"
            elseif acc == "set" then access_set = "public"
            else error("Unknown accessor: " .. acc) end

        elseif self:match(TokenType.LOCAL) then
            local accTok = self:consume(TokenType.IDENTIFIER, "Expected accessor after 'local'")
            local acc = accTok.lexeme
            if acc == "get" then access_get = "private"
            elseif acc == "set" then access_set = "private"
            else error("Invalid private accessor: " .. acc) end

        elseif self:match(TokenType.COMMA) then
            -- skip comma

        else
            error("Unexpected token in accessor list: "
                  .. self:peek().lexeme .. " (line " .. self:peek().line .. ")")
        end
    end

    self:consume(TokenType.RIGHT_PAREN, "Expected ')' after accessor list")

    return ast.Field(name, access_get, access_set)
end

----------------------------------------------------------------------------
--
-- Parse a constructor. The current token is the class name, which is
-- skipped, followed by the parameter list and body.
--
-- @return table               Constructor node
--
----------------------------------------------------------------------------
function Parser:constructorDeclaration()
    self:advance()

    self:consume(TokenType.LEFT_PAREN, "Expected '(' after constructor")
    local params = self:parameterList()
    self:consume(TokenType.RIGHT_PAREN, "Expected ')' after parameters")

    local body = self:methodBody()
    return ast.Constructor(params, body)
end

----------------------------------------------------------------------------
--
-- Parse a method declaration. The 'function' keyword (and 'local', for
-- private methods) has already been consumed.
--
-- @param  isPrivate  boolean  True if declared with 'local function'
--
-- @return table              Method node
--
----------------------------------------------------------------------------
function Parser:methodDeclaration(isPrivate)
    local nameTok = self:consume(TokenType.IDENTIFIER, "Expected method name")
    local name = nameTok.lexeme

    self:consume(TokenType.LEFT_PAREN, "Expected '(' after method name")
    local params = self:parameterList()
    self:consume(TokenType.RIGHT_PAREN, "Expected ')' after parameters")

    local body = self:methodBody()
    return ast.Method(name, params, body, isPrivate)
end

----------------------------------------------------------------------------
--
-- Parse a comma-separated list of parameter names. Stops before ')'.
--
-- @return table               List of parameter names (strings)
--
----------------------------------------------------------------------------
function Parser:parameterList()
    local params = {}

    if self:check(TokenType.RIGHT_PAREN) then return params end

    table.insert(params, self:consume(TokenType.IDENTIFIER, "Expected parameter").lexeme)

    while self:match(TokenType.COMMA) do
        table.insert(params, self:consume(TokenType.IDENTIFIER, "Expected parameter").lexeme)
    end

    return params
end

----------------------------------------------------------------------------
--
-- Collect a constructor or method body up to the closing 'end'. Token
-- lexemes are joined with single spaces and kept as raw text.
--
-- @return string              Body source text
--
----------------------------------------------------------------------------
function Parser:methodBody()
    local fragments = {}

    while not self:check(TokenType.END) and not self:isAtEnd() do
        local tok = self:advance()
        table.insert(fragments, tok.lexeme)
    end

    self:consume(TokenType.END, "Expected 'end' after method body")

    return table.concat(fragments, " ")
end

return Parser
