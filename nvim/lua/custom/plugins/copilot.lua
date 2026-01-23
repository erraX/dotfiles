local env = require 'custom/env'

if env == 'HOME' then
  return {
    'github/copilot.vim',
  }
else
  return {}
end
