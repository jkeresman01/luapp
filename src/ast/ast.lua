local ast = {}

----------------------------------------------------------------------------
--
-- Create a Class node, the root of the AST.
--
-- @param  name         string        Class name
-- @param  fields       table|nil     List of Field nodes (default: {})
-- @param  constructor  table|nil     Constructor node, if any
-- @param  methods      table|nil     List of Method nodes (default: {})
--
-- @return table                      Class node
--
----------------------------------------------------------------------------
function ast.Class(name, fields, constructor, methods)
    return {
        type = "Class",
        name = name,
        fields = fields or {},
        constructor = constructor or nil,
        methods = methods or {}
    }
end

----------------------------------------------------------------------------
--
-- Create a Field node describing a class field and its generated accessors.
--
-- @param  name        string        Field name
-- @param  access_get  string|nil    Getter visibility: "public", "private" or nil
-- @param  access_set  string|nil    Setter visibility: "public", "private" or nil
--
-- @return table                     Field node
--
----------------------------------------------------------------------------
function ast.Field(name, access_get, access_set)
    return {
        type = "Field",
        name = name,
        get = access_get,
        set = access_set 
    }
end

----------------------------------------------------------------------------
--
-- Create a Constructor node.
--
-- @param  params  table|nil     List of parameter names (default: {})
-- @param  body    string|nil    Raw body source text (default: "")
--
-- @return table                 Constructor node
--
----------------------------------------------------------------------------
function ast.Constructor(params, body)
    return {
        type = "Constructor",
        params = params or {},
        body = body or ""
    }
end

----------------------------------------------------------------------------
--
-- Create a Method node.
--
-- @param  name       string        Method name
-- @param  params     table|nil     List of parameter names (default: {})
-- @param  body       string|nil    Raw body source text (default: "")
-- @param  isPrivate  boolean|nil   True if declared with 'local function'
--
-- @return table                    Method node
--
----------------------------------------------------------------------------
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
