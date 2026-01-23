-- Add this plugin because in *.vue template
-- When toggle comment, it reports: Option 'commentstring' is empty
return {
  'folke/ts-comments.nvim',
  opts = {},
  event = 'VeryLazy',
  enabled = vim.fn.has 'nvim-0.10.0' == 1,
}
