local lazyroot = vim.fn.stdpath("data") .. "/lazy"
if not vim.loop.fs_stat(lazyroot .. "/lazy.nvim") then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazyroot .. "/lazy.nvim",
  })
end
vim.opt.rtp:prepend(lazyroot .. "/lazy.nvim")

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    
    -- Language & Tooling Extras
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.typescript" }, -- JS / TS / JSX / TSX
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.astro" },
    { import = "lazyvim.plugins.extras.lang.ruby" },
    { import = "lazyvim.plugins.extras.lang.tex" },       -- LaTeX
    { import = "lazyvim.plugins.extras.formatting.prettier" }, -- Prettier for HTML/CSS/JS/Astro
    
    -- Import custom user plugins from lua/plugins/
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true },
})

