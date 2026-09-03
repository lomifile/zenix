local c = require("xcode-zenix.palette")

local function bar(fg, gui)
  return { fg = fg, bg = c.bg_chrome, gui = gui }
end

local function mode(fg)
  return {
    a = bar(fg, "bold"),
    b = bar(c.comment),
    c = bar(c.gutter),
    x = bar(c.comment),
    y = bar(c.comment),
    z = bar(c.comment),
  }
end

return {
  normal = mode(c.steel),
  insert = mode(c.cyan),
  visual = mode(c.pink),
  replace = mode(c.salmon),
  command = mode(c.orange),
  terminal = mode(c.teal),
  inactive = mode(c.gutter),
}
