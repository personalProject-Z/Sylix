local Module_Server = {}

-- [[ ฟังก์ชันเช็ค Platform (ต้องมีอันนี้ด้วย) ]]
function Module_Server.GetPlatform(player)
    -- ตรวจสอบผ่าน UserInputService (จะแม่นยำที่สุดสำหรับตัวเราเอง)
    if player == game.Players.LocalPlayer then
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled then return "Mobile"
        elseif UIS.KeyboardEnabled then return "PC"
        else return "Console" end
    end
    -- สำหรับคนอื่น Roblox ไม่เปิดเผยข้อมูลตรงๆ จึงส่งเป็น Default ไว้
    return "PC/Mobile" 
end

-- [[ ฟังก์ชันหลักสำหรับสร้าง List ผู้เล่น ]]
function Module_Server.RenderPlayerList(section, WindUI)
    for _, v in pairs(game.Players:GetPlayers()) do
        -- ใช้ rbxthumb สำหรับดึงรูป Avatar Headshot
        local avatarIcon = "rbxthumb://type=AvatarHeadShot&id=" .. v.UserId .. "&w=150&h=150"
        local platform = Module_Server.GetPlatform(v)
        
        section:Paragraph({
            Title = v.DisplayName .. " (@" .. v.Name .. ")",
            -- Fix: เพิ่มข้อมูล Device เข้าไปใน Desc
            Desc = "Device: " .. platform .. "\nID: " .. v.UserId,
            Image = avatarIcon, 
            ImageSize = 35,
            Buttons = {
                {
                    Icon = "copy",
                    Title = "Copy ID",
                    Callback = function()
                        setclipboard(tostring(v.UserId))
                        if WindUI then
                            WindUI:Notify({ 
                                Title = "Success", 
                                Content = "Copied ID: " .. v.Name, 
                                Duration = 3 
                            })
                        end
                    end,
                }
            }
        })
    end
end

return Module_Server
