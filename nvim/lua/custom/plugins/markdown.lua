return {
  -- {
  --   'MeanderingProgrammer/render-markdown.nvim',
  --   ft = { 'markdown' },
  --   dependencies = {
  --     'nvim-treesitter/nvim-treesitter',
  --     'nvim-tree/nvim-web-devicons',
  --   },
  --   opts = {},
  -- },
  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    build = 'cd app && npx --yes yarn install',
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', desc = '[M]arkdown [P]review' },
    },
  },
}
