return {
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup {
        auto_load = true, -- Automatically load preview when entering another markdown buffer.
        close_on_bdelete = true, -- Close preview window on buffer delete? What the fuck does that mean?
        theme = "dark", -- 'dark' or 'light'
        update_on_change = true, -- Update the preview when a change is made to the markdown file.
        throttle_at = 200000, -- Start throttling when file exceeds this amount in bytes (in file size)
        throttle_time = "auto", -- Minimum amount of time in milliseconds that has to pass before starting new render
        app = "browser", -- Options are 'webview' in which opens a webview window. 'browser' will use default browser as previewer. The browser can be specified with arguments:
        -- app = 'chromium'
        -- app = { 'chromium', '--new-window' }
        filetype = { "markdown" }, -- list of filetypes to recognize as markdown
      }
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
  },
}
