local CameraCache = {
    lastUpdate = 0,
    position = Vector3.new(),
    cframe = CFrame.new(),
    fieldOfView = 70
}

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local JOINT_CONFIGS = {
    R15 = {{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"},
           {"LeftUpperArm", "LeftLowerArm"}, {"LeftUpperArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
           {"RightUpperArm", "RightLowerArm"}, {"RightUpperArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
           {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftUpperLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
           {"RightUpperLeg", "RightLowerLeg"}, {"RightUpperLeg", "RightFoot"}},
    R6 = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"},
          {"Torso", "Right Leg"}}
}

local LOD_LEVELS = {

    HIGH = {
        distance = 150,
        updateRate = 1,
        features = {
            box = true,
            healthBar = true,
            nickname = true,
            skeleton = true
        }
    },

    MEDIUM = {
        distance = 250,
        updateRate = 1,
        features = {
            box = true,
            healthBar = true,
            nickname = true,
            skeleton = false
        }
    },

    LOW = {
        distance = 400,
        updateRate = 2,
        features = {
            box = true,
            healthBar = false,
            nickname = true,
            skeleton = false
        }
    }
}
local DEFAULT_SETTINGS = {
    Enabled = true,
    BoxEnable = false,
    HealthBar = false,
    Nickname = false,
    Skeleton = false,
    Chams = false,
    BoxColor = Color3.new(1, 1, 1),
    SkeletonColor = Color3.new(1, 1, 1),
    NicknameColor = Color3.new(1, 1, 1),
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    RenderDistance = 1000,
    MaxCacheSize = 20, -- // Maximum cache
    CleanupInterval = 20, -- // Per 1min cleanup
    MaxSkeletonParts = 20, -- // Maximum skeleton parts per player
    CacheUpdateInterval = 0.016, -- // 60fps cache updates
    UseLOD = true
}
local ESPObjectPool = {
    available = {},
    inUse = {},
    lastCleanup = 0,
    creationTimes = {}
}
local PerformanceMetrics = {
    frameCount = 0,
    lastFPSCheck = 0,
    currentFPS = 60,
    adaptiveLOD = false
}
local lastCamCFrame = nil

local function UpdateCameraCache()
    local currentTime = tick()
    local camCFrame = CurrentCamera.CFrame
    if currentTime - CameraCache.lastUpdate >= DEFAULT_SETTINGS.CacheUpdateInterval and camCFrame ~= lastCamCFrame then
        CameraCache.position = CurrentCamera.CFrame.Position
        CameraCache.cframe = camCFrame
        CameraCache.fieldOfView = CurrentCamera.FieldOfView
        CameraCache.lastUpdate = currentTime
    end
end
local function WorldToViewportPoint(position)
    local screenPosition, onScreen = CurrentCamera:WorldToViewportPoint(position)
    return Vector2.new(screenPosition.X, screenPosition.Y), onScreen
end
local function GetSquaredDistanceFromCamera(position)
    local delta = position - CameraCache.position
    return delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
end
local function CreateDrawing(drawingType, properties)
    local drawing = Drawing.new(drawingType)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end
local function GetLODLevel(squaredDistance)
    if squaredDistance <= LOD_LEVELS.HIGH.distance * LOD_LEVELS.HIGH.distance then
        return LOD_LEVELS.HIGH, "HIGH"
    elseif squaredDistance <= LOD_LEVELS.MEDIUM.distance * LOD_LEVELS.MEDIUM.distance then
        return LOD_LEVELS.MEDIUM, "MEDIUM"
    elseif squaredDistance <= LOD_LEVELS.LOW.distance * LOD_LEVELS.LOW.distance then
        return LOD_LEVELS.LOW, "LOW"
    else
        return nil, "OUT_OF_RANGE"
    end
end
local function UpdatePerformanceMetrics()
    PerformanceMetrics.frameCount = PerformanceMetrics.frameCount + 1
    local currentTime = tick()
    if currentTime - PerformanceMetrics.lastFPSCheck >= 1.0 then
        PerformanceMetrics.currentFPS = PerformanceMetrics.frameCount / (currentTime - PerformanceMetrics.lastFPSCheck)
        PerformanceMetrics.frameCount = 0
        PerformanceMetrics.lastFPSCheck = currentTime
        -- Enable adaptive LOD if FPS drops below 30
        PerformanceMetrics.adaptiveLOD = PerformanceMetrics.currentFPS < 30
    end
end
function ESPObjectPool:Output(input)
    if DEFAULT_SETTINGS.DeveloperMode then
        warn(input)
    end
end
function ESPObjectPool:GetDrawing(drawingType, properties, maxCacheSize)
    local poolKey = drawingType
    maxCacheSize = maxCacheSize or DEFAULT_SETTINGS.MaxCacheSize
    if not self.available[poolKey] then
        self.available[poolKey] = {}
    end
    local drawing = table.remove(self.available[poolKey])
    if not drawing then
        drawing = CreateDrawing(drawingType, properties)
        self.creationTimes[drawing] = tick()
    else
        for property, value in pairs(properties) do
            drawing[property] = value
        end
    end
    if not self.inUse[poolKey] then
        self.inUse[poolKey] = {}
    end
    table.insert(self.inUse[poolKey], drawing)
    return drawing
end
function ESPObjectPool:ReturnDrawing(drawingType, drawing)
    if not drawing then
        return
    end
    drawing.Visible = false
    local poolKey = drawingType
    if not self.available[poolKey] then
        self.available[poolKey] = {}
    end
    if self.inUse[poolKey] then
        for i, obj in ipairs(self.inUse[poolKey]) do
            if obj == drawing then
                table.remove(self.inUse[poolKey], i)
                break
            end
        end
    end
    if #self.available[poolKey] >= DEFAULT_SETTINGS.MaxCacheSize then
        if self.creationTimes[drawing] then
            self.creationTimes[drawing] = nil
        end
        drawing:Destroy()
    else
        table.insert(self.available[poolKey], drawing)
    end
end
function ESPObjectPool:ForceCleanup()
    self:Output("[ESP Periodic Cleanup] ForceCleanup begin!")
    local currentTime = tick()
    for poolKey, availableList in pairs(self.available) do
        if #availableList > DEFAULT_SETTINGS.MaxCacheSize then
            local priorityList = {}
            for i, drawing in ipairs(availableList) do
                local age = currentTime - (self.creationTimes[drawing] or 0)
                local priority = age
                table.insert(priorityList, {
                    drawing = drawing,
                    priority = priority,
                    index = i
                })
            end
            table.sort(priorityList, function(a, b)
                return a.priority > b.priority
            end)
            local toRemove = #availableList - DEFAULT_SETTINGS.MaxCacheSize
            for i = 1, math.min(toRemove, #priorityList) do
                local item = priorityList[i]
                local drawing = item.drawing
                self.creationTimes[drawing] = nil
                for j = #availableList, 1, -1 do
                    if availableList[j] == drawing then
                        table.remove(availableList, j)
                        break
                    end
                end
                drawing:Destroy()
            end
        end
    end
    self.lastCleanup = currentTime
end
function ESPObjectPool:PeriodicCleanup()
    local currentTime = tick()
    if currentTime - self.lastCleanup > DEFAULT_SETTINGS.CleanupInterval then
        self:Output("[ESP Periodic Cleanup] Starting scheduled cleanup...")
        self:ForceCleanup()
    end
end
function ESPLibrary.new()
    local self = setmetatable({}, ESPLibrary)
    self.Settings = table.clone(DEFAULT_SETTINGS)
    self.ESPObjects = {}
    return self
end

function ESPLibrary:CreateDrawing(type, props)
    local d = Drawing.new(type)
    for k, v in pairs(props) do
        d[k] = v
    end
    return d
end

function ESPLibrary:UpdateSettings(new)
    for k, v in pairs(new) do
        self.Settings[k] = v
    end
end

function ESPLibrary:AddPlayer(player)
    if player == LocalPlayer then
        return
    end
    local objects = {
        Box = self:CreateDrawing("Square", {
            Thickness = 1,
            Color = self.Settings.BoxColor,
            Filled = false,
            Visible = false
        }),
        Name = self:CreateDrawing("Text", {
            Size = 16,
            Center = true,
            Outline = true,
            Color = self.Settings.NicknameColor,
            Visible = false
        }),
        Health = self:CreateDrawing("Line", {
            Thickness = 2,
            Color = self.Settings.HealthBarColor,
            Visible = false
        }),
        Skeleton = {}
    }
    self.ESPObjects[player] = objects
end

function ESPLibrary:RemovePlayer(player)
    if self.ESPObjects[player] then
        for _, v in pairs(self.ESPObjects[player]) do
            if type(v) == "table" then
                for _, line in pairs(v) do
                    line:Remove()
                end
            else
                v:Remove()
            end
        end
        self.ESPObjects[player] = nil
    end
end
function ESPLibrary:Start()
    Players.PlayerAdded:Connect(function(p)
        self:AddPlayer(p)
    end)
    Players.PlayerRemoving:Connect(function(p)
        self:RemovePlayer(p)
    end)
    for _, p in pairs(Players:GetPlayers()) do
        self:AddPlayer(p)
    end

    RunService.RenderStepped:Connect(function()
        for player, obj in pairs(self.ESPObjects) do
            local char = player.Character
            -- ดึง Humanoid และ RootPart ใหม่ทุก Frame เพื่อความ Real-time
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if hrp and hum and self.Settings.Enabled then
                local pos, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
                local dist = (CurrentCamera.CFrame.Position - hrp.Position).Magnitude

                if onScreen and dist <= self.Settings.RenderDistance then
                    -- คำนวณขนาด Box
                    local topPos = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local bottomPos = CurrentCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local sizeY = bottomPos.Y - topPos.Y
                    local sizeX = sizeY / 1.5
                    local boxSize = Vector2.new(sizeX, sizeY)
                    local boxPos = Vector2.new(pos.X - sizeX / 2, pos.Y - sizeY / 2)

                    -- [[ อัปเดต BOX ]] --
                    obj.Box.Visible = self.Settings.BoxEnable
                    obj.Box.Position = boxPos
                    obj.Box.Size = boxSize

                    -- [[ อัปเดต NAME ]] --
                    obj.Name.Visible = self.Settings.Nickname
                    obj.Name.Text = player.Name
                    obj.Name.Position = Vector2.new(pos.X, boxPos.Y - 18)

                    -- [[ อัปเดต HEALTH BAR (REAL-TIME FIX) ]] --
                    if self.Settings.HealthBar then
                        obj.Health.Visible = true

                        -- คำนวณเปอร์เซ็นต์เลือดปัจจุบัน
                        local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

                        -- กำหนดตำแหน่ง Bar ให้อยู่ข้าง Box ด้านซ้าย
                        local barPosX = boxPos.X - 5
                        local barStart = boxPos.Y + boxSize.Y -- จุดล่างสุดของบาร์
                        local barEnd = boxPos.Y + boxSize.Y - (boxSize.Y * healthPercent) -- จุดสูงสุดตามเลือดที่มี

                        obj.Health.From = Vector2.new(barPosX, barStart)
                        obj.Health.To = Vector2.new(barPosX, barEnd)

                        -- ปรับสีตามปริมาณเลือด (Option: เขียวไปแดง)
                        obj.Health.Color = Color3.fromHSV(healthPercent * 0.3, 1, 1)
                    else
                        obj.Health.Visible = false
                    end

                    -- [[ SKELETON LOGIC ]] --
                    -- (คงเดิมตามโค้ดของคุณ)
                    if self.Settings.Skeleton then
                        local joints = hum.RigType == Enum.HumanoidRigType.R15 and JOINT_CONFIGS.R15 or JOINT_CONFIGS.R6
                        for i, joint in pairs(joints) do
                            local p1 = char:FindFirstChild(joint[1])
                            local p2 = char:FindFirstChild(joint[2])
                            if p1 and p2 then
                                local pos1, vis1 = CurrentCamera:WorldToViewportPoint(p1.Position)
                                local pos2, vis2 = CurrentCamera:WorldToViewportPoint(p2.Position)
                                if vis1 and vis2 then
                                    if not obj.Skeleton[i] then
                                        obj.Skeleton[i] = self:CreateDrawing("Line", {
                                            Thickness = 1,
                                            Color = self.Settings.SkeletonColor
                                        })
                                    end
                                    obj.Skeleton[i].Visible = true
                                    obj.Skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                                    obj.Skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                                else
                                    if obj.Skeleton[i] then
                                        obj.Skeleton[i].Visible = false
                                    end
                                end
                            end
                        end
                    else
                        for _, v in pairs(obj.Skeleton) do
                            v.Visible = false
                        end
                    end
                else
                    -- ปิดการมองเห็นถ้าอยู่นอกจอหรือไกลเกินไป
                    obj.Box.Visible = false
                    obj.Name.Visible = false
                    obj.Health.Visible = false
                    for _, v in pairs(obj.Skeleton) do
                        v.Visible = false
                    end
                end
            else
                -- ปิดการมองเห็นถ้าไม่มี Humanoid/HRP
                obj.Box.Visible = false
                obj.Name.Visible = false
                obj.Health.Visible = false
                for _, v in pairs(obj.Skeleton) do
                    v.Visible = false
                end
            end
        end
    end)
end
return ESPLibrary
