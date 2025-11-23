local Scanner = {}
Scanner.__index = Scanner

local TokenType = {
    -- single-character tokens
    LEFT_PAREN = "LEFT_PAREN",
    RIGHT_PAREN = "RIGHT_PAREN",
    COMMA = "COMMA",

    DOT = "DOT",
    EQUAL = "EQUAL",
    LESS = "LESS",

    -- keywords
    CLASS = "CLASS",
    LOCAL = "LOCAL",
    FUNCTION = "FUNCTION",
    END = "END",

    -- identifiers, literals
    IDENTIFIER = "IDENTIFIER",
    STRING = "STRING",
    NUMBER = "NUMBER",

    EOF = "EOF",
}

local keywords = {
    ["class"]    = TokenType.CLASS,
    ["local"]    = TokenType.LOCAL,
    ["function"] = TokenType.FUNCTION,
    ["end"]      = TokenType.END,
}

local function Token(type, lexeme, literal, line)
    return {
        type = type,
        lexeme = lexeme,
        literal = literal,
        line = line
    }
end

function Scanner:new(source)
    return setmetatable({
        source = source,
        tokens = {},
        start = 1,
        current = 1,
        line = 1,
    }, Scanner)
end

function Scanner:isAtEnd()
    return self.current > #self.source
end

function Scanner:advance()
    local c = self.source:sub(self.current, self.current)
    self.current = self.current + 1
    return c
end

function Scanner:addToken(t, literal)
    local text = self.source:sub(self.start, self.current - 1)
    table.insert(self.tokens, Token(t, text, literal, self.line))
end

function Scanner:match(expected)
    if self:isAtEnd() then return false end
    if self.source:sub(self.current, self.current) ~= expected then return false end
    self.current = self.current + 1
    return true
end

function Scanner:peek()
    if self:isAtEnd() then return "\0" end
    return self.source:sub(self.current, self.current)
end

function Scanner:peekNext()
    if self.current + 1 > #self.source then return "\0" end
    return self.source:sub(self.current + 1, self.current + 1)
end

function Scanner:scanTokens()
    while not self:isAtEnd() do
        self.start = self.current
        self:scanToken()
    end

    table.insert(self.tokens, Token(TokenType.EOF, "", nil, self.line))
    return self.tokens
end

function Scanner:isAlpha(c)
    return c:match("%a") ~= nil or c == "_"
end

function Scanner:isDigit(c)
    return c:match("%d") ~= nil
end

function Scanner:isAlphaNumeric(c)
    return self:isAlpha(c) or self:isDigit(c)
end

function Scanner:scanToken()
    local c = self:advance()

    if c == "(" then self:addToken(TokenType.LEFT_PAREN)
    elseif c == ")" then self:addToken(TokenType.RIGHT_PAREN)
    elseif c == "," then self:addToken(TokenType.COMMA)
    elseif c == "." then self:addToken(TokenType.DOT)
    elseif c == "=" then self:addToken(TokenType.EQUAL)
    elseif c == "<" then self:addToken(TokenType.LESS)

    elseif c == " " or c == "\r" or c == "\t" then
        -- ignore whitespace

    elseif c == "\n" then
        self.line = self.line + 1

    elseif c == '"' then
        self:string()

    elseif self:isDigit(c) then
        self:number()

    elseif self:isAlpha(c) then
        self:identifier()

    else
        error("Unexpected character at line " .. self.line .. ": " .. c)
    end
end

function Scanner:string()
    while self:peek() ~= '"' and not self:isAtEnd() do
        if self:peek() == "\n" then self.line = self.line + 1 end
        self:advance()
    end

    if self:isAtEnd() then error("Unterminated string.") end

    -- closing "
    self:advance()

    local value = self.source:sub(self.start + 1, self.current - 2)
    self:addToken(TokenType.STRING, value)
end

function Scanner:number()
    while self:isDigit(self:peek()) do self:advance() end

    local value = tonumber(self.source:sub(self.start, self.current - 1))
    self:addToken(TokenType.NUMBER, value)
end

function Scanner:identifier()
    while self:isAlphaNumeric(self:peek()) do self:advance() end

    local text = self.source:sub(self.start, self.current - 1)
    local type = keywords[text] or TokenType.IDENTIFIER

    self:addToken(type)
end

return {
    Scanner = Scanner,
    TokenType = TokenType
}

