local Module_Server = {}

-- ฟังก์ชันหลักสำหรับสร้าง List ผู้เล่น
function Module_Server.RenderPlayerList(section, WindUI)
    for _, v in pairs(game.Players:GetPlayers()) do
        local avatarIcon = "rbxthumb://type=AvatarHeadShot&id=" .. v.UserId .. "&w=150&h=150"
        local platform = Module_Server.GetPlatform(v)
        section:Paragraph({
            Title = v.DisplayName .. " (@" .. v.Name .. ")",
            Desc = "ID: " .. v.UserId,
            Image = avatarIcon, 
            ImageSize = 35,
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
