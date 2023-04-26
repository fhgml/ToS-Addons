local addonName = "NOTICECROWD";
local addonNameLower = string.lower(addonName);

local author = "fh";

_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][author] = _G["ADDONS"][author] or {};
_G["ADDONS"][author][addonName] = _G["ADDONS"][author][addonName] or {};
local g = _G["ADDONS"][author][addonName];

local version = '1.4.5';

local debug_flg = false;

--ライブラリ読み込み
local acutil = require('acutil');
--Lua 5.2+ migration
if not _G['unpack'] and (table and table.unpack) then _G['unpack'] = table.unpack end

g.settingsDirLoc = string.format("../addons/%s", addonNameLower);
g.settingsFileLoc = string.format("%s/settings.json", g.settingsDirLoc);
g.timerlogFileLoc = string.format("%s/timer.json", g.settingsDirLoc);

g.debugFileLoc = string.format("%s/debug.txt", g.settingsDirLoc);

g.DefaultSettings = {};
g.DefaultSettings.Position = {X = 400, Y = 300};
g.DefaultSettings.EnabledMaps = {};
g.DefaultSettings.ShowPTChat = false;
g.DefaultSettings.NoticeBGM = true;
g.DefaultSettings.NoticeSE = true;
g.DefaultSettings.NoticeVoice = true;

g.DefaultLastTime = {
    day = -1,
    hour = 0,
    min = 0,
    sec = 0
};

if not g.loaded then
    g.settings = g.DefaultSettings;
end

g.lasttime = nil;
g.loaded = false;

g.spawnstarttime = 0;
g.spawnendtime = 0;

g.timerTick = 0
g.startTick = 0
g.loopTick = 0
g.description = nil
g.spawnmap = {};
g.spawnmapID = {};

g.CROWDBYMAP = 4;
g.crowdAll = 0;
g.crowdKilled = 0;

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

function g.SaveFramePosition(self, X, Y)
    self.settings.Position.X = X;
    self.settings.Position.Y = Y;
    self:SaveSettings();
end

-- update window
function g.UpdateFrame(self)
    self:UpdateTimerDesc();
    self:UpdateTimerRemaining();
    self:UpdateFrameLanguage();
    self:UpdatePopCount();
    self:UpdatePopTime();
end

function g.UpdateTimerDesc(self)
    local desc = self:GetTimerDesc();
  
    if not desc then
      desc = "説明なし";
    end
  
    self:GetTimerDescObj():SetTextByKey('value', desc);
end

function g.UpdateTimerRemaining(self)
    self:GetRemainHourObj():SetTextByKey('value', self:GetHour());
    self:GetRemainMinObj():SetTextByKey('value', self:GetMinute());
end

function g.UpdateFrameLanguage(self)
    self:GetRemainTimeTextObj():SetTextByKey('value', '追従者残り時間');
end

function g.UpdatePopCount(self)
    local msgStr = "追従者数: "..g.crowdKilled.."/"..g.crowdAll;
    self:GetPopCountObj():SetTextByKey('value', msgStr);
end

function g.UpdatePopTime(self)
    local sptime = self:GetSpawnTime();
    local msgStr = "予想時刻: "..sptime;
    self:GetPopTimeObj():SetTextByKey('value', msgStr);
end

-- GET UI Object
function g.GetTimerObj(self)
    local timerTickObj = GET_CHILD(self.Frame, 'timerTick', 'ui::CAddOnTimer');
    timerTickObj:SetUpdateScript('NOTICECROWD_ON_TICK');
    return timerTickObj;
end

function g.GetTimerDescObj(self)
    return GET_CHILD(self.Frame, 'timerDesc', 'ui::CRichText')
end
  
function g.GetRemainTimeTextObj(self)
    return GET_CHILD(self.Frame, 'remainTimeText', 'ui::CRichText')
end

function g.GetRemainClockGbox(self)
    return GET_CHILD(self.Frame, 'remainClockGbox', 'ui::CGroupBox')
end

function g.GetRemainHourObj(self)
    return GET_CHILD(self:GetRemainClockGbox(), 'remainHour', 'ui::CRichText')
end

