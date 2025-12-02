-- LocalScript: StarterGui/ClientGUI_Local
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local RE_Invis = ReplicatedStorage:WaitForChild("ToggleInvisibility")
local RE_Platform = ReplicatedStorage:WaitForChild("ToggleJumpPlatform")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EliasDevGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main frame
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 320, 0, 160)
frame.Position = UDim2.new(0.7, 0, 0.05, 0)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Parent = screenGui
frame.Active = true

-- Top bar
local top = Instance.new("Frame")
top.Size = UDim2.new(1,0,0,28)
top.Position = UDim2.new(0,0,0,0)
top.BackgroundColor3 = Color3.fromRGB(20,20,20)
top.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.7,0,1,0)
title.Position = UDim2.new(0,6,0,0)
title.BackgroundTransparency = 1
title.Text = "Herramientas"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.Parent = top

-- Close button (X)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,20)
closeBtn.Position = UDim2.new(1,-34,0,4)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 18
closeBtn.BackgroundColor3 = Color3.fromRGB(160,50,50)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = top

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0,28,0,20)
minBtn.Position = UDim2.new(1,-68,0,4)
minBtn.Text = "—"
minBtn.Font = Enum.Font.SourceSansBold
minBtn.TextSize = 18
minBtn.BackgroundColor3 = Color3.fromRGB(120,120,120)
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Parent = top

-- Content area
local content = Instance.new("Frame")
content.Size = UDim2.new(1,0,0,132)
content.Position = UDim2.new(0,0,0,28)
content.BackgroundTransparency = 1
content.Parent = frame

-- Button: Invisibilidad
local invisBtn = Instance.new("TextButton")
invisBtn.Size = UDim2.new(0,0,0,40)
invisBtn.Position = UDim2.new(0,12,0,14)
invisBtn.Size = UDim2.new(0,140,0,40)
invisBtn.Text = "Invisibilidad: OFF"
invisBtn.Parent = content
invisBtn.Font = Enum.Font.SourceSans
invisBtn.TextSize = 16

-- Button: Salto (platform)
local jumpBtn = Instance.new("TextButton")
jumpBtn.Size = UDim2.new(0,140,0,40)
jumpBtn.Position = UDim2.new(0,168,0,14)
jumpBtn.Text = "Salto: OFF"
jumpBtn.Parent = content
jumpBtn.Font = Enum.Font.SourceSans
jumpBtn.TextSize = 16

-- Floating circle (minimized icon)
local circle = Instance.new("ImageButton")
circle.Name = "FloatCircle"
circle.Size = UDim2.new(0,48,0,48)
circle.Position = UDim2.new(0.95,-56,0.05,0) -- default corner
circle.Parent = screenGui
circle.Visible = false
circle.BackgroundTransparency = 1
circle.Image = "" -- puedes poner una imagen si quieres o dejar vacío para color
circle.BackgroundColor3 = Color3.fromRGB(50,50,50)

-- Make frames draggable (generic)
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragging and dragStart and startPos then
                local delta = input.Position - dragStart
                local absX = startPos.X.Offset + delta.X
                local absY = startPos.Y.Offset + delta.Y
                guiObject.Position = UDim2.new(startPos.X.Scale, absX, startPos.Y.Scale, absY)
            end
        end
    end)
end

makeDraggable(frame, top)
makeDraggable(circle, circle)

-- State variables
local invisOn = false
local platformOn = false

-- Button actions
invisBtn.MouseButton1Click:Connect(function()
    invisOn = not invisOn
    invisBtn.Text = "Invisibilidad: " .. (invisOn and "ON" or "OFF")
    -- send to server
    RE_Invis:FireServer(invisOn)
end)

jumpBtn.MouseButton1Click:Connect(function()
    platformOn = not platformOn
    jumpBtn.Text = "Salto: " .. (platformOn and "ON" or "OFF")
    RE_Platform:FireServer(platformOn)
end)

closeBtn.MouseButton1Click:Connect(function()
    -- destroy GUI entirely
    screenGui:Destroy()
end)

minBtn.MouseButton1Click:Connect(function()
    -- hide main frame and show circle
    frame.Visible = false
    circle.Visible = true
end)

circle.MouseButton1Click:Connect(function()
    frame.Visible = true
    circle.Visible = false
end)

-- Make sure GUI persists across respawn
player.CharacterAdded:Connect(function()
    screenGui.Parent = player:WaitForChild("PlayerGui")
end)
