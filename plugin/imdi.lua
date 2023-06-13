vim.api.nvim_create_user_command('IMEnable', function()
  require('imdi').enable_imdi_for_buffer()
end, {})

vim.api.nvim_create_user_command('IMDisable', function()
  require('imdi').disable_imdi_for_buffer()
end, {})
