local dbus = require('dbus_proxy')
local uv = vim.uv or vim.loop

local M = {}
local fcitx5 = nil

local function connect_dbus()
  return dbus.Proxy:new(
    {
      bus = dbus.Bus.SESSION,
      name = "org.fcitx.Fcitx5",
      interface = "org.fcitx.Fcitx.Controller1",
      path = "/controller"
    }
  )
end

local function init()
  fcitx5 = fcitx5 or connect_dbus()
end

local function activate()
  init()
  fcitx5:Activate()
end

local function deactivate()
  init()
  fcitx5:Deactivate()
end

local function augroup_name_for_buffer(bufnr)
  return 'imdi-' .. bufnr
end

local function clear_autocmd(bufnr)
  local function error_handler(err)
    if string.find(err, " Vim:E367: ") then
      -- Autocmd group doesn't exist. Nothing to do though.
      return
    else
      print(debug.traceback())
    end
  end

  xpcall(function()
    vim.api.nvim_del_augroup_by_name(augroup_name_for_buffer(bufnr))
  end, error_handler)
end

local function register_autocmd(bufnr)
  local augroup = vim.api.nvim_create_augroup(
    augroup_name_for_buffer(bufnr), { clear = true })

  vim.api.nvim_create_autocmd('InsertEnter', {
    buffer = bufnr,
    group = augroup,
    callback = activate,
  })
  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = bufnr,
    group = augroup,
    callback = deactivate,
  })
end

M.enable_imdi_for_buffer = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  register_autocmd(bufnr)
end

M.disable_imdi_for_buffer = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  clear_autocmd(bufnr)
end

return M
