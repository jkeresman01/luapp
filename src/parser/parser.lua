local Parser = {}
Parser.__index = Parser

local TokenType = require("src.scanner.scanner").TokenType
local ast = require("src.ast.ast")

function Parser:new(tokens, source)
    return setmetatable({
        source = source,
        current = 1,
    }, Parser)
end

function Parser:peek()     return self.tokens[self.current] end
function Parser:previous() return self.tokens[self.current - 1] end

function Parser:isAtEnd()
    return self:peek().type == TokenType.EOF
end

function Parser:advance()
    if not self:isAtEnd() then self.current = self.current + 1 end
    return self:previous()
end

function Parser:check(type)
    if self:isAtEnd() then return false end
    return self:peek().type == type
end

function Parser:match(type)
    if self:check(type) then
        self:advance()
        return true
    end
    return false
end

function Parser:consume(type, message)
    if self:check(type) then return self:advance() end
    error(message .. " (line " .. self:peek().line .. ")")
end

function Parser:parse()
    return self:classDeclaration()
end

function Parser:classDeclaration()
    self:consume(TokenType.CLASS, "Expected 'class'")
    local nameTok = self:consume(TokenType.IDENTIFIER, "Expected class name")
    local className = nameTok.lexeme

    local fields = {}
    local constructor = nil
    local methods = {}

    while not self:check(TokenType.END) and not self:isAtEnd() do

        if self:match(TokenType.LOCAL) and self:check(TokenType.IDENTIFIER) then
            table.insert(fields, self:fieldDeclaration())

        elseif self:match(TokenType.LOCAL) and self:match(TokenType.FUNCTION) then
            table.insert(methods, self:methodDeclaration(true))

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

function Parser:constructorDeclaration()
    self:advance()

    self:consume(TokenType.LEFT_PAREN, "Expected '(' after constructor")
    local params = self:parameterList()
    self:consume(TokenType.RIGHT_PAREN, "Expected ')' after parameters")

    local body = self:methodBody()
    return ast.Constructor(params, body)
end

function Parser:methodDeclaration(isPrivate)
    local nameTok = self:consume(TokenType.IDENTIFIER, "Expected method name")
    local name = nameTok.lexeme

    self:consume(TokenType.LEFT_PAREN, "Expected '(' after method name")
    local params = self:parameterList()
    self:consume(TokenType.RIGHT_PAREN, "Expected ')' after parameters")

    local body = self:methodBody()
    return ast.Method(name, params, body, isPrivate)
end

function Parser:parameterList()
    local params = {}

    if self:check(TokenType.RIGHT_PAREN) then return params end

    table.insert(params, self:consume(TokenType.IDENTIFIER, "Expected parameter").lexeme)

    while self:match(TokenType.COMMA) do
        table.insert(params, self:consume(TokenType.IDENTIFIER, "Expected parameter").lexeme)
    end

    return params
end

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