function g.GetRemainMinObj(self)
    return GET_CHILD(self:GetRemainClockGbox(), 'remainMin', 'ui::CRichText')
end

function g.GetPopCountObj(self)
    return GET_CHILD(self.Frame, 'popCount', 'ui::CRichText')
end

function g.GetPopTimeObj(self)
    return GET_CHILD(self.Frame, 'popTime', 'ui::CRichText')
end

-- timer start/stop update
function g.StartTimer(self, startTime, desc)
    self:SetTimerDesc(desc);
    self:SetLoopTick(startTime);
    self:UpdateFrame();

    --call timer every 60secs
    self:GetTimerObj():Start(60);
end

function g.StopTimer(self)
    self:GetTimerObj():Stop();
end

function g.LoopTimer(self)
    local startTime = NOTICECROWD_GET_DIFF_TIME();
    if startTime ~= nil then
        self:StartTimer(startTime, g.description);
    else
        NOTICECROWD_CLOSE();
    end
end

function g.TickTimer(self)
    NOTICECROWD_ON_EVERY_MIN();
    -- 10 minutes late
    if self.timerTick == 10 then
      NOTICECROWD_ON_10MIN_LEFT();
    -- timer complete
    elseif self.timerTick < 0 then
      self:StopTimer();
      NOTICECROWD_ON_COMPLETE();
      return;
    end
    self.timerTick = self.timerTick - 1;
end

function g.SetTick(self, tick)
    self.timerTick = math.floor(tick);
end

function g.SetLoopTick(self, startTime)
    self.startTick = math.floor(startTime);
    self:SetTick(startTime);
end

-- 説明文のgetter,setter
function g.GetTimerDesc(self, desc)
    return self.description;
end

function g.SetTimerDesc(self, desc)
    self.description = (desc and desc ~= '') and desc or nil;
end

function g.GetHour(self)
    return string.format('%02d', math.floor(self.timerTick / 60));
end 
  
function g.GetMinute(self)
    return string.format('%02d', math.floor(self.timerTick % 60));
end

function g.GetSpawnTime(self)
    return string.format('%02d : %02d - %02d : %02d', 
        self.spawnstarttime,
        self.lasttime.min,
        self.spawnendtime,
        self.lasttime.min
    );
end

function g.AddHour(self, hour1, hour2)
    local added = tonumber(hour1) + tonumber(hour2);
    while added >= 24 do
        added = added - 24;
    end
    return added;
end

-- caller
function NOTICECROWD_ON_TICK(frame)
    g:TickTimer();
end

function NOTICECROWD_ON_EVERY_MIN()
    g:UpdateTimerRemaining();
end

function NOTICECROWD_ON_10MIN_LEFT()
    CHAT_SYSTEM("あと10分です");
end

function NOTICECROWD_ON_COMPLETE()
    g:LoopTimer();
end

-- UI イベント
function NOTICECROWD_TOGGLE()
    g:ToggleFrame();
end
  
  
function NOTICECROWD_OPEN()
    g:ShowFrame(true);
end
  
  
function NOTICECROWD_CLOSE()
    g:StopTimer();
    g:ShowFrame(false);
end
  
-- UI ドラッグ
function NOTICECROWD_END_DRAG()
    local X = g.Frame:GetX();
    local Y = g.Frame:GetY();
    g:SaveFramePosition(X, Y);
end

