--- @sync entry

local function default_output(format)
  local state_home = os.getenv('XDG_STATE_HOME')
  local home = os.getenv('HOME')
  local name = format == 'nul' and 'tabs.nul' or 'tabs.dump'
  if state_home and state_home ~= '' then
    return state_home .. '/yazi/' .. name
  end

  if home and home ~= '' then
    return home .. '/.local/state/yazi/' .. name
  end

  return '/tmp/yazi-' .. name
end

local function truthy(value)
  return value == true or value == 'true' or value == '1' or value == 'yes' or value == 'on'
end

local function dirname(path)
  return path:match('^(.+)/[^/]+$')
end

local function shell_escape_field(value)
  if value == nil then
    return '-'
  end

  local s = tostring(value)
  if s == '' then
    return '-'
  end

  -- Backslash-escape fields so the default space separator remains parseable
  -- for humans/debugging. For machine restore, prefer --format=cmd or --format=nul.
  s = s:gsub('\\', '\\\\')
  s = s:gsub('\n', '\\n')
  s = s:gsub('\r', '\\r')
  s = s:gsub('\t', '\\t')
  s = s:gsub(' ', '\\ ')

  return s
end

local function sh_quote(value)
  local s = tostring(value or '')
  -- POSIX single-quote escaping: abc'def -> 'abc'\''def'
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function debug_log(enabled, message)
  if not enabled then
    return
  end

  ya.dbg('dump-tabs: ' .. message)
  ya.notify({
    title = 'dump-tabs debug',
    content = message,
    level = 'info',
    timeout = 2,
  })
end

local function tab_target(tab)
  return tostring(tab.current.cwd)
end

local function collect_table(sep)
  local lines = {}

  for i = 1, #cx.tabs do
    local tab = cx.tabs[i]
    local current = tab.current
    local hovered = current.hovered

    local fields = {
      shell_escape_field(i),
      shell_escape_field(i == cx.tabs.idx and 'active' or '-'),
      shell_escape_field(tab.name),
      shell_escape_field(current.cwd),
      shell_escape_field(hovered and hovered.url or nil),
    }

    lines[#lines + 1] = table.concat(fields, sep)
  end

  return table.concat(lines, '\n') .. '\n', #cx.tabs, cx.tabs.idx
end

local function collect_lines()
  local lines = {}
  for i = 1, #cx.tabs do
    lines[#lines + 1] = tab_target(cx.tabs[i])
  end
  return table.concat(lines, '\n') .. '\n', #cx.tabs, cx.tabs.idx
end

local function collect_nul()
  local parts = {}
  for i = 1, #cx.tabs do
    parts[#parts + 1] = tab_target(cx.tabs[i])
  end
  return table.concat(parts, '\0') .. '\0', #cx.tabs, cx.tabs.idx
end

local function collect_cmd()
  local parts = { 'yazi' }
  for i = 1, #cx.tabs do
    parts[#parts + 1] = sh_quote(tab_target(cx.tabs[i]))
  end
  return table.concat(parts, ' ') .. '\n', #cx.tabs, cx.tabs.idx
end

local function collect_tabs(format, sep)
  if format == 'table' then
    return collect_table(sep)
  elseif format == 'lines' then
    return collect_lines()
  elseif format == 'nul' then
    return collect_nul()
  elseif format == 'cmd' then
    return collect_cmd()
  else
    error('unknown format: ' .. tostring(format))
  end
end

return {
  entry = function(_, job)
    local args = job.args or {}
    local format = args.format or args.fmt or 'table'
    local output = args.output or args[1] or default_output(format)
    local sep = args.sep or ' '
    local debug = truthy(args.debug)

    debug_log(debug, 'start output=' .. output .. ' format=' .. format .. ' sep=' .. sep)

    local ok_collect, data, count, active = pcall(collect_tabs, format, sep)
    if not ok_collect then
      ya.err('dump-tabs collect failed: ' .. tostring(data))
      ya.notify({
        title = 'dump-tabs',
        content = 'collect failed: ' .. tostring(data),
        level = 'error',
        timeout = 8,
      })
      return
    end

    debug_log(
      debug,
      'collected tabs='
        .. tostring(count)
        .. ' active='
        .. tostring(active)
        .. ' bytes='
        .. tostring(#data)
    )

    local dir = dirname(output)

    -- `entry` is sync so it can read `cx` directly. File I/O is async-only,
    -- so hand only plain sendable values to the async context and finish there.
    ya.async(function()
      if dir and dir ~= '' then
        if debug then
          ya.dbg('dump-tabs: ensure dir=' .. dir)
          ya.notify({
            title = 'dump-tabs debug',
            content = 'ensure dir=' .. dir,
            level = 'info',
            timeout = 2,
          })
        end

        local status, mkdir_err = Command('mkdir'):arg('-p'):arg(dir):status()
        if not status or not status.success then
          local msg = mkdir_err and tostring(mkdir_err) or 'mkdir failed'
          ya.err('dump-tabs mkdir failed: ' .. msg)
          ya.notify({
            title = 'dump-tabs',
            content = 'mkdir failed: ' .. msg,
            level = 'error',
            timeout = 8,
          })
          return
        end
      end

      if debug then
        ya.dbg('dump-tabs: writing file')
        ya.notify({
          title = 'dump-tabs debug',
          content = 'writing file',
          level = 'info',
          timeout = 2,
        })
      end

      local ok_write, err = fs.write(Url(output), data)
      if not ok_write then
        ya.err('dump-tabs write failed: ' .. tostring(err))
        ya.notify({
          title = 'dump-tabs',
          content = 'write failed: ' .. tostring(err),
          level = 'error',
          timeout = 8,
        })
        return
      end

      if debug then
        ya.dbg('dump-tabs: done')
        ya.notify({ title = 'dump-tabs debug', content = 'done', level = 'info', timeout = 2 })
      end

      ya.notify({
        title = 'dump-tabs',
        content = 'written: ' .. output,
        level = 'info',
        timeout = 3,
      })
    end)
  end,
}
