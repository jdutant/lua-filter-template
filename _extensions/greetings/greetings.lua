
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------

do
    local searchers = package.searchers or package.loaders
    local origin_seacher = searchers[2]
    searchers[2] = function(path)
        local files =
        {
------------------------
-- Modules part begin --
------------------------

["other"] = function()
--------------------
-- Module: 'other'
--------------------
function dummy()
    return
end
end,

----------------------
-- Modules part end --
----------------------
        }
        if files[path] then
            return files[path]
        else
            return origin_seacher(path)
        end
    end
end
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------
--- greetings.lua – turns any document into a friendly greeting
---
--- Copyright: © 2021–2022 Contributors
--- License: MIT – see LICENSE for details

-- Makes sure users know if their pandoc version is too old for this
-- filter.
PANDOC_VERSION:must_be_at_least '2.17'

--- Amends the contents of a document with a simple greeting.
local function say_hello (doc)
  doc.meta.subtitle = doc.meta.title            -- demote title to subtitle
  doc.meta.title = pandoc.Inlines 'Greetings!'  -- set new title
  doc.blocks:insert(1, pandoc.Para 'Hello from the Lua filter!')
  return doc
end

return {
  -- Apply the `say_hello` function to the main Pandoc document.
  { Pandoc = say_hello }
}
