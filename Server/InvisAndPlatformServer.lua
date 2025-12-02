-- Server script: ServerScriptService/InvisAndPlatformServer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RE_Invis = ReplicatedStorage:WaitForChild("ToggleInvisibility")
local RE_Platform = ReplicatedStorage:WaitForChild("ToggleJumpPlatform")

-- Guardamos estados y datos originales para restaurar
local playerState = {} -- [player] = {invisible = bool, originals = {...}, platform = part, followConn = conn}

-- Helper: collect parts / guis in a character/model to hide/restore
local function collectVisuals(character)
    local parts = {}
    for _, obj in pairs(character:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
            table.insert(parts, obj)
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            table.insert(parts, obj)
        end
    end
    return parts
end

-- Set invisibility for a target player for all clients (server authoritative)
local function setInvisibleForAll(targetPlayer, makeInvis)
    local char = targetPlayer.Character
    if not char then return end

    -- store original values first time
    playerState[targetPlayer] = playerState[targetPlayer] or {}
    local st = playerState[targetPlayer]
    st.originals = st.originals or {}

    local visuals = collectVisuals(char)
    for _, obj in pairs(visuals) do
        -- store original on first time
        if not st.originals[obj] then
            if obj:IsA("BasePart") then
                st.originals[obj] = {Class="BasePart", Transparency = obj.Transparency, CanCollide = obj.CanCollide}
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                st.originals[obj] = {Class=obj.ClassName, Transparency = obj.Transparency}
            elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                st.originals[obj] = {Class=obj.ClassName, Enabled = obj.Enabled}
            end
        end

        -- apply invisibility or restore
        if makeInvis then
            if obj:IsA("BasePart") then
                obj.Transparency = 1
                -- optional: obj.CanCollide = false -- keep collisions if you want, but usually invisible should still collide
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                obj.Enabled = false
            end
        else
            -- restore if original exists
            local orig = st.originals[obj]
            if orig then
                if orig.Class == "BasePart" then
                    obj.Transparency = orig.Transparency or 0
                    if orig.CanCollide ~= nil then obj.CanCollide = orig.CanCollide end
                elseif orig.Class == "Decal" or orig.Class == "Texture" then
                    obj.Transparency = orig.Transparency or 0
                else
                    if orig.Enabled ~= nil then obj.Enabled = orig.Enabled end
                end
            end
        end
    end

    st.invisible = makeInvis
end

-- When a tool is picked up (parent becomes character), also hide tool parts
local function onCharacterAdded(player, character)
    -- connect tool parent changes
    character.DescendantAdded:Connect(function(desc)
        local st = playerState[player]
        if st and st.invisible then
            -- if new part added and we are invisible, hide it
            if desc:IsA("BasePart") then
                st.originals = st.originals or {}
                if not st.originals[desc] then
                    st.originals[desc] = {Class="BasePart", Transparency = desc.Transparency, CanCollide = desc.CanCollide}
                end
                desc.Transparency = 1
            elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                st.originals = st.originals or {}
                if not st.originals[desc] then
                    st.originals[desc] = {Class=desc.ClassName, Enabled = desc.Enabled}
                end
                desc.Enabled = false
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    playerState[player] = {invisible = false, originals = {}}
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    -- cleanup
    local st = playerState[player]
    if st then
        -- restore any leftover originals
        if st.invisible then
            setInvisibleForAll(player, false)
        end
        -- remove platform
        if st.followConn then
            st.followConn:Disconnect()
            st.followConn = nil
        end
        if st.platform and st.platform.Parent then
            st.platform:Destroy()
            st.platform = nil
        end
        playerState[player] = nil
    end
end)

-- RemoteEvent: toggle invisibility (client requests toggle)
RE_Invis.OnServerEvent:Connect(function(player, want)
    -- Validate: must exist and be boolean
    if type(want) ~= "boolean" then return end
    playerState[player] = playerState[player] or {originals = {}}
    setInvisibleForAll(player, want)
end)

-- Platform management
local function createPlatformFor(player)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local hrp = char.HumanoidRootPart
    -- create a thin, translucent platform
    local p = Instance.new("Part")
    p.Name = "JumpPlatform_"..player.Name
    p.Size = Vector3.new(6, 0.5, 6)
    p.Anchored = true
    p.CanCollide = true
    p.Transparency = 0.5
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = workspace
    -- position initially under feet
    p.CFrame = hrp.CFrame - Vector3.new(0, (hrp.Size.Y/2 + 3), 0)
    return p
end

local function startPlatformFollow(player)
    local st = playerState[player] or {}
    if st.followConn then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    -- ensure platform exists
    if not st.platform or not st.platform.Parent then
        st.platform = createPlatformFor(player)
    end
    if not st.platform then return end

    -- follow with prediction
    st.followConn = RunService.Heartbeat:Connect(function(dt)
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        local hrp2 = player.Character.HumanoidRootPart
        -- prediction: small ahead based on velocity
        local predicted = hrp2.Position + hrp2.Velocity * 0.12
        -- offset down so platform is under feet (adjust height as needed)
        local targetPos = predicted - Vector3.new(0, 3.5, 0)
        -- smooth LERP to avoid jitter
        local cur = st.platform.Position
        local newPos = cur:Lerp(targetPos, math.clamp(20 * dt, 0, 1))
        st.platform.CFrame = CFrame.new(newPos)
    end)
end

local function stopPlatformFollow(player)
    local st = playerState[player]
    if not st then return end
    if st.followConn then
        st.followConn:Disconnect()
        st.followConn = nil
    end
    if st.platform and st.platform.Parent then
        st.platform:Destroy()
        st.platform = nil
    end
end

-- Handle toggle request from client for jump-platform mode
RE_Platform.OnServerEvent:Connect(function(player, want)
    if type(want) ~= "boolean" then return end
    playerState[player] = playerState[player] or {originals = {}}
    local st = playerState[player]
    st.platformEnabled = want

    if want then
        -- connect jumping events
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if st.jumpingConn then st.jumpingConn:Disconnect() end
            st.jumpingConn = humanoid.Jumping:Connect(function(isActive)
                -- on jump, create/refresh platform and start follow
                if isActive then
                    if not st.platform or not st.platform.Parent then
                        st.platform = createPlatformFor(player)
                    end
                    startPlatformFollow(player)
                end
            end)
        end
        -- listen for respawn to reattach
        if st.charAddedConn then st.charAddedConn:Disconnect() end
        st.charAddedConn = player.CharacterAdded:Connect(function(c)
            wait(0.2)
            if st.platformEnabled then
                local hum = c:FindFirstChildOfClass("Humanoid")
                if hum then
                    if st.jumpingConn then st.jumpingConn:Disconnect() end
                    st.jumpingConn = hum.Jumping:Connect(function(isActive)
                        if isActive then
                            if not st.platform or not st.platform.Parent then
                                st.platform = createPlatformFor(player)
                            end
                            startPlatformFollow(player)
                        end
                    end)
                end
            end
        end)
    else
        -- disable platform mode
        if st.jumpingConn then st.jumpingConn:Disconnect(); st.jumpingConn = nil end
        if st.charAddedConn then st.charAddedConn:Disconnect(); st.charAddedConn = nil end
        stopPlatformFollow(player)
    end
end)
