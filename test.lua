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

local cands = M.candidates({ { name = "mba" }, { name = "pbox" } })
eq(#cands, 2, "candidates count")
eq(cands[1].on, "m", "candidates key1")
eq(cands[1].desc, "mba", "candidates desc1")
eq(cands[2].on, "p", "candidates key2")

if fails == 0 then
	print("ALL TESTS PASS")
else
	os.exit(1)
end
