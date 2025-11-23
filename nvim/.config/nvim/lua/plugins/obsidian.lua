return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "Test_vault",
        path = "~/Documents/ObsidianVaults/Test_vault",
      },
      {
        name = "Nemi",
        path = "~/Documents/ObsidianVaults/Nemi",
      },
      {
        name = "DP1 ~ DP2",
        path = "~/Documents/ObsidianVaults/DP1 ~ DP2/",
      },
    },

    daily_notes = {
      folder = "日記",
      date_format = "%Y-%m-%d",
      default_tags = nil,
      template = "Template v2.md",
    },

    templates = {
      folder = "日記",
    },

    ui = {
      enable = true,
    },

    -- see below for full list of options 👇

    disable_frontmatter = true,
  },
}
