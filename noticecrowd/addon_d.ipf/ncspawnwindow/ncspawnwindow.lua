local addonName = "NCSPAWNWINDOW";
local addonNameLower = string.lower(addonName);

local oaddonNameLower = "noticecrowd";

local author = "fh";

_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][author] = _G["ADDONS"][author] or {};
_G["ADDONS"][author][addonName] = _G["ADDONS"][author][addonName] or {};
local g = _G["ADDONS"][author][addonName];

local version = '1.4.5';

local DEBUG_FLAG = false;



--ライブラリ読み込み
local acutil = require('acutil');
--Lua 5.2+ migration
if not _G['unpack'] and (table and table.unpack) then _G['unpack'] = table.unpack end

g.settingsDirLoc = string.format("../addons/%s", oaddonNameLower);
g.settingsFileLoc = string.format("%s/spawnsettings.json", g.settingsDirLoc);

g.DefaultSettings = {};
g.DefaultSettings.Position = {X = 400, Y = 300};
g.DefaultSettings.ShowWindow = {true};

if not g.loaded then
    g.settings = g.DefaultSettings;
end

g.loaded = false;

g.spawnmap = {};
g.spawnmapClass = {};
g.countmsg = "";

-- DEVELOPERCONSOLE_PRINT_TEXT(string.format("%s.lua is loaded", addonName));

-- load-save settings

function g.LoadSettings(self)
    local settings, err = acutil.loadJSON(self.settingsFileLoc, self.DefaultSettings);

    if err then
        -- DEVELOPERCONSOLE_PRINT_TEXT('Message.CannotLoadSettings');
    end

    if not settings then
        settings = self.DefaultSettings;
    end

    self.settings = settings;
end

function g.SaveSettings(self)
    return acutil.saveJSON(self.settingsFileLoc, self.settings);
end

------------------------------------------------
-- frame viewer

function g.ShowFrame(self, flag)
    if flag ~= nil and flag ~= true and flag ~= false then
        return false;
    end

    if flag == nil then
        flag = self.Frame:IsVisible() == 0;
    end

    self.Frame:SetPos(self.settings.Position.X, self.settings.Position.Y);
    self.Frame:ShowWindow(flag and 1 or 0);
    self:UpdateFrame();

    return true
end

function g.ToggleFrame(self)
    return self:ShowFrame();
end

function g.ClearWindow(self)
    g.spawnmap = {};
    g.spawnmapClass = {};
end

function g.SaveFramePosition(self, X, Y)
    self.settings.Position.X = X;
    self.settings.Position.Y = Y;
    self:SaveSettings();
end

-- update window
function g.UpdateFrame(self)
    self:UpdateSpawnLocation();
    self:UpdateCrowdCount();
end

function g.UpdateCrowdCount(self)
    local msgStr = "追従者数: "..g.countmsg;
    self:GetPopCountObj():SetTextByKey('value', msgStr);
end

function g.UpdateSpawnLocation(self)
    local textobj = self:GetSpawnTextObj();
    textobj[1]:SetTextByKey('value', self:GetSpawnLocation(1));
    textobj[2]:SetTextByKey('value', self:GetSpawnLocation(2));
    textobj[3]:SetTextByKey('value', self:GetSpawnLocation(3));
    textobj[4]:SetTextByKey('value', self:GetSpawnLocation(4));
    textobj[5]:SetTextByKey('value', self:GetSpawnLocation(5));
    textobj[6]:SetTextByKey('value', self:GetSpawnLocation(6));
end

-- GET UI Object
function g.GetTimerObj(self)
    local timerTickObj = GET_CHILD(self.Frame, 'timerTick', 'ui::CAddOnTimer');
    timerTickObj:SetUpdateScript('NCSPAWNWINDOW_ON_TICK');
    return timerTickObj;
end

function g.GetSpawnTextObj(self)
    return {
        GET_CHILD(self.Frame, "spawnText1", 'ui::CRichText'),
        GET_CHILD(self.Frame, "spawnText2", 'ui::CRichText'),
        GET_CHILD(self.Frame, "spawnText3", 'ui::CRichText'),
        GET_CHILD(self.Frame, "spawnText4", 'ui::CRichText'),
        GET_CHILD(self.Frame, "spawnText5", 'ui::CRichText'),
        GET_CHILD(self.Frame, "spawnText6", 'ui::CRichText')
    };
end

function g.GetPopCountObj(self)
    return GET_CHILD(self.Frame, 'popCount', 'ui::CRichText')
end

function g.GetSpawnLocation(self, num)
    if num <= #g.spawnmap then
        local mapstr = NCSPAWNWINDOW_GET_DIC_MAPNAME(g.spawnmap[num]);
        return mapstr;
    --    return g.spawnmap[num];
    else
        return "";
    end
end

