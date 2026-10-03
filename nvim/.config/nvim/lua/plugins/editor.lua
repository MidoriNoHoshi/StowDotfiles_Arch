return {
  -- Surround actions (cs"' to change surrounding quotes)
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- Extra treesitter parsers. LazyVim merges `ensure_installed` lists, so these
  -- add to the defaults. scss/tsx cover what Astro files commonly inject.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "astro",
        "bibtex",
        "css",
        "html",
        "javascript",
        "latex",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "ruby",
        "scss",
        "tsx",
        "typescript",
      },
    },
  },
}
