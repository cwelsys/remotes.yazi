local M = {}

function M.parse_vfs(text)
	local hosts, cur = {}, nil
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local s = line:match("^%s*(.-)%s*$")
		if s:sub(1, 1) ~= "#" then
			-- Sections are `[scheme.domain]`, e.g. `[sftp.my-server]`. Yazi <26.x used
			-- `[services.name]` with a `type = "..."` key, still accepted below.
			local scheme, name = s:match("^%[([%w%-]+)%.([%w%-]+)%]$")
			if name then
				cur = { name = name, scheme = scheme }
				hosts[#hosts + 1] = cur
			elseif cur then
				local k, v = s:match("^([%w_]+)%s*=%s*(.+)$")
				if k then
					cur[k] = (v:gsub('^"(.*)"$', "%1"))
				end
			end
		end
	end
	for _, h in ipairs(hosts) do
		if h.scheme == "services" then
			h.scheme = h.type or "sftp"
		end
	end
	return hosts
end

function M.pick_key(name, used)
	for i = 1, #name do
		local c = name:sub(i, i):lower()
		if c:match("%w") and not used[c] then
			used[c] = true
			return c
		end
	end
	for d = 1, 9 do
		local c = tostring(d)
		if not used[c] then
			used[c] = true
			return c
		end
	end
	return "?"
end

function M.status_map(decoded)
	local map = {}
	if type(decoded) ~= "table" then
		return map
	end
	for _, peer in pairs(decoded.Peer or {}) do
		if type(peer) == "table" and peer.HostName then
			map[peer.HostName] = { online = peer.Online == true, os = peer.OS }
		end
	end
	return map
end

function M.build_items(hosts, status)
	status = status or {}
	local used = { q = true, j = true, k = true, l = true }
	local online, rest = {}, {}
	for _, h in ipairs(hosts) do
		local st = status[h.name] or (h.host and status[h.host])
		local item = {
			name = h.name,
			scheme = h.scheme or "sftp",
			key = M.pick_key(h.name, used),
			online = st and st.online or false,
			os = (st and st.os) or h.os,
			known = st ~= nil,
		}
		local bucket = (item.known and item.online) and online or rest
		bucket[#bucket + 1] = item
	end
	for _, item in ipairs(rest) do
		online[#online + 1] = item
	end
	return online
end

function M.read_hosts()
	local base = os.getenv("YAZI_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/yazi")
	local f = io.open(base .. "/vfs.toml", "r")
	if not f then
		return {}
	end
	local text = f:read("*a")
	f:close()
	return M.parse_vfs(text)
end

function M.fetch_status()
	local ok, output = pcall(function()
		return Command("tailscale"):arg({ "status", "--json" }):output()
	end)
	if not ok or not output or not output.status or not output.status.success then
		return {}
	end
	return M.status_map(ya.json_decode(output.stdout or ""))
end

local toggle_ui = ya.sync(function(st)
	if st.children then
		Modal:children_remove(st.children)
		st.children = nil
	else
		st.children = Modal:children_add(st, 10)
	end
	ui.render()
end)

local set_items = ya.sync(function(st, items)
	st.items = items
	st.cursor = 0
	ui.render()
end)

local update_cursor = ya.sync(function(st, step)
	local n = st.items and #st.items or 0
	st.cursor = n == 0 and 0 or ya.clamp(0, (st.cursor or 0) + step, n - 1)
	ui.render()
end)

local active_item = ya.sync(function(st)
	return st.items and st.items[(st.cursor or 0) + 1]
end)

function M:new(area)
	self:layout(area)
	return self
end

function M:layout(area)
	local n = self.items and #self.items or 0
	local v = ui.Layout()
		:direction(ui.Layout.VERTICAL)
		:constraints({ ui.Constraint.Fill(1), ui.Constraint.Length(n + 4), ui.Constraint.Fill(1) })
		:split(area)
	local h = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({ ui.Constraint.Fill(1), ui.Constraint.Percentage(44), ui.Constraint.Fill(1) })
		:split(v[2])
	self._area = h[2]
end

function M:redraw()
	if not self._area then
		return {}
	end
	local rows = {}
	for _, it in ipairs(self.items or {}) do
		local dot
		if not it.known then
			dot = ui.Span(" ")
		elseif it.online then
			dot = ui.Span("●"):fg("green")
		else
			dot = ui.Span("○"):fg("darkgray")
		end
		rows[#rows + 1] = ui.Row { it.key, dot, it.name, it.os or "" }
	end
	return {
		ui.Clear(self._area),
		ui.Border(ui.Edge.ALL)
			:area(self._area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg("blue"))
			:title(ui.Line(" Remotes  ·  j/k move  ·  ⏎ connect  ·  q quit "):align(ui.Align.CENTER)),
		ui.Table(rows)
			:area(self._area:pad(ui.Pad(1, 2, 1, 2)))
			:row(self.cursor)
			:row_style(ui.Style():fg("blue"):underline())
			:widths({
				ui.Constraint.Length(3),
				ui.Constraint.Length(2),
				ui.Constraint.Fill(1),
				ui.Constraint.Length(8),
			}),
	}
end

function M:reflow()
	return { self }
end

function M:click() end

function M:scroll() end

function M:touch() end

function M:entry()
	local hosts = M.read_hosts()
	if #hosts == 0 then
		ya.notify { title = "Remotes", content = "No hosts found in vfs.toml", level = "warn", timeout = 3 }
		return
	end

	local items = M.build_items(hosts, M.fetch_status())
	set_items(items)
	toggle_ui()

	local keys = {
		{ on = "q", run = "quit" },
		{ on = "<Esc>", run = "quit" },
		{ on = "k", run = "up" },
		{ on = "<Up>", run = "up" },
		{ on = "j", run = "down" },
		{ on = "<Down>", run = "down" },
		{ on = "<Enter>", run = "enter" },
		{ on = "l", run = "enter" },
		{ on = "<Right>", run = "enter" },
	}
	local base_n = #keys
	for _, it in ipairs(items) do
		keys[#keys + 1] = { on = it.key, run = "enter" }
	end

	local chosen
	while true do
		local idx = ya.which { cands = keys, silent = true }
		if not idx then
			break
		end
		local run = keys[idx].run
		if run == "quit" then
			break
		elseif run == "up" then
			update_cursor(-1)
		elseif run == "down" then
			update_cursor(1)
		elseif run == "enter" then
			chosen = idx > base_n and items[idx - base_n] or active_item()
			break
		end
	end

	toggle_ui()
	if chosen then
		ya.emit("tab_create", { chosen.scheme .. "://" .. chosen.name })
	end
end

return M
