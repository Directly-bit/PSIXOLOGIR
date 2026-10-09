--[[
═══════════════════════════════════════════════════════════════════════════════
    ПСИХОЛОГИЧЕСКИЙ ХОРРОР  •  v4 FINAL  •  Delta Mobile  •  Luau
    ─────────────────────────────────────────────────────────────────────────
    • Всё визуально ТОЛЬКО для тебя
    • Управление ЗАБЛОКИРОВАНО, кнопки GUI работают
    • Кнопки Roblox СКРЫТЫ / ЗАКРЫТЫ невидимым щитом
    • Выход — только PSIXOLORUR
    • Музыка: 2 мин → рестарт → 2 мин → рестарт (по кругу)
    • С 30 сек: красные монстры → взрыв через 15 сек → лужа крови
    • Затемнение: 0.5% в сек → 75% за 150 сек
═══════════════════════════════════════════════════════════════════════════════
]]

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 1. СЕРВИСЫ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local TweenService        = game:GetService("TweenService")
local SoundService        = game:GetService("SoundService")
local ContextActionService= game:GetService("ContextActionService")
local GuiService          = game:GetService("GuiService")
local Debris              = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "[Horror] LocalPlayer не найден")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
assert(PlayerGui, "[Horror] PlayerGui не найден")
local Camera = workspace.CurrentCamera

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
print("[Horror] Платформа: " .. (IsMobile and "MOBILE" or "PC"))

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 2. КОНСТАНТЫ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CONFIG = {
    -- Музыка
    MUSIC_ID          = "rbxassetid://81458780462068",
    MUSIC_VOLUME      = 0.5,
    MUSIC_RESTART_AT  = 120,   -- каждые 2 минуты с начала

    -- Выход
    PASSWORD          = "PSIXOLORUR",
    PASS_REVEAL_AT    = 300,   -- через 5 минут

    -- Затемнение
    DARK_STEP         = 0.005, -- 0.5% в секунду
    MAX_DARKNESS      = 0.75,  -- 75%

    -- Блокировка
    UI_LOCK_TIME      = 600,   -- 10 минут
    LOCK_RETRY_HZ     = 0.1,

    -- Монстры
    MONSTER_START_AT  = 30,    -- с 30 секунды
    MONSTER_LIFETIME  = 15,    -- взрыв через 15 сек
    MONSTER_SPAWN_MIN = 3,     -- интервал спавна (мин)
    MONSTER_SPAWN_MAX = 6,     -- интервал спавна (макс)
    MAX_MONSTERS      = 6,     -- одновременно

    -- Падения персонажа
    FALL_INTERVAL     = 1.2,   -- каждые ~1.2 сек
    FALL_DURATION     = 0.25,  -- падение длится 0.25 сек
}

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 3. СОСТОЯНИЕ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local H = {
    active       = false,
    cancelled    = false,
    finished     = false,
    darkness     = 0,
    music        = nil,
    darkFrame    = nil,
    blockGui     = nil,
    savedModules = nil,
    conns        = {},
    effectsLive  = false,
    monsters     = {},
    startedAt    = 0,
}

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 4. ХЕЛПЕРЫ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function create(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end

local function track(c)
    if c then table.insert(H.conns, c) end
    return c
end

local function disconnectAll()
    for _, c in ipairs(H.conns) do
        pcall(function() c:Disconnect() end)
    end
    H.conns = {}
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 5. ОТКЛЮЧЕНИЕ УПРАВЛЕНИЯ ПЕРСОНАЖЕМ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function DisableCharacterControl()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if not ps then return end
    local pm = ps:FindFirstChild("PlayerModule")
    if not pm then return end
    H.savedModules = pm
    local ok, controls = pcall(require, pm)
    if ok and controls then
        pcall(function() controls:Disable() end)
        pcall(function()
            if controls.controls then
                for _, c in pairs(controls.controls) do
                    if typeof(c) == "table" and c.Disable then
                        pcall(function() c:Disable() end)
                    end
                end
            end
        end)
    end
end

local function EnableCharacterControl()
    if not H.savedModules then return end
    local ok, controls = pcall(require, H.savedModules)
    if ok and controls then
        pcall(function() controls:Enable() end)
    end
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 6. ПОЛНАЯ БЛОКИРОВКА ВСЕХ КНОПОК ROBLOX
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--[[
    Стратегия "закрыть всё невидимым щитом":
      1) Пробуем УБРАТЬ все CoreGui элементы через SetCoreGuiEnabled
      2) Что не убирается — закрываем НЕВИДИМЫМ TextButton поверх
      3) Esc / меню — глушим на уровне ContextActionService
      4) Если каким-то образом что-то открылось — GuiService.MenuOpened → закрыть
    Обойти этот барьер можно ТОЛЬКО через наш пароль — он снимает всю защиту.
]]
local function KillCoreUiOnce()
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
    for _, t in ipairs({
        Enum.CoreGuiType.Chat,
        Enum.CoreGuiType.PlayerList,
        Enum.CoreGuiType.Backpack,
        Enum.CoreGuiType.EmotesMenu,
        Enum.CoreGuiType.Health,
    }) do
        pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
    end
    pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
    pcall(function() StarterGui:SetCore("ChatActive", false) end)
    pcall(function() StarterGui:SetCore("PointsNotificationsActive", false) end)
