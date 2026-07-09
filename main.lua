local function default_output()
	local home = os.getenv("HOME")
	if home and home ~= "" then
		return home .. "/.local/state/yazi/tabs.dump"
	end

	return "/tmp/yazi-tabs.dump"
end

local function truthy(value)
	return value == true or value == "true" or value == "1" or value == "yes" or value == "on"
end

local function dirname(path)
	return path:match("^(.+)/[^/]+$")
end

local function debug_log(enabled, message)
	if not enabled then
		return
	end

	ya.dbg("dump-tabs: " .. message)
	ya.notify {
		title = "dump-tabs debug",
		content = message,
		level = "info",
		timeout = 2,
	}
end

local collect_tabs = ya.sync(function(sep)
	local function shell_escape(value)
		if value == nil then
			return "-"
		end

		local s = tostring(value)
		if s == "" then
			return "-"
		end

		-- Backslash-escape fields so the default space separator remains parseable.
		-- This is intentionally close to shell escaping, while keeping the output
		-- compact and easy to read: `/path/with space` -> `/path/with\ space`.
		s = s:gsub("\\", "\\\\")
		s = s:gsub("\n", "\\n")
		s = s:gsub("\r", "\\r")
		s = s:gsub("\t", "\\t")
		s = s:gsub(" ", "\\ ")

		return s
	end

	local lines = {}

	for i = 1, #cx.tabs do
		local tab = cx.tabs[i]
		local current = tab.current
		local hovered = current.hovered

		local fields = {
			shell_escape(i),
			shell_escape(i == cx.tabs.idx and "active" or "-"),
			shell_escape(tab.name),
			shell_escape(current.cwd),
			shell_escape(hovered and hovered.url or nil),
		}

		lines[#lines + 1] = table.concat(fields, sep)
	end

	return {
		data = table.concat(lines, "\n") .. "\n",
		count = #cx.tabs,
		active = cx.tabs.idx,
	}
end)

return {
	entry = function(_, job)
		local output = job.args.output or job.args[1] or default_output()
		local sep = job.args.sep or " "
		local debug = truthy(job.args.debug)

		debug_log(debug, "start output=" .. output .. " sep=" .. sep)

		local ok_collect, result = pcall(collect_tabs, sep)
		if not ok_collect then
			ya.err("dump-tabs collect failed: " .. tostring(result))
			ya.notify {
				title = "dump-tabs",
				content = "collect failed: " .. tostring(result),
				level = "error",
				timeout = 8,
			}
			return
		end

		debug_log(debug, "collected tabs=" .. tostring(result.count) .. " active=" .. tostring(result.active) .. " bytes=" .. tostring(#result.data))

		local dir = dirname(output)
		if dir and dir ~= "" then
			debug_log(debug, "ensure dir=" .. dir)
			local status, mkdir_err = Command("mkdir"):arg("-p"):arg(dir):status()
			if not status or not status.success then
				local msg = mkdir_err and tostring(mkdir_err) or "mkdir failed"
				ya.err("dump-tabs mkdir failed: " .. msg)
				ya.notify {
					title = "dump-tabs",
					content = "mkdir failed: " .. msg,
					level = "error",
					timeout = 8,
				}
				return
			end
		end

		debug_log(debug, "writing file")
		local ok_write, err = fs.write(Url(output), result.data)
		if not ok_write then
			ya.err("dump-tabs write failed: " .. tostring(err))
			ya.notify {
				title = "dump-tabs",
				content = "write failed: " .. tostring(err),
				level = "error",
				timeout = 8,
			}
			return
		end

		debug_log(debug, "done")
		ya.notify {
			title = "dump-tabs",
			content = "written: " .. output,
			level = "info",
			timeout = 3,
		}
	end,
}
