local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- [[ แก้ไข: เพิ่ม CameraCache ที่ขาดไป ]]
local CameraCache = {
    position = Vector3.new(),
    cframe = CFrame.new(),
    fieldOfView = 70,
    lastUpdate = 0
}

local JOINT_CONFIGS = {
    R15 = {{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"},
           {"LeftUpperArm", "LeftLowerArm"}, {"LeftUpperArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
           {"RightUpperArm", "RightLowerArm"}, {"RightUpperArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
           {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftUpperLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
           {"RightUpperLeg", "RightLowerLeg"}, {"RightUpperLeg", "RightFoot"}},
    R6 = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"},
          {"Torso", "Right Leg"}}
}

local DEFAULT_SETTINGS = {
    Enabled = true,
    BoxEnable = false,
    HealthBar = false,
    Nickname = false,
    Skeleton = false,
    BoxColor = Color3.new(1, 1, 1),
    SkeletonColor = Color3.new(1, 1, 1),
    NicknameColor = Color3.new(1, 1, 1),
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    RenderDistance = 1000,
    CacheUpdateInterval = 0.016,
}

-- [[ Helper Functions ]]
local function UpdateCameraCache()
    local currentTime = tick()
    local camCFrame = CurrentCamera.CFrame
    if currentTime - CameraCache.lastUpdate >= DEFAULT_SETTINGS.CacheUpdateInterval then
        CameraCache.position = camCFrame.Position
        CameraCache.cframe = camCFrame
        CameraCache.fieldOfView = CurrentCamera.FieldOfView
        CameraCache.lastUpdate = currentTime
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
    for k, v in pairs(props) do d[k] = v end
    return d
end

function ESPLibrary:UpdateSettings(new)
    for k, v in pairs(new) do self.Settings[k] = v end
end

function ESPLibrary:AddPlayer(player)
    if player == LocalPlayer then return end
    self.ESPObjects[player] = {
        Box = self:CreateDrawing("Square", {Thickness = 1, Color = self.Settings.BoxColor, Visible = false}),
        Name = self:CreateDrawing("Text", {Size = 16, Center = true, Outline = true, Color = self.Settings.NicknameColor, Visible = false}),
        Health = self:CreateDrawing("Line", {Thickness = 2, Color = self.Settings.HealthBarColor, Visible = false}),
        Skeleton = {}
    }
end

function ESPLibrary:RemovePlayer(player)
    if self.ESPObjects[player] then
        for _, v in pairs(self.ESPObjects[player]) do
            if type(v) == "table" then for _, line in pairs(v) do line:Remove() end
            else v:Remove() end
        end
        self.ESPObjects[player] = nil
    end
end

function ESPLibrary:Start()
    Players.PlayerAdded:Connect(function(p) self:AddPlayer(p) end)
    Players.PlayerRemoving:Connect(function(p) self:RemovePlayer(p) end)
    for _, p in pairs(Players:GetPlayers()) do self:AddPlayer(p) end

    RunService.RenderStepped:Connect(function()
        UpdateCameraCache() -- อัปเดตตำแหน่งกล้องทุกเฟรม
        
        for player, obj in pairs(self.ESPObjects) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if hrp and hum and self.Settings.Enabled then
                local pos, onScreen = CurrentCamera:WorldToViewportPoint(hrp.Position)
                local dist = (CameraCache.position - hrp.Position).Magnitude

                if onScreen and dist <= self.Settings.RenderDistance then
                    -- คำนวณขนาด Box
                    local topPos = CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local bottomPos = CurrentCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local sizeY = math.abs(bottomPos.Y - topPos.Y)
                    local sizeX = sizeY / 1.5
                    local boxSize = Vector2.new(sizeX, sizeY)
                    local boxPos = Vector2.new(pos.X - sizeX / 2, pos.Y - sizeY / 2)

                    -- Update UI Elements
                    obj.Box.Visible = self.Settings.BoxEnable
                    obj.Box.Position = boxPos
                    obj.Box.Size = boxSize

                    obj.Name.Visible = self.Settings.Nickname
                    obj.Name.Text = player.Name
                    obj.Name.Position = Vector2.new(pos.X, boxPos.Y - 18)

                    if self.Settings.HealthBar then
                        local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        obj.Health.Visible = true
                        obj.Health.From = Vector2.new(boxPos.X - 5, boxPos.Y + boxSize.Y)
                        obj.Health.To = Vector2.new(boxPos.X - 5, boxPos.Y + boxSize.Y - (boxSize.Y * healthPercent))
                        obj.Health.Color = Color3.fromHSV(healthPercent * 0.3, 1, 1)
                    else
                        obj.Health.Visible = false
                    end

                    if self.Settings.Skeleton then
                        local joints = hum.RigType == Enum.HumanoidRigType.R15 and JOINT_CONFIGS.R15 or JOINT_CONFIGS.R6
                        for i, joint in pairs(joints) do
                            local p1, p2 = char:FindFirstChild(joint[1]), char:FindFirstChild(joint[2])
                            if p1 and p2 then
                                local pos1, vis1 = CurrentCamera:WorldToViewportPoint(p1.Position)
                                local pos2, vis2 = CurrentCamera:WorldToViewportPoint(p2.Position)
                                if vis1 and vis2 then
                                    if not obj.Skeleton[i] then
                                        obj.Skeleton[i] = self:CreateDrawing("Line", {Thickness = 1, Color = self.Settings.SkeletonColor})
                                    end
                                    obj.Skeleton[i].Visible = true
                                    obj.Skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                                    obj.Skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                                else
                                    if obj.Skeleton[i] then obj.Skeleton[i].Visible = false end
                                end
                            end
                        end
                    else
                        for _, v in pairs(obj.Skeleton) do v.Visible = false end
                    end
                else
                    obj.Box.Visible = false
                    obj.Name.Visible = false
                    obj.Health.Visible = false
                    for _, v in pairs(obj.Skeleton) do v.Visible = false end
                end
            else
                obj.Box.Visible = false
                obj.Name.Visible = false
                obj.Health.Visible = false
                for _, v in pairs(obj.Skeleton) do v.Visible = false end
            end
        end
    end)
end

return ESPLibrary
