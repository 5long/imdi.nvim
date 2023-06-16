local create_command = vim.api.nvim_create_user_command

create_command('IMEnable', function()
  require('imdi').enable_imdi_for_buffer()
end, {})

create_command('IMDisable', function()
  require('imdi').disable_imdi_for_buffer()
end, {})