-- 初期設定
function NOTICECROWD_ON_INIT(addon, frame)
    -- DEVELOPERCONSOLE_PRINT_TEXT("noticecrowd:set init.");

    g.Addon = addon
    g.Frame = frame

    if not g.loaded then 
        if(g.NOTICECROWD_OLD_NOTICE_ON_MSG==nil) then
            g.NOTICECROWD_OLD_NOTICE_ON_MSG = NOTICE_ON_MSG;
            _G["NOTICE_ON_MSG"] = NOTICECROWD_HOOK_NOTICE_ON_MSG;
        end

        acutil.slashCommand("/nextcrowd", NOTICECROWD_SHOW_NEXT_CROWD);
        acutil.slashCommand("/showtimer", NOTICECROWD_TOGGLE_WINDOW);
        -- acutil.slashCommand("/savetimelog", NOTICECROWD_SAVE_TIMELOG);
        -- acutil.slashCommand("/setlasttimenow", NOTICECROWD_SET_TIMELOG);
        acutil.slashCommand("/setcrowdtime", NOTICECROWD_SET_TIME);
        acutil.slashCommand("/showptchat", NOTICECROWD_SHOW_PTCHAT);
        acutil.slashCommand("/noticecrowd", NOTICECROWD_HELP);
        acutil.slashCommand("/ncnoticebgm", NOTICECROWD_TOGGLE_BGM);
        acutil.slashCommand("/ncnoticese", NOTICECROWD_TOGGLE_SE);
        acutil.slashCommand("/ncnoticevoice", NOTICECROWD_TOGGLE_VOICE);

        NOTICECROWD_LOAD_TIMELOG();
        NOTICECROWD_SAVE_TIMELOG();
        g:LoadSettings();
        g:SaveSettings();

        g.loaded = true;
    end

    addon:RegisterMsg('GAME_START', 'NOTICECROWD_GAME_START');

    -- NOTICECROWD_SET_WINDOW();
end

function NOTICECROWD_GAME_START(frame)
    local mapId = session.GetMapID();
    local enabled = g.settings.EnabledMaps[tostring(mapId)];
    if (enabled == 1) then
        NOTICECROWD_SET_WINDOW();
    end
    -- g.spawnmap = {};
end

function NOTICECROWD_TOGGLE_WINDOW()
    local frame = g.frame
    local mapId = session.GetMapID();
    local enabled = g.settings.EnabledMaps[tostring(mapId)];
    if (enabled == 1) then
        NOTICECROWD_CLOSE();
        g.settings.EnabledMaps[tostring(mapId)] = 0
    else
        NOTICECROWD_SET_WINDOW();
        g.settings.EnabledMaps[tostring(mapId)] = 1
    end
    g:SaveSettings();
end

function NOTICECROWD_REVIEW_WINDOW()
    local frame = g.frame
    local mapId = session.GetMapID();
    local enabled = g.settings.EnabledMaps[tostring(mapId)];
    if (enabled == 1) then
        NOTICECROWD_SET_WINDOW();
    end
end

function NOTICECROWD_SET_WINDOW()
    g:StopTimer();
    local startTime = NOTICECROWD_GET_DIFF_TIME();
    if startTime ~= nil then
        g:StartTimer(startTime, g.description);
        NOTICECROWD_OPEN();
    end
end

function NOTICECROWD_SET_TIMELOG()
    local serverTime = geTime.GetServerSystemTime();
    g.lasttime = {
        day = serverTime.wDay,
        hour = serverTime.wHour,
        min = serverTime.wMinute,
        sec = serverTime.wSecond
    }
    NOTICECROWD_SAVE_TIMELOG();
    NOTICECROWD_REVIEW_WINDOW();
end

function NOTICECROWD_SET_TIME(commands)
    if #commands < 1 then
        return
    end
    local last_hour = tonumber(table.remove(commands, 1));
    local last_minute = tonumber(table.remove(commands, 1));
    CHAT_SYSTEM("set last spawn time at "..last_hour..":"..last_minute);
    g.lasttime.hour = last_hour;
    g.lasttime.min = last_minute;
    g.lasttime.sec = 0;
    local serverTime = geTime.GetServerSystemTime();
    local lastmins = (g.lasttime.hour * 60) + g.lasttime.min;
    local nowmins = (serverTime.wHour * 60) + serverTime.wMinute; 
    if (lastmins < nowmins) then
        g.lasttime.day = serverTime.wDay;
    else
        g.lasttime.day = tonumber(serverTime.wDay)- 1;
    end
    NOTICECROWD_SAVE_TIMELOG();
    NOTICECROWD_REVIEW_WINDOW();
end

function NOTICECROWD_SAVE_TIMELOG()
    acutil.saveJSON(g.timerlogFileLoc, g.lasttime);
end

function NOTICECROWD_LOAD_TIMELOG()
    local t,err = acutil.loadJSON(g.timerlogFileLoc, g.DefaultLastTime);
    
    if not t then
        t = g.DefaultLastTime;
    end
    g.lasttime = t;
