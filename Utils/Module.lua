local Settings = ...

if type(Settings) ~= "table" then
  return nil
end

local _ENV = (getgenv or getrenv or getfenv)()

local VirtualInputManager: VirtualInputManager = game:GetService("VirtualInputManager")
local CollectionService: CollectionService = game:GetService("CollectionService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService: TeleportService = game:GetService("TeleportService")
local RunService: RunService = game:GetService("RunService")
local Players: Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunValidator: RemoteEvent = Remotes:WaitForChild("Validator2")
local CommF: RemoteFunction = Remotes:WaitForChild("CommF_")
local CommE: RemoteEvent = Remotes:WaitForChild("CommE")

local ChestModels = workspace:WaitForChild("ChestModels")
local WorldOrigin = workspace:WaitForChild("_WorldOrigin")
local Characters = workspace:WaitForChild("Characters")
local SeaBeasts = workspace:WaitForChild("SeaBeasts")
local Enemies = workspace:WaitForChild("Enemies")
local Map = workspace:WaitForChild("Map")

local EnemySpawns = WorldOrigin:WaitForChild("EnemySpawns")
local Locations = WorldOrigin:WaitForChild("Locations")

local RenderStepped = RunService.RenderStepped
local Heartbeat = RunService.Heartbeat
local Stepped = RunService.Stepped
local Player = Players.LocalPlayer

local Data = Player:WaitForChild("Data")
local Level = Data:WaitForChild("Level")
local Fragments = Data:WaitForChild("Fragments")
local Money = Data:WaitForChild("Beli")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")

local EXECUTOR_NAME = string.upper(if identifyexecutor then identifyexecutor() else "NULL")
local IS_BLACKLISTED_EXECUTOR = table.find({"NULL", "XENO", "SWIFT", "JJSPLOIT"}, EXECUTOR_NAME)

local hookmetamethod = (not IS_BLACKLISTED_EXECUTOR and hookmetamethod) or (function(...) return ... end)
local sethiddenproperty = sethiddenproperty or (function(...) return ... end)
local setupvalue = setupvalue or (debug and debug.setupvalue)
local getupvalue = getupvalue or (debug and debug.getupvalue)

local BRING_TAG = _ENV._Bring_Tag or `b{math.random(80, 2e4)}t`
local KILLAURA_TAG = _ENV._KillAura_Tag or `k{math.random(120, 2e4)}t`

_ENV._Bring_Tag = BRING_TAG
_ENV._KillAura_Tag = KILLAURA_TAG

local Connections = {} do
  if _ENV.rz_connections then
    for _, Connection in ipairs(_ENV.rz_connections) do
      Connection:Disconnect()
    end
  end
  
  _ENV.rz_connections = Connections
end

local function GetEnemyName(string)
  return (string:find("Lv. ") and string:gsub(" %pLv. %d+%p", "") or string):gsub(" %pBoss%p", "")
end

local function GetCharacterHumanoid(Character)
  if Character:GetAttribute("IsBoat") or Character.Parent == SeaBeasts then
    local HealthValue = Character:FindFirstChild("Health")
    
    if HealthValue then
      return HealthValue
    elseif Character:FindFirstChild("Humanoid") then
      return true
    end
  else
    return Character:FindFirstChildOfClass("Humanoid")
  end
end

local function CheckPlayerAlly(__Player: Player): boolean
  if tostring(__Player.Team) == "Marines" and __Player.Team == Player.Team then
    return false
  elseif __Player:HasTag(`Ally{Player.Name}`) or Player:HasTag(`Ally{__Player.Name}`) then
    return false
  end
  
  return true
end

local function WaitChilds(Instance, ...)
  for _, ChildName in ipairs({...}) do
    Instance = Instance:WaitForChild(ChildName)
  end
  return Instance
end

local function FastWait(Seconds, Instance, ...)
  local Success, Result = pcall(function(...)
    for _, ChildName in ipairs({...}) do
      Instance = Instance:WaitForChild(ChildName, Seconds)
    end
    return Instance
  end, ...)
  
  return Success and Result or nil
end

function ToDictionary(array)
  local Dictionary = {}
  
  for _, String in ipairs(array) do
    Dictionary[String] = true
  end
  
  return Dictionary
end

local Signal = {} do
  local Connection = {} do
    Connection.__index = Connection
    
    function Connection:Disconnect(): (nil)
      if not self.Connected then
        return nil
      end
      
      local find = table.find(self.Signal, self)
      
      if find then
        table.remove(self.Signal, find)
      end
      
      self.Function = nil
      self.Connected = false
    end
    
    function Connection:Fire(...): (nil)
      if not self.Function then
        return nil
      end
      
      task.spawn(self.Function, ...)
    end
    
    function Connection.new(): Connection
      return setmetatable({
        Connected = true
      }, Connection)
    end
    
    setmetatable(Connection, {
      __index = function(self, index)
        error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(index)), 2)
      end,
      __newindex = function(tb, key, value)
        error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
      end
    })
  end
  
  Signal.__index = Signal
  
  function Signal:Connect(Function): Connection
    if type(Function) ~= "function" then
      return nil
    end
    
    local NewConnection = Connection.new()
    NewConnection.Function = Function
    NewConnection.Signal = self
    
    table.insert(self.Connections, NewConnection)
    return NewConnection
  end
  
  function Signal:Once(Function): (nil)
    local Connection;
    Connection = self:Connect(function(...)
      Function(...)
      Connection:Disconnect()
    end)
    return Connection
  end
  
  function Signal:Wait(): any?
    local WaitingCoroutine = coroutine.running()
    local Connection;Connection = self:Connect(function(...)
      Connection:Disconnect()
      task.spawn(WaitingCoroutine, ...)
    end)
    return coroutine.yield()
  end
  
  function Signal:Fire(...): (nil)
    for _, Connection in ipairs(self.Connections) do
      if Connection.Connected then
        Connection:Fire(...)
      end
    end
  end
  
  function Signal.new(): Signal
    return setmetatable({
      Connections = {}
    }, Signal)
  end
  
  setmetatable(Signal, {
    __index = function(self, index)
      error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(index)), 2)
    end,
    __newindex = function(self, index, value)
      error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(index)), 2)
    end
  })
end

