local Scanner = {}
Scanner.__index = Scanner

-- Every kind of token the scanner can produce.
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

-- Reserved words mapped to their token types.
local keywords = {
    ["class"]    = TokenType.CLASS,
    ["local"]    = TokenType.LOCAL,
    ["function"] = TokenType.FUNCTION,
    ["end"]      = TokenType.END,
}

----------------------------------------------------------------------------
--
-- Create a token.
--
-- @param  type     string      One of the TokenType values
-- @param  lexeme   string      Raw source text of the token
-- @param  literal  any|nil     Parsed value (strings and numbers only)
-- @param  line     number      Source line where the token appears
--
-- @return table                Token
--
----------------------------------------------------------------------------
local function Token(type, lexeme, literal, line)
    return {
        type = type,
        lexeme = lexeme,
        literal = literal,
        line = line
    }
end

----------------------------------------------------------------------------
--
-- Create a new scanner for the given source text.
--
-- @param  source  string       Luapp source code
--
-- @return Scanner              New scanner instance
--
----------------------------------------------------------------------------
function Scanner:new(source)
    return setmetatable({
        source = source,
        tokens = {},
        start = 1,
        current = 1,
        line = 1,
    }, Scanner)
end

----------------------------------------------------------------------------
--
-- Check whether all source characters have been consumed.
--
-- @return boolean             True if at end of source
--
----------------------------------------------------------------------------
function Scanner:isAtEnd()
    return self.current > #self.source
end

----------------------------------------------------------------------------
--
-- Consume and return the current character.
--
-- @return string              The consumed character
--
----------------------------------------------------------------------------
function Scanner:advance()
    local c = self.source:sub(self.current, self.current)
    self.current = self.current + 1
    return c
end

----------------------------------------------------------------------------
--
-- Add a token spanning from 'start' up to the current position.
--
-- @param  t        string      One of the TokenType values
-- @param  literal  any|nil     Parsed value, if the token has one
--
----------------------------------------------------------------------------
function Scanner:addToken(t, literal)
    local text = self.source:sub(self.start, self.current - 1)
    table.insert(self.tokens, Token(t, text, literal, self.line))
end

----------------------------------------------------------------------------
--
-- Consume the current character only if it equals the expected one.
--
-- @param  expected  string    Character to match
--
-- @return boolean             True if matched (and consumed)
--
----------------------------------------------------------------------------
function Scanner:match(expected)
    if self:isAtEnd() then return false end
    if self.source:sub(self.current, self.current) ~= expected then return false end
    self.current = self.current + 1
    return true
end

----------------------------------------------------------------------------
--
-- Look at the current character without consuming it.
--
-- @return string              Current character, or "\0" at end of source
--
----------------------------------------------------------------------------
function Scanner:peek()
    if self:isAtEnd() then return "\0" end
    return self.source:sub(self.current, self.current)
end

----------------------------------------------------------------------------
--
-- Look one character past the current one without consuming anything.
--
-- @return string              Next character, or "\0" past end of source
--
----------------------------------------------------------------------------
function Scanner:peekNext()
    if self.current + 1 > #self.source then return "\0" end
    return self.source:sub(self.current + 1, self.current + 1)
end

----------------------------------------------------------------------------
--
-- Scan the whole source into a list of tokens, terminated by an EOF token.
--
-- @return table               List of tokens
--
----------------------------------------------------------------------------
function Scanner:scanTokens()
    while not self:isAtEnd() do
        self.start = self.current
        self:scanToken()
    end

    table.insert(self.tokens, Token(TokenType.EOF, "", nil, self.line))
    return self.tokens
end

----------------------------------------------------------------------------
--
-- Check whether a character is a letter or underscore.
--
-- @param  c  string           Single character
--
-- @return boolean             True if alphabetic or '_'
--
----------------------------------------------------------------------------
function Scanner:isAlpha(c)
    return c:match("%a") ~= nil or c == "_"
end

----------------------------------------------------------------------------
--
-- Check whether a character is a decimal digit.
--
-- @param  c  string           Single character
--
-- @return boolean             True if a digit
--
----------------------------------------------------------------------------
function Scanner:isDigit(c)
    return c:match("%d") ~= nil
end

----------------------------------------------------------------------------
--
-- Check whether a character is a letter, underscore or digit.
--
-- @param  c  string           Single character
--
-- @return boolean             True if alphanumeric or '_'
--
----------------------------------------------------------------------------
function Scanner:isAlphaNumeric(c)
    return self:isAlpha(c) or self:isDigit(c)
end

----------------------------------------------------------------------------
--
-- Scan a single token starting at the current position. Whitespace is
-- skipped, newlines bump the line counter, and unknown characters raise
-- an error.
--
----------------------------------------------------------------------------
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

----------------------------------------------------------------------------
--
-- Scan a double-quoted string literal. The opening quote has already been
-- consumed. The token literal is the text between the quotes.
--
----------------------------------------------------------------------------
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

----------------------------------------------------------------------------
--
-- Scan an integer literal. The first digit has already been consumed.
--
----------------------------------------------------------------------------
function Scanner:number()
    while self:isDigit(self:peek()) do self:advance() end

    local value = tonumber(self.source:sub(self.start, self.current - 1))
    self:addToken(TokenType.NUMBER, value)
end

----------------------------------------------------------------------------
--
-- Scan an identifier or keyword. The first character has already been
-- consumed. Reserved words become keyword tokens, everything else
-- becomes an IDENTIFIER.
--
----------------------------------------------------------------------------
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
