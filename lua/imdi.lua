local dbus = require('dbus_proxy')

local M = {}
local fcitx5 = nil
local FCITX5_STATE_ACTIVE = 2
local FCITX5_STATE_INACTIVE = 1

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

local function reconnect_and_retry(action)
  vim.notify("imdi: failed to " .. action .. "(). Reconnecting")
  local ok, err = force_init()
  if ok then
    fcitx5[action](fcitx5)
  else
    vim.notify("imdi: unable to reconnect to DBus:\n" .. tostring(err))
  end
end

local function activate()
  init()
  local ok, _ = fcitx5:Activate()
  if not ok then reconnect_and_retry("Activate") end
end

local function deactivate()
  init()
  local ok, _ = fcitx5:Deactivate()
  if not ok then reconnect_and_retry("Deactivate") end
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

local function is_cmd_search_mode(m)
  if m ~= 'c' then
    return false
  end
  local cmdtype = vim.fn.getcmdtype() 
  return cmdtype == '/' or cmdtype == '?'
end

local function should_activate(m)
  return m == 'i' or m == 'R' or is_cmd_search_mode(m)
end

local function should_deactivate(m)
  return m == 'n' or string.find(m, 'ni')
end

local function mode_changed(_)
  local m = vim.fn.mode(1)

  if should_activate(m) then
    return activate()
  end

  if should_deactivate(m) then
    return deactivate()
  end
end

local function register_autocmd(bufnr)
  local augroup_name = augroup_name_for_buffer(bufnr)
  local existing_augroup = vim.api.nvim_create_augroup(
    augroup_name, { clear = false })

  local existing_autocmd = vim.api.nvim_get_autocmds({
    group = existing_augroup})
  if #existing_autocmd ~= 0 then
    return
  end

  local augroup = vim.api.nvim_create_augroup(
    augroup_name, { clear = true })

  -- ModeChanged matches by pattern
  -- But we can't match w/ both buffer & pattern
  vim.api.nvim_create_autocmd('ModeChanged', {
    buffer = bufnr,
    group = augroup,
    callback = mode_changed,
  })
end

local function evaluate_sticky_situation(bufnr)
  init()
  local im_state = fcitx5:State()
  if im_state == FCITX5_STATE_ACTIVE then
    M.enable_forced_mode(bufnr)
  elseif im_state == FCITX5_STATE_INACTIVE then
    M.disable_forced_mode(bufnr)
  else
    print("imdi: unknown input method state "
      .. im_state .. ". Don't know what to do")
  end
end

local function clear_sticky_autocmd(bufnr)
  local augroup = 'imdi-sticky-' .. bufnr
  vim.api.nvim_del_augroup_by_name(augroup)
end

local function registry_sticky_autocmd(bufnr)
  local augroup = vim.api.nvim_create_augroup(
    'imdi-sticky-' .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd('InsertLeavePre', {
    buffer = bufnr,
    group = augroup,
    callback = function()
      evaluate_sticky_situation(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('CmdlineLeave', {
    buffer = bufnr,
    group = augroup,
    callback = function()
      local m = vim.fn.mode(1)
      if is_cmd_search_mode(m) then
        evaluate_sticky_situation(bufnr)
      end
    end,
  })
end

M.enable_forced_mode = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  init()
  register_autocmd(bufnr)
end

M.disable_forced_mode = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  clear_autocmd(bufnr)
end

M.get_fcitx5_conn = function ()
  return fcitx5
end

M.enable_sticky_mode = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  registry_sticky_autocmd(bufnr)
end

M.disable_sticky_mode = function(bufnr)
  bufnr = (bufnr or bufnr ~= 0) and bufnr or vim.fn.bufnr()
  clear_sticky_autocmd(bufnr)
  M.disable_forced_mode(bufnr)
end

return M
