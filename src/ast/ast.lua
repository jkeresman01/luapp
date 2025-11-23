local ast = {}

function ast.Class(name, fields, constructor, methods)
    return {
        type = "Class",
        name = name,
        fields = fields or {},
        constructor = constructor or nil,
        methods = methods or {}
    }
end

function ast.Field(name, access_get, access_set)
    return {
        type = "Field",
        name = name,
        get = access_get,
        set = access_set 
    }
end

function ast.Constructor(params, body)
    return {
        type = "Constructor",
        params = params or {},
        body = body or ""
    }
end

function ast.Method(name, params, body, isPrivate)
    return {
        type = "Method",
        name = name,
        private = isPrivate or false,
        params = params or {},
        body = body or ""
    }
end

return ast

