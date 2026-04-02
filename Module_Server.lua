local Module_Server = {}

function Module_Server.GetPlatform(player)
    if player == game.Players.LocalPlayer then
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled then return "Mobile"
        elseif UIS.KeyboardEnabled then return "PC"
        else return "Console" end
    end
    return "PC/Mobile"
end

function Module_Server.RenderPlayerList(section, WindUI)
    for _, v in pairs(game.Players:GetPlayers()) do
        local avatarIcon = "rbxthumb://type=AvatarHeadShot&id=" .. v.UserId .. "&w=150&h=150"
        local platform = Module_Server.GetPlatform(v)

        section:Paragraph({
            Title = "Name: " .. v.DisplayName .. " (@" .. v.Name .. ")",
            Desc = "Device: " .. platform .. "\nID: " .. v.UserId,
            Image = avatarIcon,
            ImageSize = 35,
            Buttons = {
                {
                    Icon = "copy",
                    Title = "Copy ID",
                    Callback = function()
                        setclipboard(tostring(v.UserId))
                        WindUI:Notify({ Title = "Success", Content = "Copied ID: " .. v.Name, Duration = 3 })
                    end,
                }
            }
        })
    end
end

return Module_Server
