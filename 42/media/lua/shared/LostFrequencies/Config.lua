LostFrequencies = LostFrequencies or {}

LostFrequencies.Config = {
    module = "LostFrequencies",
    dataKey = "LostFrequenciesState",
    version = "0.5.3",
    protocolVersion = 7,
    effectIntervalSeconds = 60,
    maxAlertLength = 500,
}

local function root()
    return SandboxVars and SandboxVars.LostFrequencies or {}
end

function LostFrequencies.Config.options()
    local values = root()
    return {
        enabled = values.Enabled ~= false,
        frequency = math.floor(tonumber(values.Frequency) or 102800),
        utcOffset = math.max(-12, math.min(14, math.floor(tonumber(values.UtcOffset) or -4))),
        activationHour = math.max(0, math.min(23, math.floor(tonumber(values.ActivationHour) or 6))),
        reminderHour = math.max(0, math.min(23, math.floor(tonumber(values.ReminderHour) or 18))),
        interfaceKey = math.max(0, math.min(255, math.floor(tonumber(values.InterfaceKey) or 66))),
        minimumDurationDays = math.max(1, math.min(3, math.floor(tonumber(values.MinimumDurationDays) or 1))),
        maximumDurationDays = math.max(1, math.min(3, math.floor(tonumber(values.MaximumDurationDays) or 3))),
        loginGraceMinutes = math.max(0, math.min(60, math.floor(tonumber(values.LoginGraceMinutes) or 5))),
        randomIntensity = values.RandomIntensity ~= false,
        adminExempt = values.AdminExempt == true,
        showGlobalAlert = values.ShowGlobalAlert ~= false,
        showOverheadAlerts = values.ShowOverheadAlerts == true,
        radioBroadcasts = values.RadioBroadcasts ~= false,
        relayLogging = values.RelayLogging ~= false,
        avoidImmediateRepeats = values.AvoidImmediateRepeats ~= false,
        environmentalSignals = values.EnvironmentalSignals ~= false,
        weatherRefreshMinutes = math.max(15, math.min(180, math.floor(tonumber(values.WeatherRefreshMinutes) or 60))),
        curseEnabled = {
            hollow_stomachs = values.HungerEnabled ~= false,
            parched_earth = values.ThirstEnabled ~= false,
            sleepless_signal = values.FatigueEnabled ~= false,
            heavy_air = values.EnduranceEnabled ~= false,
            red_static = values.PanicEnabled ~= false,
            aching_bones = values.PainEnabled ~= false,
            black_sky = values.EnvironmentalSignals ~= false and values.BlackSkyEnabled ~= false,
            tropical_static = values.EnvironmentalSignals ~= false and values.TropicalStaticEnabled ~= false,
            whiteout = values.EnvironmentalSignals ~= false and values.WhiteoutEnabled ~= false,
            dead_air = values.DeadAirEnabled ~= false,
            clear_signal = true,
            second_wind = true,
            quiet_frequency = true,
            eye_of_the_storm = values.EnvironmentalSignals ~= false,
        },
    }
end
