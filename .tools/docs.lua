local path = require 'pandoc.path'
local utils = require 'pandoc.utils'
local stringify = utils.stringify

local function log(msg)
  io.stderr:write('[Docs.lua filter: ERROR] '..msg..'\n')
end

local function read_file (filename)
  local fh = io.open(filename)
  if not fh then
    log('Cannot read file '..filename..'.')
    return
  end
  local content = fh:read('*a')
  fh:close()
  return content
end

local formats_by_extension = {
  md = 'markdown',
  latex = 'latex',
  native = 'haskell',
  tex = 'latex',
  html = 'html',
}

local function sample_blocks(sample_file)
  local sample_content = read_file(sample_file)
  if not sample_content then
    return nil
  end
  local extension = select(2, path.split_extension(sample_file)):sub(2)
  local format = formats_by_extension[extension] or extension
  local filename = path.filename(sample_file)

  local sample_attr = pandoc.Attr('', {format, 'sample'})
  return {
    pandoc.Header(3, pandoc.Str(filename), {filename}),
    pandoc.CodeBlock(sample_content, sample_attr)
  }
end

local function result_block_raw(result_content, format)
  return pandoc.CodeBlock(result_content,
    pandoc.Attr('', {format, 'sample'})
  )
end

local function result_block_html(filename)
  local html = '<iframe width=100% height=720px '
    -- ..'src="'..filename..'" sandbox>\n'
    ..'src="'..filename..'">\n' -- non-sandbox to display linked images
    ..'<p><a href="'..filename..'">Click to see file</a></p>\n'
    ..'</iframe>'
  return pandoc.RawBlock('html', html)
end

local function result_blocks(result_file)
  local extension = select(2, path.split_extension(result_file)):sub(2)
  local format = formats_by_extension[extension] or extension
  local filename = path.filename(result_file)
  local result = nil

  if format == 'html' then 
    result = result_block_html(filename)
  else
    result = result_block_raw(result_file, format)
  end

  if result then
    return pandoc.List:new{
      pandoc.Header(3,
      pandoc.Link(pandoc.Str(filename), filename),
      { id = filename }
      ),
      result
    }
  end

end

local function code_blocks (code_file)
  local code_content = read_file(code_file)
  if code_content then
    local code_attr = pandoc.Attr(code_file, {'lua'})
    return {
      pandoc.CodeBlock(code_content, code_attr)
    }
  end
end

function Pandoc (doc)
  local meta = doc.meta
  local blocks = doc.blocks

  -- Ensure the document has a title: already set or first level 1 heading.
  if not meta.title then
    blocks = blocks:walk{
      Header = function (h)
        if h.level == 1 and not meta.title then
          meta.title = h.content
          return {}
        end
      end
    }
  end

  -- Add the sample file source and result as an example if both present.
  local spl_blocks = sample_blocks(stringify(meta['sample-file']))
  local res_blocks = result_blocks(stringify(meta['result-file']))
  if spl_blocks and res_blocks then
    blocks:extend{pandoc.Header(2, 'Example', pandoc.Attr('Example'))}
    blocks:extend(spl_blocks)
    blocks:extend(res_blocks)
  end

  -- Add the filter code.
  local code_file = stringify(meta['code-file'])
  local cde_blocks = code_blocks(code_file)
  if cde_blocks then
    blocks:extend{pandoc.Header(2, 'Code', pandoc.Attr('Code'))}
    blocks:extend{pandoc.Para{pandoc.Link(pandoc.Str(code_file), code_file)}}
    blocks:extend(cde_blocks)
  end

  return pandoc.Pandoc(blocks, meta)
end
