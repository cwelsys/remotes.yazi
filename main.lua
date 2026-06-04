local M = {}

function M.parse_vfs(text)
	local hosts, cur = {}, nil
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local s = line:match("^%s*(.-)%s*$")
		if s:sub(1, 1) == "#" then
		else
			local name = s:match("^%[services%.([%w%-]+)%]$")
			if name then
				cur = { name = name }
				hosts[#hosts + 1] = cur
			elseif cur then
				local k, v = s:match("^([%w_]+)%s*=%s*(.+)$")
				if k then
					cur[k] = (v:gsub('^"(.*)"$', "%1"))
				end
			end
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

function M.label(h, st)
	local dot = ""
	if st then
		dot = st.online and "● " or "○ "
	end
	local osname = (st and st.os) or h.os
	return dot .. h.name .. (osname and (" (" .. osname .. ")") or "")
end

function M.candidates(hosts, status)
	status = status or {}
	local used, cands = {}, {}
	for _, h in ipairs(hosts) do
		cands[#cands + 1] = { on = M.pick_key(h.name, used), desc = M.label(h, status[h.name]) }
	end
	return cands
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
	local items = {}
	for _, h in ipairs(hosts) do
		local st = status[h.name]
		items[#items + 1] = {
			name = h.name,
			key = M.pick_key(h.name, used),
			online = st and st.online or false,
			os = (st and st.os) or h.os,
			known = st ~= nil,
		}
	end
	return items
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

function M:entry()
	local hosts = M.read_hosts()
	if #hosts == 0 then
		ya.notify { title = "Remotes", content = "No services found in vfs.toml", level = "warn", timeout = 3 }
		return
	end

	local idx = ya.which { cands = M.candidates(hosts) }
	if not idx then
		return
	end

	ya.emit("tab_create", { "sftp://" .. hosts[idx].name })
end

return M