local Module = {} do
  local Cached = {
    Closest = nil,
    Equipped = nil,
    Humanoids = {},
    Progress = {},
    Enemies = {},
    Bring = {},
    Tools = {}
  }
  
  Module.GameData = {
    Sea = ({ [2753915549] = 1, [4442272183] = 2, [7449423635] = 3 })[game.PlaceId] or 0,
    SeasName = { "Main", "Dressrosa", "Zou" },
    MaxMastery = 600,
    MaxLevel = 2600,
  }
  
  Module.Debounce = {
    TargetDebounce = 0,
    UpdateDebounce = 0,
    GetEnemy = 0,
    Skills = {}
  }
  
  do
    Module.FruitsId = {
      ["rbxassetid://15060012861"] = "Rocket-Rocket",
      ["rbxassetid://15057683975"] = "Spin-Spin",
      ["rbxassetid://15104782377"] = "Blade-Blade",
      ["rbxassetid://15105281957"] = "Spring-Spring",
      ["rbxassetid://15116740364"] = "Bomb-Bomb",
      ["rbxassetid://15116696973"] = "Smoke-Smoke",
      ["rbxassetid://15107005807"] = "Spike-Spike",
      ["rbxassetid://15111584216"] = "Flame-Flame",
      ["rbxassetid://15112469964"] = "Falcon-Falcon",
      ["rbxassetid://15100433167"] = "Ice-Ice",
      ["rbxassetid://15111517529"] = "Sand-Sand",
      ["rbxassetid://15111553409"] = "Dark-Dark",
      ["rbxassetid://15112600534"] = "Diamond-Diamond",
      ["rbxassetid://15100283484"] = "Light-Light",
      ["rbxassetid://15104817760"] = "Rubber-Rubber",
      ["rbxassetid://15100485671"] = "Barrier-Barrier",
      ["rbxassetid://15112333093"] = "Ghost-Ghost",
      ["rbxassetid://15105350415"] = "Magma-Magma",
      ["rbxassetid://15057718441"] = "Quake-Quake",
      ["rbxassetid://15100313696"] = "Buddha-Buddha",
      ["rbxassetid://15116730102"] = "Love-Love",
      ["rbxassetid://15116967784"] = "Spider-Spider",
      ["rbxassetid://14661873358"] = "Sound-Sound",
      ["rbxassetid://15100246632"] = "Phoenix-Phoenix",
      ["rbxassetid://15112215862"] = "Portal-Portal",
      ["rbxassetid://15116747420"] = "Rumble-Rumble",
      ["rbxassetid://15116721173"] = "Pain-Pain",
      ["rbxassetid://15100384816"] = "Blizzard-Blizzard",
      ["rbxassetid://15100299740"] = "Gravity-Gravity",
      ["rbxassetid://14661837634"] = "Mammoth-Mammoth",
      ["rbxassetid://15708895165"] = "T-Rex-T-Rex",
      ["rbxassetid://15100273645"] = "Dough-Dough",
      ["rbxassetid://15112263502"] = "Shadow-Shadow",
      ["rbxassetid://15100184583"] = "Control-Control",
      ["rbxassetid://15106768588"] = "Leopard-Leopard",
      ["rbxassetid://15482881956"] = "Kitsune-Kitsune",
      ["rbxassetid://11911905519"] = "Spirit-Spirit",
      ["rbxassetid://118054805452821"] = "Gas-Gas",
      ["rbxassetid://115276580506154"] = "Yeti-Yeti",
      ["https://assetdelivery.roblox.com/v1/asset/?id=10395893751"] = "Venom-Venom",
      ["https://assetdelivery.roblox.com/v1/asset/?id=10537896371"] = "Dragon-Dragon"
    }
    
    Module.Bosses = {
      -- Bosses Sea 1
      ["Saber Expert"] = {
        NoQuest = true,
        Position = CFrame.new(-1461, 30, -51)
      },
      ["The Saw"] = {
        RaidBoss = true,
        Position = CFrame.new(-690, 15, 1583)
      },
      ["Greybeard"] = {
        RaidBoss = true,
        Position = CFrame.new(-5043, 25, 4262)
      },
      ["The Gorilla King"] = {
        IsBoss = true,
        Level = 20,
        Position = CFrame.new(-1128, 6, -451),
        Quest = {"JungleQuest", CFrame.new(-1598, 37, 153)}
      },
      ["Bobby"] = {
        IsBoss = true,
        Level = 55,
        Position = CFrame.new(-1131, 14, 4080),
        Quest = {"BuggyQuest1", CFrame.new(-1140, 4, 3829)}
      },
      ["Yeti"] = {
        IsBoss = true,
        Level = 105,
        Position = CFrame.new(1185, 106, -1518),
        Quest = {"SnowQuest", CFrame.new(1385, 87, -1298)}
      },
      ["Vice Admiral"] = {
        IsBoss = true,
        Level = 130,
        Position = CFrame.new(-4807, 21, 4360),
        Quest = {"MarineQuest2", CFrame.new(-5035, 29, 4326), 2}
      },
      ["Swan"] = {
        IsBoss = true,
        Level = 240,
        Position = CFrame.new(5230, 4, 749),
        Quest = {"ImpelQuest", CFrame.new(5191, 4, 692)}
      },
      ["Chief Warden"] = {
        IsBoss = true,
        Level = 230,
        Position = CFrame.new(5230, 4, 749),
        Quest = {"ImpelQuest", CFrame.new(5191, 4, 692), 2}
      },
      ["Warden"] = {
        IsBoss = true,
        Level = 220,
        Position = CFrame.new(5230, 4, 749),
        Quest = {"ImpelQuest", CFrame.new(5191, 4, 692), 1}
      },
      ["Magma Admiral"] = {
        IsBoss = true,
        Level = 350,
        Position = CFrame.new(-5694, 18, 8735),
        Quest = {"MagmaQuest", CFrame.new(-5319, 12, 8515)}
      },
      ["Fishman Lord"] = {
        IsBoss = true,
        Level = 425,
        Position = CFrame.new(61350, 31, 1095),
        Quest = {"FishmanQuest", CFrame.new(61122, 18, 1567)}
      },
      ["Wysper"] = {
        IsBoss = true,
        Level = 500,
        Position = CFrame.new(-7927, 5551, -637),
        Quest = {"SkyExp1Quest", CFrame.new(-7861, 5545, -381)}
      },
      ["Thunder God"] = {
        IsBoss = true,
        Level = 575,
        Position = CFrame.new(-7751, 5607, -2315),
        Quest = {"SkyExp2Quest", CFrame.new(-7903, 5636, -1412)}
      },
      ["Cyborg"] = {
        IsBoss = true,
        Level = 675,
        Position = CFrame.new(6138, 10, 3939),
        Quest = {"FountainQuest", CFrame.new(5258, 39, 4052)}
      },
      
      -- Bosses Sea 2
      ["Don Swan"] = {
        RaidBoss = true,
        Position = CFrame.new(2289, 15, 808)
      },
      ["Cursed Captain"] = {
        RaidBoss = true,
        Position = CFrame.new(912, 186, 33591)
      },
      ["Darkbeard"] = {
        RaidBoss = true,
        Position = CFrame.new(3695, 13, -3599)
      },
      ["Diamond"] = {
        IsBoss = true,
        Level = 750,
        Position = CFrame.new(-1569, 199, -31),
        Quest = {"Area1Quest", CFrame.new(-427, 73, 1835)}
      },
      ["Jeremy"] = {
        IsBoss = true,
        Level = 850,
        Position = CFrame.new(2316, 449, 787),
        Quest = {"Area2Quest", CFrame.new(635, 73, 919)}
      },
      ["Fajita"] = {
        IsBoss = true,
        Level = 925,
        Position = CFrame.new(-2086, 73, -4208),
        Quest = {"MarineQuest3", CFrame.new(-2441, 73, -3219)}
      },
      ["Smoke Admiral"] = {
        IsBoss = true,
        Level = 1150,
        Position = CFrame.new(-5078, 24, -5352),
        Quest = {"IceSideQuest", CFrame.new(-6061, 16, -4904)}
      },
      ["Awakened Ice Admiral"] = {
        IsBoss = true,
        Level = 1400,
        Position = CFrame.new(6473, 297, -6944),
        Quest = {"FrostQuest", CFrame.new(5668, 28, -6484)}
      },
      ["Tide Keeper"] = {
        IsBoss = true,
        Level = 1475,
        Position = CFrame.new(-3711, 77, -11469),
        Quest = {"ForgottenQuest", CFrame.new(-3056, 240, -10145)}
      },
      
      -- Bosses Sea 3
      ["Cake Prince"] = {
        RaidBoss = true,
        Position = CFrame.new(-2103, 70, -12165)
      },
      ["Dough King"] = {
        RaidBoss = true,
        Position = CFrame.new(-2103, 70, -12165)
      },
      ["rip_indra True Form"] = {
        RaidBoss = true,
        Position = CFrame.new(-5333, 424, -2673)
      },
      ["Stone"] = {
        IsBoss = true,
        Level = 1550,
        Position = CFrame.new(-1049, 40, 6791),
        Quest = {"PiratePortQuest", CFrame.new(-449, 109, 5950)}
      },
      ["Hydra Leader"] = {
        IsBoss = true,
        Level = 1675,
        Position = CFrame.new(5730, 602, 199),
        Quest = {"VenomCrewQuest", CFrame.new(5448, 602, 748)}
      },
      ["Kilo Admiral"] = {
        IsBoss = true,
        Level = 1750,
        Position = CFrame.new(2904, 509, -7349),
        Quest = {"MarineTreeIsland", CFrame.new(2485, 74, -6788)}
      },
      ["Captain Elephant"] = {
        IsBoss = true,
        Level = 1875,
        Position = CFrame.new(-13393, 319, -8423),
        Quest = {"DeepForestIsland", CFrame.new(-13233, 332, -7626)}
      },
      ["Beautiful Pirate"] = {
        IsBoss = true,
        Level = 1950,
        Position = CFrame.new(5370, 22, -89),
        Quest = {"DeepForestIsland2", CFrame.new(-12682, 391, -9901)}
      },
      ["Cake Queen"] = {
        IsBoss = true,
        Level = 2175,
        Position = CFrame.new(-710, 382, -11150),
        Quest = {"IceCreamIslandQuest", CFrame.new(-818, 66, -10964)}
      },
      ["Longma"] = {
        NoQuest = true,
        Position = CFrame.new(-10218, 333, -9444)
      }
    }
    
    Module.Shop = {
      {"Frags", {{"Race Reroll", {"BlackbeardReward", "Reroll", "2"}}, {"Reset Stats", {"BlackbeardReward", "Refund", "2"}}}},
      {"Fighting Style", {
        {"Buy Black Leg", {"BuyBlackLeg"}},
        {"Buy Electro", {"BuyElectro"}},
        {"Buy Fishman Karate", {"BuyFishmanKarate"}},
        {"Buy Dragon Claw", {"BlackbeardReward", "DragonClaw", "2"}},
        {"Buy Superhuman", {"BuySuperhuman"}},
        {"Buy Death Step", {"BuyDeathStep"}},
        {"Buy Sharkman Karate", {"BuySharkmanKarate"}},
        {"Buy Electric Claw", {"BuyElectricClaw"}},
        {"Buy Dragon Talon", {"BuyDragonTalon"}},
        {"Buy GodHuman", {"BuyGodhuman"}},
        {"Buy Sanguine Art", {"BuySanguineArt"}}
        -- {"Buy Divine Art", {"BuyDivineArt"}}
      }},
      {"Ability Teacher", {
        {"Buy Geppo", {"BuyHaki", "Geppo"}},
        {"Buy Buso", {"BuyHaki", "Buso"}},
        {"Buy Soru", {"BuyHaki", "Soru"}},
        {"Buy Ken", {"KenTalk", "Buy"}}
      }},
      {"Sword", {
        {"Buy Katana", {"BuyItem", "Katana"}},
        {"Buy Cutlass", {"BuyItem", "Cutlass"}},
        {"Buy Dual Katana", {"BuyItem", "Dual Katana"}},
        {"Buy Iron Mace", {"BuyItem", "Iron Mace"}},
        {"Buy Triple Katana", {"BuyItem", "Triple Katana"}},
        {"Buy Pipe", {"BuyItem", "Pipe"}},
        {"Buy Dual-Headed Blade", {"BuyItem", "Dual-Headed Blade"}},
        {"Buy Soul Cane", {"BuyItem", "Soul Cane"}},
        {"Buy Bisento", {"BuyItem", "Bisento"}}
      }},
      {"Gun", {
        {"Buy Musket", {"BuyItem", "Musket"}},
        {"Buy Slingshot", {"BuyItem", "Slingshot"}},
        {"Buy Flintlock", {"BuyItem", "Flintlock"}},
        {"Buy Refined Slingshot", {"BuyItem", "Refined Slingshot"}},
        {"Buy Dual Flintlock", {"BuyItem", "Dual Flintlock"}},
        {"Buy Cannon", {"BuyItem", "Cannon"}},
        {"Buy Kabucha", {"BlackbeardReward", "Slingshot", "2"}}
      }},
      {"Accessories", {
        {"Buy Black Cape", {"BuyItem", "Black Cape"}},
        {"Buy Swordsman Hat", {"BuyItem", "Swordsman Hat"}},
        {"Buy Tomoe Ring", {"BuyItem", "Tomoe Ring"}}
      }},
      {"Race", {{"Ghoul Race", {"Ectoplasm", "Change", 4}}, {"Cyborg Race", {"CyborgTrainer", "Buy"}}}}
    }
  end
  
  do
    Module.IsSuperBring = false
    
    Module.RemoveCanTouch = 0
    Module.AttackCooldown = 0
    Module.PirateRaid = 0
    
    Module.Webhooks = true
    Module.JobIds = true
    
    Module.Progress = {}
    Module.BossesName = {}
    Module.EnemyLocations = {}
    Module.SpawnLocations = {}
    
    Module.Cached = Cached
  end
  
  Module.Signals = {} do
    local Signals = Module.Signals
    
    Signals.OptionChanged = Signal.new()
    Signals.EnemyAdded = Signal.new()
    Signals.EnemyDied = Signal.new()
    Signals.Notify = Signal.new()
    Signals.Error = Signal.new()

    Signals.Error:Connect(function(ErrorMessage)
      _ENV.loadedFarm = false
      _ENV.OnFarm = false
      
      local Message = Instance.new("Message", workspace)
      _ENV.redz_hub_error = Message
      Message.Text = (`redz-Hub error [ {Settings.RunningOption or "Null"} ] {ErrorMessage}`)
    end)
  end
  
  Module.RunFunctions = {} do
    Module.RunFunctions.Translator = function(Window, Translation)
      local MakeTab = Window.MakeTab
      
      Window.MakeTab = function(self, Configs)
        if Translation[ Configs[1] ] then
          Configs[1] = Translation[ Configs[1] ]
        end
        
        local Tab = MakeTab(self, Configs)
        local NewTab = {}
        
        function NewTab:AddSection(Name)
          return Tab:AddSection(Translation[Name] or Name)
        end
        
        function NewTab:AddButton(Configs)
          local Translator = Translation[ Configs[1] ]
          
          if Translator then
            Configs[1] = type(Translator) == "string" and Translator or Translator[1]
            Configs.Desc = type(Translator) ~= "string" and Translator[2]
          end
          
          return Tab:AddButton(Configs)
        end
        
        function NewTab:AddToggle(Configs)
          local Translator = Translation[ Configs[1] ]
          
          if Translator then
            Configs[1] = type(Translator) == "string" and Translator or Translator[1]
            Configs.Desc = type(Translator) ~= "string" and Translator[2]
          end
          
          return Tab:AddToggle(Configs)
        end
        
        function NewTab:AddSlider(Configs)
          local Translator = Translation[ Configs[1] ]
          
          if Translator then
            Configs[1] = type(Translator) == "string" and Translator or Translator[1]
            Configs.Desc = type(Translator) ~= "string" and Translator[2]
          end
          
          return Tab:AddSlider(Configs)
        end
        
        function NewTab:AddDropdown(Configs)
          local Translator = Translation[ Configs[1] ]
          
          if Translator then
            Configs[1] = type(Translator) == "string" and Translator or Translator[1]
            Configs.Desc = type(Translator) ~= "string" and Translator[2]
          end
          
          return Tab:AddDropdown(Configs)
        end
        
        function NewTab:AddTextBox(Configs)
          local Translator = Translation[ Configs[1] ]
          
          if Translator then
            Configs[1] = type(Translator) == "string" and Translator or Translator[1]
            Configs.Desc = type(Translator) ~= "string" and Translator[2]
          end
          
          return Tab:AddTextBox(Configs)
        end
        
        for i,v in pairs(Tab) do
          if not NewTab[i] then
            NewTab[i] = v
          end
        end
        
        return NewTab
      end
    end
    
    Module.RunFunctions.Quests = function(self, QuestsModule, getTasks)
      local MaxLvl = ({ {0, 700}, {700, 1500}, {1500, math.huge} })[self.Sea]
      local bl_Quests = {"BartiloQuest", "MarineQuest", "CitizenQuest"}
      
      for name, task in QuestsModule do
        if table.find(bl_Quests, name) then continue end
        
        for num, mission in task do
          local Level = mission.LevelReq
          if Level >= MaxLvl[1] and Level < MaxLvl[2] then
            local target, positions = getTasks(mission)
            table.insert(self.QuestList, {
              Name = name,
              Count = num,
              Enemy = { Name = target, Level = Level, Position = positions }
            })
          end
        end
      end
      
      table.sort(self.QuestList, function(v1, v2) return v1.Enemy.Level < v2.Enemy.Level end)
    end
    
    Module.RunFunctions.LibraryToggle = function(EnabledOptions, Options)
      return function(...)
        local Tab, Settings, Flag = ...
        
        Options[Flag] = Tab:AddToggle({
          Settings[1],                                         -- Name
          type(Settings[2]) ~= "string" and Settings[2],       -- Default
          function(Value) EnabledOptions[Flag] = Value end,    -- Callback
          Flag,                                                -- Flag
          Desc = (type(Settings[2]) == "string" and Settings[2]) or Settings[3]
        })
      end
    end
    
    Module.RunFunctions.FarmQueue = function(Options)
      local Success, ErrorMessage = pcall(function()
        while task.wait(Settings.SmoothMode and 0.25 or 0) do
          local Enabled = false
          
          for _, Option in Options do
            Settings.RunningOption = Option.Name
            local Method = Option.Function()
            
            if Method then
              Settings.RunningMethod = type(Method) == "string" and Method
              Enabled = true; break
            else
              Settings.RunningOption, Settings.RunningMethod = nil, nil
            end
          end
          
          _ENV.OnFarm = (_ENV.teleporting or Enabled)
        end
      end)
      
      Module.Signals.Error:Fire(ErrorMessage)
    end
  end
  
  function Module.FireRemote(...)
    return CommF:InvokeServer(...)
  end
  
  function Module.IsAlive(Character)
    if Character then
      local Humanoid = Cached.Humanoids[Character] or GetCharacterHumanoid(Character)
      
      if Humanoid == true then
        return true
      end
      
      if Humanoid then
        if not Cached.Humanoids[Character] then
          Cached.Humanoids[Character] = Humanoid
        end
        
        return Humanoid[if Humanoid.ClassName == "Humanoid" then "Health" else "Value"] > 0
      end
    end
  end
  
  function Module.KillAura(Distance: number?, Name: string?): (nil)
    Distance = Distance or 500
    
    local EnemyList = Enemies:GetChildren()
    
    for i = 1, #EnemyList do
      local Enemy = EnemyList[i]
      local PrimaryPart = Enemy.PrimaryPart
      
      if (not Name or Enemy.Name == Name) and PrimaryPart and not Enemy:HasTag(KILLAURA_TAG) then
        if Module.IsAlive(Enemy) and Player:DistanceFromCharacter(PrimaryPart.Position) < Distance then
          Enemy:AddTag(KILLAURA_TAG)
        end
      end
    end
  end
  
  function Module.IsBoss(Name: string): boolean
    return Module.Bosses[Name] and true or false
  end
  
  function Module.UseSkills(Target: any?, Skills: table?): (nil)
    if Player:DistanceFromCharacter(Target.Position) >= 60 then
      return nil
    end
    
    for Skill, Enabled in Skills do
      local Debounce = Module.Debounce.Skills[Skill]
      
      if Enabled and (not Debounce or (tick() - Debounce) >= 0.5) then
        VirtualInputManager:SendKeyEvent(true, Skill, false, game)
        VirtualInputManager:SendKeyEvent(false, Skill, false, game)
        Module.Debounce.Skills[Skill] = tick()
      end
    end
  end
  
  function Module.Rejoin(): (nil)
    task.spawn(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, Player)
  end
  
  function Module.EnemySpawned(EnemyName)
    if (tick() - Module.Debounce.GetEnemy) <= 0.25 then
      return nil
    end
    
    local Enemies = Module.Enemies
    local Enemy = if type(EnemyName) == "table" then Enemies:GetClosest(EnemyName) else Enemies:GetEnemyByTag(EnemyName)
    
    if Enemy then
      return Enemy
    elseif Settings.SmoothMode then
      Module.Debounce.GetEnemy = tick()
    end
  end
  
  
  function Module:IsBlacklistedExecutor(): boolean
    return IS_BLACKLISTED_EXECUTOR
  end
  
  function Module:TravelTo(Sea: number?): (nil)
    Module.FireRemote(`Travel{self.GameData.SeasName[self.GameData.Sea]}`)
  end
  
  function Module:ServerHop(MaxPlayers: number?, Region: string?): (nil)
    MaxPlayers = MaxPlayers or self.SH_MaxPlrs or 8
    -- Region = Region or self.SH_Region or "Singapore"
    
    local ServerBrowser = ReplicatedStorage.__ServerBrowser
    
    for i = 1, 100 do
      local Servers = ServerBrowser:InvokeServer(i)
      for id,info in pairs(Servers) do
        if id ~= game.JobId and info["Count"] <= MaxPlayers then
          task.spawn(ServerBrowser.InvokeServer, ServerBrowser, "teleport", id)
        end
      end
    end
  end
  
  function Module.EquipTool(ToolName: string, ByType: boolean?): (nil)
    if not Module.IsAlive(Player.Character) then
      return nil
    end
    
    local Equipped = Cached.Equipped
    
    if Equipped and Equipped.Parent and Equipped[if ByType then "ToolTip" else "Name"] == ToolName then
      if Equipped.Parent == Player.Backpack then
        Player.Character.Humanoid:EquipTool(Equipped)
      elseif Equipped.Parent == Player.Character then
        return nil
      end
    end
    
    if ToolName and not ByType then
      local BackpackTool = Player.Backpack:FindFirstChild(Name)
      
      if BackpackTool then
        Cached.Equipped = BackpackTool
        Player.Character.Humanoid:EquipTool(BackpackTool)
      end
    else
      local ToolTip = if ByType then ToolName else Settings.FarmTool
      
      for _, Tool in Player.Backpack:GetChildren() do
        if Tool:IsA("Tool") and Tool.ToolTip == ToolTip then
          Cached.Equipped = Tool
          Player.Character.Humanoid:EquipTool(Tool)
          return nil
        end
      end
    end
  end
  
  function Module:BringEnemies(ToEnemy: Instance, SuperBring: boolean?): (nil)
    if not self.IsAlive(ToEnemy) or not ToEnemy.PrimaryPart then
      return nil
    end
    
    pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
    
    if Settings.BringMobs then
      Module.IsSuperBring = if SuperBring then true else false
      
      local Name = ToEnemy.Name
      local Position = (Player.Character or Player.CharacterAdded:Wait()):GetPivot().Position
      local Target = ToEnemy.PrimaryPart.CFrame
      local BringPositionTag = if SuperBring then "ALL_MOBS" else Name
      
      if not Cached.Bring[BringPositionTag] or (Target.Position - Cached.Bring[BringPositionTag].Position).Magnitude > 25 then
        Cached.Bring[BringPositionTag] = Target
      end
      
      local EnemyList = if SuperBring then Enemies:GetChildren() else self.Enemies:GetTagged(Name)
      
      for i = 1, #EnemyList do
        local Enemy = EnemyList[i]
        if Enemy.Parent ~= Enemies or Enemy:HasTag(BRING_TAG) then continue end
        if not Enemy:FindFirstChild("CharacterReady") then continue end
        
        local PrimaryPart = Enemy.PrimaryPart
        if self.IsAlive(Enemy) and PrimaryPart then
          if (Position - PrimaryPart.Position).Magnitude < Settings.BringDistance then
            Enemy:AddTag(BRING_TAG)
          end
        end
      end
    else
      if not Cached.Bring[ToEnemy] then
        Cached.Bring[ToEnemy] = ToEnemy.PrimaryPart.CFrame
      end
      
      ToEnemy.PrimaryPart.CFrame = Cached.Bring[ToEnemy]
    end
  end
  
  function Module:GetRaidIsland(): Instance?
    if Cached.RaidIsland then
      return Cached.RaidIsland
    end
    
    for i = 5, 1, -1 do
      local Name = "Island " .. i
      for _, Island in ipairs(Locations:GetChildren()) do
        if Island.Name == Name and Player:DistanceFromCharacter(Island.Position) < 3500 then
          Cached.RaidIsland = Island
          return Island
        end
      end
    end
  end
  
  function Module:GetProgress(Tag, ...)
    local Progress = Cached.Progress
    local entry = Progress[Tag]
    
    if entry and (tick() - entry.debounce) < 2 then
      return entry.result
    end
    
    local result = self.FireRemote(...)
    
    if entry then
      entry.result = result
      entry.debounce = tick()
    else
      Progress[Tag] = {
        debounce = tick(),
        result = result
      }
    end
    
    return result
  end
  
  function Module:RemoveBoatCollision(Boat)
    local Objects = Boat:GetDescendants()
    
    for i = 1, #Objects do
      local BasePart = Objects[i]
      if BasePart:IsA("BasePart") and BasePart.CanCollide then
        BasePart.CanCollide = false
      end
    end
  end
  
  Module.Chests = setmetatable({}, {
    __call = function(self, ...)
      if self.Cached and not self.Cached:GetAttribute("IsDisabled")  then
        return self.Cached
      end
      
      if self.Debounce and (tick() - self.Debounce) < 0.5 then
        return nil
      end
      
      local Position = (Player.Character or Player.CharacterAdded:Wait()):GetPivot().Position
      local Chests = CollectionService:GetTagged("_ChestTagged")
      
      if #Chests == 0 then
        return nil
      end
      
      local Distance, Nearest = math.huge
      
      for i = 1, #Chests do
        local Chest = Chests[i]
        local Magnitude = (Chest:GetPivot().Position - Position).Magnitude
        
        if not Chest:GetAttribute("IsDisabled") and Magnitude < Distance then
          Distance, Nearest = Magnitude, Chest
        end
      end
      
      self.Debounce = tick()
      self.Cached = Nearest
      return Nearest
    end
  })
  
  Module.Berry = setmetatable({}, {
    __call = function(self, BerryArray)
      local CachedBush = self.Cached
      
      if CachedBush then
        for Tag, CFrame in pairs(CachedBush:GetAttributes()) do
          return CachedBush
        end
      end
      
      if self.Debounce and (tick() - self.Debounce) < 0.5 then
        return nil
      end
      
      local Position = (Player.Character or Player.CharacterAdded:Wait()):GetPivot().Position
      local BerryBush = CollectionService:GetTagged("BerryBush")
      
      local Distance, Nearest = math.huge
      
      for i = 1, #BerryBush do
        local Bush = BerryBush[i]
        
        for AttributeName, BerryName in pairs(Bush:GetAttributes()) do
          if not BerryArray or table.find(BerryArray, BerryName) then
            local Magnitude = (Bush.Parent:GetPivot().Position - Position).Magnitude
            
            if Magnitude < Distance then
              Nearest, Distance = Bush, Magnitude
            end
          end
        end
      end
      
      self.Debounce = tick()
      self.Cached = Nearest
      return Nearest
    end
  })
  
  Module.FruitsName = setmetatable({}, {
    __index = function(self, Fruit)
      local RealFruitsName = Module.FruitsId
      local Name = Fruit.Name
      
      if Name ~= "Fruit " then
        rawset(self, Fruit, Name)
        return Name
      end
      
      local Model = Fruit:WaitForChild("Fruit", 9e9)
      local Handle = FastWait(1, Model, "Fruit") or FastWait(1, Model, "Idle")
      
      if Handle and (Handle:IsA("Animation") or Handle:IsA("MeshPart")) then
        local IdProperty = if Handle:IsA("Animation") then "AnimationId" else "MeshId"
        local RealName = RealFruitsName[ Handle[IdProperty] ]
        
        if RealName and type(RealName) == "string" then
          rawset(self, Fruit, `Fruit [ {RealName} ]`)
          return rawget(self, Fruit)
        end
      end
      
      rawset(self, Fruit, "Fruit [ ??? ]")
      return "Fruit [ ??? ]"
    end
  })
  
  Module.Enemies = (function()
    local EnemiesModule = {
      __CakePrince = {},
      __PirateRaid = {},
      __RaidBoss = {},
      __Bones = {},
      __Elite = {},
      __Others = {}
    }
    
    local Signals = Module.Signals
    local IsAlive = Module.IsAlive
    local SeaCastle = CFrame.new(-5556, 314, -2988)
    
    local Elites = ToDictionary({ "Deandre", "Diablo", "Urban" })
    local Bones = ToDictionary({ "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" })
    local CakePrince = ToDictionary({ "Head Baker", "Baking Staff", "Cake Guard", "Cookie Crafter" })
    
    local function newEnemy(List, Enemy)
      local Humanoid = Enemy:WaitForChild("Humanoid")
      
      if Humanoid and Humanoid.Health > 0 then
        table.insert(List, Enemy)
        Humanoid.Died:Wait()
        table.remove(List, table.find(List, Enemy))
      end
    end
    
    local function PirateRaidEnemy(Enemy)
      local Humanoid = Enemy:WaitForChild("Humanoid")
      
      if not Humanoid or Humanoid.Health <= 0 then
        return nil
      end
      
      local HumanoidRootPart = Enemy:WaitForChild("HumanoidRootPart")
      
      if HumanoidRootPart and (Enemy.Name ~= "rip_indra True Form" and Enemy.Name ~= "Blank Buddy") then
        if (HumanoidRootPart.Position - SeaCastle.Position).Magnitude <= 750 then
          task.spawn(newEnemy, EnemiesModule.__PirateRaid, Enemy)
          Module.PirateRaid = tick()
        end
      end
    end
    
    local function EnemyAdded(Enemy)
      local Name = Enemy.Name
      local Others = EnemiesModule.__Others
      
      if EnemiesModule[`__{Name}`] then
        task.spawn(newEnemy, EnemiesModule[`__{Name}`], Enemy)
      elseif Enemy:GetAttribute("RaidBoss") then
        task.spawn(newEnemy, EnemiesModule.__RaidBoss, Enemy)
      elseif Elites[Name] then
        task.spawn(newEnemy, EnemiesModule.__Elite, Enemy)
      elseif Bones[Name] then
        task.spawn(newEnemy, EnemiesModule.__Bones, Enemy)
      elseif CakePrince[Name] then
        task.spawn(newEnemy, EnemiesModule.__CakePrince, Enemy)
      end
      
      if Module.GameData.Sea == 3 then
        task.spawn(PirateRaidEnemy, Enemy)
      end
      
      Others[Name] = Others[Name] or {}
      task.spawn(newEnemy, Others[Name], Enemy)
    end
    
    function EnemiesModule.IsSpawned(EnemyName: string): boolean
      local Cached = Module.SpawnLocations[EnemyName]
      
      if Cached and Cached.Parent then
        return (Cached:GetAttribute("Active") or EnemiesModule:GetEnemyByTag(EnemyName)) and true or false
      end
      
      return EnemiesModule:GetEnemyByTag(EnemyName) and true or false
    end
    
    function EnemiesModule:GetTagged(TagName: string): table?
      return self[`__{TagName}`] or self.__Others[TagName]
    end
    
    function EnemiesModule:GetEnemyByTag(TagName: string): Model?
      local CachedEnemy = Cached.Enemies[TagName]
      
      if CachedEnemy and IsAlive(CachedEnemy) then
        return CachedEnemy
      end
      
      local Enemies = self:GetTagged(TagName)
      
      if Enemies and #Enemies > 0 then
        for i = 1, #Enemies do
          if IsAlive(Enemies[i]) then
            return Enemies[i]
          end
        end
      end
    end
    
    function EnemiesModule:GetClosest(Enemies: table)
      local SpecialTag = table.concat(Enemies, ".")
      local CachedEnemy = Cached.Enemies[SpecialTag]
      
      if CachedEnemy and IsAlive(CachedEnemy) then
        return CachedEnemy
      end
      
      local Distance, Nearest = math.huge
      
      for i = 1, #Enemies do
        local Enemy = self:GetClosestByTag(Enemies[i])
        local Magnitude = Enemy and Player:DistanceFromCharacter(Enemy.PrimaryPart.Position)
        
        if Enemy and Magnitude <= Distance then
          Distance, Nearest = Magnitude, Enemy
        end
      end
      
      if Nearest then
        Cached.Enemies[SpecialTag] = Nearest
        return Nearest
      end
    end
    
    function EnemiesModule:GetClosestByTag(TagName: string): Model?
      local CachedEnemy = Cached.Enemies[TagName]
      
      if CachedEnemy and IsAlive(CachedEnemy) then
        return CachedEnemy
      end
      
      local Enemies = self:GetTagged(TagName)
      
      if Enemies and #Enemies > 0 then
        local Distance, Nearest = math.huge
        
        local Position = (Player.Character or Player.CharacterAdded()):GetPivot().Position
        
        for i = 1, #Enemies do
          local Enemy = Enemies[i]
          local PrimaryPart = Enemy.PrimaryPart
          
          if PrimaryPart and IsAlive(Enemy) then
            local Magnitude = (Position - PrimaryPart.Position).Magnitude
            
            if Magnitude <= 15 then
              Cached.Enemies[TagName] = Enemy
              return Enemy
            elseif Magnitude <= Distance then
              Distance, Nearest = Magnitude, Enemy
            end
          end
        end
        
        if Nearest then
          Cached.Enemies[TagName] = Nearest
          return Nearest
        end
      end
    end
    
    function EnemiesModule:CreateNewTag(Tag: string, Enemies: table): table?
      local NewTag = {}
      self[`__{Tag}`] = NewTag
      
      for i = 1, #Enemies do
        self[`__{Enemies[i]}`] = NewTag
        local Others = self.__Others[ Enemies[i] ]
        
        if Others then
          for i = 1, #Others do
            task.spawm(newEnemy, NewTag, Others[i])
          end
        end
      end
      
      return NewTag
    end
    
    local function Bring(Enemy)
      local PlayerRootPart = (Player.Character or Player.CharacterAdded()):WaitForChild("HumanoidRootPart")
      local RootPart = Enemy:WaitForChild("HumanoidRootPart")
      local Humanoid = Enemy:WaitForChild("Humanoid")
      local EnemyName = Enemy.Name
      
      local BodyVelocity = Instance.new("BodyVelocity", RootPart)
      BodyVelocity.Velocity = Vector3.zero
      BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
      
      local BodyPosition = Instance.new("BodyPosition", RootPart)
      BodyPosition.Position = RootPart.Position
      BodyPosition.P, BodyPosition.D = 1e4, 1e3
      BodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
      
      while PlayerRootPart and RootPart and Humanoid and Humanoid.Health > 0 and Enemy do
        local Target = Cached.Bring[if Module.IsSuperBring then "ALL_MOBS" else EnemyName]
        
        if Target and (PlayerRootPart.Position - RootPart.Position).Magnitude <= Settings.BringDistance then
          if (RootPart.Position - Target.Position).Magnitude <= 5 then
            RootPart.CFrame = Target
          else
            BodyPosition.Position = Target.Position
          end
        end;task.wait()
      end
      
      if BodyVelocity then BodyVelocity:Destroy() end
      if BodyPosition then BodyPosition:Destroy() end
      if Enemy and Enemy:HasTag(BRING_TAG) then Enemy:RemoveTag(BRING_TAG) end
    end
    
    local function KillAura(Enemy)
      local Humanoid = Enemy:FindFirstChild("Humanoid")
      local RootPart = Enemy:FindFirstChild("HumanoidRootPart")
      
      pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
      
      if Humanoid and RootPart then
        RootPart.CanCollide = false
        RootPart.Size = Vector3.new(60, 60, 60)
        Humanoid:ChangeState(15)
        Humanoid.Health = 0
        task.wait()
        Enemy:RemoveTag(KILLAURA_TAG)
      end
    end
    
    for _, Enemy in CollectionService:GetTagged("BasicMob") do EnemyAdded(Enemy) end
    table.insert(Connections, CollectionService:GetInstanceAddedSignal("BasicMob"):Connect(EnemyAdded))
    -- table.insert(Connections, Enemies.ChildAdded:Connect(EnemyAdded))
    
    table.insert(Connections, CollectionService:GetInstanceAddedSignal(KILLAURA_TAG):Connect(KillAura))
    table.insert(Connections, CollectionService:GetInstanceAddedSignal(BRING_TAG):Connect(Bring))
    
    return EnemiesModule
  end)()
  
  Module.Inventory = (function()
    local Inventory = {
      Unlocked = setmetatable({}, { __index = function() return false end }),
      Mastery = setmetatable({}, { __index = function() return 0 end }),
      Count = setmetatable({}, { __index = function() return 0 end }),
      Items = {},
    }
    
    function Inventory:UpdateItem(item)
      if type(item) == "table" then
        if item.Type == "Wear" then
          item.Type = "Accessory"
        end
        
        local Name = item.Name
        
        self.Items[Name] = item
        
        if not self.Unlocked[Name] then self.Unlocked[Name] = true end
        if item.Count then self.Count[Name] = item.Count end
        if item.Mastery then self.Mastery[Name] = item.Mastery end
      end
    end
    
    function Inventory:RemoveItem(ItemName)
      if type(ItemName) == "string" then
        self.Unlocked[ItemName] = nil
        self.Mastery[ItemName] = nil
        self.Count[ItemName] = nil
        self.Items[ItemName] = nil
      end
    end
    
    local function OnClientEvent(Method, ...)
      if Method == "ItemChanged" then
        Inventory:UpdateItem(...)
      elseif Method == "ItemAdded" then
        Inventory:UpdateItem(...)
      elseif Method == "ItemRemoved" then
        Inventory:RemoveItem(...)
      elseif Method == "Notify" then
        Module.Signals.Notify:Fire(...)
      end
    end
    
    task.spawn(function()
      table.insert(Connections, CommE.OnClientEvent:Connect(OnClientEvent))
      for _, item in ipairs(Module.FireRemote("getInventory")) do Inventory:UpdateItem(item) end
    end)
    
    return Inventory
  end)()
  
  Module.FastAttack = (function()
    local FastAttack = {
      Distance = 50,
      attackMobs = true,
      attackPlayers = true,
      Equipped = nil,
      Debounce = 0,
      ComboDebounce = 0,
      ShootDebounce = 0,
      M1Combo = 0,
      
      ShootsPerTarget = {
        ["Dual Flintlock"] = 2
      },
      SpecialShoots = {
        ["Skull Guitar"] = "TAP",
        ["Bazooka"] = "Position",
        ["Cannon"] = "Position"
      },
      HitboxLimbs = {"RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm", "RightHand", "LeftHand"}
    }
    
    local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
    local RE_ShootGunEvent = Net:WaitForChild("RE/ShootGunEvent")
    local RE_RegisterHit = Net:WaitForChild("RE/RegisterHit")
    
    local SUCCESS_FLAGS, COMBAT_REMOTE_THREAD = pcall(function()
      return require(Modules.Flags).COMBAT_REMOTE_THREAD or false
    end)
    
    local SUCCESS_SHOOT, SHOOT_FUNCTION = pcall(function()
      return getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9)
    end)
    
    local SUCCESS_HIT, HIT_FUNCTION = pcall(function()
      return (getmenv or getsenv)(Net)._G.SendHitsToServer
    end)
    
    local IsAlive = Module.IsAlive
    
    function FastAttack:ShootInTarget(TargetPosition: Vector3): (nil)
      if not SUCCESS_SHOOT or not SHOOT_FUNCTION then return end
      
      local Equipped = IsAlive(Player.Character) and Player.Character:FindFirstChildOfClass("Tool")
      
      if Equipped and Equipped.ToolTip == "Gun" then
        if Equipped:FindFirstChild("Cooldown") and (tick() - self.ShootDebounce) >= Equipped.Cooldown.Value then
          local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
          
          if ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
            Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
            GunValidator:FireServer(self:GetValidator2())
            
            if ShootType == "TAP" then
              Equipped.RemoteEvent:FireServer("TAP", TargetPosition)
            else
              RE_ShootGunEvent:FireServer(TargetPosition)
            end
            
            self.ShootDebounce = tick()
          end
        end
      end
    end
    
    function FastAttack:CheckStun(ToolTip: string, Character: Character, Humanoid: Humanoid): boolean
      local Stun = Character:FindFirstChild("Stun")
      local Busy = Character:FindFirstChild("Busy")
      
      if Humanoid.Sit and (ToolTip == "Sword" or ToolTip == "Melee" or ToolTip == "Gun") then
        return false
      elseif Stun and Stun.Value > 0 then -- {{ or Busy and Busy.Value }}
        return false
      end
      
      return true
    end
    
    function FastAttack:Process(assert: boolean, Enemies: Folder, BladeHits: table, Position: Vector3, Distance: number): (nil)
      if not assert then return end
      
      local HitboxLimbs = self.HitboxLimbs
      local Mobs = Enemies:GetChildren()
      
      for i = 1, #Mobs do
        local Enemy = Mobs[i]
        local BasePart = Enemy:FindFirstChild(HitboxLimbs[math.random(#HitboxLimbs)])
        
        if not BasePart then continue end
        if not Enemy:FindFirstChild("CharacterReady") then continue end
        
        local CanAttack = Enemy.Parent == Characters and CheckPlayerAlly(Players:GetPlayerFromCharacter(Enemy))
        
        if Enemy ~= Player.Character and (Enemy.Parent ~= Characters or CanAttack) then
          if IsAlive(Enemy) and (Position - BasePart.Position).Magnitude <= Distance then
            if not self.EnemyRootPart then
              self.EnemyRootPart = BasePart
            else
              table.insert(BladeHits, { Enemy, BasePart })
            end
          end
        end
      end
    end
    
    function FastAttack:GetAllBladeHits(Character: Character, Distance: number?): (nil)
      local Position = Character:GetPivot().Position
      local BladeHits = {}
      Distance = Distance or self.Distance
      
      self:Process(self.attackMobs, Enemies, BladeHits, Position, Distance)
      self:Process(self.attackPlayers, Characters, BladeHits, Position, Distance)
      
      return BladeHits
    end
    
    function FastAttack:GetClosestEnemyPosition(Character: Character, Distance: number?): (nil)
      local BladeHits = self:GetAllBladeHits(Character, Distance)
      
      local Distance, Closest = math.huge
      
      for i = 1, #BladeHits do
        local Magnitude = if Closest then (Closest.Position - BladeHits[i][2].Position).Magnitude else Distance
        
        if Magnitude <= Distance then
          Distance, Closest = Magnitude, BladeHits[i][2]
        end
      end
      
      return if Closest then Closest.Position else nil
    end
    
    function FastAttack:GetGunHits(Character: Character, Distance: number?)
      local BladeHits = self:GetAllBladeHits(Character, Distance)
      local GunHits = {}
      
      for i = 1, #BladeHits do
        if not GunHits[1] or (BladeHits[i][2].Position - GunHits[1].Position).Magnitude <= 10 then
          table.insert(GunHits, BladeHits[i][2])
        end
      end
      
      return GunHits
    end
    
    function FastAttack:GetCombo(): number
      local Combo = if tick() - self.ComboDebounce <= 0.4 then self.M1Combo else 0
      Combo = if Combo >= 4 then 1 else Combo + 1
      
      self.ComboDebounce = tick()
      self.M1Combo = Combo
      
      return Combo
    end
    
    function FastAttack:UseFruitM1(Character: Character, Equipped: Tool, Combo: number): (nil)
      local Position = Character:GetPivot().Position
      local EnemyList = Enemies:GetChildren()
      
      for i = 1, #EnemyList do
        local Enemy = EnemyList[i]
        local PrimaryPart = Enemy.PrimaryPart
        if IsAlive(Enemy) and PrimaryPart and (PrimaryPart.Position - Position).Magnitude <= 50 then
          local Direction = (PrimaryPart.Position - Position).Unit
          return Equipped.LeftClickRemote:FireServer(Direction, Combo)
        end
      end
    end
    
    function FastAttack:UseNormalClick(Humanoid: Humanoid, Character: Character, Cooldown: number): (nil)
      self.EnemyRootPart = nil
      local BladeHits = self:GetAllBladeHits(Character)
      
      if self.EnemyRootPart then
        RE_RegisterAttack:FireServer(Cooldown)
        
        if SUCCESS_FLAGS and COMBAT_REMOTE_THREAD and SUCCESS_HIT and HIT_FUNCTION then
          HIT_FUNCTION(self.EnemyRootPart, BladeHits)
        else
          RE_RegisterHit:FireServer(self.EnemyRootPart, BladeHits)
        end
      end
    end
    
    function FastAttack:GetValidator2()
      local v1 = getupvalue(SHOOT_FUNCTION, 15) -- v40, 15
      local v2 = getupvalue(SHOOT_FUNCTION, 13) -- v41, 13
      local v3 = getupvalue(SHOOT_FUNCTION, 16) -- v42, 16
      local v4 = getupvalue(SHOOT_FUNCTION, 17) -- v43, 17
      local v5 = getupvalue(SHOOT_FUNCTION, 14) -- v44, 14
      local v6 = getupvalue(SHOOT_FUNCTION, 12) -- v45, 12
      local v7 = getupvalue(SHOOT_FUNCTION, 18) -- v46, 18
      
      local v8 = v6 * v2                  -- v133
      local v9 = (v5 * v2 + v6 * v1) % v3 -- v134
      
      v9 = (v9 * v3 + v8) % v4
      v5 = math.floor(v9 / v3)
      v6 = v9 - v5 * v3
      v7 = v7 + 1
      
      setupvalue(SHOOT_FUNCTION, 15, v1) -- v40, 15
      setupvalue(SHOOT_FUNCTION, 13, v2) -- v41, 13
      setupvalue(SHOOT_FUNCTION, 16, v3) -- v42, 16
      setupvalue(SHOOT_FUNCTION, 17, v4) -- v43, 17
      setupvalue(SHOOT_FUNCTION, 14, v5) -- v44, 14
      setupvalue(SHOOT_FUNCTION, 12, v6) -- v45, 12
      setupvalue(SHOOT_FUNCTION, 18, v7) -- v46, 18
      
      return math.floor(v9 / v4 * 16777215), v7
    end
    
    function FastAttack:UseGunShoot(Character, Equipped)
      local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
      
      if ShootType == "Normal" then
        local Hits = self:GetGunHits(Character, 120)
        
        if #Hits > 0 then
          local Target = Hits[1].Position
          
          Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
          GunValidator:FireServer(self:GetValidator2())
          
          for i = 1, (self.ShootsPerTarget[Equipped.Name] or 1) do
            RE_ShootGunEvent:FireServer(Target, Hits)
          end
        end
      elseif ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
        local Target = self:GetClosestEnemyPosition(Character, 200)
        
        if Target then
          Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
          GunValidator:FireServer(self:GetValidator2())
          
          if ShootType == "TAP" then
            Equipped.RemoteEvent:FireServer("TAP", Target)
          else
            RE_ShootGunEvent:FireServer(Target)
          end
        end
      end
    end
    
    function FastAttack.attack()
      if not Settings.AutoClick or (tick() - Module.AttackCooldown) <= 1 then return end
      if not IsAlive(Player.Character) then return end
      
      local self = FastAttack
      local Character = Player.Character
      local Humanoid = Character.Humanoid
      
      local Equipped = Character:FindFirstChildOfClass("Tool")
      local ToolTip = Equipped and Equipped.ToolTip
      local ToolName = Equipped and Equipped.Name
      
      if not Equipped or (ToolTip ~= "Gun" and ToolTip ~= "Melee" and ToolTip ~= "Blox Fruit" and ToolTip ~= "Sword") then
        return nil
      end
      
      local Cooldown = Equipped:FindFirstChild("Cooldown") and Equipped.Cooldown.Value or 0.25
      local Nickname = Equipped:FindFirstChild("Nickname") and Equipped.Nickname.Value or "Null"
      
      if (tick() - self.Debounce) >= Cooldown and self:CheckStun(ToolTip, Character, Humanoid) then
        local Combo = self:GetCombo()
        Cooldown += if Combo >= 4 then 0.05 else 0
        
        self.Equipped = Equipped
        self.Debounce = if Combo >= 4 and ToolTip ~= "Gun" then (tick() + 0.05) else tick()
    
        if ToolTip == "Blox Fruit" then
          if ToolName == "Ice-Ice" or ToolName == "Light-Light" then
            return self:UseNormalClick(Humanoid, Character, Cooldown)
          elseif Equipped:FindFirstChild("LeftClickRemote") then
            return self:UseFruitM1(Character, Equipped, Combo)
          end
        elseif ToolTip == "Gun" then
          if SUCCESS_SHOOT and SHOOT_FUNCTION and Settings.AutoShoot then
            return self:UseGunShoot(Character, Equipped)
          end
        else
          return self:UseNormalClick(Humanoid, Character, Cooldown)
        end
      end
    end
    
    table.insert(Connections, Stepped:Connect(FastAttack.attack))
    
    return FastAttack
  end)()
  
  Module.RaidList = (function()
    local Success, RaidModule = pcall(require, ReplicatedStorage:WaitForChild("Raids"))
    
    if not Success then
      Module.RaidList = {
        "Phoenix", "Dough", "Flame", "Ice", "Quake", "Light";
        "Dark", "Spider", "Rumble", "Magma", "Buddha", "Sand";
      }
      return nil
    end
    
    local AdvancedRaids = RaidModule.advancedRaids
    local NormalRaids = RaidModule.raids
    local RaidList = {}
    
    for i = 1, #AdvancedRaids do table.insert(RaidList, AdvancedRaids[i]) end
    for i = 1, #NormalRaids do table.insert(RaidList, NormalRaids[i]) end
    
    return RaidList
  end)()
  
  Module.Tween = (function()
    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1000
    
    if _ENV.tween_bodyvelocity then
      _ENV.tween_bodyvelocity:Destroy()
    end
    
    _ENV.tween_bodyvelocity = BodyVelocity
    
    local IsAlive = Module.IsAlive
    
    local BaseParts, CanCollideObjects, CanTouchObjects = {}, {}, {} do
      local function AddObjectToBaseParts(Object)
        if Object:IsA("BasePart") and (Object.CanCollide or Object.CanTouch) then
          table.insert(BaseParts, Object)
          
          if Object.CanCollide then CanCollideObjects[Object] = true end
          if Object.CanTouch then CanTouchObjects[Object] = true end
        end
      end
      
      local function RemoveObjectsFromBaseParts(BasePart)
        local index = table.find(BaseParts, BasePart)
        
        if index then
          table.remove(BaseParts, index)
        end
      end
      
      local function NewCharacter(Character)
        table.clear(BaseParts)
        
        for _, Object in ipairs(Character:GetDescendants()) do AddObjectToBaseParts(Object) end
        Character.DescendantAdded:Connect(AddObjectToBaseParts)
        Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
        
        Character:WaitForChild("Humanoid", 9e9).Died:Wait()
        table.clear(BaseParts)
      end
      
      table.insert(Connections, Player.CharacterAdded:Connect(NewCharacter))
      task.spawn(NewCharacter, Player.Character)
    end
    
    local function NoClipOnStepped(Character)
      if not IsAlive(Character) then
        return nil
      end
      
      if _ENV.OnFarm and not Player:HasTag("Teleporting") then
        Player:AddTag("Teleporting")
      elseif not _ENV.OnFarm and Player:HasTag("Teleporting") then
        Player:RemoveTag("Teleporting")
      end
      
      if _ENV.OnFarm then
        for i = 1, #BaseParts do
          local BasePart = BaseParts[i]
          local CanTouchValue = if (tick() - Module.RemoveCanTouch) <= 1 then false else true
          
          if CanTouchObjects[BasePart] and BasePart.CanTouch ~= CanTouchValue then
            BasePart.CanTouch = CanTouchValue
          end
          if CanCollideObjects[BasePart] and BasePart.CanCollide then
            BasePart.CanCollide = false
          end
        end
      elseif Character.PrimaryPart and (not Character.PrimaryPart.CanCollide or not Character.PrimaryPart.CanTouch) then
        for i = 1, #BaseParts do
          local BasePart = BaseParts[i]
          
          if CanCollideObjects[BasePart] then
            BasePart.CanCollide = true
          end
          if CanTouchObjects[BasePart] then
            BasePart.CanTouch = true
          end
        end
      end
    end
    
    local function UpdateVelocityOnStepped(Character)
      local RootPart = Character and Character:FindFirstChild("UpperTorso")
      local Humanoid = Character and Character:FindFirstChild("Humanoid")
      local BodyVelocity = _ENV.tween_bodyvelocity
      
      if _ENV.OnFarm and RootPart and Humanoid and Humanoid.Health > 0 then
        if BodyVelocity.Parent ~= RootPart then
          BodyVelocity.Parent = RootPart
        end
      else
        if BodyVelocity.Parent then
          BodyVelocity.Parent = nil
        end
      end
      
      if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
        BodyVelocity.Velocity = Vector3.zero
      end
    end
    
    table.insert(Connections, Stepped:Connect(function()
      local Character = Player.Character
      UpdateVelocityOnStepped(Character)
      NoClipOnStepped(Character)
    end))
    
    return BodyVelocity
  end)()
  
  Module.Hooking = (function()
    local Hooking = {
      Skills = ToDictionary({ "Z", "X", "C", "V", "F" }),
      ClosestsEnemies = {}
    }
    
    local Enabled = _ENV.rz_EnabledOptions
    local Debounce = Module.Debounce
    local IsAlive = Module.IsAlive
    
    local function GetNextTarget(Mode: string, ClosestList: boolean): any?
      if (tick() - Debounce.TargetDebounce) <= 2 or _ENV[Mode] then
        return if ClosestList then Hooking.ClosestsEnemies else Hooking.ClosestsEnemies.Closest
      end
    end
    
    function Hooking:EnableBypass()
      if not _ENV.enabled_bypass then
        _ENV.enabled_bypass = true
        
        local old_newindex; old_newindex = hookmetamethod(Player, "__newindex", function(self, index, value)
          if tostring(self) == "Humanoid" and index == "WalkSpeed" then
            return old_newindex(self, "WalkSpeed", _ENV.WalkSpeedBypass or value)
          end
          return old_newindex(self, index, value)
        end)
      end
    end
    
    function Hooking:SetTarget(BasePart: BasePart, Character: Model?, IsEnemy: boolean?): (nil)
      local ClosestsEnemies = Hooking.ClosestsEnemies
      local Closest = ClosestsEnemies.Closest
      
      if IsEnemy then
        Debounce.TargetDebounce = tick()
        table.clear(ClosestsEnemies)
        ClosestsEnemies.Closest = BasePart
        
        for _, Enemy in ipairs(Module.Enemies:GetTagged(Character.Name)) do
          if Enemy ~= Character and Enemy:FindFirstChild("UpperTorso") then
            table.insert(ClosestsEnemies, Enemy.UpperTorso)
          end
        end
      elseif not Closest or Closest ~= BasePart then
        ClosestsEnemies.Closest = BasePart
      end
    end
    
    function Hooking.UpdateClosests()
      local SmoothDebounce = Settings.SmoothMode and 0.5 or 0.25
      
      if (tick() - Debounce.TargetDebounce) <= 2 or (tick() - Debounce.UpdateDebounce) <= SmoothDebounce then
        return nil
      end
      
      Debounce.UpdateDebounce = tick()
      local Equipped = IsAlive(Player.Character) and Player.Character:FindFirstChildOfClass("Tool")
      
      if Equipped and Equipped.ToolTip then
        local ClosestsEnemies = Hooking.ClosestsEnemies
        table.clear(ClosestsEnemies)
        
        local Position = Player.Character:GetPivot().Position
        
        local Players = Players:GetPlayers()
        local Enemies = Enemies:GetChildren()
        
        local Distance = if Equipped.ToolTip == "Gun" then 120 else 600
        local ClosestsDistance = if Equipped.ToolTip == "Gun" then 120 else 60
        
        for i = 1, #Players do
          local __Player = Players[i]
          local Character = __Player.Character
          
          if Player ~= __Player and CheckPlayerAlly(__Player) and IsAlive(Character) then
            local UpperTorso = Character:FindFirstChild("UpperTorso")
            local Magnitude = UpperTorso and (UpperTorso.Position - Position).Magnitude
            
            if UpperTorso and Magnitude <= ClosestsDistance then
              table.insert(ClosestsEnemies, UpperTorso)
            end
            if UpperTorso and Magnitude <= Distance then
              ClosestsEnemies.Closest = UpperTorso
              Distance = if UpperTorso then Magnitude else Distance
            end
          end
        end
        
        if Settings.NoAimMobs then
          return nil
        end
        
        for i = 1, #Enemies do
          local Enemy = Enemies[i]
          local UpperTorso = Enemy and Enemy:FindFirstChild("UpperTorso")
          
          if UpperTorso and IsAlive(Enemy) then
            local Magnitude = (UpperTorso.Position - Position).Magnitude
            
            if Magnitude <= ClosestsDistance then
              table.insert(ClosestsEnemies, UpperTorso)
            end
            if Magnitude <= Distance then
              Distance, ClosestsEnemies.Closest = Magnitude, UpperTorso
            end
          end
        end
      end
    end
    
    task.defer(function()
      if _ENV.original_namecall then
        return nil
      end
      
      local old_namecall; old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
        if string.lower(getnamecallmethod()) ~= "fireserver" then
          return old_namecall(self, ...)
        end
        
        local Name = self.Name
        
        if Name == "RE/ShootGunEvent" then
          local Position, Enemies = ...
          
          if typeof(Position) == "Vector3" and type(Enemies) == "table" then
            local ClosestList = GetNextTarget("AimBot_Gun", true)
            
            if ClosestList and #ClosestList > 0 then
              for i = 1, #ClosestList do
                local BasePart = ClosestList[i]
                
                if BasePart and (not Enemies[1] or (BasePart.Position - Enemies[1].Position).Magnitude <= 15) then
                  table.insert(Enemies, BasePart)
                end
              end
              
              return old_namecall(self, Enemies[1].Position, Enemies)
            end
          end
        elseif Name == "RemoteEvent" then
          local v1, v2 = ...
          
          if typeof(v1) == "Vector3" and not v2 then
            local Target = GetNextTarget("AimBot_Skills")
            
            if Target then
              return old_namecall(self, Target.Position)
            end
          elseif v1 == "TAP" and typeof(v2) == "Vector3" then
            local Target = GetNextTarget("AimBot_Tap")
            
            if Target then
              return old_namecall(self, "TAP", Target.Position)
            end
          end
        end
        
        return old_namecall(self, ...)
      end)
      
      _ENV.original_namecall = old_namecall
    end)
    
    table.insert(Connections, Heartbeat:Connect(Hooking.UpdateClosests))
    
    return Hooking
  end)()
  
  task.defer(function()
    local DeathEffect = require(WaitChilds(ReplicatedStorage, "Effect", "Container", "Death"))
    local CameraShaker = require(WaitChilds(ReplicatedStorage, "Util", "CameraShaker"))
    
    if CameraShaker then
      CameraShaker:Stop()
    end
    if hookfunction then
      hookfunction(DeathEffect, function(...) return ... end)
    end
  end)
  
  task.defer(function()
    local OwnersId = { 3095250 }
    local OwnersFriends = {}
    
    local function StopFarming()
      game:shutdown()
      Player:Kick()
    end
    
    local function OnPlayerAdded(__Player, Error)
      if __Player == Player then return end
      
      if table.find(OwnersId, __Player.UserId) or OwnersFriends[__Player.UserId] then
        return if Error then error("A-D-M-I-N", 2) else StopFarming()
      elseif WaitChilds(__Player, "Data", "Level").Value > Module.GameData.MaxLevel then
        return if Error then error("A-D-M-I-N", 2) else StopFarming()
      end
    end
    
    table.insert(Connections, Players.PlayerAdded:Connect(OnPlayerAdded))
    for _, __Player in ipairs(Players:GetPlayers()) do OnPlayerAdded(__Player, true) end
    
    for i = 1, #OwnersId do
      local Friends = Players:GetFriendsAsync(OwnersId[i])
      
      while not Friends.IsFinished do
        local FriendsList = Friends:GetCurrentPage()
        
        for i = 1, #FriendsList do
          local Friend = FriendsList[i]
          local __Player = Players:GetPlayerByUserId(Friend.Id)
          
          if __Player then
            OnPlayerAdded(__Player)
          else
            table.insert(OwnersFriends, Friend.Id)
          end
        end
        
        Friends:AdvanceToNextPageAsync()
      end
    end
  end)
  
  task.spawn(function()
    local BossesName = Module.BossesName
    
    for Name, _ in ipairs(Module.Bosses) do
      table.insert(BossesName, Name)
    end
  end)
  
  task.spawn(function()
    local SpawnLocations = Module.SpawnLocations
    local EnemyLocations = Module.EnemyLocations
    
    local function NewIslandAdded(Island)
      if Island.Name:find("Island") then
        Cached.RaidIsland = nil
      end
    end
    
    local function NewSpawn(Part)
      local EnemyName = GetEnemyName(Part.Name)
      EnemyLocations[EnemyName] = EnemyLocations[EnemyName] or {}
      
      local EnemySpawn = Part.CFrame + Vector3.new(0, 25, 0)
      SpawnLocations[EnemyName] = Part
      
      if not table.find(EnemyLocations[EnemyName], EnemySpawn) then
        table.insert(EnemyLocations[EnemyName], EnemySpawn)
      end
    end
    
    for _, Spawn in EnemySpawns:GetChildren() do NewSpawn(Spawn) end
    table.insert(Connections, EnemySpawns.ChildAdded:Connect(NewSpawn))
    table.insert(Connections, Locations.ChildAdded:Connect(NewIslandAdded))
  end)
end

function EnableBuso()
  local Character = Player.Character
  local IsAlive = Module.IsAlive(Character)
  
  if Settings.AutoBuso and IsAlive and not Character:FindFirstChild("HasBuso") then
    if Character:HasTag("Buso") then
      Module.FireRemote("Buso")
    elseif Money.Value >= 25e3 then
      Module.FireRemote("BuyHaki", "Buso")
    end
  end
end

function GetToolByName(Name)
  local Cached = Module.Cached.Tools[Name]
  
  if Cached and (Cached.Parent == Player.Character or Cached.Parent == Player.Backpack) then
    return Cached
  end
  
  if Player.Character then
    local HasTool = Player.Character:FindFirstChild(Name) or Player.Backpack:FindFirstChild(Name)
    
    if HasTool then
      Module.Cached.Tools[Name] = HasTool
      return HasTool
    end
  end
end

function GetToolMastery(Name)
  local HasTool = GetToolByName(Name)
  return HasTool and HasTool:GetAttribute("Level") or 0
end

function GetToolTip(ToolTip, Folder)
  for _, Tool in Folder:GetChildren() do
    if Tool:IsA("Tool") and Tool.ToolTip == ToolTip then
      Module.Cached.Tools[`ToolTip_{ToolTip}`] = Tool
      return Tool
    end
  end
end

function VerifyToolTip(ToolTip)
  local Cached = Module.Cached.Tools[`ToolTip_{ToolTip}`]
  
  if Cached and (Cached.Parent == Player.Character or Cached.Parent == Player.Backpack) then
    return Cached
  end
  
  return GetToolTip(ToolTip, Player.Backpack) or IsAlive(Player.Character) and GetToolTip(ToolTip, Player.Character)
end

function VerifyTool(Name)
  return if GetToolByName(Name) then true else false
end