end

local function CreateInvisibleShield()
    local old = PlayerGui:FindFirstChild("HorrorBlockGui")
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = "HorrorBlockGui",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)
    H.blockGui = gui

    -- Верхняя полоса (Topbar / меню / чат)
    local top = create("TextButton", {
        Name = "TopShield",
        Size = UDim2.new(1, 0, 0, 100),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Modal = true,
        Active = true,
        ZIndex = 1,
    }, gui)
    top.MouseButton1Click:Connect(function() end)
    top.MouseButton2Click:Connect(function() end)
    top.TouchTap:Connect(function() end)

    -- Левая зона — кнопка меню Roblox
    local left = create("TextButton", {
        Name = "LeftShield",
        Size = UDim2.new(0, 120, 0, 100),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Modal = true,
        ZIndex = 2,
    }, gui)
    left.MouseButton1Click:Connect(function() end)
    left.TouchTap:Connect(function() end)

    -- Правая зона — кнопка выхода / чата
    local right = create("TextButton", {
        Name = "RightShield",
        Size = UDim2.new(0, 300, 0, 100),
        Position = UDim2.new(1, -300, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Modal = true,
        ZIndex = 2,
    }, gui)
    right.MouseButton1Click:Connect(function() end)
    right.TouchTap:Connect(function() end)

    return gui
end

local function LockAllRobloxUI()
    KillCoreUiOnce()
    CreateInvisibleShield()

    -- Retry-цикл (10 минут)
    task.spawn(function()
        local endAt = os.clock() + CONFIG.UI_LOCK_TIME
        while H.active and os.clock() < endAt do
            KillCoreUiOnce()
            task.wait(CONFIG.LOCK_RETRY_HZ)
        end
    end)

    -- Меню открылось → закрыть
    track(GuiService.MenuOpened:Connect(function()
        if not H.active then return end
        pcall(function() GuiService:SetMenuIsOpen(false) end)
        KillCoreUiOnce()
    end))

    -- Глушим Esc / F9 / чат
    pcall(function()
        ContextActionService:BindActionAtPriority(
            "HorrorBlockAll",
            function() return Enum.ContextActionResult.Sink end,
            false,
            Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.Escape,
            Enum.KeyCode.F9,
            Enum.KeyCode.F10,
            Enum.KeyCode.Slash,
            Enum.KeyCode.Backquote
        )
    end)

    track(UserInputService.InputBegan:Connect(function(input, gp)
        if not H.active then return end
        if input.KeyCode == Enum.KeyCode.Escape
        or input.KeyCode == Enum.KeyCode.F9
        or input.KeyCode == Enum.KeyCode.Slash then
            KillCoreUiOnce()
        end
    end))
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 7. ПОЛНАЯ ОЧИСТКА (при пароле / отмене)
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function CleanupAll()
    H.active   = false
    H.finished = true
    H.effectsLive = false

    disconnectAll()
    pcall(function() ContextActionService:UnbindAction("HorrorBlockAll") end)

    -- Удаляем GUI
    for _, n in ipairs({
        "HorrorWarningGui", "HorrorDarkGui", "HorrorPassGui",
        "HorrorBlockGui", "HorrorMusicHolder", "HorrorMonsterGui",
    }) do
        local g = PlayerGui:FindFirstChild(n)
        if g then pcall(function() g:Destroy() end) end
    end

    -- Удаляем монстров и лужи
    for _, m in ipairs(H.monsters) do
        if typeof(m) == "Instance" and m.Parent then
            pcall(function() m:Destroy() end)
        end
    end
    H.monsters = {}

    -- Звук
    local s = SoundService:FindFirstChild("HorrorMusic")
    if s then pcall(function() s:Destroy() end) end
    H.music = nil

    -- Возврат UI / Topbar
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
    pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)

    -- Возврат управления
    EnableCharacterControl()

    -- Возврат персонажа
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hum.JumpPower = 50 end)
            if hum.UseJumpPower == false then
                pcall(function() hum.JumpHeight = 7.2 end)
            end
            pcall(function() hum.PlatformStand = false end)
        end
    end

    print("[Horror] Всё восстановлено. Выход выполнен.")
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 8. ЭТАП 1 — ОКНО ПРЕДУПРЕЖДЕНИЯ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function ShowWarning()
    local old = PlayerGui:FindFirstChild("HorrorWarningGui")
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = "HorrorWarningGui",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 99999,
    }, PlayerGui)

    create("Frame", {
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 1,
    }, gui)

    local main = create("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(0.92, 0.85),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(18, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, gui)
    create("UICorner", { CornerRadius = UDim.new(0, 16) }, main)
    create("UIStroke", { Color = Color3.fromRGB(190, 0, 0), Thickness = 3 }, main)

    local title = create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -20, 0, 0.18),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Text = "⚠ ПСИХОЛОГИЧЕСКИЙ ХОРРОР ⚠",
        TextColor3 = Color3.fromRGB(255, 30, 30),
        TextScaled = true,
        TextWrapped = true,
        Font = Enum.Font.GothamBlack,
        ZIndex = 3,
    }, main)

    create("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(1, -40, 0.42, 0),
        Position = UDim2.new(0, 20, 0.22, 0),
        BackgroundTransparency = 1,
        Text = "Этот скрипт содержит пугающие элементы, мерцание и громкие звуки.\n\n" ..
               "УПРАВЛЕНИЕ БУДЕТ ЗАБЛОКИРОВАНО.\n\n" ..
               "Все кнопки Roblox будут закрыты.\n\n" ..
               "Выход — только через пароль.",
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextScaled = true,
        TextWrapped = true,
        Font = Enum.Font.Gotham,
        ZIndex = 3,
    }, main)

    local cancelBtn = create("TextButton", {
        Name = "CancelBtn",
        Size = UDim2.new(0.42, 0, 0, 60),
        Position = UDim2.new(0.04, 0, 1, -80),
        BackgroundColor3 = Color3.fromRGB(90, 90, 90),
        Text = "ОТМЕНИТЬ",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        AutoButtonColor = true,
        ZIndex = 3,
    }, main)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, cancelBtn)

    local continueBtn = create("TextButton", {
        Name = "ContinueBtn",
        Size = UDim2.new(0.42, 0, 0, 60),
        Position = UDim2.new(0.54, 0, 1, -80),
        BackgroundColor3 = Color3.fromRGB(190, 0, 0),
        Text = "ПРОДОЛЖИТЬ",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        AutoButtonColor = true,
        ZIndex = 3,
    }, main)
    create("UICorner", { CornerRadius = UDim.new(0, 12) }, continueBtn)

    -- Пульс заголовка
    task.spawn(function()
        while gui.Parent and not H.cancelled and not H.active do
            TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                TextColor3 = Color3.fromRGB(110, 0, 0),
            }):Play()
            task.wait(1)
            if not gui.Parent then break end
            TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                TextColor3 = Color3.fromRGB(255, 30, 30),
            }):Play()
            task.wait(1)
        end
    end)

    local debounce = false

    local function doCancel()
        if debounce then return end
        debounce = true
        H.cancelled = true
        H.finished  = true
        pcall(function() gui:Destroy() end)
        print("[Horror] Отменено.")
    end

    local function doContinue()
        if debounce then return end
        debounce = true
        H.active = true
        H.startedAt = os.clock()
        pcall(function() gui:Destroy() end)
        task.wait(0.1)
        print("[Horror] Запуск...")
        LaunchHorror()
    end

    cancelBtn.MouseButton1Click:Connect(doCancel)
    cancelBtn.TouchTap:Connect(doCancel)
    continueBtn.MouseButton1Click:Connect(doContinue)
    continueBtn.TouchTap:Connect(doContinue)
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 9. ЭТАП 2 — МУЗЫКА С РЕСТАРТОМ КАЖДЫЕ 2 МИНУТЫ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function StartMusic()
    local oldS = SoundService:FindFirstChild("HorrorMusic")
    if oldS then oldS:Destroy() end
    local oldG = PlayerGui:FindFirstChild("HorrorMusicHolder")
    if oldG then oldG:Destroy() end

    local holder = create("ScreenGui", {
        Name = "HorrorMusicHolder",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = -1,
    }, PlayerGui)

    local snd = Instance.new("Sound")
    snd.Name         = "HorrorMusic"
    snd.Volume       = CONFIG.MUSIC_VOLUME
    snd.Looped       = false
    snd.PlayOnRemove = false
    snd.Parent       = holder

    task.wait(0.1)
    snd.SoundId = CONFIG.MUSIC_ID
    H.music = snd

    local w = 0
    while snd.TimeLength <= 0 and w < 10 do
        task.wait(0.1); w = w + 0.1
    end

    snd:Play()

    -- Каждые 2 минуты — рестарт (не Looped, а принудительное переигрывание)
    task.spawn(function()
        while H.active do
            task.wait(CONFIG.MUSIC_RESTART_AT)
            if not H.active then break end
            if snd.Parent then
                pcall(function()
                    snd:Stop()
                    snd.TimePosition = 0
                    snd:Play()
                end)
                print("[Horror] Музыка перезапущена (2 мин).")
            end
        end
    end)

    -- Если трек короткий и закончился раньше — рестарт
    track(snd.Ended:Connect(function()
        if not H.active then return end
        if snd.Parent then
            pcall(function() snd:Play() end)
        end
    end))

    return snd
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 10. ЭТАП 3 — СЕРЫЙ ОВЕРЛЕЙ (0.5% в секунду)
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function CreateDarkOverlay()
    local old = PlayerGui:FindFirstChild("HorrorDarkGui")
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = "HorrorDarkGui",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 99997,
    }, PlayerGui)

    local frame = create("Frame", {
        Name = "Dark",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundColor3 = Color3.fromRGB(128, 128, 128),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        Active = true,
    }, gui)

    H.darkFrame = frame
    return frame
