-- taskguard.lua: single-flight hs.task runner with a hang watchdog.
--
-- Every background refresh in this config follows the same shape: kick off an
-- hs.task, ignore the call if one is already running, and update a cache from
-- the callback. Two hazards come with it:
--
--   1. An hs.task that isn't referenced can be garbage collected mid-run, and
--      then its callback never fires.
--   2. If the callback never fires, the "already in flight" guard latches and
--      that subsystem stops refreshing for the life of the session.
--
-- This holds the reference and terminates a task that overruns its timeout, so
-- the guard always clears.

local taskguard = {}

local DEFAULT_TIMEOUT = 20

-- taskguard.new(timeout) -> run(bin, args, onDone)
--
-- run() returns true if it started a task, false if one was already in flight
-- (or hs.task refused to build one). onDone receives (exitCode, stdOut, stdErr).
function taskguard.new(timeout)
    timeout = timeout or DEFAULT_TIMEOUT
    local task = nil
    local watchdog = nil

    local function clear()
        task = nil
        if watchdog then
            watchdog:stop()
            watchdog = nil
        end
    end

    return function(bin, args, onDone)
        if task then return false end

        task = hs.task.new(bin, function(exitCode, stdOut, stdErr)
            clear()
            if onDone then onDone(exitCode, stdOut, stdErr) end
        end, args)
        if not task then return false end

        task:start()

        watchdog = hs.timer.doAfter(timeout, function()
            watchdog = nil
            if task then
                pcall(function() task:terminate() end)
                task = nil
            end
        end)

        return true
    end
end

return taskguard
