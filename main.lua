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

return M