end

local function RunDarkening()
    local frame = H.darkFrame
    if not frame then return end
    H.darkness = 0

    while H.active and H.darkness < CONFIG.MAX_DARKNESS do
        task.wait(1)
        if not H.active or not frame.Parent then break end
        H.darkness = math.min(H.darkness + CONFIG.DARK_STEP, CONFIG.MAX_DARKNESS)
        frame.BackgroundTransparency = 1 - H.darkness

        if H.darkness >= CONFIG.MAX_DARKNESS and not H.effectsLive then
            H.effectsLive = true
            frame.BackgroundTransparency = 0.25
            task.spawn(ApplyCharacterEffects)
            print("[Horror] 75% серости достигнуто.")
        end
    end
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 11. ЭТАП 4 — ЭФФЕКТЫ ПЕРСОНАЖА
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function GetHumanoid()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:FindFirstChildOfClass("Humanoid")
end

local function RunWalkSlow()
    while H.active do
        local hum = GetHumanoid()
        if hum and hum.Health > 0 and hum.WalkSpeed > 4 then
            hum.WalkSpeed = math.max(4, hum.WalkSpeed - 0.5)
        end
        task.wait(1)
    end
end

local function RunJumpSlow()
    while H.active do
        local hum = GetHumanoid()
        if hum and hum.Health > 0 then
            if hum.UseJumpPower then
                if hum.JumpPower > 10 then
                    hum.JumpPower = math.max(10, hum.JumpPower - 1)
                end
            else
                if hum.JumpHeight > 2 then
                    hum.JumpHeight = math.max(2, hum.JumpHeight - 0.4)
                end
            end
        end
        task.wait(1)
    end
