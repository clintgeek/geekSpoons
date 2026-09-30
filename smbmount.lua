local env = require("env")

local smbmount = {}

local KEYCHAIN_SERVICE = env.get("SMB_KEYCHAIN_SERVICE", "SERVER._smb._tcp.local")
local KEYCHAIN_ACCOUNT = env.get("SMB_KEYCHAIN_ACCOUNT", "crocker")
local MOUNT_CHECK_INTERVAL = 5
local MOUNT_RETRY_COOLDOWN = 30
-- Ceiling on a single mount round. mount_smbfs can hang on an unreachable or
-- half-answering server, and without this the isMounting latch below would
-- never clear and mounting would stop being retried for the session.
local MOUNT_ROUND_TIMEOUT = 60

local SHARES = {
    { name = "extra_space", remote = "//crocker@server.local/extra_space", mountPoint = os.getenv("HOME") .. "/mnt/server/extra_space" },
    { name = "media", remote = "//crocker@server.local/Media", mountPoint = os.getenv("HOME") .. "/mnt/server/media" },
    { name = "next_cloud", remote = "//crocker@server.local/NextCloud", mountPoint = os.getenv("HOME") .. "/mnt/server/next_cloud" },
}

local timer = nil
local tasks = {}
local isMounting = false
local mountRoundWatchdog = nil
local lastAttempt = 0
local parentMount = os.getenv("HOME") .. "/mnt/server"
local parentDev = nil

local function isMounted(mountPoint)
    local ok, dev = pcall(hs.fs.attributes, mountPoint, "dev")
    return ok and dev and parentDev and dev ~= parentDev
end

local function mountShare(share, onDone)
    local tmp = (hs.execute("mktemp -t smbmount.XXXXXX.exp 2>/dev/null") or ""):gsub("%s+$", "")
    if tmp == "" then
        onDone()
        return
    end
    local f = io.open(tmp, "w")
    if not f then
        os.remove(tmp)
        onDone()
        return
    end
    f:write([[
set timeout 30
set server [lindex $argv 0]
set account [lindex $argv 1]
set remote [lindex $argv 2]
set mnt [lindex $argv 3]

set pass ""
if { [catch { exec /bin/sh -c "/usr/bin/security find-internet-password -s \"$server\" -a \"$account\" -w 2>/dev/null" } pass] } { set pass "" }
if { $pass == "" } {
    if { [catch { exec /bin/sh -c "/usr/bin/security find-generic-password -s \"$server\" -a \"$account\" -w 2>/dev/null" } pass] } { set pass "" }
}
set pass [string trim $pass]

spawn /sbin/mount_smbfs $remote $mnt
expect {
    -re "Password.*:" {
        send -- $pass
        send -- "\r"
        exp_continue
    }
    eof
    timeout
}
catch { wait }
]])
    f:close()

    local function cleanup(exitCode, stdOut, stdErr)
        if exitCode ~= 0 then
            print("smbmount: " .. share.name .. " failed (" .. tostring(exitCode) .. "): " .. (stdErr or "") .. (stdOut or ""))
        else
            print("smbmount: " .. share.name .. " mounted")
        end
        tasks[share.name] = nil
        pcall(onDone)
        os.remove(tmp)
    end

    local task = hs.task.new("/usr/bin/expect", cleanup, { tmp, KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT, share.remote, share.mountPoint })
    if task then
        tasks[share.name] = task
        if not task:start() then
            tasks[share.name] = nil
            os.remove(tmp)
            onDone()
        end
    else
        os.remove(tmp)
        onDone()
    end
end

local function endMountRound()
    isMounting = false
    if mountRoundWatchdog then
        mountRoundWatchdog:stop()
        mountRoundWatchdog = nil
    end
end

local function attemptMounts()
    if isMounting then return end
    local now = os.time()
    if now - lastAttempt < MOUNT_RETRY_COOLDOWN then return end
    lastAttempt = now
    isMounting = true

    local pending = 0
    local function onOneDone()
        pending = pending - 1
        if pending <= 0 then endMountRound() end
    end

    for _, share in ipairs(SHARES) do
        if not isMounted(share.mountPoint) then
            pending = pending + 1
            mountShare(share, onOneDone)
        end
    end
    if pending == 0 then
        endMountRound()
        return
    end

    mountRoundWatchdog = hs.timer.doAfter(MOUNT_ROUND_TIMEOUT, function()
        mountRoundWatchdog = nil
        for name, task in pairs(tasks) do
            if name ~= "__nc" and task then
                pcall(function() task:terminate() end)
                tasks[name] = nil
            end
        end
        isMounting = false
        print("smbmount: mount round timed out after " .. MOUNT_ROUND_TIMEOUT .. "s")
    end)
end

local function check()
    if tasks["__nc"] then return end
    local task = hs.task.new("/usr/bin/nc", function(exitCode, stdOut, stdErr)
        tasks["__nc"] = nil
        if exitCode == 0 then
            for _, share in ipairs(SHARES) do
                if not isMounted(share.mountPoint) then
                    attemptMounts()
                    return
                end
            end
        end
    end, { "-z", "-w", "1", "server.local", "445" })
    if not task then return end
    tasks["__nc"] = task
    if not task:start() then
        tasks["__nc"] = nil
    end
end

function smbmount.start()
    -- hs.fs.attributes *returns* nil for a missing path instead of raising, so
    -- pcall succeeds and only `dev` tells us whether the read worked. Checking
    -- `ok` made this warning unreachable, and a nil parentDev makes isMounted()
    -- always false -- which had every share re-mounting every cooldown forever.
    local ok, dev = pcall(hs.fs.attributes, parentMount, "dev")
    parentDev = ok and dev or nil
    if not parentDev then
        print("smbmount: could not read parent mount directory " .. parentMount ..
              " -- create it (mkdir -p) or mount detection cannot work")
        return
    end
    if timer then timer:stop() end
    timer = hs.timer.doEvery(MOUNT_CHECK_INTERVAL, check)
    hs.timer.doAfter(2, check)
end

return smbmount