end

function NOTICECROWD_HOOK_NOTICE_ON_MSG(frame, msg, argStr, argNum)
    local f,m = pcall(g.NOTICECROWD_NEW_NOTICE_ON_MSG,frame,msg,argStr,argNum);
    if f ~= true then
        CHAT_SYSTEM(m);
    end
    g.NOTICECROWD_OLD_NOTICE_ON_MSG(frame,msg,argStr,argNum);
end

function g.NOTICECROWD_NEW_NOTICE_ON_MSG(frame, msg, argStr, argNum)
    if debug_flg then
        local file,err = io.open(g.debugFileLoc, "a")
        if err then
            ui.SysMsg("SAVE CHAT FAILED.");
        else
            file:write(argStr.."\n");
            file:close();
        end
    end
    -- DEVELOPERCONSOLE_PRINT_TEXT("msg: "..msg.." argStr: "..argStr);
    if string.find(argStr,"AppearPCMonster") then
        NOTICECROWD_APPEARCROWD(argStr);
    elseif string.find(argStr,"DisappearPCMonster") then
        g.crowdKilled = g.crowdKilled + 1;
        g.spawnmap = {};
        g.spawnmapID = {};
        g:UpdateFrame();
        NCSPAWNWINDOW_COPY_COUNT(g.crowdKilled.."/"..g.crowdAll);
    end
end

function NOTICECROWD_APPEARCROWD(str)
    -- DEVELOPERCONSOLE_PRINT_TEXT("A Crowd of Followers Appeared");

    --if debug_flg then
    --    acutil.saveJSON(self.debugFileLoc, str);
    --end

    if (g.crowdKilled > 0) then
        g.crowdKilled = 0;
        g.crowdAll = 0;
    end
    g.crowdAll = g.crowdAll + g.CROWDBYMAP;
    local mapstr = "";
    --local mapstr = string.gsub(str,".*(@dicID.*%*%^).*","%1");
    local cmsg = "";
    if string.find(str, "%(.*,.*,.*%)") then
        -- 非常時 (文字列直打ち)
        mapstr = string.gsub(str,".*AppearPCMonster.*$%*$name$%*$%(.*,.*,(.*)%)#@!","%1");
        cmsg = "追従者出現:"..mapstr;
        table.insert(g.spawnmap, mapstr);
        table.insert(g.spawnmapID, mapstr);
        CHAT_SYSTEM(cmsg);
    else
        mapstr = string.gsub(str,".*AppearPCMonster.*$%*$name$%*$(.*)#@!","%1");
        cmsg = "追従者出現:"..dictionary.ReplaceDicIDInCompStr(mapstr);
        table.insert(g.spawnmap, dictionary.ReplaceDicIDInCompStr(mapstr));
        if string.find(mapstr,"dicID") then
            table.insert(g.spawnmapID, mapstr);
        else
            table.insert(g.spawnmapID, dictionary.ReplaceDicIDInCompStr(mapstr));
        end
        CHAT_SYSTEM(cmsg);
    end
    if g.settings.ShowPTChat then
        ui.Chat("/p "..cmsg);
    end
    if g.settings.NoticeVoice then
        GetMyActor():GetEffect():PlaySound('voice_archer_multishot_cast');
    end
    if g.settings.NoticeBGM then
        imcSound.PlayMusic('m_boss_scenario2');
    end
    if g.settings.NoticeSE then
        imcSound.PlaySoundEvent('button_click_stats_up');
    end
    --GetMyActor():GetEffect():PlaySound('voice_archer_multishot_cast');
    --imcSound.PlayMusic('m_boss_scenario2');
    NCSPAWNWINDOW_COPY_SPAWN(g.spawnmapID);
    NCSPAWNWINDOW_SET_WINDOW();
    NCSPAWNWINDOW_COPY_COUNT(g.crowdKilled.."/"..g.crowdAll);
    NOTICECROWD_SET_TIMELOG();
    NOTICECROWD_ON_COMPLETE();
    g:UpdateFrame();
end

