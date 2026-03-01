-- =============================================================
-- MENU CAL — Menubar Mini Calendar for Hammerspoon
-- Shows today's date in menubar, click for monthly calendar
-- Reads holidays + tasks from Task Deck's tasks.json
-- Add to init.lua: require("menucal")
-- =============================================================

local M = {}
local menubarItem = nil
local calPopup = nil
local dismissTap = nil
local dataFile = os.getenv("HOME") .. "/.hammerspoon/tasks.json"

local function log(msg)
    print("[MenuCal] " .. tostring(msg))
end

local function loadData()
    local f = io.open(dataFile, "r")
    if not f then
        log("No tasks.json found at " .. dataFile)
        return {}
    end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return {} end
    local ok, data = pcall(hs.json.decode, content)
    if ok and data then return data end
    log("Failed to decode tasks.json")
    return {}
end

local function closePopup()
    if dismissTap then
        dismissTap:stop()
        dismissTap = nil
    end
    if calPopup then
        calPopup:delete()
        calPopup = nil
    end
end

local function buildHTML()
    local data = loadData()
    local jsonStr = hs.json.encode(data) or "{}"

    local css = [[
*{margin:0;padding:0;box-sizing:border-box;}
body{
    font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;
    background:#fff;color:#1c1c1e;font-size:13px;
    user-select:none;-webkit-user-select:none;
    overflow:hidden;
}
.header{
    display:flex;align-items:center;justify-content:space-between;
    padding:12px 16px 8px;
}
.month-title{font-size:16px;font-weight:600;color:#1c1c1e;}
.month-title .year{color:#8e8e93;font-weight:400;font-size:14px;margin-left:4px;}
.nav-btns{display:flex;gap:4px;}
.nav-btn{
    width:28px;height:28px;border-radius:6px;border:none;background:#F5F5F7;
    cursor:pointer;font-size:14px;color:#636366;display:flex;align-items:center;
    justify-content:center;transition:background .15s;
}
.nav-btn:hover{background:#E8E8ED;}
.nav-btn:active{background:#D1D1D6;}
.today-btn{
    font-size:11px;font-weight:600;color:#007AFF;padding:4px 10px;
    border-radius:6px;border:1px solid #007AFF;background:transparent;
    cursor:pointer;transition:all .15s;width:auto;
}
.today-btn:hover{background:#007AFF;color:#fff;}
.grid{
    display:grid;grid-template-columns:repeat(7,1fr);
    padding:4px 12px 8px;gap:1px;
}
.hdr{
    font-size:10px;font-weight:600;color:#aeaeb2;text-align:center;
    padding:4px 0;text-transform:uppercase;letter-spacing:.5px;
}
.day{
    text-align:center;padding:6px 2px;border-radius:8px;
    font-size:13px;position:relative;cursor:pointer;
    min-height:34px;display:flex;flex-direction:column;
    align-items:center;justify-content:center;
    transition:background .12s;
}
.day:hover{background:#F5F5F7;}
.day.empty{cursor:default;}
.day.empty:hover{background:transparent;}
.day.weekend{color:#aeaeb2;}
.day.holiday{background:#FEF2F2;color:#DC2626;font-weight:600;}
.day.holiday:hover{background:#FEE2E2;}
.day.today{
    background:#007AFF;color:#fff;font-weight:700;border-radius:50%;
    width:32px;height:32px;margin:0 auto;padding:0;
    min-height:32px;
}
.day.today:hover{background:#0066DD;}
.day.today.holiday{
    background:linear-gradient(135deg,#007AFF 50%,#DC2626 100%);
}
.day.other-month{color:#d1d1d6;}
.day.selected:not(.today){outline:2px solid #007AFF;outline-offset:-2px;border-radius:8px;}
.dot-row{
    display:flex;gap:2px;justify-content:center;
    position:absolute;bottom:2px;left:0;right:0;
}
.dot{width:4px;height:4px;border-radius:50%;}
.dot.green{background:#34C759;}
.dot.amber{background:#FF9500;}
.dot.red{background:#FF3B30;}
.dot.blue{background:#007AFF;}
.holiday-bar{
    padding:0 16px 6px;font-size:11px;color:#DC2626;font-weight:500;
    min-height:18px;
}
.footer{
    border-top:1px solid #F0F0F5;padding:8px 16px;
    display:flex;align-items:center;justify-content:space-between;
}
.footer-left{font-size:11px;color:#8e8e93;}
.footer-btn{
    font-size:11px;color:#007AFF;cursor:pointer;font-weight:500;
    padding:4px 10px;border-radius:6px;border:1px solid #E5E5EA;
    background:#fff;transition:all .15s;
}
.footer-btn:hover{background:#F5F5F7;}
.agenda{max-height:140px;overflow-y:auto;padding:2px 16px 8px;}
.agenda::-webkit-scrollbar{width:4px;}
.agenda::-webkit-scrollbar-thumb{background:#d1d1d6;border-radius:2px;}
.agenda-item{
    display:flex;align-items:center;gap:8px;padding:4px 0;
    border-bottom:1px solid #F5F5F7;font-size:11px;cursor:default;
}
.agenda-item:hover{background:#F8F8FA;}
.agenda-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;}
.agenda-title{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#1c1c1e;}
.agenda-due{color:#8e8e93;font-size:10px;white-space:nowrap;}
.agenda-section-title{font-size:10px;font-weight:600;color:#8e8e93;padding:6px 0 2px;text-transform:uppercase;letter-spacing:.5px;}
]]

    local js = [[
var data = __DATA__;
if(!data||typeof data!=='object') data={};
if(!data.tasks) data.tasks=[];
if(!data.holidays) data.holidays=[];

var MONTH_NAMES=['January','February','March','April','May','June','July','August','September','October','November','December'];
var DAY_HDRS=['Su','Mo','Tu','We','Th','Fr','Sa'];
var PRIORITY_WEIGHTS={very_low:10,low:20,medium:40,high:60,very_high:80,urgent:100};

var viewYear, viewMonth;
var selectedDate=null;
var userClickedDate=false;

function today(){var d=new Date();return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());}
function pad(n){return n<10?'0'+n:''+n;}

function normDate(s){
    if(!s)return '';s=s.trim();
    var m=s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if(m)return m[1]+'-'+pad(parseInt(m[2]))+'-'+pad(parseInt(m[3]));
    m=s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
    if(m)return m[3]+'-'+pad(parseInt(m[1]))+'-'+pad(parseInt(m[2]));
    var d=new Date(s);if(!isNaN(d.getTime()))return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
    return '';
}

data.holidays.forEach(function(h){
    if(h.startDate) h.startDate=normDate(h.startDate);
    if(h.endDate) h.endDate=normDate(h.endDate);
    if(h.date){h.startDate=normDate(h.date);if(!h.endDate)h.endDate=h.startDate;}
});

function isHoliday(ds){
    for(var i=0;i<data.holidays.length;i++){
        var h=data.holidays[i];
        var start=h.startDate||h.date||'';var end2=h.endDate||start;
        if(ds>=start&&ds<=end2)return h.name;
    }
    return null;
}

function buildDayMap(){
    var map={};
    data.tasks.forEach(function(t){
        if(t.status==='closed')return;
        if(t.finalDueDate){
            if(!map[t.finalDueDate])map[t.finalDueDate]={tasks:[],followUps:[],maxPri:0,hasHard:false};
            var dm=map[t.finalDueDate];
            dm.tasks.push(t);
            dm.maxPri=Math.max(dm.maxPri,PRIORITY_WEIGHTS[t.priority]||0);
            if(t.dueDateType==='hard')dm.hasHard=true;
        }
        if(t.nextActionDate&&t.nextActionDate!==t.finalDueDate){
            if(!map[t.nextActionDate])map[t.nextActionDate]={tasks:[],followUps:[],maxPri:0,hasHard:false};
            map[t.nextActionDate].followUps.push(t);
        }
    });
    return map;
}

function goToday(){
    var now=new Date();
    viewYear=now.getFullYear();viewMonth=now.getMonth();
    selectedDate=today();
    userClickedDate=false;
    render();
}

function navMonth(dir){
    viewMonth+=dir;
    if(viewMonth>11){viewMonth=0;viewYear++;}
    if(viewMonth<0){viewMonth=11;viewYear--;}
    render();
}

function selectDay(ds){
    selectedDate=ds;
    userClickedDate=true;
    render();
}

function openTaskDeck(){
    var dateToSend=userClickedDate?selectedDate:'';
    window.webkit.messageHandlers.menucal.postMessage({action:'openTaskDeck',date:dateToSend||''});
}

function openTaskDeckForDate(ds){
    window.webkit.messageHandlers.menucal.postMessage({action:'openTaskDeck',date:ds});
}

function render(){
    var todayStr=today();
    var dayMap=buildDayMap();
    var firstDay=new Date(viewYear,viewMonth,1).getDay();
    var daysInMonth=new Date(viewYear,viewMonth+1,0).getDate();

    document.getElementById('monthTitle').innerHTML=
        MONTH_NAMES[viewMonth]+'<span class="year">'+viewYear+'</span>';

    var html='';
    DAY_HDRS.forEach(function(h){html+='<div class="hdr">'+h+'</div>';});

    var prevDays=new Date(viewYear,viewMonth,0).getDate();
    for(var e=firstDay-1;e>=0;e--){
        var pd=prevDays-e;
        html+='<div class="day other-month" onclick="navMonth(-1)">'+pd+'</div>';
    }

    for(var day=1;day<=daysInMonth;day++){
        var ds=viewYear+'-'+pad(viewMonth+1)+'-'+pad(day);
        var dow=new Date(viewYear,viewMonth,day).getDay();
        var cls='day';
        if(dow===0||dow===6) cls+=' weekend';
        var hol=isHoliday(ds);
        if(hol) cls+=' holiday';
        if(ds===todayStr) cls+=' today';
        if(ds===selectedDate) cls+=' selected';

        var dotHtml='';
        var dm=dayMap[ds];
        if(dm){
            var dots='<div class="dot-row">';
            if(dm.tasks.length>0){
                var dotColor='green';
                if(dm.maxPri>=80||dm.hasHard) dotColor='red';
                else if(dm.maxPri>=60) dotColor='amber';
                dots+='<span class="dot '+dotColor+'"></span>';
            }
            if(dm.followUps.length>0) dots+='<span class="dot blue"></span>';
            dots+='</div>';
            dotHtml=dots;
        }

        html+='<div class="'+cls+'" onclick="selectDay(\''+ds+'\')">'+day+dotHtml+'</div>';
    }

    var totalCells=firstDay+daysInMonth;
    var remaining=(totalCells%7===0)?0:7-(totalCells%7);
    for(var n=1;n<=remaining;n++){
        html+='<div class="day other-month" onclick="navMonth(1)">'+n+'</div>';
    }

    document.getElementById('calGrid').innerHTML=html;

    var holBar='';
    if(selectedDate){
        var selHol=isHoliday(selectedDate);
        if(selHol) holBar=selHol;
    }
    if(!holBar){
        var monthHols=[];
        for(var d=1;d<=daysInMonth;d++){
            var ds2=viewYear+'-'+pad(viewMonth+1)+'-'+pad(d);
            var h2=isHoliday(ds2);
            if(h2&&monthHols.indexOf(h2)<0) monthHols.push(h2);
        }
        if(monthHols.length>0) holBar=monthHols.join(' \u00B7 ');
    }
    document.getElementById('holidayBar').innerHTML=holBar;

    renderAgenda(dayMap);

    var activeTasks=data.tasks.filter(function(t){return t.status!=='closed';});
    var overdue=activeTasks.filter(function(t){return t.finalDueDate&&t.finalDueDate<todayStr;});
    var info=activeTasks.length+' active task'+(activeTasks.length!==1?'s':'');
    if(overdue.length>0) info+=' \u00B7 <span style="color:#FF3B30;">'+overdue.length+' overdue</span>';
    document.getElementById('footerInfo').innerHTML=info;

    /* Request popup resize to fit content */
    setTimeout(function(){
        var h=document.body.scrollHeight;
        window.webkit.messageHandlers.menucal.postMessage({action:'resize',height:h});
    },20);
}

function renderAgenda(dayMap){
    var area=document.getElementById('agenda');
    if(!selectedDate){area.innerHTML='';return;}

    var dm=dayMap[selectedDate];
    if(!dm||(dm.tasks.length===0&&dm.followUps.length===0)){
        area.innerHTML='<div style="font-size:11px;color:#aeaeb2;padding:8px 0;text-align:center;">No tasks for this date</div>';
        return;
    }

    var html='';
    if(dm.tasks.length>0){
        html+='<div class="agenda-section-title">Due</div>';
        dm.tasks.forEach(function(t){
            var pri=PRIORITY_WEIGHTS[t.priority]||40;
            var dotColor=pri>=80?'#FF3B30':pri>=60?'#FF9500':pri>=40?'#FFCC00':'#34C759';
            html+='<div class="agenda-item" ondblclick="openTaskDeckForDate(\''+selectedDate+'\')">';
            html+='<span class="agenda-dot" style="background:'+dotColor+';"></span>';
            html+='<span class="agenda-title">'+(t.title||'Untitled')+'</span>';
            if(t.estDuration) html+='<span class="agenda-due">~'+t.estDuration+'</span>';
            html+='</div>';
        });
    }
    if(dm.followUps.length>0){
        html+='<div class="agenda-section-title">Follow-ups</div>';
        dm.followUps.forEach(function(t){
            html+='<div class="agenda-item" ondblclick="openTaskDeckForDate(\''+selectedDate+'\')">';
            html+='<span class="agenda-dot" style="background:#007AFF;"></span>';
            html+='<span class="agenda-title">'+(t.title||'Untitled')+'</span>';
            html+='</div>';
        });
    }
    area.innerHTML=html;
}

var now=new Date();
viewYear=now.getFullYear();viewMonth=now.getMonth();
selectedDate=today();
render();
]]

    -- Inject data safely (gsub replacement can break on % in JSON)
    local marker = "__DATA__"
    local pos = js:find(marker, 1, true)
    if pos then
        js = js:sub(1, pos - 1) .. jsonStr .. js:sub(pos + #marker)
    end

    return "<!DOCTYPE html><html><head><meta charset='UTF-8'><style>"
        .. css
        .. "</style></head><body>"
        .. '<div class="header"><div class="month-title" id="monthTitle"></div>'
        .. '<div class="nav-btns">'
        .. '<button class="today-btn" onclick="goToday()">Today</button>'
        .. '<button class="nav-btn" onclick="navMonth(-1)">&#9664;</button>'
        .. '<button class="nav-btn" onclick="navMonth(1)">&#9654;</button>'
        .. '</div></div>'
        .. '<div class="grid" id="calGrid"></div>'
        .. '<div class="holiday-bar" id="holidayBar"></div>'
        .. '<div class="agenda" id="agenda"></div>'
        .. '<div class="footer">'
        .. '<span class="footer-left" id="footerInfo"></span>'
        .. '<button class="footer-btn" onclick="openTaskDeck()">Open Task Deck</button>'
        .. '</div>'
        .. "<script>" .. js .. "</script>"
        .. "</body></html>"
end

local function getMenubarTitle()
    local d = os.date("*t")
    return tostring(d.day)
end

local function togglePopup()
    if calPopup then
        closePopup()
        return
    end

    local ok, frame = pcall(function() return menubarItem:frame() end)
    if not ok or not frame then
        log("Could not get menubar frame")
        return
    end

    local popW, popH = 300, 500
    local x = frame.x + frame.w / 2 - popW / 2
    local y = frame.y + frame.h + 4

    local screen = hs.screen.mainScreen():frame()
    if x + popW > screen.x + screen.w then x = screen.x + screen.w - popW - 8 end
    if x < screen.x then x = screen.x + 8 end

    local uc = hs.webview.usercontent.new("menucal")
    uc:setCallback(function(msg)
        local body = msg.body
        if body.action == "openTaskDeck" then
            local filterDate = body.date
            closePopup()
            hs.timer.doAfter(0.15, function()
                if filterDate and filterDate ~= "" then
                    _G._menucalFilterDate = filterDate
                end
                hs.eventtap.keyStroke({"ctrl", "alt"}, "C")
            end)
        elseif body.action == "resize" then
            if calPopup and body.height then
                local minH = 320
                local maxH = 500
                local newH = math.max(minH, math.min(maxH, body.height + 4))
                local f = calPopup:frame()
                if f and math.abs(f.h - newH) > 5 then
                    f.h = newH
                    calPopup:frame(f)
                end
            end
        end
    end)

    local htmlOk, html = pcall(buildHTML)
    if not htmlOk then
        log("buildHTML error: " .. tostring(html))
        return
    end

    calPopup = hs.webview.new(
        hs.geometry.rect(x, y, popW, popH), {}, uc
    )
        :windowStyle({"borderless"})
        :html(html)
        :allowTextEntry(true)
        :level(hs.drawing.windowLevels.popUpMenu)
        :shadow(true)
        :show()
        :bringToFront(true)

    dismissTap = hs.eventtap.new(
        {hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.keyDown},
        function(event)
            if not calPopup then return false end
            if event:getType() == hs.eventtap.event.types.keyDown then
                if event:getKeyCode() == 53 then
                    closePopup()
                    return true
                end
            else
                local pos = hs.mouse.absolutePosition()
                local ok2, pf = pcall(function() return calPopup:frame() end)
                if ok2 and pf then
                    if pos.x < pf.x or pos.x > pf.x + pf.w or pos.y < pf.y or pos.y > pf.y + pf.h then
                        closePopup()
                    end
                end
            end
            return false
        end
    ):start()
end

local midnightTimer = nil

local function secondsUntilMidnight()
    local now = os.time()
    local t = os.date("*t", now)
    -- Build tomorrow at 00:00:00
    t.hour = 0
    t.min = 0
    t.sec = 0
    t.day = t.day + 1
    local midnight = os.time(t)
    return midnight - now
end

local function scheduleMidnightUpdate()
    if midnightTimer then
        midnightTimer:stop()
        midnightTimer = nil
    end

    local secs = secondsUntilMidnight()
    -- Add 2 second buffer so we're safely into the new day
    secs = secs + 2
    log("Next title update in " .. secs .. " seconds")

    midnightTimer = hs.timer.doAfter(secs, function()
        if menubarItem then
            local newTitle = getMenubarTitle()
            menubarItem:setTitle(newTitle)
            log("Updated title to: " .. newTitle)
        end
        -- Schedule the next midnight update
        scheduleMidnightUpdate()
    end)
end

local function init()
    log("Initializing...")

    if menubarItem then
        menubarItem:delete()
        menubarItem = nil
    end

    menubarItem = hs.menubar.new()
    if not menubarItem then
        log("ERROR: hs.menubar.new() returned nil")
        return
    end

    menubarItem:setTitle(getMenubarTitle())
    menubarItem:setClickCallback(togglePopup)
    log("Menubar item created with title: " .. getMenubarTitle())

    -- Schedule automatic date update at midnight
    scheduleMidnightUpdate()

    -- Also update when system wakes from sleep (covers overnight sleep)
    M._sleepWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake then
            log("System woke from sleep, checking date...")
            hs.timer.doAfter(2, function()
                if menubarItem then
                    local newTitle = getMenubarTitle()
                    menubarItem:setTitle(newTitle)
                    log("Post-wake title: " .. newTitle)
                end
                -- Reschedule since the old timer may have fired during sleep
                scheduleMidnightUpdate()
            end)
        end
    end)
    M._sleepWatcher:start()
end

local initOk, initErr = pcall(init)
if not initOk then
    log("INIT ERROR: " .. tostring(initErr))
end

return M
