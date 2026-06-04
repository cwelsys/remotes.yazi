ya = { sync = function(f) return f end }

local here = arg[0]:match("^(.*/)") or "./"
local M = dofile(here .. "main.lua")

local fails = 0
local function eq(a, b, msg)
	if a ~= b then
		fails = fails + 1
		print(("FAIL %s: expected [%s] got [%s]"):format(msg or "", tostring(b), tostring(a)))
	end
end

local sample = [[
[services.mba]
type = "sftp"
host = "mba"
user = "cwel"
port = 22
os = "macos"

# a comment line
[services.pbox]
type = "sftp"
host = "pbox"
user = "cwel"
port = 22
]]

local h = M.parse_vfs(sample)
eq(#h, 2, "parse_vfs count")
eq(h[1].name, "mba", "parse_vfs name1")
eq(h[1].host, "mba", "parse_vfs host1")
eq(h[1].user, "cwel", "parse_vfs user1")
eq(h[1].os, "macos", "parse_vfs os1")
eq(h[2].name, "pbox", "parse_vfs name2")
eq(h[2].os, nil, "parse_vfs os2 absent")

local used = {}
eq(M.pick_key("mba", used), "m", "pick_key first letter")
eq(M.pick_key("pbox", used), "p", "pick_key second host")
eq(M.pick_key("main", used), "a", "pick_key collision -> next free letter")

local decoded = {
	Peer = {
		["k1"] = { HostName = "bmac", Online = true, OS = "macOS" },
		["k2"] = { HostName = "pbox", Online = true, OS = "linux" },
		["k3"] = { HostName = "mba", Online = false, OS = "macOS" },
	},
}
local sm = M.status_map(decoded)
eq(sm.bmac.online, true, "status_map bmac online")
eq(sm.bmac.os, "macOS", "status_map bmac os")
eq(sm.mba.online, false, "status_map mba offline")
eq(M.status_map(nil).x, nil, "status_map nil-safe")

local items = M.build_items({ { name = "mba" }, { name = "pbox" } }, sm)
eq(#items, 2, "build_items count")
eq(items[1].name, "pbox", "build_items online sorted first")
eq(items[1].online, true, "build_items first is online")
eq(items[1].key, "p", "build_items quick-key stays with host")
eq(items[2].name, "mba", "build_items offline after online")
eq(items[2].key, "m", "build_items offline quick-key in file order")
eq(items[2].os, "macOS", "build_items os from status")
eq(items[2].known, true, "build_items known peer")

local mixed = M.build_items({ { name = "aaa" }, { name = "ccc" }, { name = "ddd" } }, {
	ccc = { online = true, os = "linux" },
})
eq(mixed[1].name, "ccc", "build_items online floats to top")
eq(mixed[2].name, "aaa", "build_items rest keeps file order")
eq(mixed[3].name, "ddd", "build_items rest keeps file order 2")

local kless = M.build_items({ { name = "jelly" } }, {})
eq(kless[1].key, "e", "build_items reserves nav keys")
eq(kless[1].known, false, "build_items unknown when no status")

if fails == 0 then
	print("ALL TESTS PASS")
else
	os.exit(1)
end
