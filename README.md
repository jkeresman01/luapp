# Luapp

**Luapp** is a small programming language that adds a familiar object-oriented syntax and ports Kotlin collections 
framework to Lua.


It transpiles lua++ file into valid lua code.


Code writen in lua++
```lua
class Person
    local _name ( get, set )
    local _age  ( get, local set )

    Person(name, age)
        self._name = name
        self._age = age
    end

    local function is_minor()
        return self._age < 18
    end

    function description()
        if is_minor() then
            return "I am a minor"
        else
            return "I am an adult"
        end
    end

end

Same code written in pure lua (we transpile to this)

```lua
local Person = {}
Person.__index = Person

function Person:new(name, age)
    local self = setmetatable({}, Person)
    self._name = name
    self._age = age
    return self
end

function Person:get_name() return self._name end
function Person:set_name(v) self._name = v end
function Person:get_age()  return self._age end

local function Person_set_age(self, v)
    self._age = v
end

function Person:is_minor()
    return self._age < 18
end

function Person:description()
    if self:is_minor() then
        return "I am a minor"
    else
        return "I am an adult"
    end
end

return Person
```
