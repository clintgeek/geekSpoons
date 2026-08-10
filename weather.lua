local weather = {}

local env = require("env")
local WEATHER_LOCATION = env.get("WEATHER_LOCATION") or "Arkadelphia, AR"

local REFRESH_INTERVAL = 10 * 60
local cachedState = { available = false }
local refreshTimer = nil
local running = false

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

local function refresh()
    if running then return end
    running = true

    hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        running = false
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

        cachedState = {
            available = true,
            location = WEATHER_LOCATION,
            temp = current.temp_F or "",
            feelsLike = current.FeelsLikeF or "",
            humidity = current.humidity or "",
            rainChance = rainChance,
            condition = condition,
            icon = icon,
            backgroundUrl = unsplashBg
        }
    end, { "-s", "-m", "15", "https://wttr.in/" .. WEATHER_LOCATION:gsub(", ", ",") .. "?format=j1" }):start()
end

function weather.getStatus()
    return cachedState
end

function weather.start()
    if refreshTimer then refreshTimer:stop() end
    refresh()
    refreshTimer = hs.timer.doEvery(REFRESH_INTERVAL, refresh)
end

return weather
