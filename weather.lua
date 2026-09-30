local weather = {}

local env = require("env")
local WEATHER_LOCATION = env.get("WEATHER_LOCATION") or "Arkadelphia, AR"

local REFRESH_INTERVAL = 10 * 60
local FETCH_TIMEOUT = 25  -- watchdog; curl's own -m is 15s
local cachedState = { available = false }
local refreshTimer = nil
local running = false
-- Keep the task referenced until it exits. An unreferenced hs.task can be
-- collected mid-run, and since `running` is only cleared inside the callback,
-- a collected task latched the guard below and stopped weather refreshing for
-- the rest of the session.
local taskRef = nil
local watchdog = nil

local WEATHER_BACKGROUNDS = {
    sunny = "https://images.unsplash.com/photo-1601297183305-6df142704ea2?w=800&h=400&fit=crop&q=80",
    clear = "https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=800&h=400&fit=crop&q=80",
    cloudy = "https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800&h=400&fit=crop&q=80",
    rainy = "https://images.unsplash.com/photo-1428908728789-d2de25dbd4e2?w=800&h=400&fit=crop&q=80",
    snow = "https://images.unsplash.com/photo-1491002052546-bf38f186af56?w=800&h=400&fit=crop&q=80",
    fog = "https://images.unsplash.com/photo-1487621167305-5d248087c724?w=800&h=400&fit=crop&q=80",
    partly = "https://images.unsplash.com/photo-1513002749550-c59d786b8e6c?w=800&h=400&fit=crop&q=80"
}

local function getWeatherBackground(condition)
    if not condition then return WEATHER_BACKGROUNDS.partly end
    local c = condition:lower()
    
    if c:find("clear") or c:find("sun") then
        return WEATHER_BACKGROUNDS.sunny
    elseif c:find("rain") or c:find("drizzle") or c:find("shower") then
        return WEATHER_BACKGROUNDS.rainy
    elseif c:find("snow") or c:find("sleet") then
        return WEATHER_BACKGROUNDS.snow
    elseif c:find("fog") or c:find("mist") then
        return WEATHER_BACKGROUNDS.fog
    elseif c:find("cloud") or c:find("overcast") then
        return WEATHER_BACKGROUNDS.cloudy
    elseif c:find("partly") then
        return WEATHER_BACKGROUNDS.partly
    else
        return WEATHER_BACKGROUNDS.partly
    end
end

local function finish()
    running = false
    taskRef = nil
    if watchdog then
        watchdog:stop()
        watchdog = nil
    end
end

local function refresh()
    if running then return end
    running = true

    taskRef = hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        finish()
        if exitCode ~= 0 or not stdOut or stdOut:gsub("%s+", "") == "" then
            cachedState = { available = false }
            return
        end

        local ok, data = pcall(hs.json.decode, stdOut)
        if not ok or not data or not data.current_condition or not data.current_condition[1] then
            cachedState = { available = false }
            return
        end

        local current = data.current_condition[1]
        local hourly = nil
        if data.weather and data.weather[1] and data.weather[1].hourly and data.weather[1].hourly[1] then
            hourly = data.weather[1].hourly[1]
        end

        local condition = ""
        if current.weatherDesc and current.weatherDesc[1] then
            condition = current.weatherDesc[1].value or ""
            condition = condition:gsub("^%s+", ""):gsub("%s+$", "")
        end

        local rainChance = 0
        if hourly and hourly.chanceofrain then
            rainChance = tonumber(hourly.chanceofrain) or 0
        end

        local icon = ""
        if current.weatherIconUrl and current.weatherIconUrl[1] then
            icon = current.weatherIconUrl[1].value or ""
        end

        local unsplashBg = getWeatherBackground(condition)

        local windMph = current.windspeedMiles or ""
        local windDir = current.winddir16Point or ""
        local uvIndex = current.uvIndex or ""
        local visibility = current.visibility or ""
        local pressure = current.pressure or ""

        local forecast = {}
        if data.weather then
            for i = 1, math.min(#data.weather, 3) do
                local day = data.weather[i]
                local dayCondition = ""
                if day.hourly and #day.hourly > 4 then
                    local h = day.hourly[4]
                    if h.weatherDesc and h.weatherDesc[1] then
                        dayCondition = h.weatherDesc[1].value or ""
                    end
                end
                table.insert(forecast, {
                    date = day.date or "",
                    maxTemp = day.maxtempF or "",
                    minTemp = day.mintempF or "",
                    condition = dayCondition
                })
            end
        end

        cachedState = {
            available = true,
            location = WEATHER_LOCATION,
            temp = current.temp_F or "",
            feelsLike = current.FeelsLikeF or "",
            humidity = current.humidity or "",
            rainChance = rainChance,
            condition = condition,
            icon = icon,
            backgroundUrl = unsplashBg,
            windMph = windMph,
            windDir = windDir,
            uvIndex = uvIndex,
            visibility = visibility,
            pressure = pressure,
            forecast = forecast
        }
    end, { "-s", "-m", "15", "http://wttr.in/" .. WEATHER_LOCATION:gsub(", ", ",") .. "?format=j1" })

    if not taskRef then
        running = false
        return
    end
    taskRef:start()

    watchdog = hs.timer.doAfter(FETCH_TIMEOUT, function()
        watchdog = nil
        if taskRef then
            pcall(function() taskRef:terminate() end)
            taskRef = nil
            running = false
        end
    end)
end

function weather.getStatus()
    return cachedState
end

function weather.refresh()
    refresh()
end

function weather.start()
    if refreshTimer then refreshTimer:stop() end
    refresh()
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return weather
