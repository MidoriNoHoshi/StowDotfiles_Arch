-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- Put Mason's bin dir on PATH up front. Mason normally does this when it loads,
-- but nvim-treesitter needs the `tree-sitter` CLI earlier (e.g. its build hook
-- after `:Lazy update`), and without it parsers silently fail to rebuild and
-- drift out of sync with their queries.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if not vim.env.PATH:find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end

-- Neovim doesn't detect MDX (common in Astro projects); treat it as markdown for treesitter
vim.filetype.add({ extension = { mdx = "mdx" } })
vim.treesitter.language.register("markdown", "mdx")

-- Soft wrap long lines at word boundaries, keeping indentation
opt.wrap = true
opt.linebreak = true
opt.breakindent = true
opt.breakindentopt = { "shift:2", "list:-1" } -- extra indent on continuations, align wrapped list items
opt.showbreak = "↪ "

-- Indentation defaults
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
