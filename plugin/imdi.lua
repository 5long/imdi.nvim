local imdi = require('imdi')

vim.api.nvim_create_user_command('IMEnable', imdi.enable_imdi_for_buffer, {})
vim.api.nvim_create_user_command('IMDisable', imdi.disable_imdi_for_buffer, {})
