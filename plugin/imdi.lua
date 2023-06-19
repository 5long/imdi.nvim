local create_command = vim.api.nvim_create_user_command

create_command('IMEnable', function()
  require('imdi').enable_forced_mode()
end, {})

create_command('IMDisable', function()
  require('imdi').disable_forced_mode()
end, {})

create_command('IMStickyEnable', function()
  require('imdi').enable_sticky_mode()
end, {})

create_command('IMStickyDisable', function()
  require('imdi').disable_sticky_mode()
end, {})
