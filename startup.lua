-- Four-face analogue London clock with Westminster chimes
-- Requires one or more CC:Tweaked advanced monitors and a speaker.

local monitors = { peripheral.find("monitor") }
local speakers = { peripheral.find("speaker") }

if #monitors == 0 then
    error("No monitors connected")
end

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

local function isBritishSummerTime(utc)
    if utc.month > 3 and utc.month < 10 then
        return true
    end

    if utc.month < 3 or utc.month > 10 then
        return false
    end

    local changeDay = lastSunday(utc.year, utc.month)

    if utc.month == 3 then
        return utc.day > changeDay
            or (utc.day == changeDay and utc.hour >= 1)
    end

    return utc.day < changeDay
        or (utc.day == changeDay and utc.hour < 1)
end

local function londonTime()
    local utcSeconds = math.floor(os.epoch("utc") / 1000)
    local utc = os.date("!*t", utcSeconds)
    local offset = isBritishSummerTime(utc) and 3600 or 0

    return os.date("!*t", utcSeconds + offset)
end

local function round(number)
    return math.floor(number + 0.5)
end

local displays = {}

for _, monitor in ipairs(monitors) do
    monitor.setTextScale(0.5)

    local width, height = monitor.getSize()
    local buffer = window.create(monitor, 1, 1, width, height, false)

    table.insert(displays, {
        buffer = buffer,
        width = width,
        height = height
    })
end

local function drawClock(display, time)
    local screen = display.buffer
    local width = display.width
    local height = display.height

    screen.setVisible(false)

    local previousTerminal = term.redirect(screen)

    screen.setBackgroundColour(colors.black)
    screen.clear()
    screen.setCursorBlink(false)

    local centreX = math.floor((width + 1) / 2)
    local centreY = math.floor((height + 1) / 2)
    local radiusY = math.max(4, math.floor((height - 2) / 2))
    local radiusX = math.min(
        math.floor((width - 2) / 2),
        math.floor(radiusY * 1.5)
    )

    -- Fill the clock face.
    for offsetY = -radiusY, radiusY do
        local position = offsetY / radiusY
        local span = math.floor(
            radiusX * math.sqrt(math.max(0, 1 - position * position))
        )

        paintutils.drawLine(
            centreX - span,
            centreY + offsetY,
            centreX + span,
            centreY + offsetY,
            colors.gray
        )
    end

    -- Outer rim.
    for degrees = 0, 359 do
        local angle = math.rad(degrees)

        paintutils.drawPixel(
            round(centreX + math.sin(angle) * radiusX),
            round(centreY - math.cos(angle) * radiusY),
            colors.lightGray
        )
    end

    -- Hour markers.
    for hour = 0, 11 do
        local angle = (hour / 12) * math.pi * 2
        local markerColour = hour % 3 == 0
            and colors.yellow
            or colors.white

        paintutils.drawPixel(
            round(centreX + math.sin(angle) * radiusX * 0.82),
            round(centreY - math.cos(angle) * radiusY * 0.82),
            markerColour
        )
    end

    local seconds = time.sec
    local minutes = time.min + seconds / 60
    local hours = (time.hour % 12) + minutes / 60

    local function drawHand(position, divisions, length, colour)
        local angle = (position / divisions) * math.pi * 2

        paintutils.drawLine(
            centreX,
            centreY,
            round(centreX + math.sin(angle) * radiusX * length),
            round(centreY - math.cos(angle) * radiusY * length),
            colour
        )
    end

    drawHand(hours, 12, 0.48, colors.yellow)
    drawHand(minutes, 60, 0.68, colors.white)
    drawHand(seconds, 60, 0.76, colors.red)
    paintutils.drawPixel(centreX, centreY, colors.white)

    term.redirect(previousTerminal)
    screen.setVisible(true)
end

local function playNote(instrument, volume, pitch)
    for _, speaker in ipairs(speakers) do
        speaker.playNote(instrument, volume, pitch)
    end
end

-- Four phrases arranged in the style of the Westminster quarters.
local westminsterPhrases = {
    {14, 12, 10, 5},
    {10, 14, 12, 5},
    {10, 12, 14, 10},
    {14, 10, 12, 5}
}

local quarterPatterns = {
    {1},
    {2, 1},
    {3, 2, 1},
    {4, 3, 2, 1}
}

local function playPhrase(phraseNumber)
    local phrase = westminsterPhrases[phraseNumber]

    for _, pitch in ipairs(phrase) do
        playNote("chime", 2.5, pitch)
        sleep(0.42)
    end

    sleep(0.55)
end

local function playQuarterChime(quarter, hour)
    if #speakers == 0 then
        return
    end

    for _, phraseNumber in ipairs(quarterPatterns[quarter]) do
        playPhrase(phraseNumber)
    end

    -- On the hour, follow the Westminster phrase with 1-12 deep bongs.
    if quarter == 4 then
        sleep(0.8)

        local strikes = hour % 12

        if strikes == 0 then
            strikes = 12
        end

        for _ = 1, strikes do
            playNote("bell", 3.0, 4)
            sleep(1.35)
        end
    end
end

local function clockLoop()
    local previousSecond = -1

    while true do
        local time = londonTime()

        if time.sec ~= previousSecond then
            for _, display in ipairs(displays) do
                drawClock(display, time)
            end

            previousSecond = time.sec
        end

        sleep(0.05)
    end
end

local function chimeLoop()
    local current = londonTime()
    local previousMinute = current.min

    while true do
        local time = londonTime()

        if time.min ~= previousMinute then
            previousMinute = time.min

            if time.min == 15 then
                playQuarterChime(1, time.hour)
            elseif time.min == 30 then
                playQuarterChime(2, time.hour)
            elseif time.min == 45 then
                playQuarterChime(3, time.hour)
            elseif time.min == 0 then
                playQuarterChime(4, time.hour)
            end
        end

        sleep(0.2)
    end
end

parallel.waitForAll(clockLoop, chimeLoop)
