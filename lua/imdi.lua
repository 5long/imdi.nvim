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

local function force_init()
  fcitx5 = connect_dbus()
  return fcitx5:Ping()
end

local function init()
  if fcitx5 then
    return {}, nil
  else
    return force_init()
  end
end

local function activate()
  init()
  local ok, err = fcitx5:Activate()

  if ok then
    return
  end

  vim.notify("imdi: failed to activate input method. Reconnecting")
  local ok, err = force_init()
  if ok then
    fcitx5:Activate()
  else
    vim.notify("imdi: unable to activate input method:\n" .. tostring(err))
  end
end

local function deactivate()
  init()
  local ok, err = fcitx5:Deactivate()

  if ok then return end

  vim.notify("imdi: failed to deactivate input method. Reconnecting")
  local ok, err = force_init()
  if ok then
    fcitx5:Deactivate()
  else
    vim.notify("imdi: unable to deactivate input method:\n" .. tostring(err))
  end
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

local function should_activate(m)
  -- Neovim doesn't trigger ModeChanged new_mode=no* yet
  return m == 'i' or m == 'R' or string.find(m, 'no')
end

local function should_deactivate(m)
  return m == 'n' or string.find(m, 'ni')
end

local function mode_changed(ev)
  local m = vim.fn.mode(1)

  if should_activate(m) then
    return activate()
  end

  if should_deactivate(m) then
    return deactivate()
  end
end

local function register_autocmd(bufnr)
  local augroup = vim.api.nvim_create_augroup(
    augroup_name_for_buffer(bufnr), { clear = true })

  -- ModeChanged matches by pattern
  -- But we can't match w/ both buffer & pattern
  vim.api.nvim_create_autocmd('ModeChanged', {
    buffer = bufnr,
    group = augroup,
    callback = mode_changed,
  })
end

M.enable_imdi_for_buffer = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  init()
  register_autocmd(bufnr)
end

M.disable_imdi_for_buffer = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  clear_autocmd(bufnr)
end

return M