end

-- ПАДЕНИЯ: каждые ~1.2 сек → 100 раз за 2 минуты
local function RunRapidFalls()
    while H.active do
        task.wait(CONFIG.FALL_INTERVAL)
        if not H.active then break end
        local hum = GetHumanoid()
        if hum and hum.Health > 0 then
            pcall(function() hum.PlatformStand = true end)
            task.wait(CONFIG.FALL_DURATION)
            if hum.Parent and H.active then
                pcall(function() hum.PlatformStand = false end)
            end
        end
    end
end

function ApplyCharacterEffects()
    print("[Horror] Эффекты персонажа активированы.")
    task.spawn(RunWalkSlow)
    task.spawn(RunJumpSlow)
    task.spawn(RunRapidFalls)
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 12. ЭТАП 5 — КРАСНЫЕ МОНСТРЫ-НПС
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--[[
    Логика:
      - С 30 секунды начинают спавниться красные монстры вокруг игрока
      - Каждый живёт 15 секунд
      - При смерти ВЗРЫВАЕТСЯ (частицы + вспышка)
      - После взрыва остаётся ЛУЖА КРОВИ на земле
]]
local function CreateBloodPool(position)
    -- Лужа крови — плоский красный цилиндр
    local pool = Instance.new("Part")
    pool.Name = "HorrorBloodPool"
    pool.Shape = Enum.PartType.Cylinder
    pool.Anchored = true
    pool.CanCollide = false
    pool.CanQuery = false
    pool.CanTouch = false
    pool.Material = Enum.Material.Glass
    pool.Color = Color3.fromRGB(80, 0, 0)
    pool.Transparency = 0.25
    pool.Size = Vector3.new(0.2, 2.5, 2.5)
    pool.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    pool.Parent = workspace

    Debris:AddItem(pool, 30)
    table.insert(H.monsters, pool)
    return pool
