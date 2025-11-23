-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    "OXY2DEV/markview.nvim",
  },
  lazy = false,
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "astro",
      -- add more arguments for adding more treesitter parsers
    },
  },
}