function NOTICECROWD_DEBUG_NOTICE_MSG(num)
    local argStr = "!@#$AppearPCMonster$*$name$*$(바이덴티스 신당,Videntis Shrine,バイデンティス神堂)#@!"
    if num == 1 then
        argStr = "!@#$AppearPCMonster{name}$*$name$*$노브리어 숲#@!";
    elseif num == 2 then
        argStr = "!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20161012_023686$*^#@!";
    end
    --!@#$AppearPCMonster{name}$*$name$*$카듀멜 절벽#@!
    --!@#$AppearPCMonster{name}$*$name$*$별의 탑 1층#@!
    --!@#$AppearPCMonster{name}$*$name$*$아르커스 숲#@!
    --!@#$AppearPCMonster{name}$*$name$*$대지의 요새 거주구역#@!
    --"!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20150714_011746$*^#@!";
        --"!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20161012_023686$*^#@!",
        --"!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20170418_027530$*^#@!",
        --"!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20150804_014154$*^#@!"
        NOTICECROWD_APPEARCROWD(argStr);
    --argStr = "!@#$AppearPCMonster{name}$*$name$*$@dicID_^*$ETC_20161012_023686$*^#@!";
    --NOTICECROWD_APPEARCROWD(argStr);
end

function NOTICECROWD_GET_DIFF_TIME()
    local serverTime = geTime.GetServerSystemTime();
    if g.lasttime == nil then
        CHAT_SYSTEM("it doesnt have last spawn time log");
        return nil;
    elseif  g.lasttime.day == serverTime.wDay then
        local lastmins = (g.lasttime.hour * 60) + g.lasttime.min;
        local nowmins = (serverTime.wHour * 60) + serverTime.wMinute;
        local timediff = nowmins - lastmins;
        return NOTICECROWD_CHECK_CROWD_DTIME(timediff);
    else
        if g.lasttime.day == -1 then
            CHAT_SYSTEM("it doesnt have last spawn time log");
            return nil;
        end
        if serverTime.wDay ~= 1 then
            local daydiff = serverTime.wDay - g.lasttime.day;
            if daydiff ~= 1 then
                CHAT_SYSTEM("time log is too old.");
                return nil;
            end
        end  
        local lastmins = (g.lasttime.hour * 60) + g.lasttime.min;
        local nowmins = (serverTime.wHour * 60) + serverTime.wMinute;
        local timediff = nowmins - lastmins + 1440;
        return NOTICECROWD_CHECK_CROWD_DTIME(timediff);
    end
end

function NOTICECROWD_CHECK_CROWD_DTIME(timediff)
    local remain_time = nil;
    if timediff < 240 then
        remain_time = 240 - timediff;
        g.spawnstarttime = g:AddHour(tonumber(g.lasttime.hour), 4);
        g.spawnendtime = g:AddHour(tonumber(g.lasttime.hour), 6);
        g:SetTimerDesc("出現まで");
    elseif timediff < 360 then
        remain_time = 360 - timediff;
        g.spawnstarttime = g:AddHour(tonumber(g.lasttime.hour), 4);
        g.spawnendtime = g:AddHour(tonumber(g.lasttime.hour), 6);
        g:SetTimerDesc("出現終了まで");
        g.crowdKilled = 0;
        g.crowdAll = 0;
    elseif timediff < 480 then
        remain_time = 480 - timediff;
        g:SetTimerDesc("出現まで(一回見逃し)");
        g.spawnstarttime = g:AddHour(tonumber(g.lasttime.hour), 8);
        g.spawnendtime = g:AddHour(tonumber(g.lasttime.hour), 12);
    else
        CHAT_SYSTEM("以前記録された時刻が古く出現時間を特定できません");
        remain_time = nil;
    end 
    return remain_time;
end

function NOTICECROWD_SHOW_NEXT_CROWD()
    local serverTime = geTime.GetServerSystemTime()
    if g.lasttime == nil then
        CHAT_SYSTEM("it doesnt have last spawn time log");
    elseif  g.lasttime.day == serverTime.wDay then
        local lastmins = (g.lasttime.hour * 60) + g.lasttime.min;
        local nowmins = (serverTime.wHour * 60) + serverTime.wMinute;
        local timediff = nowmins - lastmins;
        NOTICECROWD_CHECK_CROWD_TIME(timediff);
    else
        if serverTime.wDay ~= 1 then
            local daydiff = serverTime.wDay - g.lasttime.day;
            if daydiff ~= 1 then
                CHAT_SYSTEM("time log is too old.");
                return;
            end
        end  
        local lastmins = (g.lasttime.hour * 60) + g.lasttime.min;
        local nowmins = (serverTime.wHour * 60) + serverTime.wMinute;
        local timediff = nowmins - lastmins + 1440;
        NOTICECROWD_CHECK_CROWD_TIME(timediff);
    end