function NCSPAWNWINDOW_GET_DIC_MAPNAME(str)
    local c_str = dictionary.ReplaceDicIDInCompStr(str);
    return c_str;
end

-- warp
function g.Warp(self, className)
     _G.WORLDMAP2_TOKEN_WARP(className);
end

-- UI イベント
function NCSPAWNWINDOW_TOGGLE()
    g:ToggleFrame();
end
  
  
function NCSPAWNWINDOW_OPEN()
    g:ShowFrame(true);
end
  
  
function NCSPAWNWINDOW_CLOSE()
    g:ClearWindow();
    g:ShowFrame(false);
end
  
-- UI ドラッグ
function NCSPAWNWINDOW_END_DRAG()
    local X = g.Frame:GetX();
    local Y = g.Frame:GetY();
    g:SaveFramePosition(X, Y);
end


function NCSPAWNWINDOW_WARP1()
    if #g.spawnmap >=1 then
        g:Warp(g.spawnmapClass[1].ClassName);
    end
end

function NCSPAWNWINDOW_WARP2()
    if #g.spawnmap >=2 then
        g:Warp(g.spawnmapClass[2].ClassName);
    end
end

function NCSPAWNWINDOW_WARP3()
    if #g.spawnmap >=3 then
        g:Warp(g.spawnmapClass[3].ClassName);
    end
end

function NCSPAWNWINDOW_WARP4()
    if #g.spawnmap >=4 then
        g:Warp(g.spawnmapClass[4].ClassName);
    end
end

function NCSPAWNWINDOW_WARP5()
    if #g.spawnmap >=5 then
        g:Warp(g.spawnmapClass[5].ClassName);
    end
end

function NCSPAWNWINDOW_WARP6()
    if #g.spawnmap >=6 then
        g:Warp(g.spawnmapClass[6].ClassName);
    end
end

-- 初期設定
function NCSPAWNWINDOW_ON_INIT(addon, frame)
    -- DEVELOPERCONSOLE_PRINT_TEXT("noticecrowd:set init.");

    g.Addon = addon
    g.Frame = frame

    if not g.loaded then

        acutil.slashCommand("/ncshowspawn", NCSPAWNWINDOW_SHOWFLG);

        g:LoadSettings();
        g:SaveSettings();

        g.loaded = true;
    end

    addon:RegisterMsg('GAME_START', 'NCSPAWNWINDOW_GAME_START');

    -- NOTICECROWD_SET_WINDOW();
end

function NCSPAWNWINDOW_SHOWFLG()
    if (g.settings.ShowWindow) then
        CHAT_SYSTEM("spawn window is hidden");
        NCSPAWNWINDOW_CLOSE();
        g.settings.ShowWindow = false;
    else
        CHAT_SYSTEM("spawn window will be shown");
        NCSPAWNWINDOW_OPEN();
        g.settings.ShowWindow = true;
    end
    g:SaveSettings();
end

function NCSPAWNWINDOW_GAME_START(frame)
    if g.settings.ShowWindow then
        if #g.spawnmap >=1 then
            NCSPAWNWINDOW_SET_WINDOW();
        end
    end
end

function NCSPAWNWINDOW_SET_WINDOW()
    if g.settings.ShowWindow then
        NCSPAWNWINDOW_OPEN();
    end
end

function NCSPAWNWINDOW_SEARCH_MAP(mapstr)
    local targetMap = nil;

    local clsList, cnt = GetClassList('worldmap2_submap_data');
    for i = 0, cnt-1 do
        local cls = GetClassByIndexFromList(clsList, i);
        local mapData = GetClass('Map', cls.MapName);
        local mapName = string.gsub(dictionary.ReplaceDicIDInCompStr(mapData.Name), " ", "");

        if string.find(string.lower(mapName), string.lower(mapstr)) ~= nil then
            targetMap = mapData;
            break;
        end
    end
    return targetMap;
end

function NCSPAWNWINDOW_COPY_SPAWN(spmap)
    g.spawnmap = spmap;
    if #g.spawnmap == 1 then
        g.spawnmapClass = {};
    end
    if string.find(g.spawnmap[#g.spawnmap],"dicID") then
        table.insert(g.spawnmapClass, _G.GetClassByStrProp('Map', 'Name', g.spawnmap[#g.spawnmap]));
    else
        table.insert(g.spawnmapClass, NCSPAWNWINDOW_SEARCH_MAP(g.spawnmap[#g.spawnmap]));
    end
    --for i = 1 , #g.spawnmap do
    --    g.spawnmapClass[i] = _G.GetClassByStrProp('Map', 'Name', g.spawnmap[i]);
    --end 
end

function NCSPAWNWINDOW_COPY_COUNT(countmsg)
    g.countmsg = countmsg;
    g:UpdateFrame();
end
