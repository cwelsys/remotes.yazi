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

return M
