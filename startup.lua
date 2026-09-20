-- London clock for multiple CC:Tweaked monitors

local monitors = { peripheral.find("monitor") }

if #monitors == 0 then
    error("No monitors are connected")
end

local digits = {
    ["0"] = {"###", "# #", "# #", "# #", "###"},
    ["1"] = {" # ", "## ", " # ", " # ", "###"},
    ["2"] = {"###", "  #", "###", "#  ", "###"},
    ["3"] = {"###", "  #", "###", "  #", "###"},
    ["4"] = {"# #", "# #", "###", "  #", "  #"},
    ["5"] = {"###", "#  ", "###", "  #", "###"},
    ["6"] = {"###", "#  ", "###", "# #", "###"},
    ["7"] = {"###", "  #", "  #", "  #", "  #"},
    ["8"] = {"###", "# #", "###", "# #", "###"},
    ["9"] = {"###", "# #", "###", "  #", "###"},
    [":"] = {" ", "#", " ", "#", " "}
}

-- Returns 0 for Sunday, 1 for Monday, etc.
local function dayOfWeek(year, month, day)
    local offsets = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}

    if month < 3 then
        year = year - 1
    end

    return (
        year
        + math.floor(year / 4)
        - math.floor(year / 100)
        + math.floor(year / 400)
        + offsets[month]
        + day
    ) % 7
end

local function lastSunday(year, month)
    return 31 - dayOfWeek(year, month, 31)
end

-- UK summer time starts at 01:00 UTC on the last Sunday
-- in March and ends at 01:00 UTC on the last Sunday in October.
local function isBritishSummerTime(utc)
    if utc.month > 3 and utc.month < 10 then
        return true
    end

    if utc.month < 3 or utc.month > 10 then
        return false
    end

    local transitionDay = lastSunday(utc.year, utc.month)

    if utc.month == 3 then
        return utc.day > transitionDay
            or (utc.day == transitionDay and utc.hour >= 1)
    end

    return utc.day < transitionDay
        or (utc.day == transitionDay and utc.hour < 1)
end

local function centredWrite(monitor, y, text, colour)
    local width = monitor.getSize()
    monitor.setBackgroundColour(colours.black)
    monitor.setTextColour(colour)
    monitor.setCursorPos(
        math.max(1, math.floor((width - #text) / 2) + 1),
        y
    )
    monitor.write(text)
end

local function drawClock(monitor, london, zone)
    monitor.setTextScale(1)

    local width, height = monitor.getSize()

    -- Fall back to smaller text if the monitor is unusually small.
    if width < 17 or height < 8 then
        monitor.setTextScale(0.5)
        width, height = monitor.getSize()
    end

    monitor.setBackgroundColour(colours.black)
    monitor.clear()
    monitor.setCursorBlink(false)

    local timeText = string.format(
        "%02d:%02d",
        london.hour,
        london.min
    )

    local clockWidth = 0
    for i = 1, #timeText do
        clockWidth = clockWidth + #digits[timeText:sub(i, i)][1]

        if i < #timeText then
            clockWidth = clockWidth + 1
        end
    end

    local top = math.max(1, math.floor((height - 8) / 2) + 1)
    local startX = math.max(1, math.floor((width - clockWidth) / 2) + 1)

    centredWrite(monitor, top, "LONDON", colours.white)

    for row = 1, 5 do
        local x = startX

        for i = 1, #timeText do
            local character = timeText:sub(i, i)
            local pattern = digits[character][row]

            for pixel = 1, #pattern do
                if pattern:sub(pixel, pixel) == "#" then
                    monitor.setBackgroundColour(colours.lightBlue)
                    monitor.setCursorPos(x + pixel - 1, top + row + 1)
                    monitor.write(" ")
                end
            end

            x = x + #pattern + 1
        end
    end

    centredWrite(
        monitor,
        top + 7,
        string.format("%s  %02d SEC", zone, london.sec),
        colours.lightGrey
    )
end

local previousSecond = -1

while true do
    local utcSeconds = math.floor(os.epoch("utc") / 1000)
    local utc = os.date("!*t", utcSeconds)
    local summerTime = isBritishSummerTime(utc)

    local londonSeconds = utcSeconds + (summerTime and 3600 or 0)
    local london = os.date("!*t", londonSeconds)
    local zone = summerTime and "BST" or "GMT"

    if london.sec ~= previousSecond then
        for _, monitor in ipairs(monitors) do
            drawClock(monitor, london, zone)
        end

        previousSecond = london.sec
    end

    sleep(0.1)
end
