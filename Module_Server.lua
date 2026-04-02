local Module_Server = {}

-- ฟังก์ชันเช็ค Platform
function Module_Server.GetPlatform(player)
    -- เช็ค Device เฉพาะของตัวเอง (LocalPlayer)
    if player == game.Players.LocalPlayer then
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled then return "Mobile"
        elseif UIS.KeyboardEnabled then return "PC"
        else return "Console" end
    end
    return "PC/Mobile" -- ค่าสมมติสำหรับคนอื่น (เนื่องจาก Roblox ปิดกั้นข้อมูลนี้เพื่อความเป็นส่วนตัว)
end

-- ฟังก์ชันหลักสำหรับสร้าง List ผู้เล่น
function Module_Server.RenderPlayerList(section, WindUI)
    for _, v in pairs(game.Players:GetPlayers()) do
        -- ใช้ rbxthumb แบบ HeadShot (รูปหัว) เพราะขนาดเล็กและโหลดง่ายกว่า
        local avatarIcon = "rbxthumb://type=AvatarHeadShot&id=" .. v.UserId .. "&w=150&h=150"
        local platform = Module_Server.GetPlatform(v)

        section:Paragraph({
            Title = "Name: " .. v.DisplayName .. " (@" .. v.Name .. ")",
            -- 🛠 เพิ่มบรรทัด Device: และ ID:
            Desc = "Device: " .. platform .. "\nID: " .. v.UserId,

            -- 🛠 ย้ายรูปมาใส่ตรง Image (ไอคอนหน้าข้อความ) แทน Thumbnail
            Image = avatarIcon, 
            ImageSize = 35, -- ปรับขนาดไอคอนให้ใหญ่พอดี ไม่บังตัวหนังสือ

            Buttons = {
                {
                    Icon = "copy",
                    Title = "Copy ID",
                    Callback = function()
                        setclipboard(tostring(v.UserId))
                        if WindUI then
                            WindUI:Notify({ Title = "Success", Content = "Copied ID: " .. v.Name, Duration = 3 })
                        end
                    end,
                }
            }
        })
    end
end

return Module_Server
