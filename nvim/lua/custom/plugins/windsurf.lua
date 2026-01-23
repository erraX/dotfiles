local env = require 'custom/env'

if env == 'HOME' then
  return {}
else
  return {
    'Exafunction/windsurf.vim',
    event = 'BufEnter',
  }
end