end

function NOTICECROWD_CHECK_CROWD_TIME(timediff)
    if timediff < 240 then
        local starttime = 240 - timediff;
        local shour = math.floor(starttime / 60);
        local ehour = shour + 2;
        local sminute = starttime % 60;
        CHAT_SYSTEM("next spawn time at: "..shour..":"..sminute.." - "..ehour..":"..sminute);
    elseif timediff < 360 then
        local endtime = 360 - timediff;
        local ehour = math.floor(endtime / 60);
        local eminute = endtime % 60;
        CHAT_SYSTEM("next spawn will soon ( ~ "..ehour..":"..eminute);
    elseif timediff < 480 then
        local starttime = 480 - timediff;
        local shour = math.floor(starttime / 60);
        local ehour = shour + 4;
        local sminute = starttime % 60;
        CHAT_SYSTEM("next spawn time at: "..shour..":"..sminute.." - "..ehour..":"..sminute);
    else
        CHAT_SYSTEM("time log is too old");
    end 
end

function NOTICECROWD_SHOW_PTCHAT()
    if g.settings.ShowPTChat then
        g.settings.ShowPTChat = false;
        CHAT_SYSTEM("dont show crowd of follores at pt-chat.");
    else
        g.settings.ShowPTChat = true;
        CHAT_SYSTEM("show crowd of follores at pt-chat.");
    end
    g:SaveSettings();
end

function NOTICECROWD_TOGGLE_BGM()
    if g.settings.NoticeBGM then
        g.settings.NoticeBGM = false;
        CHAT_SYSTEM("dont notice at bgm.");
    else
        g.settings.NoticeBGM = true;
        CHAT_SYSTEM("notice at bgm.");
    end
    g:SaveSettings();
end

function NOTICECROWD_TOGGLE_SE()
    if g.settings.NoticeSE then
        g.settings.NoticeSE = false;
        CHAT_SYSTEM("dont notice at SE.");
    else
        g.settings.NoticeBGM = true;
        CHAT_SYSTEM("notice at SE.");
    end
    g:SaveSettings();
end

function NOTICECROWD_TOGGLE_VOICE()
    if g.settings.NoticeVoice then
        g.settings.NoticeVoice = false;
        CHAT_SYSTEM("dont notice at voice.");
    else
        g.settings.NoticeVoice = true;
        CHAT_SYSTEM("notice at voice.");
    end
    g:SaveSettings();
end

function NOTICECROWD_HELP()
    CHAT_SYSTEM("このアドオンは、追従者の出る時刻をタイマー形式で表示するアドオンです。");
    CHAT_SYSTEM("初回利用時は、一度追従者が出るまで待つか、/setcrowdtimeコマンドで前回の出現時間をセットしてください。");
    CHAT_SYSTEM("コマンド一覧");
    CHAT_SYSTEM("showtimer: GUI形式で追従者が出るまでの時間を表示/非表示");
    CHAT_SYSTEM("nextcrowd: テキストチャットに追従者が出るまでの時間を表示");
    CHAT_SYSTEM("setcrowdtime: /setcrowdtime (時刻) (分) で前回出た追従者の時刻を設定");
    CHAT_SYSTEM("showptchat: PTチャットへ追従者のログを記録 on/off");
    CHAT_SYSTEM("ncshowspawn: 出現先を別ウィンドウに出力する on/off");
    CHAT_SYSTEM("ncnoticebgm: 告知時にBGMを鳴らす on/off");
    CHAT_SYSTEM("ncnoticevoice: 告知時にボイスを鳴らす on/off");
    CHAT_SYSTEM("ncnoticese: 告知時にSEを鳴らす on/off");
end