local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ปรับ URL ให้ตรงกับ Route ของคุณ
-- หากรันในคอมเครื่องเดียวกันใช้ http://localhost:3000/api/update-data
-- หากรันจากคนละเครื่องให้ใช้ IP ของเครื่องที่รัน Next.js
local API_URL = "http://localhost:3000/api/update-data" 

local http_request = syn and syn.request or http_request or (http and http.request) or request

--- ### UI & Logic Methods ### ---
local GardenManager = {}
GardenManager.__index = GardenManager

function GardenManager.new()
    local self = setmetatable({}, GardenManager)
    self.isSyncing = false
    return self
end

-- Method สำหรับดึงข้อความจาก UI อย่างปลอดภัย
function GardenManager:safeText(path)
    local ok, val = pcall(function() return path and path.Text end)
    return ok and val or nil
end

-- Method สำหรับเช็คสต็อกร้านค้า
function GardenManager:getShopStock(shopName)
    local items = {}
    local shopGui = player.PlayerGui:FindFirstChild(shopName)
    
    if shopGui and shopGui:FindFirstChild("Frame") then
        local scroll = shopGui.Frame:FindFirstChild("ScrollingFrame")
        if scroll then
            for _, item in pairs(scroll:GetChildren()) do
                local info = item:FindFirstChild("MainInfo")
                if info and info:FindFirstChild("StockText") then
                    local stock = tonumber(self:safeText(info.StockText):match("%d+")) or 0
                    table.insert(items, { name = item.Name, quantity = stock })
                end
            end
        end
    end
    return items
end

-- Method สำหรับรวมข้อมูลทั้งหมด (Payload)
function GardenManager:collectData()
    local money = "0"
    pcall(function()
        money = player.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
    end)

    local payload = {
        player = player.Name, -- ส่งไปเป็นชื่อไฟล์ใน Next.js
        displayName = player.DisplayName,
        userId = player.UserId,
        money = money,
        shop_stock = {
            seeds = self:getShopStock("SeedShop"),
            gear = self:getShopStock("GearShop")
        },
        inventory = {},
        updatedAt = os.date("%Y-%m-%d %H:%M:%S")
    }

    -- ดึงข้อมูล Backpack
    local inv = {}
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in pairs(bp:GetChildren()) do
            local name = t:GetAttribute("BaseName") or t.Name
            inv[name] = (inv[name] or 0) + (t:GetAttribute("ItemCount") or 1)
        end
    end
    for n, q in pairs(inv) do table.insert(payload.inventory, {name = n, amount = q}) end

    return payload
end

-- Method หลักในการส่งข้อมูลไปยัง Next.js
function GardenManager:sync()
    if self.isSyncing then return end
    self.isSyncing = true
    
    local ok, data = pcall(function() return self:collectData() end)
    if not ok then 
        warn("❌ Data Collection Failed")
        self.isSyncing = false
        return 
    end

    local response = http_request({
        Url = API_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(data)
    })

    if response and response.Success then
        print("🚀 Data Sent to Next.js: " .. data.player)
    else
        warn("📡 Sync Error: " .. (response and response.StatusCode or "Server Offline"))
    end
    
    self.isSyncing = false
end

--- ### การเรียกใช้งาน ### ---
local MyGarden = GardenManager.new()

-- ตั้งค่า Loop ให้ทำงานเบื้องหลัง
task.spawn(function()
    print("🌿 Garden Dashboard Sync Active...")
    while true do
        MywGarden:sync()
        task.wait(10) -- ส่งข้อมูลทุก 10 วินาที
    end
end)