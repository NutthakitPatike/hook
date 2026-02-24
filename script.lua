local httpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [[ CONFIGURATION ]] --
-- ใส่ URL จาก ngrok ของคุณที่นี่ (ต้องมี /api/update-data ต่อท้าย)
local API_URL = "https://dozenth-mundanely-monica.ngrok-free.dev/api/update-data" 

-- อ้างอิง UI เพื่อดึงค่าสภาพอากาศปัจจุบัน
local weatherDisplay = player.PlayerGui:WaitForChild("WeatherDisplay", 10)
local weatherContainer = weatherDisplay and weatherDisplay:FindFirstChild("WeatherContainer")

-- ฟังก์ชันดึงรายการของในร้านค้าจาก StockText ใน UI
local function getActiveStock(shopName)
    local items = {}
    local shopGui = player.PlayerGui:FindFirstChild(shopName)
    
    if shopGui and shopGui:FindFirstChild("Frame") then
        local scrollingFrame = shopGui.Frame:FindFirstChild("ScrollingFrame")
        if scrollingFrame then
            for _, itemFrame in pairs(scrollingFrame:GetChildren()) do
                local mainInfo = itemFrame:FindFirstChild("MainInfo")
                if mainInfo and mainInfo:FindFirstChild("StockText") then
                    local rawText = mainInfo.StockText.Text
                    local stockNumber = tonumber(rawText:match("%d+")) or 0
                    
                    table.insert(items, {
                        name = itemFrame.Name,
                        quantity = stockNumber
                    })
                end
            end
        end
    end
    return items
end

local function getFinalData()
    local displayName = player.DisplayName
    local userId = player.UserId
    local moneyDisplay = player.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
    
    local payload = {
        player = player.Name,
        displayName = displayName,
        userId = userId,
        money = moneyDisplay,
        weather = {}, 
        inventory = {},
        shop_stock = {
            seeds = getActiveStock("SeedShop"),
            gear = getActiveStock("GearShop")
        },
        updatedAt = os.date("%Y-%m-%d %H:%M:%S")
    }

    -- 1. เช็คสภาพอากาศจาก UI
    if weatherContainer then
        local activeIcon = weatherContainer:FindFirstChild("ActiveWeatherIcon")
        local weatherName = weatherContainer.WeatherInfo.WeatherName.Text
        
        if activeIcon and weatherName ~= "" then
            payload.weather = {
                isActive = true,
                name = weatherName,
                description = weatherContainer.WeatherInfo.WeatherDescription.Text:gsub("<[^>]+>", ""),
                iconId = activeIcon.Image:match("%d+") or "0"
            }
        else
            payload.weather = { isActive = false, name = "Normal", description = "Sky is clear.", iconId = "0" }
        end
    else
        payload.weather = { isActive = false, name = "Normal", description = "Waiting for game UI...", iconId = "0" }
    end

    -- 2. ดึงข้อมูล Backpack
    local invCounts = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            local itemType = tool:GetAttribute("Type") or "Plants"
            local count = tool:GetAttribute("ItemCount") 
                         or tool:GetAttribute("Amount") 
                         or (tool:FindFirstChild("Amount") and tool.Amount.Value) 
                         or 1
            
            if not invCounts[baseName] then 
                invCounts[baseName] = {type = itemType, amount = 0} 
            end
            invCounts[baseName].amount = invCounts[baseName].amount + count
        end
    end

    for name, data in pairs(invCounts) do
        table.insert(payload.inventory, { 
            name = name, 
            type = data.type, 
            amount = data.amount,
            ItemCount = data.amount 
        })
    end

    return payload
end

-- ฟังก์ชันส่งข้อมูลไปที่ ngrok / Dashboard
local function syncToDashboard()
    local success, data = pcall(getFinalData)
    if success then
        local jsonPayload = httpService:JSONEncode(data)
        
        -- ใช้ http_request (สำหรับ Executor)
        local request = (syn and syn.request) or (http and http.request) or http_request
        if request then
            local response = request({
                Url = API_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["ngrok-skip-browser-warning"] = "true" -- ข้ามหน้าแจ้งเตือน ngrok
                },
                Body = jsonPayload
            })

            if response and response.Success then
                print("✅ Dashboard Synced! (Status: " .. response.StatusMessage .. ")")
            else
                warn("❌ Sync Failed: " .. (response and response.StatusCode or "Unknown Error"))
            end
        else
            warn("❌ Executor does not support http_request")
        end
        
        -- ยังคงเขียนไฟล์ลงเครื่องไว้เป็น Backup (เผื่อคุณอยากเช็คไฟล์)
        writefile("DashboardData.json", jsonPayload) 
    else
        warn("❌ Data Prep Error: " .. tostiring(data))
    end
end

-- เริ่มการทำงาน
print("🚀 Garden Sync System Started...")
syncToDashboard()

while true do
    task.wait(10) -- อัปเดตทุก 10 วินาที
    syncToDashboard()
end