end

local function CreateExplosionAt(position)
    -- Вспышка света
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 40, 40)
    light.Range = 20
    light.Brightness = 5
    local holder = Instance.new("Part")
    holder.Anchored = true
    holder.CanCollide = false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.1, 0.1, 0.1)
    holder.CFrame = CFrame.new(position)
    holder.Parent = workspace
    light.Parent = holder
    Debris:AddItem(holder, 0.6)

    -- Частицы
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://243660364"
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Lifetime = NumberRange.new(0.5, 1.2)
    emitter.Speed = NumberRange.new(15, 30)
    emitter.Rate = 0
    emitter.Parent = holder
    emitter:Emit(40)
end

local function SpawnMonster()
    -- Позиция рядом с игроком (радиус 10-20 studs)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local angle = math.random() * math.pi * 2
    local dist  = math.random(10, 22)
    local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
    local spawnPos = root.Position + offset
    spawnPos = Vector3.new(spawnPos.X, spawnPos.Y + 3, spawnPos.Z)

    -- Тело монстра — красный шар
    local body = Instance.new("Part")
    body.Name = "HorrorMonster"
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(3, 3, 3)
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.Neon
    body.Color = Color3.fromRGB(200, 0, 0)
    body.CFrame = CFrame.new(spawnPos)
    body.Parent = workspace
    table.insert(H.monsters, body)

    -- Пульсация размера
    task.spawn(function()
        while body.Parent and H.active do
            local tweenIn = TweenService:Create(body, TweenInfo.new(0.4), {
                Size = Vector3.new(3.6, 3.6, 3.6),
            })
            tweenIn:Play()
            task.wait(0.4)
            if not body.Parent then break end
            local tweenOut = TweenService:Create(body, TweenInfo.new(0.4), {
                Size = Vector3.new(2.6, 2.6, 2.6),
            })
            tweenOut:Play()
            task.wait(0.4)
        end
    end)

    -- Свечение
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 0, 0)
    light.Range = 12
    light.Brightness = 3
    light.Parent = body

    -- Живёт 15 сек → взрыв + лужа
    task.spawn(function()
        task.wait(CONFIG.MONSTER_LIFETIME)
        if not body.Parent then return end

        local explPos = body.Position

        -- Взрыв
        CreateExplosionAt(explPos)

        -- Удаляем тело
        pcall(function() body:Destroy() end)

        -- Лужа крови на полу (опускаем на пару studs вниз)
        local groundPos = explPos - Vector3.new(0, 2.5, 0)
        CreateBloodPool(groundPos)

        print("[Horror] Монстр взорвался, осталась лужа.")
    end)
