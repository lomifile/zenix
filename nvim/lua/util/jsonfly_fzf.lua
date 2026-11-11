local M = {}

M.config = {
  key_max_length = 60,
  value_max_length = 80,
  overflow_marker = "…",
  highlights = {
    key = "@property",
    string = "@string",
    number = "@number",
    boolean = "@boolean",
    null = "@constant.builtin",
    other = "@punctuation.bracket",
  },
}

local PAIRS = { pair = true, block_mapping_pair = true, flow_pair = true }
local SEQUENCES = { array = true, block_sequence = true, flow_sequence = true }
local WRAPPERS = { block_node = true, flow_node = true, plain_scalar = true, block_sequence_item = true }

local KINDS = {
  string = "string",
  string_scalar = "string",
  double_quote_scalar = "string",
  single_quote_scalar = "string",
  block_scalar = "string",
  number = "number",
  integer_scalar = "number",
  float_scalar = "number",
  ["true"] = "boolean",
  ["false"] = "boolean",
  boolean_scalar = "boolean",
  null = "null",
  null_scalar = "null",
}

local function unwrap(node)
  while node and WRAPPERS[node:type()] and node:named_child_count() > 0 do
    node = node:named_child(0)
  end
  return node
end

local function truncate(text, max)
  if vim.fn.strchars(text) <= max then
    return text
  end
  return vim.fn.strcharpart(text, 0, max - 1) .. M.config.overflow_marker
end

local function node_text(node, buf)
  return vim.treesitter.get_node_text(node, buf)
end

local function key_text(node, buf)
  local text = node_text(node, buf)
  return (text:gsub('^["\'](.*)["\']$', "%1"))
end

local function describe(node, buf)
  local inner = unwrap(node)
  if not inner then
    return "", "null"
  end
  local text = node_text(inner, buf):gsub("%s+", " ")
  return truncate(text, M.config.value_max_length), KINDS[inner:type()] or "other"
end

local function collect(root, buf)
  local entries = {}

  local function add(path, at, value)
    local row, col = at:range()
    local preview, kind = describe(value, buf)
    entries[#entries + 1] = {
      key = table.concat(path, "."),
      lnum = row + 1,
      col = col,
      preview = preview,
      kind = kind,
    }
  end

  local function walk(node, path)
    local t = node:type()
    if t == "comment" then
      return
    end
    if PAIRS[t] then
      local k, v = node:field("key")[1], node:field("value")[1]
      if not k then
        return
      end
      local child = vim.list_extend(vim.list_slice(path), { key_text(k, buf) })
      add(child, k, v)
      if v then
        walk(v, child)
      end
      return
    end
    if SEQUENCES[t] then
      local i = 0
      for item in node:iter_children() do
        if item:named() and item:type() ~= "comment" then
          local child = vim.list_extend(vim.list_slice(path), { tostring(i) })
          add(child, item, item)
          walk(item, child)
          i = i + 1
        end
      end
      return
    end
    for item in node:iter_children() do
      if item:named() then
        walk(item, path)
      end
    end
  end

  walk(root, {})
  return entries
end

local function show(entries, buf)
  local fzf = require("fzf-lua")
  local ansi = require("fzf-lua.utils").ansi_from_hl
  local cfg = M.config
  local filename = vim.api.nvim_buf_get_name(buf)

  local lines = {}
  for _, e in ipairs(entries) do
    lines[#lines + 1] = string.format(
      "%s:%d:%d:%s %s",
      filename,
      e.lnum,
      e.col + 1,
      ansi(cfg.highlights.key, truncate(e.key, cfg.key_max_length)),
      ansi(cfg.highlights[e.kind] or cfg.highlights.other, e.preview)
    )
  end

  fzf.fzf_exec(lines, {
    prompt = "󰍉  ",
    winopts = { title = " JSON keys " },
    previewer = "builtin",
    fzf_opts = {
      ["--ansi"] = true,
      ["--delimiter"] = ":",
      ["--with-nth"] = "4..",
    },
    actions = {
      ["default"] = function(selected)
        local line = selected and selected[1]
        if not line then
          return
        end
        local lnum, col = line:sub(#filename + 1):match("^:(%d+):(%d+):")
        if not lnum then
          return
        end
        vim.cmd("normal! m'")
        pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(lnum), tonumber(col) - 1 })
      end,
    },
  })
end

function M.collect(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end
  return collect(parser:parse()[1]:root(), buf)
end

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  local entries = M.collect(buf)
  if not entries then
    vim.notify("No treesitter parser for " .. vim.bo[buf].filetype, vim.log.levels.WARN)
    return
  end
  if #entries == 0 then
    vim.notify("No keys found", vim.log.levels.INFO)
    return
  end
  show(entries, buf)
end

return M
