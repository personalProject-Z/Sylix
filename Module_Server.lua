local ServerInfo = {}
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- // ฟังก์ชันดึง Region ของ Server (ต้องใช้ HTTP)
function ServerInfo:GetRegion()
    local success, result = pcall(function()
        local response = HttpService:JSONDecode(game:HttpGet("http://ip-api.com/json/"))
        return response.country or "Unknown"
    end)
    return success and result or "Locked (No HTTP)"
end

-- // ฟังก์ชันเช็ค Device (ตรวจสอบเบื้องต้นจาก Input)
function ServerInfo:GetPlayerDevice(player)
    if not player then return "Unknown" end
    
    -- หมายเหตุ: วิธีนี้แม่นยำที่สุดเท่าที่สคริปต์ปกติจะทำได้
    local guiService = game:GetService("GuiService")
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile/Tablet"
    elseif UserInputService.KeyboardEnabled then
        return "PC"
    elseif GuiService:IsTenFootInterface() then
        return "Console"
    else
        return "Unknown"
    end
end

-- // ฟังก์ชันคำนวณเวลาที่เซิร์ฟเวอร์รันมา
function ServerInfo:GetServerRunTime()
    local seconds = math.floor(workspace.DistributedGameTime)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- // ฟังก์ชันดึงค่า Ping (หน่วย ms)
function ServerInfo:GetPing()
    return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
end

-- // ฟังก์ชันดึงจำนวนผู้เล่น
function ServerInfo:GetPlayerCount()
    return #Players:GetPlayers() .. " / " .. Players.MaxPlayers
end

return ServerInfo