end

local function RunMonsterSpawner()
    -- Ждём 30 секунд
    local t = 0
    while t < CONFIG.MONSTER_START_AT and H.active do
        task.wait(1); t = t + 1
    end
    if not H.active then return end
    print("[Horror] Монстры активированы.")

    while H.active do
        -- Считаем активных монстров
        local alive = 0
        for _, m in ipairs(H.monsters) do
            if m and m.Parent and m.Name == "HorrorMonster" then
                alive = alive + 1
            end
        end

        if alive < CONFIG.MAX_MONSTERS then
            SpawnMonster()
        end

        task.wait(math.random(CONFIG.MONSTER_SPAWN_MIN, CONFIG.MONSTER_SPAWN_MAX))
    end
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 13. ЭТАП 6 — ПОЛЕ ПАРОЛЯ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SchedulePasswordField()
    task.spawn(function()
        local t = 0
        while t < CONFIG.PASS_REVEAL_AT and H.active do
            task.wait(1); t = t + 1
        end
        if not H.active then return end

        local old = PlayerGui:FindFirstChild("HorrorPassGui")
        if old then old:Destroy() end

        local gui = create("ScreenGui", {
            Name = "HorrorPassGui",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 2147483647,
        }, PlayerGui)

        local frame = create("Frame", {
            Size = UDim2.fromScale(0.9, 0.14),
            Position = UDim2.fromScale(0.5, 0.85),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(12, 12, 12),
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
        }, gui)
        create("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
        create("UIStroke", { Color = Color3.fromRGB(130, 0, 0), Thickness = 2 }, frame)

        create("TextLabel", {
            Size = UDim2.new(1, -20, 0.3, 0),
            Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1,
            Text = "ВВЕДИТЕ КОД, ЧТОБЫ ВЫЙТИ",
            TextColor3 = Color3.fromRGB(220, 60, 60),
            Font = Enum.Font.GothamBold,
            TextScaled = true,
        }, frame)

        local box = create("TextBox", {
            Size = UDim2.new(1, -40, 0.5, 0),
            Position = UDim2.new(0.5, 0, 0.72, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            Text = "",
            PlaceholderText = "• • • • • • • • • •",
            TextColor3 = Color3.fromRGB(245, 245, 245),
            PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
            Font = Enum.Font.Code,
            TextScaled = true,
            ClearTextOnFocus = false,
        }, frame)
        create("UICorner", { CornerRadius = UDim.new(0, 10) }, box)
        create("UIStroke", { Color = Color3.fromRGB(95, 0, 0), Thickness = 2 }, box)

        UserInputService.MouseIconEnabled = true

        local focusConn = box.FocusLost:Connect(function()
            if box.Text == CONFIG.PASSWORD then
                box.Text = ""
                CleanupAll()
            else
                box.Text = ""
                local orig = frame.Position
                for _ = 1, 6 do
                    frame.Position = orig + UDim2.new(0, math.random(-8, 8), 0, 0)
                    task.wait(0.03)
                end
                frame.Position = orig
            end
        end)
        track(focusConn)
    end)
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 14. ГЛАВНЫЙ ЗАПУСК
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function LaunchHorror()
    print("[Horror] ============ СТАРТ ============")

    -- 1. Отключаем управление персонажем
    DisableCharacterControl()

    -- 2. Блокируем/скрываем все кнопки Roblox
    LockAllRobloxUI()

    -- 3. Скрываем курсор
    UserInputService.MouseIconEnabled = false

    -- 4. Серый оверлей
    CreateDarkOverlay()

    -- 5. Музыка (рестарт каждые 2 минуты)
    StartMusic()

    -- 6. Фоновые процессы
    task.spawn(RunDarkening)
    task.spawn(RunMonsterSpawner)
    SchedulePasswordField()

    print("[Horror] Пароль выхода: " .. CONFIG.PASSWORD)
end

--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--// 15. СТАРТ
--//━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ShowWarning()
print("[Horror] Скрипт загружен. Ожидание решения...")
