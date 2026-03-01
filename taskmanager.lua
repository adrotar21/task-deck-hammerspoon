-- =============================================================
-- TASK DECK — Hammerspoon Task Manager Module
-- Hotkey: Ctrl+Alt+C
-- Add to init.lua: require("taskmanager")
-- =============================================================

local M = {}

local taskWindow = nil
local previousWindow = nil
local dataFile = os.getenv("HOME") .. "/.hammerspoon/tasks.json"

local function loadData()
    local f = io.open(dataFile, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return nil end
    return hs.json.decode(content)
end

local function saveData(data)
    local f = io.open(dataFile, "w")
    if f then
        f:write(hs.json.encode(data, true))
        f:close()
    end
end

local function closeTaskManager()
    if taskWindow then
        -- Save window geometry
        local ok, hswin = pcall(function() return taskWindow:hswindow() end)
        if ok and hswin then
            local frame = hswin:frame()
            local currentData = loadData()
            if currentData then
                if not currentData.preferences then currentData.preferences = {} end
                currentData.preferences.windowGeometry = {
                    x = frame.x, y = frame.y, w = frame.w, h = frame.h
                }
                saveData(currentData)
            end
        end
        taskWindow:delete()
        taskWindow = nil
    end
    if previousWindow then
        hs.timer.doAfter(0.05, function()
            if previousWindow and previousWindow:application() then
                previousWindow:focus()
            end
            previousWindow = nil
        end)
    end
end

local function buildHTML(dataJson)
    return [==[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
*{margin:0;padding:0;box-sizing:border-box;}
html{background:#e8e8ed;}
body{
    font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",sans-serif;
    background:#f5f5f7;color:#1d1d1f;height:100vh;overflow:hidden;
    user-select:none;-webkit-user-select:none;font-size:13px;line-height:1.4;
    border:1px solid #c7c7cc;border-top:none;display:flex;flex-direction:column;
}

/* ═══ TOOLBAR ═══ */
.toolbar{
    display:flex;align-items:center;gap:6px;padding:8px 12px;
    background:#ffffff;border-bottom:1px solid #d2d2d7;flex-shrink:0;flex-wrap:wrap;
}
.search-wrap{position:relative;flex:1;min-width:160px;}
.toolbar-search{
    width:100%;padding:6px 28px 6px 10px;font-size:13px;border:1px solid #d2d2d7;
    border-radius:8px;background:#f5f5f7;color:#1d1d1f;outline:none;
}
.toolbar-search:focus{border-color:#007AFF;box-shadow:0 0 0 2px rgba(0,122,255,0.15);}
.toolbar-search::placeholder{color:#8e8e93;}
.search-clear{
    position:absolute;right:6px;top:50%;transform:translateY(-50%);
    width:18px;height:18px;border-radius:50%;background:#c7c7cc;color:#fff;
    font-size:12px;display:none;align-items:center;justify-content:center;
    cursor:pointer;line-height:1;
}
.search-clear.visible{display:inline-flex;}
.search-clear:hover{background:#aeaeb2;}
.tb-btn{
    padding:4px 8px;border-radius:6px;border:1px solid #d2d2d7;background:#fff;
    color:#1d1d1f;font-size:12px;cursor:pointer;white-space:nowrap;
    display:inline-flex;align-items:center;gap:3px;
}
.tb-btn:hover{background:#f0f0f5;}
.tb-btn.active{background:#007AFF;color:#fff;border-color:#007AFF;}
.sort-select{
    padding:4px 6px;border-radius:6px;border:1px solid #d2d2d7;
    background:#fff;font-size:12px;color:#1d1d1f;outline:none;cursor:pointer;
}
/* Filter pills */
.filter-bar{
    display:flex;gap:4px;padding:0 12px 6px;background:#fff;
    border-bottom:1px solid #d2d2d7;flex-shrink:0;
}
.filter-pill{
    padding:3px 10px;border-radius:12px;border:1px solid #d2d2d7;
    background:#fff;font-size:11px;cursor:pointer;color:#636366;font-weight:500;
}
.filter-pill:hover{background:#f0f0f5;}
.filter-pill.active{background:#007AFF;color:#fff;border-color:#007AFF;}
.filter-pill .count{
    display:inline-block;margin-left:3px;background:rgba(0,0,0,.08);
    padding:0 5px;border-radius:8px;font-size:10px;
}
.filter-pill.active .count{background:rgba(255,255,255,.25);}

/* ═══ CALENDAR ═══ */
.cal-section{
    border-bottom:1px solid #d2d2d7;flex-shrink:0;background:#fff;
    position:relative;overflow:hidden;
}
.cal-toolbar{
    display:flex;align-items:center;justify-content:space-between;
    padding:4px 10px;border-bottom:1px solid #e5e5ea;
}
.cal-toolbar-label{font-size:11px;color:#8e8e93;font-weight:500;}
.cal-zoom-btns{display:flex;gap:2px;}
.cal-zoom-btn{
    padding:2px 8px;border-radius:4px;border:1px solid #d2d2d7;
    background:#fff;font-size:11px;cursor:pointer;color:#636366;
}
.cal-zoom-btn:hover{background:#f0f0f5;}
.cal-zoom-btn.active{background:#007AFF;color:#fff;border-color:#007AFF;}
.cal-scroll{
    display:flex;overflow-x:auto;padding:6px 8px 8px;gap:10px;
    scrollbar-width:thin;
}
.cal-scroll::-webkit-scrollbar{height:5px;}
.cal-scroll::-webkit-scrollbar-thumb{background:#c7c7cc;border-radius:3px;}
.cal-month{flex-shrink:0;}
.cal-month-title{font-size:11px;font-weight:600;color:#1d1d1f;text-align:center;margin-bottom:3px;}
.cal-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:1px;}
.cal-hdr{font-size:9px;color:#8e8e93;text-align:center;padding:1px 0;font-weight:500;}
.cal-day{
    font-size:10px;text-align:center;padding:2px 1px;border-radius:4px;
    min-width:20px;position:relative;cursor:default;
}
.cal-day.weekend{background:#f5f5f7;color:#aeaeb2;}
.cal-day.today{background:#007AFF;color:#fff;font-weight:700;border-radius:50%;}
.cal-day.holiday{background:#FDECEA;color:#D32F2F;font-weight:600;}
.cal-day.today.holiday{background:linear-gradient(135deg,#007AFF 40%,#D32F2F 100%);color:#fff;font-weight:700;border-radius:50%;}
.cal-day.weekend.holiday{background:#FDECEA;color:#D32F2F;}
.cal-day.empty{visibility:hidden;}
.cal-day-wrap{position:relative;}
.cal-day-dots{display:flex;gap:1px;justify-content:center;margin-top:1px;min-height:4px;}
.cal-dot{width:4px;height:4px;border-radius:50%;}
.cal-dot.green{background:#34C759;}
.cal-dot.amber{background:#FF9500;}
.cal-dot.red{background:#FF3B30;}
.cal-day-count{font-size:7px;color:#8e8e93;position:absolute;top:-1px;right:0px;}
.cal-day.selected-day{outline:2px solid #007AFF;outline-offset:-1px;border-radius:4px;}
.cal-filter-banner{
    display:flex;align-items:center;gap:8px;padding:5px 12px;
    background:#E8F0FE;border-bottom:1px solid #C5D9F7;font-size:12px;
    color:#007AFF;font-weight:500;flex-shrink:0;
}
.cal-filter-banner .clear-btn{
    cursor:pointer;padding:1px 8px;border-radius:4px;background:#fff;
    border:1px solid #d2d2d7;font-size:11px;color:#636366;
}
.cal-filter-banner .clear-btn:hover{background:#f0f0f5;}
.cal-month.zoom-0{width:130px;}
.cal-month.zoom-0 .cal-day{font-size:8px;padding:1px 0;min-width:16px;}
.cal-month.zoom-0 .cal-hdr{font-size:8px;}
.cal-month.zoom-0 .cal-month-title{font-size:10px;}
.cal-month.zoom-1{width:170px;}
.cal-month.zoom-2{width:240px;}
.cal-month.zoom-2 .cal-day{font-size:12px;padding:4px 2px;min-width:30px;}
.cal-month.zoom-2 .cal-hdr{font-size:10px;}
.cal-month.zoom-2 .cal-month-title{font-size:13px;}
.cal-month.zoom-3{width:320px;}
.cal-month.zoom-3 .cal-day{font-size:13px;padding:6px 3px;min-width:40px;min-height:32px;}
.cal-month.zoom-3 .cal-hdr{font-size:11px;}
.cal-month.zoom-3 .cal-month-title{font-size:14px;font-weight:600;}

/* ═══ TABS ═══ */
.tab-bar{display:flex;gap:0;border-bottom:1px solid #d2d2d7;background:#fff;flex-shrink:0;}
.tab-btn{
    flex:1;padding:7px 0;text-align:center;font-size:13px;font-weight:500;
    cursor:pointer;border-bottom:2px solid transparent;color:#8e8e93;transition:all .12s;
}
.tab-btn:hover{color:#1d1d1f;}
.tab-btn.active{color:#007AFF;border-bottom-color:#007AFF;}

/* ═══ TASK LIST ═══ */
.task-area{flex:1;overflow-y:auto;padding:8px 10px;}
.task-area::-webkit-scrollbar{width:6px;}
.task-area::-webkit-scrollbar-thumb{background:#c7c7cc;border-radius:3px;}

.task-item{
    display:flex;align-items:flex-start;padding:8px 10px;margin-bottom:4px;
    border-radius:10px;background:#fff;border:1px solid #e5e5ea;
    box-shadow:0 .5px 2px rgba(0,0,0,.04);transition:all .12s;cursor:pointer;
    flex-wrap:wrap;
}
.task-item:hover{background:#f0f0f5;border-color:#d2d2d7;}
.task-item.selected{border-color:#007AFF;box-shadow:0 0 0 2px rgba(0,122,255,.15);}
.task-item.highlight{background:#FFFDE7;}
.task-expand-btn{
    width:16px;height:16px;font-size:10px;color:#aeaeb2;cursor:pointer;
    display:inline-flex;align-items:center;justify-content:center;
    flex-shrink:0;margin-right:4px;margin-top:2px;border-radius:3px;
}
.task-expand-btn:hover{background:#e5e5ea;color:#636366;}
.priority-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0;margin-right:8px;margin-top:4px;}
.task-main{flex:1;min-width:0;}
.task-title{font-size:13px;font-weight:500;color:#1d1d1f;}
.task-title .at-tag{color:#007AFF;font-weight:600;}
.task-title .search-hl{background:#FFD60A;border-radius:2px;padding:0 1px;}
.task-meta{font-size:11px;color:#8e8e93;margin-top:2px;display:flex;gap:8px;flex-wrap:wrap;}
.task-meta-item{display:inline-flex;align-items:center;gap:2px;}
.status-pill{display:inline-block;padding:1px 7px;border-radius:8px;font-size:10px;font-weight:600;letter-spacing:.2px;}
.status-not_started{background:#F2F2F7;color:#8E8E93;}
.status-in_progress{background:#E8F0FE;color:#007AFF;}
.status-blocked{background:#FFF3E0;color:#E65100;}
.status-done{background:#E8F5E9;color:#2E7D32;}
.status-closed{background:#ECEFF1;color:#546E7A;}
.priority-vlow{background:#C7C7CC;}
.priority-low{background:#34C759;}
.priority-medium{background:#007AFF;}
.priority-high{background:#FF9500;}
.priority-vhigh{background:#FF6B00;}
.priority-urgent{background:#FF3B30;}
.due-overdue{color:#FF3B30 !important;font-weight:600;}
.due-today{color:#FF9500 !important;font-weight:600;}
.due-tomorrow{color:#E6A700 !important;}
.due-soon{color:#A68B00 !important;}
.timer-badge{
    display:inline-flex;align-items:center;gap:3px;padding:1px 6px;
    border-radius:6px;font-size:10px;font-weight:600;background:#FFEBEE;color:#D32F2F;
}
.timer-badge.running{animation:pulse 1.5s infinite;}
@keyframes pulse{0%,100%{opacity:1;}50%{opacity:.6;}}
.subtask-container{width:100%;margin-top:4px;padding-left:24px;border-left:2px solid #e5e5ea;margin-left:12px;}
.due-badge{font-size:10px;padding:1px 5px;border-radius:4px;font-weight:500;}
.due-badge.hard{background:#FFEBEE;color:#C62828;border:1px solid #FFCDD2;}
.due-badge.suggested{background:#FFF8E1;color:#F57F17;border:1px solid #FFF9C4;}
.task-actions{display:flex;gap:3px;margin-left:6px;flex-shrink:0;align-self:flex-start;margin-top:2px;}
.task-act-btn{padding:3px 5px;border-radius:4px;font-size:11px;color:#aeaeb2;cursor:pointer;}
.task-act-btn:hover{background:#e5e5ea;color:#1d1d1f;}
.completed-header{
    display:flex;align-items:center;gap:6px;padding:8px 10px;margin-top:8px;
    border-radius:8px;background:#f5f5f7;cursor:pointer;font-size:12px;
    color:#8e8e93;font-weight:500;border:1px solid #e5e5ea;
}
.completed-header:hover{background:#e5e5ea;}
.completed-list{margin-top:4px;}
.completed-list .task-item{opacity:.7;}

/* ═══ RECURRING TABLE ═══ */
.rec-toolbar{
    display:flex;align-items:center;gap:8px;padding:6px 10px;
    background:#fff;border-bottom:1px solid #e5e5ea;flex-shrink:0;
}
.rec-table-wrap{overflow:auto;flex:1;}
.rec-table{width:100%;border-collapse:separate;border-spacing:0;font-size:12px;}
.rec-table th{
    position:sticky;top:0;background:#f5f5f7;padding:6px 8px;font-weight:600;
    text-align:left;border-bottom:2px solid #d2d2d7;font-size:11px;
    color:#636366;white-space:nowrap;z-index:2;
}
.rec-table td{
    padding:5px 8px;border-bottom:1px solid #e5e5ea;vertical-align:middle;
    white-space:nowrap;
}
.rec-table tr:hover td{background:#f9f9fb;}
.rec-status-cell{text-align:center;min-width:75px;cursor:pointer;}
.rec-status{
    display:inline-block;padding:2px 8px;border-radius:6px;font-size:10px;
    font-weight:600;cursor:pointer;
}
.rec-status.ns{background:#F2F2F7;color:#8E8E93;}
.rec-status.ip{background:#E8F0FE;color:#007AFF;}
.rec-status.dn{background:#E8F5E9;color:#2E7D32;}
.rec-week-current{background:#E8F0FE !important;}
.rec-table td input,.rec-table td select{
    border:none;background:transparent;font-size:12px;color:#1d1d1f;
    outline:none;width:100%;padding:2px 0;font-family:inherit;
}
.rec-table td input:focus,.rec-table td select:focus{
    background:#fff;border-radius:4px;box-shadow:0 0 0 2px rgba(0,122,255,.15);
    padding:2px 4px;
}
/* Column width classes */
.rec-col-task{min-width:220px;width:220px;}
.rec-col-meeting{min-width:150px;}
.rec-col-type{min-width:90px;width:90px;}
.rec-col-owner{min-width:120px;}
.rec-col-day{min-width:65px;width:65px;}
/* Resizable header */
.rec-table th{position:sticky;top:0;resize:horizontal;overflow:hidden;}
/* Week header with archive toggle */
.week-hdr{display:flex;flex-direction:column;align-items:center;gap:1px;}
.week-hdr-date{font-size:11px;}
.week-archive-btn{
    font-size:9px;color:#007AFF;cursor:pointer;padding:0 4px;
    border-radius:3px;font-weight:500;
}
.week-archive-btn:hover{background:#E8F0FE;}
.rec-add-row{
    padding:6px 10px;font-size:12px;color:#007AFF;cursor:pointer;
    display:inline-flex;align-items:center;gap:4px;margin:6px 0;
}
.rec-add-row:hover{text-decoration:underline;}

/* ═══ MODALS ═══ */
.modal-overlay{
    display:none;position:fixed;top:0;left:0;right:0;bottom:0;
    background:rgba(0,0,0,.25);z-index:100;align-items:center;justify-content:center;
}
.modal-overlay.active{display:flex;}
.modal{
    background:#fff;border-radius:14px;padding:20px;width:580px;max-height:85vh;
    overflow-y:auto;box-shadow:0 8px 32px rgba(0,0,0,.18);border:1px solid #d2d2d7;
}
.modal h2{font-size:17px;font-weight:600;margin-bottom:12px;color:#1d1d1f;}
.modal h3{font-size:13px;font-weight:600;margin:10px 0 4px;color:#1d1d1f;}
.modal-close{float:right;font-size:12px;color:#007AFF;cursor:pointer;font-weight:500;padding:2px 6px;border-radius:4px;}
.modal-close:hover{background:#E8F0FE;}
.form-row{display:flex;gap:8px;margin-bottom:8px;}
.form-group{margin-bottom:8px;}
.form-group.flex1{flex:1;}
.form-group label{display:block;font-size:11px;color:#8e8e93;margin-bottom:3px;font-weight:500;}
.form-group input,.form-group select,.form-group textarea{
    width:100%;padding:7px 10px;font-size:13px;border:1px solid #d2d2d7;
    border-radius:8px;background:#fff;color:#1d1d1f;outline:none;font-family:inherit;
}
.form-group input:focus,.form-group select:focus,.form-group textarea:focus{
    border-color:#007AFF;box-shadow:0 0 0 2px rgba(0,122,255,.15);
}
.form-group textarea{resize:vertical;min-height:50px;}
.form-group input::placeholder,.form-group textarea::placeholder{color:#c7c7cc;}
.form-buttons{display:flex;gap:8px;margin-top:12px;}
.btn{padding:7px 14px;border-radius:8px;border:none;font-size:13px;cursor:pointer;font-weight:500;}
.btn-primary{background:#007AFF;color:#fff;}
.btn-primary:hover{background:#0066d6;}
.btn-secondary{background:#e5e5ea;color:#1d1d1f;}
.btn-secondary:hover{background:#d2d2d7;}
.btn-danger{background:#FF3B30;color:#fff;}
.btn-danger:hover{background:#d63029;}
.btn-sm{padding:3px 8px;font-size:11px;}
.link-row{display:flex;gap:6px;margin-bottom:4px;align-items:center;}
.link-row input{flex:1;padding:5px 8px;font-size:12px;border:1px solid #d2d2d7;border-radius:6px;outline:none;background:#fff;color:#1d1d1f;}
.link-row input:focus{border-color:#007AFF;}
.link-remove{color:#FF3B30;cursor:pointer;font-size:16px;padding:0 4px;}
.mention-dropdown{
    position:absolute;background:#fff;border:1px solid #d2d2d7;border-radius:8px;
    box-shadow:0 4px 16px rgba(0,0,0,.12);max-height:160px;overflow-y:auto;z-index:200;min-width:180px;
}
.mention-item{padding:6px 10px;cursor:pointer;font-size:12px;}
.mention-item:hover,.mention-item.active{background:#E8F0FE;color:#007AFF;}

/* ═══ HELP ═══ */
.help-card{width:540px;max-height:500px;}
.help-card h2{margin-bottom:4px;}
.help-card .help-sub{font-size:12px;color:#8e8e93;margin-bottom:12px;line-height:1.5;}
.help-card h3{font-size:13px;font-weight:600;margin:10px 0 3px;}
.help-card p{font-size:12px;color:#48484a;line-height:1.55;margin-bottom:5px;}
.help-card kbd{
    display:inline-block;background:#f2f2f7;padding:1px 5px;border-radius:4px;
    font-family:-apple-system,sans-serif;font-size:11px;color:#636366;border:1px solid #d2d2d7;
}

/* ═══ HINT BAR ═══ */
.hint-bar{
    font-size:10px;color:#8e8e93;text-align:center;padding:4px 8px;
    border-top:1px solid #e5e5ea;flex-shrink:0;background:#fff;
    display:flex;align-items:center;justify-content:center;gap:6px;
}
.hint-bar kbd{
    display:inline-block;background:#e5e5ea;padding:0 5px;border-radius:3px;
    font-family:-apple-system,sans-serif;font-size:10px;color:#636366;border:1px solid #d2d2d7;
}
.help-btn{
    width:18px;height:18px;border-radius:50%;background:#e5e5ea;border:1px solid #d2d2d7;
    color:#8e8e93;font-size:11px;font-weight:600;display:inline-flex;align-items:center;
    justify-content:center;cursor:pointer;flex-shrink:0;
}
.help-btn:hover{background:#d2d2d7;color:#636366;}
.empty-state{text-align:center;padding:30px 20px;color:#8e8e93;}
.empty-state .icon{font-size:24px;margin-bottom:6px;}
.at-tag{color:#007AFF;font-weight:600;}
</style>
</head>
<body oncontextmenu="return false;">

<!-- ═══ TOOLBAR ═══ -->
<div class="toolbar">
    <div class="search-wrap">
        <input type="text" class="toolbar-search" id="searchBar" placeholder="Search tasks... ( / )">
        <span class="search-clear" id="searchClear" onclick="clearSearch()">&times;</span>
    </div>
    <select class="sort-select" id="sortSelect" onchange="changeSortMode(this.value)">
        <option value="smart">Smart Sort</option>
        <option value="due">Due Date</option>
        <option value="priority">Priority</option>
        <option value="updated">Recently Updated</option>
        <option value="opened">Date Opened</option>
        <option value="category">Category</option>
    </select>
    <button class="tb-btn" onclick="showTaskForm(null)" title="New task (N)">+ New</button>
    <button class="tb-btn" onclick="openContactsModal()" title="Contacts">&#128100;</button>
    <button class="tb-btn" onclick="openExportModal()" title="Export">&#8599;</button>
    <button class="tb-btn" onclick="openHolidayModal()" title="Holidays">&#128197;</button>
</div>

<!-- ═══ FILTER BAR ═══ -->
<div class="filter-bar" id="filterBar">
    <span class="filter-pill" data-filter="all" onclick="setFilter('all')">All</span>
    <span class="filter-pill" data-filter="overdue" onclick="setFilter('overdue')">Overdue <span class="count" id="countOverdue">0</span></span>
    <span class="filter-pill" data-filter="today" onclick="setFilter('today')">Due Today <span class="count" id="countToday">0</span></span>
    <span class="filter-pill" data-filter="soon" onclick="setFilter('soon')">Next 3 Days <span class="count" id="countSoon">0</span></span>
</div>

<!-- ═══ CALENDAR ═══ -->
<div class="cal-section" id="calSection">
    <div class="cal-toolbar">
        <span class="cal-toolbar-label" id="calLabel">Calendar</span>
        <div class="cal-zoom-btns">
            <span class="cal-zoom-btn" data-zoom="0" onclick="setCalZoom(0)">&#8722;</span>
            <span class="cal-zoom-btn active" data-zoom="1" onclick="setCalZoom(1)">&#9679;</span>
            <span class="cal-zoom-btn" data-zoom="2" onclick="setCalZoom(2)">+</span>
            <span class="cal-zoom-btn" data-zoom="3" onclick="setCalZoom(3)">++</span>
        </div>
    </div>
    <div class="cal-scroll" id="calScroll"></div>
</div>

<!-- ═══ CALENDAR DATE FILTER BANNER ═══ -->
<div class="cal-filter-banner" id="calFilterBanner" style="display:none;">
    <span id="calFilterLabel">Showing tasks for: </span>
    <span class="clear-btn" onclick="clearCalDateFilter()">Clear ✕</span>
</div>

<!-- ═══ TABS ═══ -->
<div class="tab-bar">
    <div class="tab-btn active" data-tab="regular" onclick="switchTab('regular')">Tasks</div>
    <div class="tab-btn" data-tab="recurring" onclick="switchTab('recurring')">Recurring</div>
</div>

<!-- ═══ TASK AREA ═══ -->
<div class="task-area" id="taskArea"></div>

<!-- ═══ HINT BAR ═══ -->
<div class="hint-bar">
    <kbd>N</kbd> new &middot; <kbd>/</kbd> search &middot; <kbd>Tab</kbd> switch tabs &middot;
    <kbd>&#8593;&#8595;</kbd> navigate &middot; <kbd>E</kbd> edit &middot; <kbd>S</kbd> timer &middot;
    <kbd>Esc</kbd> close
    <span class="help-btn" onclick="toggleHelp()" title="Help">?</span>
</div>

<!-- ═══ TASK FORM MODAL ═══ -->
<div class="modal-overlay" id="taskFormModal">
    <div class="modal" style="width:620px;" onclick="event.stopPropagation()">
        <span class="modal-close" onclick="closeTaskForm()">Cancel</span>
        <h2 id="taskFormTitle">New Task</h2>
        <div id="taskFormBody"></div>
    </div>
</div>

<!-- ═══ CONTACTS MODAL ═══ -->
<div class="modal-overlay" id="contactsModal" onclick="closeModal('contactsModal')">
    <div class="modal" onclick="event.stopPropagation()">
        <span class="modal-close" onclick="closeModal('contactsModal')">Done</span>
        <h2>Contacts</h2>
        <div id="contactsBody"></div>
    </div>
</div>

<!-- ═══ HOLIDAY MODAL ═══ -->
<div class="modal-overlay" id="holidayModal" onclick="closeModal('holidayModal')">
    <div class="modal" onclick="event.stopPropagation()">
        <span class="modal-close" onclick="closeModal('holidayModal')">Done</span>
        <h2>Manage Holidays</h2>
        <p style="font-size:12px;color:#8e8e93;margin-bottom:10px;">
            Paste tab-separated: <strong>Name &#8677; Start Date &#8677; End Date</strong> (one per line, end date optional)
        </p>
        <textarea id="holidayImportArea" rows="6" style="width:100%;padding:8px;font-size:12px;border:1px solid #d2d2d7;border-radius:8px;font-family:monospace;margin-bottom:8px;" placeholder="Memorial Day&#9;2026-05-25&#10;Thanksgiving&#9;2026-11-26&#9;2026-11-27"></textarea>
        <div class="form-buttons" style="margin-top:0;">
            <button class="btn btn-primary" onclick="importHolidays()">Import &amp; Add</button>
            <button class="btn btn-secondary" onclick="clearHolidays()">Clear All</button>
        </div>
        <div id="holidayList" style="margin-top:10px;"></div>
    </div>
</div>

<!-- ═══ EXPORT MODAL ═══ -->
<div class="modal-overlay" id="exportModal" onclick="closeModal('exportModal')">
    <div class="modal" style="width:380px;" onclick="event.stopPropagation()">
        <span class="modal-close" onclick="closeModal('exportModal')">Done</span>
        <h2>Export Data</h2>
        <div style="display:flex;flex-direction:column;gap:8px;margin-top:12px;">
            <button class="btn btn-primary" onclick="doExport('json')">Export as JSON</button>
            <button class="btn btn-secondary" onclick="doExport('csv')">Export Tasks as CSV</button>
            <button class="btn btn-secondary" onclick="doExport('csv_recurring')">Export Recurring as CSV</button>
        </div>
    </div>
</div>

<!-- ═══ HELP OVERLAY ═══ -->
<div class="modal-overlay" id="helpModal" onclick="toggleHelp()">
    <div class="modal help-card" onclick="event.stopPropagation()">
        <span class="modal-close" onclick="toggleHelp()">Done</span>
        <h2>Task Deck</h2>
        <div class="help-sub">A keyboard-driven task manager for tracking work, recurring meetings, and time.</div>
        <h3>Smart Sort</h3>
        <p>Composite score: <strong>Priority weight</strong> (Urgent=100 down to Very Low=10) + <strong>Due proximity</strong> (overdue +50, today +40, tomorrow +30, this week +15) + <strong>Hard deadline bonus</strong> (+25). A very urgent task due in 2 days outranks a small task due today.</p>
        <h3>Tasks</h3>
        <p>Press <kbd>N</kbd> to add. Click or <kbd>&#8593;&#8595;</kbd> to select. <kbd>E</kbd> to edit. <kbd>S</kbd> to start/pause timer. <kbd>&#8594;</kbd>/<kbd>&#8592;</kbd> expand/collapse sub-tasks. Tasks move to Completed when status is set to Closed.</p>
        <h3>Filters</h3>
        <p>Click <strong>Overdue</strong>, <strong>Due Today</strong>, or <strong>Next 3 Days</strong> (which includes overdue + today + upcoming) to quickly filter your active task list. Counts update automatically.</p>
        <h3>Recurring Tasks</h3>
        <p>Switch with <kbd>Tab</kbd>. Click a status cell to cycle: Not Started &rarr; In Progress &rarr; Done. Edit fields inline &mdash; columns are resizable by dragging header edges. Click <strong>Archive</strong>/<strong>Restore</strong> on any week column header. Archived weeks older than 2 weeks are automatically cleaned up. Use &#9654; Add Weeks to extend the timeline forward.</p>
        <h3>@-Mentions</h3>
        <p>Type <kbd>@</kbd> in any title or notes field to tag a contact. Most-used contacts appear first.</p>
        <h3>Timer</h3>
        <p>Press <kbd>S</kbd> on a selected task to start/pause. Timer persists across sessions. Clear multi-day timers from the edit form.</p>
        <h3>Keyboard Shortcuts</h3>
        <p>
            <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>C</kbd> Open/close &middot;
            <kbd>N</kbd> New task &middot; <kbd>E</kbd> Edit &middot; <kbd>S</kbd> Timer<br>
            <kbd>/</kbd> Search &middot; <kbd>Tab</kbd> Switch tabs &middot; <kbd>Esc</kbd> Close/back<br>
            <kbd>&#8593;</kbd><kbd>&#8595;</kbd> Navigate &middot; <kbd>&#8594;</kbd><kbd>&#8592;</kbd> Expand/collapse<br>
            <kbd>&#8984;</kbd>+<kbd>Enter</kbd> Save form &middot; <kbd>?</kbd> Help
        </p>
    </div>
</div>

<script>
/* ═══ STATE ═══ */
var data = ]==] .. dataJson .. [==[;
if(!data||typeof data!=='object') data={};
if(!data.tasks) data.tasks=[];
if(!data.recurringTasks) data.recurringTasks=[];
if(!data.contacts) data.contacts=[];
if(!data.holidays) data.holidays=[];
/* Normalize any malformed holiday dates */
data.holidays.forEach(function(h){
    if(h.startDate) h.startDate=normDate(h.startDate);
    if(h.endDate) h.endDate=normDate(h.endDate);
    if(h.date){h.startDate=normDate(h.date);if(!h.endDate)h.endDate=h.startDate;delete h.date;}
});
if(!data.categories) data.categories=['Milestones','Initiative','Jira','Misc'];
if(!data.preferences) data.preferences={};
var prefs=data.preferences;
if(!prefs.calendarZoom&&prefs.calendarZoom!==0) prefs.calendarZoom=1;
if(!prefs.sortMode) prefs.sortMode='smart';
if(!prefs.lastTab) prefs.lastTab='regular';
if(!prefs.completedExpanded) prefs.completedExpanded=false;
if(!prefs.expandedTasks) prefs.expandedTasks={};
if(!prefs.recurringArchivedWeeks) prefs.recurringArchivedWeeks=[];
if(!prefs.recurringWeeksAhead&&prefs.recurringWeeksAhead!==0) prefs.recurringWeeksAhead=6;
if(!prefs.recColWidths) prefs.recColWidths={};

var currentTab=prefs.lastTab;
var selectedTaskId=null;
var searchQuery='';
var activeFilter='all';
var calDateFilter=null; /* date string when filtering by calendar click */
var timerInterval=null;

/* ═══ UTILS ═══ */
function genId(){return 'td_'+Date.now()+'_'+Math.random().toString(36).substr(2,6);}
function today(){var d=new Date();return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate());}
function pad2(n){return n<10?'0'+n:''+n;}
function escH(s){if(!s)return '';return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function escA(s){if(!s)return '';return s.replace(/"/g,'&quot;');}
function formatTimerSecs(secs){
    if(!secs||secs<0)secs=0;
    var h=Math.floor(secs/3600),m=Math.floor((secs%3600)/60),s=Math.floor(secs%60);
    if(h>0)return h+':'+(m<10?'0':'')+m+':'+(s<10?'0':'')+s;
    return m+':'+(s<10?'0':'')+s;
}
function daysBetween(d1,d2){
    var a=new Date(d1+'T00:00:00'),b=new Date(d2+'T00:00:00');
    return Math.round((b-a)/86400000);
}
function persist(){
    data.preferences=prefs;
    window.webkit.messageHandlers.taskManager.postMessage({action:'save',data:data});
}
function openURL(url){
    if(!url)return;
    if(url.indexOf('://')<0) url='https://'+url;
    window.webkit.messageHandlers.taskManager.postMessage({action:'openurl',url:url});
}
function openAllLinks(taskId){
    var task=findTask(taskId);
    if(task&&task.links){task.links.forEach(function(l){if(l.url)openURL(l.url);});}
}

/* ═══ SEARCH ═══ */
document.getElementById('searchBar').addEventListener('input',function(){
    searchQuery=this.value.trim();
    document.getElementById('searchClear').classList.toggle('visible',searchQuery.length>0);
    renderCurrentTab();
});
function clearSearch(){
    document.getElementById('searchBar').value='';
    searchQuery='';
    document.getElementById('searchClear').classList.remove('visible');
    renderCurrentTab();
}

/* ═══ FILTERS ═══ */
function setFilter(f){
    activeFilter=f;
    document.querySelectorAll('.filter-pill').forEach(function(p){
        p.classList.toggle('active',p.dataset.filter===f);
    });
    renderCurrentTab();
}
function updateFilterCounts(){
    var todayStr=today();
    var active=data.tasks.filter(function(t){return t.status!=='closed';});
    var overdue=0,dueToday=0,soon=0;
    active.forEach(function(t){
        if(!t.finalDueDate) return;
        var diff=daysBetween(todayStr,t.finalDueDate);
        if(diff<0) {overdue++;soon++;}
        else if(diff===0){dueToday++;soon++;}
        else if(diff<=3) soon++;
    });
    document.getElementById('countOverdue').textContent=overdue;
    document.getElementById('countToday').textContent=dueToday;
    document.getElementById('countSoon').textContent=soon;
}

/* ═══ CALENDAR ═══ */
var MONTH_NAMES=['January','February','March','April','May','June','July','August','September','October','November','December'];
var DAY_HDRS=['S','M','T','W','T','F','S'];

function setCalZoom(z){
    prefs.calendarZoom=z;persist();
    document.querySelectorAll('.cal-zoom-btn').forEach(function(b){
        b.classList.toggle('active',parseInt(b.dataset.zoom)===z);
    });
    renderCalendar();
}
function filterByCalDate(ds){
    if(calDateFilter===ds){clearCalDateFilter();return;} /* toggle off if same day */
    calDateFilter=ds;
    /* Format date nicely */
    var parts=ds.split('-');
    var d=new Date(parseInt(parts[0]),parseInt(parts[1])-1,parseInt(parts[2]));
    var label=d.toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric',year:'numeric'});
    var hol=isHoliday(ds);
    if(hol) label+=' — 🏖 '+hol;
    var banner=document.getElementById('calFilterBanner');
    document.getElementById('calFilterLabel').textContent='📅 Showing tasks for: '+label;
    banner.style.display='flex';
    /* Switch to regular tasks tab */
    if(currentTab!=='regular'){switchTab('regular');}
    renderCalendar();
    renderRegularTasks();
}
function clearCalDateFilter(){
    calDateFilter=null;
    document.getElementById('calFilterBanner').style.display='none';
    renderCalendar();
    renderRegularTasks();
}
function isHoliday(dateStr){
    for(var i=0;i<data.holidays.length;i++){
        var h=data.holidays[i];
        var start=h.startDate||h.date;var end=h.endDate||start;
        if(dateStr>=start&&dateStr<=end)return h.name;
    }
    return null;
}
function renderCalendar(){
    var now=new Date();
    var curYear=now.getFullYear(),curMonth=now.getMonth();
    var todayStr=today();var z=prefs.calendarZoom;
    var startOffset=now.getDate()<=7?-1:0;
    var totalMonths=z===0?18:z===1?12:z===2?8:4;

    /* Build task-per-day map */
    var dayMap={}; /* dateStr -> {count, maxPri, hasHard, totalMins, followUps} */
    data.tasks.forEach(function(t){
        if(t.status==='closed')return;
        if(t.finalDueDate){
            if(!dayMap[t.finalDueDate]) dayMap[t.finalDueDate]={count:0,maxPri:0,hasHard:false,totalMins:0,titles:[],followUps:[]};
            var dm=dayMap[t.finalDueDate];
            dm.count++;dm.titles.push(t.title||'');
            dm.maxPri=Math.max(dm.maxPri,PRIORITY_WEIGHTS[t.priority]||0);
            if(t.dueDateType==='hard') dm.hasHard=true;
            var dur={'5m':5,'10m':10,'15m':15,'20m':20,'30m':30,'45m':45,'1h':60,'1.5h':90,'2h':120,'3h':180,'5h':300,'8h':480,'13h':780};
            dm.totalMins+=(dur[t.estDuration]||0);
        }
        if(t.nextActionDate&&t.nextActionDate!==t.finalDueDate){
            if(!dayMap[t.nextActionDate]) dayMap[t.nextActionDate]={count:0,maxPri:0,hasHard:false,totalMins:0,titles:[],followUps:[]};
            dayMap[t.nextActionDate].followUps.push(t.title||'');
        }
    });

    var html='';
    for(var mo=startOffset-2;mo<totalMonths+startOffset-2;mo++){
        var d=new Date(curYear,curMonth+mo,1);
        var y=d.getFullYear(),m=d.getMonth();
        var firstDay=d.getDay();
        var daysInMonth=new Date(y,m+1,0).getDate();
        html+='<div class="cal-month zoom-'+z+'">';
        html+='<div class="cal-month-title">'+MONTH_NAMES[m]+' '+y+'</div>';
        html+='<div class="cal-grid">';
        DAY_HDRS.forEach(function(h){html+='<div class="cal-hdr">'+h+'</div>';});
        for(var e=0;e<firstDay;e++) html+='<div class="cal-day empty"></div>';
        for(var day=1;day<=daysInMonth;day++){
            var ds=y+'-'+(m+1<10?'0':'')+(m+1)+'-'+(day<10?'0':'')+day;
            var dow=new Date(y,m,day).getDay();
            var cls='cal-day';
            if(dow===0||dow===6) cls+=' weekend';
            var hol=isHoliday(ds);
            if(hol) cls+=' holiday';
            if(ds===todayStr) cls+=' today';

            var dm=dayMap[ds];

            /* Urgency dot color */
            var dotHtml='';
            var hasContent=(dm&&dm.count>0);
            var hasFollowUp=(dm&&dm.followUps&&dm.followUps.length>0);
            if(hasContent){
                var dotColor='green';
                if(dm.maxPri>=80||dm.hasHard) dotColor='red';
                else if(dm.maxPri>=60||dm.totalMins>=120) dotColor='amber';
                dotHtml='<div class="cal-day-dots"><span class="cal-dot '+dotColor+'"></span></div>';
                if(z>=1&&dm.count>1) dotHtml='<span class="cal-day-count">'+dm.count+'</span>'+dotHtml;
            }
            if(!hasContent&&hasFollowUp){
                dotHtml='<div class="cal-day-dots"><span class="cal-dot" style="background:#007AFF;width:4px;height:4px;"></span></div>';
            }

            var selCls=(calDateFilter===ds)?' selected-day':'';
            var clickable=(hasContent||hasFollowUp||hol)?' onclick="filterByCalDate(\''+ds+'\')" style="cursor:pointer;"':'';
            html+='<div class="'+cls+selCls+'"'+clickable+'>'+day+dotHtml+'</div>';
        }
        html+='</div></div>';
    }
    document.getElementById('calScroll').innerHTML=html;
    var container=document.getElementById('calScroll');
    var widths={0:140,1:180,2:250,3:330};
    container.scrollLeft=Math.max(0,(2-startOffset)*widths[z]-20);
}

/* ═══ SMART SORT ═══ */
var PRIORITY_WEIGHTS={very_low:10,low:20,medium:40,high:60,very_high:80,urgent:100};
var PRIORITY_LABELS={very_low:'Very Low',low:'Low',medium:'Medium',high:'High',very_high:'Very High',urgent:'Urgent'};
var PRIORITY_CLASSES={very_low:'vlow',low:'low',medium:'medium',high:'high',very_high:'vhigh',urgent:'urgent'};
var STATUS_LABELS={not_started:'Not Started',in_progress:'In Progress',blocked:'Blocked',done:'Done',closed:'Closed'};
var DURATIONS=['5m','10m','15m','20m','30m','45m','1h','1.5h','2h','3h','5h','8h','13h','multi'];

function getSmartScore(task){
    var score=PRIORITY_WEIGHTS[task.priority]||40;
    var todayStr=today();
    if(task.finalDueDate){
        var diff=daysBetween(todayStr,task.finalDueDate);
        if(diff<0)score+=50;else if(diff===0)score+=40;else if(diff===1)score+=30;
        else if(diff<=3)score+=20;else if(diff<=7)score+=15;else if(diff<=14)score+=5;
        if(task.dueDateType==='hard')score+=25;
    }
    if(task.nextActionDate){
        var nad=daysBetween(todayStr,task.nextActionDate);
        if(nad<=0)score+=10;else if(nad<=2)score+=5;
    }
    return score;
}

function sortTasks(tasks,mode){
    var t=tasks.slice();var todayStr=today();
    switch(mode){
        case 'smart':t.sort(function(a,b){return getSmartScore(b)-getSmartScore(a);});break;
        case 'due':t.sort(function(a,b){var da=a.finalDueDate||'9999-12-31',db=b.finalDueDate||'9999-12-31';if(da!==db)return da<db?-1:1;return(PRIORITY_WEIGHTS[b.priority]||0)-(PRIORITY_WEIGHTS[a.priority]||0);});break;
        case 'priority':t.sort(function(a,b){var d=(PRIORITY_WEIGHTS[b.priority]||0)-(PRIORITY_WEIGHTS[a.priority]||0);if(d!==0)return d;var da=a.finalDueDate||'9999-12-31',db=b.finalDueDate||'9999-12-31';return da<db?-1:da>db?1:0;});break;
        case 'updated':t.sort(function(a,b){return(b.lastUpdated||'')>(a.lastUpdated||'')?1:-1;});break;
        case 'opened':t.sort(function(a,b){return(b.dateOpened||'')>(a.dateOpened||'')?1:-1;});break;
        case 'category':t.sort(function(a,b){var ca=(a.category||'zzz').toLowerCase(),cb=(b.category||'zzz').toLowerCase();if(ca!==cb)return ca<cb?-1:1;return getSmartScore(b)-getSmartScore(a);});break;
    }
    return t;
}

/* ═══ RENDER TASKS ═══ */
function getDueDateClass(dateStr){
    if(!dateStr)return '';
    var diff=daysBetween(today(),dateStr);
    if(diff<0)return 'due-overdue';if(diff===0)return 'due-today';
    if(diff===1)return 'due-tomorrow';if(diff<=3)return 'due-soon';return '';
}
function highlightSearch(text){
    if(!searchQuery||!text)return escH(text);
    var esc=escH(text);var q=searchQuery.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    return esc.replace(new RegExp('('+q+')','gi'),'<span class="search-hl">$1</span>');
}
function renderAtTags(text){
    if(!text)return '';
    /* Build sorted contact names longest-first to match greedily */
    var names=data.contacts.map(function(c){return c.name;}).sort(function(a,b){return b.length-a.length;});
    var result=text;
    names.forEach(function(name){
        var escaped=name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
        result=result.replace(new RegExp('@'+escaped+'(?![\\w])','g'),'<span class="at-tag">@'+name+'</span>');
    });
    return result;
}

function renderTaskItem(task,depth){
    depth=depth||0;
    var isExpanded=prefs.expandedTasks[task.id];
    var hasChildren=task.subtasks&&task.subtasks.length>0;
    var isSelected=selectedTaskId===task.id;
    var cls='task-item'+(isSelected?' selected':'');
    if(searchQuery&&(task.title||'').toLowerCase().indexOf(searchQuery.toLowerCase())>=0)cls+=' highlight';
    var pc=PRIORITY_CLASSES[task.priority]||'medium';
    var titleHtml=renderAtTags(highlightSearch(task.title||'Untitled'));
    var statusHtml='<span class="status-pill status-'+(task.status||'not_started')+'">'+STATUS_LABELS[task.status||'not_started']+'</span>';
    var dueHtml='';
    if(task.finalDueDate){
        var dueCls=getDueDateClass(task.finalDueDate);
        var badgeCls=task.dueDateType==='hard'?'hard':'suggested';
        dueHtml='<span class="task-meta-item"><span class="due-badge '+badgeCls+' '+dueCls+'">'+(task.dueDateType==='hard'?'&#128308;':'&#128993;')+' '+task.finalDueDate+'</span></span>';
    }
    var timerHtml='';
    var totalSecs=(task.timerAccumulated||0);
    if(task.timerStart)totalSecs+=Math.floor((Date.now()-task.timerStart)/1000);
    if(task.timerStart||totalSecs>0){
        timerHtml='<span class="timer-badge '+(task.timerStart?'running':'')+'" data-timer-id="'+task.id+'">'+(task.timerStart?'&#9654;':'&#9646;')+' '+formatTimerSecs(totalSecs)+'</span>';
    }
    var catHtml=task.category?'<span class="task-meta-item" style="color:#636366;">'+escH(task.category)+'</span>':'';
    var estHtml=task.estDuration?'<span class="task-meta-item">~'+task.estDuration+'</span>':'';
    var linksInline='';
    if(task.links&&task.links.length>0){
        task.links.forEach(function(lnk){
            if(lnk.url){
                var label=escH(lnk.label||lnk.url.replace(/^https?:\/\/(www\.)?/,'').substring(0,30));
                linksInline+='<span class="task-meta-item" style="cursor:pointer;color:#007AFF;" onclick="event.stopPropagation();openURL(\''+escA(lnk.url.replace(/'/g,"\\'"))+'\')">&#128279; '+label+'</span>';
            }
        });
    }
    var html='<div class="'+cls+'" data-id="'+task.id+'" onclick="selectTask(\''+task.id+'\')" ondblclick="showTaskForm(\''+task.id+'\')">';
    if(hasChildren){
        html+='<span class="task-expand-btn" onclick="event.stopPropagation();toggleExpand(\''+task.id+'\')">'+(isExpanded?'&#9660;':'&#9654;')+'</span>';
    }else if(depth>0){
        html+='<span style="width:16px;display:inline-block;flex-shrink:0;margin-right:4px;"></span>';
    }
    html+='<span class="priority-dot priority-'+pc+'"></span>';
    html+='<div class="task-main"><div class="task-title">'+titleHtml+'</div>';
    html+='<div class="task-meta">'+statusHtml+dueHtml+catHtml+estHtml+timerHtml+linksInline+'</div></div>';
    html+='<div class="task-actions">';
    html+='<span class="task-act-btn" onclick="event.stopPropagation();showTaskForm(\''+task.id+'\')" title="Edit">&#9998;</span>';
    html+='<span class="task-act-btn" onclick="event.stopPropagation();toggleTimer(\''+task.id+'\')" title="Timer">'+(task.timerStart?'&#9646;':'&#9654;')+'</span>';
    html+='</div></div>';
    if(hasChildren&&isExpanded){
        html+='<div class="subtask-container">';
        task.subtasks.forEach(function(st){html+=renderTaskItem(st,depth+1);});
        html+='</div>';
    }
    return html;
}

function applyFilter(tasks){
    if(activeFilter==='all')return tasks;
    var todayStr=today();
    return tasks.filter(function(t){
        if(!t.finalDueDate)return false;
        var diff=daysBetween(todayStr,t.finalDueDate);
        if(activeFilter==='overdue')return diff<0;
        if(activeFilter==='today')return diff===0;
        if(activeFilter==='soon')return diff<=3; /* includes overdue+today+next3 */
        return true;
    });
}

function renderRegularTasks(){
    var area=document.getElementById('taskArea');
    var active=data.tasks.filter(function(t){return t.status!=='closed';});
    var closed=data.tasks.filter(function(t){return t.status==='closed';});
    /* Calendar date filter */
    if(calDateFilter){
        function matchesDate(t){
            if(t.finalDueDate===calDateFilter||t.nextActionDate===calDateFilter)return true;
            if(t.subtasks)return t.subtasks.some(matchesDate);
            return false;
        }
        active=active.filter(matchesDate);
        closed=closed.filter(matchesDate);
    }
    if(searchQuery){
        var q=searchQuery.toLowerCase();
        function matchesSearch(t){
            if((t.title||'').toLowerCase().indexOf(q)>=0)return true;
            if((t.notes||'').toLowerCase().indexOf(q)>=0)return true;
            if((t.category||'').toLowerCase().indexOf(q)>=0)return true;
            if(t.subtasks)return t.subtasks.some(matchesSearch);
            return false;
        }
        active=active.filter(matchesSearch);
        closed=closed.filter(matchesSearch);
    }
    if(!calDateFilter) active=applyFilter(active);
    active=sortTasks(active,prefs.sortMode);
    var html='';
    if(active.length===0&&closed.length===0&&!searchQuery&&activeFilter==='all'&&!calDateFilter){
        html='<div class="empty-state"><div class="icon">&#128203;</div>No tasks yet. Press <kbd>N</kbd> to add your first task.</div>';
    }else{
        if(active.length===0) html='<div class="empty-state" style="padding:20px;">No matching tasks</div>';
        active.forEach(function(t){html+=renderTaskItem(t,0);});
        if(closed.length>0&&(activeFilter==='all'||calDateFilter)){
            html+='<div class="completed-header" onclick="toggleCompleted()">'+(prefs.completedExpanded?'&#9660;':'&#9654;')+' Completed ('+closed.length+')</div>';
            if(prefs.completedExpanded){
                html+='<div class="completed-list">';
                closed.forEach(function(t){html+=renderTaskItem(t,0);});
                html+='</div>';
            }
        }
    }
    area.innerHTML=html;
    if(!calDateFilter) updateFilterCounts();
}

/* ═══ RECURRING TASKS ═══ */
function getRecurringWeeks(){
    var weeksAhead=prefs.recurringWeeksAhead||6;
    var weeks=[];
    var d=new Date();d.setDate(d.getDate()-d.getDay()+1); // this Monday
    d.setDate(d.getDate()-14); // start 2 weeks ago
    var totalWeeks=2+weeksAhead; // 2 past + N future
    for(var i=0;i<totalWeeks;i++){
        weeks.push(d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate()));
        d.setDate(d.getDate()+7);
    }
    return weeks;
}

function pruneOldArchived(){
    /* No longer auto-deletes — user manages via Hidden Weeks panel */
}

function toggleWeekArchive(week){
    var idx=prefs.recurringArchivedWeeks.indexOf(week);
    if(idx>=0) prefs.recurringArchivedWeeks.splice(idx,1);
    else prefs.recurringArchivedWeeks.push(week);
    persist();renderRecurringTasks();
}

function addFutureWeeks(){
    prefs.recurringWeeksAhead=(prefs.recurringWeeksAhead||6)+4;
    persist();renderRecurringTasks();
}

function cycleRecStatus(taskId,week){
    var task=data.recurringTasks.find(function(t){return t.id===taskId;});
    if(!task)return;
    if(!task.weekStatuses)task.weekStatuses={};
    var cur=task.weekStatuses[week]||'ns';
    var next=cur==='ns'?'ip':cur==='ip'?'dn':'ns';
    task.weekStatuses[week]=next;
    persist();renderRecurringTasks();
}

function renderRecurringTasks(){
    pruneOldArchived();
    var area=document.getElementById('taskArea');
    var weeks=getRecurringWeeks();
    var archived=prefs.recurringArchivedWeeks||[];
    var visibleWeeks=weeks.filter(function(w){return archived.indexOf(w)<0;});
    var archivedWeeks=weeks.filter(function(w){return archived.indexOf(w)>=0;});
    /* Also include archived weeks not in current range (from data) */
    archived.forEach(function(w){if(archivedWeeks.indexOf(w)<0)archivedWeeks.push(w);});
    archivedWeeks.sort();

    var html='<div class="rec-table-wrap"><table class="rec-table"><thead><tr>';
    html+='<th style="min-width:30px;width:30px;">#</th>';
    html+='<th class="rec-col-task">Task</th>';
    html+='<th class="rec-col-meeting">Meeting</th>';
    html+='<th class="rec-col-type">Type</th>';
    html+='<th class="rec-col-owner">Owner</th>';
    html+='<th class="rec-col-day">Day</th>';

    visibleWeeks.forEach(function(w){
        var label=w.substring(5);
        var nowMonday=new Date();nowMonday.setDate(nowMonday.getDate()-nowMonday.getDay()+1);nowMonday.setHours(0,0,0,0);
        var nowMondayStr=nowMonday.getFullYear()+'-'+pad2(nowMonday.getMonth()+1)+'-'+pad2(nowMonday.getDate());
        var isThisWeek=(w===nowMondayStr);
        html+='<th class="rec-status-cell'+(isThisWeek?' rec-week-current':'')+'" style="min-width:80px;">';
        html+='<div style="display:flex;flex-direction:column;align-items:center;gap:1px;">';
        html+='<span class="week-hdr-date">'+label+'</span>';
        html+='<span style="font-size:9px;color:#8e8e93;cursor:pointer;opacity:0.7;" onmouseover="this.style.opacity=1;this.style.color=\'#007AFF\';" onmouseout="this.style.opacity=0.7;this.style.color=\'#8e8e93\';" onclick="event.stopPropagation();toggleWeekArchive(\''+w+'\')">archive</span>';
        html+='</div></th>';
    });

    html+='<th style="min-width:50px;"></th></tr></thead><tbody>';

    var sorted=data.recurringTasks.slice().sort(function(a,b){
        if((a.dayNumber||1)!==(b.dayNumber||1))return(a.dayNumber||1)-(b.dayNumber||1);
        return(a.name||'').localeCompare(b.name||'');
    });

    sorted.forEach(function(task,idx){
        html+='<tr data-rec-id="'+task.id+'">';
        html+='<td style="color:#aeaeb2;font-size:11px;">'+(idx+1)+'</td>';
        html+='<td class="rec-col-task"><input value="'+escA(task.name)+'" onchange="updateRecField(\''+task.id+'\',\'name\',this.value)"></td>';
        html+='<td class="rec-col-meeting"><input value="'+escA(task.meeting||'')+'" onchange="updateRecField(\''+task.id+'\',\'meeting\',this.value)"></td>';
        html+='<td class="rec-col-type"><select onchange="updateRecField(\''+task.id+'\',\'type\',this.value)">';
        ['Prepare','Hold','Postpare','Reporting'].forEach(function(opt){
            html+='<option'+(task.type===opt?' selected':'')+'>'+opt+'</option>';
        });
        html+='</select></td>';
        html+='<td class="rec-col-owner"><input value="'+escA(task.owner||'')+'" onchange="updateRecField(\''+task.id+'\',\'owner\',this.value)"></td>';
        html+='<td class="rec-col-day"><select onchange="updateRecDayField(\''+task.id+'\',this.value)">';
        ['Monday','Tuesday','Wednesday','Thursday','Friday'].forEach(function(d,di){
            html+='<option value="'+(di+1)+'"'+((task.dayNumber||1)===(di+1)?' selected':'')+'>'+d.substring(0,3)+'</option>';
        });
        html+='</select></td>';

        visibleWeeks.forEach(function(w){
            var st=(task.weekStatuses||{})[w]||'ns';
            var label=st==='ns'?'Not Started':st==='ip'?'In Progress':'Done';
            html+='<td class="rec-status-cell" onclick="cycleRecStatus(\''+task.id+'\',\''+w+'\')">';
            html+='<span class="rec-status '+st+'">'+label+'</span></td>';
        });

        html+='<td>';
        html+='<span class="task-act-btn" onclick="duplicateRecTask(\''+task.id+'\')" title="Duplicate">&#9776;</span>';
        html+='<span class="task-act-btn" onclick="deleteRecTask(\''+task.id+'\')" title="Delete" style="color:#FF3B30;">&#10005;</span>';
        html+='</td></tr>';
    });

    html+='</tbody></table></div>';
    html+='<div style="padding:6px 10px;display:flex;gap:12px;align-items:center;">';
    html+='<span class="rec-add-row" onclick="addRecurringTask()">+ Add recurring task</span>';
    html+='<span class="rec-add-row" style="color:#636366;" onclick="addFutureWeeks()">&#9654; Add Weeks</span>';
    html+='</div>';

    /* ═══ ARCHIVED WEEKS DRAWER ═══ */
    if(archivedWeeks.length>0){
        var drawerOpen=prefs._archiveDrawerOpen||false;
        html+='<div style="margin:8px 10px;">';
        html+='<div onclick="prefs._archiveDrawerOpen=!prefs._archiveDrawerOpen;renderRecurringTasks();" style="cursor:pointer;display:flex;align-items:center;gap:6px;padding:6px 10px;background:#F5F5F7;border-radius:8px;border:1px solid #e5e5ea;user-select:none;">';
        html+='<span style="font-size:11px;color:#636366;transition:transform .2s;transform:rotate('+(drawerOpen?'90':'0')+'deg);">▶</span>';
        html+='<span style="font-size:12px;font-weight:600;color:#636366;">Archived Weeks</span>';
        html+='<span style="font-size:11px;color:#aeaeb2;background:#e5e5ea;border-radius:10px;padding:0 6px;">'+archivedWeeks.length+'</span>';
        html+='</div>';
        if(drawerOpen){
            html+='<div style="margin-top:4px;padding:8px 10px;background:#FAFAFA;border-radius:0 0 8px 8px;border:1px solid #e5e5ea;border-top:none;">';
            html+='<table style="width:100%;font-size:12px;border-collapse:collapse;">';
            archivedWeeks.forEach(function(w){
                var d=new Date(w+'T00:00:00');
                var endD=new Date(d);endD.setDate(endD.getDate()+4);
                var label=d.toLocaleDateString('en-US',{month:'short',day:'numeric'})+' – '+endD.toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'});
                /* Count how many statuses have data */
                var statusCount=0;var doneCount=0;
                data.recurringTasks.forEach(function(task){
                    if(task.weekStatuses&&task.weekStatuses[w]){statusCount++;if(task.weekStatuses[w]==='dn')doneCount++;}
                });
                html+='<tr style="border-bottom:1px solid #f0f0f5;">';
                html+='<td style="padding:5px 4px;color:#1c1c1e;font-weight:500;">'+label+'</td>';
                html+='<td style="padding:5px 4px;color:#aeaeb2;font-size:11px;">'+doneCount+'/'+data.recurringTasks.length+' done</td>';
                html+='<td style="padding:5px 4px;text-align:right;white-space:nowrap;">';
                html+='<span style="color:#007AFF;cursor:pointer;font-size:11px;font-weight:500;padding:2px 8px;" onclick="toggleWeekArchive(\''+w+'\')">Restore</span>';
                html+='<span style="color:#FF3B30;cursor:pointer;font-size:11px;padding:2px 8px;" onclick="if(confirm(\'Permanently delete week '+w+'? This removes all status data.\'))permanentDeleteWeek(\''+w+'\')">Delete</span>';
                html+='</td></tr>';
            });
            html+='</table>';
            if(archivedWeeks.length>1){
                html+='<div style="margin-top:6px;padding-top:6px;border-top:1px solid #e5e5ea;display:flex;gap:12px;">';
                html+='<span style="font-size:11px;color:#007AFF;cursor:pointer;font-weight:500;" onclick="restoreAllWeeks()">Restore All</span>';
                html+='<span style="font-size:11px;color:#FF3B30;cursor:pointer;" onclick="if(confirm(\'Permanently delete all '+archivedWeeks.length+' archived weeks?\'))deleteAllArchivedWeeks()">Delete All Archived</span>';
                html+='</div>';
            }
            html+='</div>';
        }
        html+='</div>';
    }
    area.innerHTML=html;
}

function addRecurringTask(){
    data.recurringTasks.push({id:genId(),name:'New Task',meeting:'',type:'Hold',owner:'',dayOfWeek:'Monday',dayNumber:1,links:[],weekStatuses:{}});
    persist();renderRecurringTasks();
}
function updateRecField(id,field,val){
    var t=data.recurringTasks.find(function(t){return t.id===id;});
    if(t){t[field]=val;persist();}
}
function updateRecDayField(id,val){
    var t=data.recurringTasks.find(function(t){return t.id===id;});
    if(t){t.dayNumber=parseInt(val);t.dayOfWeek=['','Monday','Tuesday','Wednesday','Thursday','Friday'][t.dayNumber]||'Monday';persist();renderRecurringTasks();}
}
function duplicateRecTask(id){
    var t=data.recurringTasks.find(function(t){return t.id===id;});
    if(!t)return;
    var dup=JSON.parse(JSON.stringify(t));
    dup.id=genId();dup.name=t.name+' (copy)';dup.weekStatuses={};
    data.recurringTasks.push(dup);persist();renderRecurringTasks();
}
function deleteRecTask(id){
    data.recurringTasks=data.recurringTasks.filter(function(t){return t.id!==id;});
    persist();renderRecurringTasks();
}
function permanentDeleteWeek(week){
    /* Remove from archived list */
    prefs.recurringArchivedWeeks=prefs.recurringArchivedWeeks.filter(function(w){return w!==week;});
    /* Remove all status data for this week */
    data.recurringTasks.forEach(function(task){
        if(task.weekStatuses) delete task.weekStatuses[week];
    });
    persist();renderRecurringTasks();
}
function restoreAllWeeks(){
    prefs.recurringArchivedWeeks=[];
    persist();renderRecurringTasks();
}
function deleteAllArchivedWeeks(){
    var toDelete=prefs.recurringArchivedWeeks.slice();
    prefs.recurringArchivedWeeks=[];
    toDelete.forEach(function(week){
        data.recurringTasks.forEach(function(task){
            if(task.weekStatuses) delete task.weekStatuses[week];
        });
    });
    persist();renderRecurringTasks();
}

/* ═══ TASK FORM ═══ */
var editingTaskId=null;var editingParentId=null;
function findTask(id,list){
    if(!list)list=data.tasks;
    for(var i=0;i<list.length;i++){
        if(list[i].id===id)return list[i];
        if(list[i].subtasks){var found=findTask(id,list[i].subtasks);if(found)return found;}
    }
    return null;
}

function showTaskForm(taskId,parentId){
    editingTaskId=taskId;editingParentId=parentId||null;
    var task=taskId?findTask(taskId):null;var isNew=!task;
    document.getElementById('taskFormTitle').textContent=isNew?(parentId?'New Sub-Task':'New Task'):'Edit Task';
    var t=task||{id:'',title:'',priority:'medium',category:'',
        status:'not_started',estDuration:'30m',actualDuration:0,timerStart:null,timerAccumulated:0,
        dateOpened:today(),lastUpdated:today(),nextActionDate:'',finalDueDate:'',dueDateType:'suggested',
        notes:'',links:[],subtasks:[]};
    /* Sort categories by usage count (most-used first) */
    var catUsage={};data.tasks.forEach(function(tk){if(tk.category)catUsage[tk.category]=(catUsage[tk.category]||0)+1;});
    var sortedCats=data.categories.slice().sort(function(a,b){return(catUsage[b]||0)-(catUsage[a]||0);});
    var catOpts=(isNew?'<option value="">— Select —</option>':'')+sortedCats.map(function(c){return '<option'+(t.category===c?' selected':'')+'>'+escH(c)+'</option>';}).join('');
    var priOpts=Object.keys(PRIORITY_LABELS).map(function(k){return '<option value="'+k+'"'+(t.priority===k?' selected':'')+'>'+PRIORITY_LABELS[k]+'</option>';}).join('');
    var statOpts=Object.keys(STATUS_LABELS).map(function(k){return '<option value="'+k+'"'+(t.status===k?' selected':'')+'>'+STATUS_LABELS[k]+'</option>';}).join('');
    var durOpts=DURATIONS.map(function(d){return '<option value="'+d+'"'+(t.estDuration===d?' selected':'')+'>'+d+'</option>';}).join('');
    var linksHtml='';
    (t.links||[]).forEach(function(lnk,i){
        linksHtml+='<div class="link-row" id="linkRow'+i+'">';
        linksHtml+='<input placeholder="Label" value="'+escA(lnk.label||'')+'">';
        linksHtml+='<input placeholder="URL" value="'+escA(lnk.url||'')+'">';
        if(lnk.url) linksHtml+='<span style="color:#007AFF;cursor:pointer;font-size:11px;font-weight:500;padding:2px 6px;white-space:nowrap;" onclick="openURL(\''+escA(lnk.url.replace(/'/g,"\\'"))+'\')">Open ↗</span>';
        linksHtml+='<span class="link-remove" onclick="removeFormLink('+i+')">&#215;</span></div>';
    });
    var openAllBtn='';
    if(t.links&&t.links.length>1){
        openAllBtn='<span style="font-size:12px;color:#007AFF;cursor:pointer;margin-left:12px;" onclick="openAllLinks(\''+t.id+'\')">Open All ↗</span>';
    }
    var timerHtml='';
    if(!isNew){
        var totalSecs=(t.timerAccumulated||0);
        if(t.timerStart)totalSecs+=Math.floor((Date.now()-t.timerStart)/1000);
        timerHtml='<div class="form-row"><div class="form-group flex1"><label>Actual Time</label><div style="display:flex;align-items:center;gap:8px;"><span style="font-size:14px;font-weight:600;">'+formatTimerSecs(totalSecs)+'</span><button class="btn btn-sm btn-secondary" onclick="clearTaskTimer()">Clear Timer</button></div></div></div>';
    }
    var html=
        '<div class="form-row"><div class="form-group" style="flex:3;"><label>Title</label><input type="text" id="tf_title" value="'+escA(t.title)+'" placeholder="Task title..."></div><div class="form-group" style="flex:1;"><label>Category</label><select id="tf_category">'+catOpts+'</select></div></div>'+
        '<div class="form-row"><div class="form-group flex1"><label>Priority</label><select id="tf_priority">'+priOpts+'</select></div><div class="form-group flex1"><label>Status</label><select id="tf_status">'+statOpts+'</select></div><div class="form-group flex1"><label>Est. Duration</label><select id="tf_est">'+durOpts+'</select></div></div>'+
        '<div class="form-row"><div class="form-group flex1"><label>Date Opened</label><input type="date" id="tf_opened" value="'+(t.dateOpened||today())+'"></div><div class="form-group flex1"><label>Next Action</label><input type="date" id="tf_nextAction" value="'+(t.nextActionDate||'')+'"></div></div>'+
        '<div class="form-row"><div class="form-group flex1"><label>Final Due Date</label><input type="date" id="tf_dueDate" value="'+(t.finalDueDate||'')+'"></div><div class="form-group flex1"><label>Due Type</label><select id="tf_dueType"><option value="suggested"'+(t.dueDateType==='suggested'?' selected':'')+'>Suggested</option><option value="hard"'+(t.dueDateType==='hard'?' selected':'')+'>Hard Deadline</option></select></div></div>'+
        timerHtml+
        '<div class="form-group"><label>Notes</label><textarea id="tf_notes" rows="3" placeholder="Notes, context, comments...">'+escH(t.notes||'')+'</textarea></div>'+
        '<div class="form-group"><label>Links</label><div id="formLinksContainer">'+linksHtml+'</div><span style="font-size:12px;color:#007AFF;cursor:pointer;" onclick="addFormLink()">+ Add link</span>'+openAllBtn+'</div>'+
        '<div class="form-buttons"><button class="btn btn-primary" onclick="saveTaskForm()">Save</button><button class="btn btn-secondary" onclick="closeTaskForm()">Cancel</button>'+
        (!isNew?'<button class="btn btn-danger" style="margin-left:auto;" onclick="deleteTask()">Delete</button>':'')+
        (!isNew&&!parentId?'<button class="btn btn-secondary" style="margin-left:8px;" onclick="addSubtask()">+ Sub-task</button>':'')+'</div>';
    document.getElementById('taskFormBody').innerHTML=html;
    document.getElementById('taskFormModal').classList.add('active');
    setTimeout(function(){var ti=document.getElementById('tf_title');if(ti)ti.focus();},50);
}

function addFormLink(){
    var c=document.getElementById('formLinksContainer');var idx=c.children.length;
    var div=document.createElement('div');div.className='link-row';div.id='linkRow'+idx;
    div.innerHTML='<input placeholder="Label"><input placeholder="URL"><span class="link-remove" onclick="this.parentElement.remove()">&#215;</span>';
    c.appendChild(div);
}
function removeFormLink(i){var el=document.getElementById('linkRow'+i);if(el)el.remove();}
function clearTaskTimer(){
    var task=findTask(editingTaskId);
    if(task){task.timerStart=null;task.timerAccumulated=0;persist();}
    showTaskForm(editingTaskId,editingParentId);
}

function saveTaskForm(){
    var title=document.getElementById('tf_title').value.trim();
    if(!title){document.getElementById('tf_title').focus();return;}
    var taskData={title:title,category:document.getElementById('tf_category').value,
        priority:document.getElementById('tf_priority').value,status:document.getElementById('tf_status').value,
        estDuration:document.getElementById('tf_est').value,dateOpened:document.getElementById('tf_opened').value||today(),
        lastUpdated:today(),nextActionDate:document.getElementById('tf_nextAction').value||'',
        finalDueDate:document.getElementById('tf_dueDate').value||'',dueDateType:document.getElementById('tf_dueType').value,
        notes:document.getElementById('tf_notes').value||'',links:[]};
    document.querySelectorAll('#formLinksContainer .link-row').forEach(function(row){
        var inputs=row.querySelectorAll('input');
        if(inputs[0]&&inputs[1]&&(inputs[0].value.trim()||inputs[1].value.trim()))
            taskData.links.push({label:inputs[0].value.trim(),url:inputs[1].value.trim()});
    });
    if(editingTaskId){var task=findTask(editingTaskId);if(task)Object.assign(task,taskData);}
    else{
        taskData.id=genId();taskData.actualDuration=0;taskData.timerStart=null;taskData.timerAccumulated=0;taskData.subtasks=[];
        if(editingParentId){var parent=findTask(editingParentId);if(parent){if(!parent.subtasks)parent.subtasks=[];parent.subtasks.push(taskData);prefs.expandedTasks[editingParentId]=true;}}
        else data.tasks.push(taskData);
    }
    persist();closeTaskForm();renderCurrentTab();
}

function deleteTask(){
    if(!editingTaskId)return;
    function removeFrom(list){for(var i=0;i<list.length;i++){if(list[i].id===editingTaskId){list.splice(i,1);return true;}if(list[i].subtasks&&removeFrom(list[i].subtasks))return true;}return false;}
    removeFrom(data.tasks);persist();closeTaskForm();renderCurrentTab();
}
function addSubtask(){closeTaskForm();showTaskForm(null,editingTaskId);}
function closeTaskForm(){document.getElementById('taskFormModal').classList.remove('active');editingTaskId=null;editingParentId=null;}

/* ═══ TASK INTERACTIONS ═══ */
function selectTask(id){selectedTaskId=id;renderCurrentTab();}
function toggleExpand(id){prefs.expandedTasks[id]=!prefs.expandedTasks[id];persist();renderCurrentTab();}
function toggleCompleted(){prefs.completedExpanded=!prefs.completedExpanded;persist();renderCurrentTab();}
function toggleTimer(id){
    var task=findTask(id);if(!task)return;
    if(task.timerStart){var elapsed=Math.floor((Date.now()-task.timerStart)/1000);task.timerAccumulated=(task.timerAccumulated||0)+elapsed;task.timerStart=null;}
    else task.timerStart=Date.now();
    task.lastUpdated=today();persist();renderCurrentTab();
}
function getVisibleTaskIds(){
    var ids=[];var active=data.tasks.filter(function(t){return t.status!=='closed';});
    active=applyFilter(active);active=sortTasks(active,prefs.sortMode);
    function walk(list){list.forEach(function(t){ids.push(t.id);if(prefs.expandedTasks[t.id]&&t.subtasks)walk(t.subtasks);});}
    walk(active);return ids;
}
function navigateTask(dir){
    if(currentTab!=='regular')return;var ids=getVisibleTaskIds();if(ids.length===0)return;
    var idx=ids.indexOf(selectedTaskId);if(idx===-1)selectedTaskId=ids[0];
    else{idx+=dir;if(idx<0)idx=0;if(idx>=ids.length)idx=ids.length-1;selectedTaskId=ids[idx];}
    renderCurrentTab();var el=document.querySelector('.task-item.selected');if(el)el.scrollIntoView({block:'nearest'});
}

/* Timer update loop */
function updateTimers(){
    document.querySelectorAll('.timer-badge[data-timer-id]').forEach(function(badge){
        var id=badge.dataset.timerId;var task=findTask(id);if(!task||!task.timerStart)return;
        var total=(task.timerAccumulated||0)+Math.floor((Date.now()-task.timerStart)/1000);
        badge.innerHTML='&#9654; '+formatTimerSecs(total);
    });
}

/* ═══ CONTACTS ═══ */
var editingContactIdx=null;
function openContactsModal(){renderContactsList();document.getElementById('contactsModal').classList.add('active');}
function renderContactsList(){
    var sorted=data.contacts.slice().sort(function(a,b){return(b.tagCount||0)-(a.tagCount||0);});
    var html='<div style="margin-bottom:12px;"><label style="font-size:12px;color:#8e8e93;display:block;margin-bottom:4px;">Bulk add (tab-separated: Name &#8677; Email &#8677; Role)</label>';
    html+='<textarea id="contactsBulk" rows="3" style="width:100%;padding:8px;font-size:12px;border:1px solid #d2d2d7;border-radius:8px;font-family:monospace;" placeholder="Jane Smith&#9;jane@co.com&#9;PM"></textarea>';
    html+='<button class="btn btn-sm btn-primary" style="margin-top:4px;" onclick="bulkAddContacts()">Import</button></div>';
    html+='<div style="margin-bottom:8px;display:flex;gap:6px;">';
    html+='<input id="newContactName" placeholder="Name" style="flex:2;padding:6px 8px;font-size:12px;border:1px solid #d2d2d7;border-radius:6px;">';
    html+='<input id="newContactEmail" placeholder="Email" style="flex:2;padding:6px 8px;font-size:12px;border:1px solid #d2d2d7;border-radius:6px;">';
    html+='<input id="newContactRole" placeholder="Role" style="flex:1;padding:6px 8px;font-size:12px;border:1px solid #d2d2d7;border-radius:6px;">';
    html+='<button class="btn btn-sm btn-primary" onclick="addSingleContact()">Add</button></div>';
    if(sorted.length>0){
        html+='<div style="max-height:240px;overflow-y:auto;">';
        sorted.forEach(function(c,i){
            var realIdx=data.contacts.indexOf(c);
            if(editingContactIdx===realIdx){
                html+='<div style="display:flex;align-items:center;gap:4px;padding:5px 8px;border-bottom:1px solid #E8F0FE;background:#F8FAFF;font-size:12px;">';
                html+='<input id="editCName" value="'+escA(c.name)+'" style="flex:2;padding:4px 6px;font-size:12px;border:1px solid #007AFF;border-radius:4px;">';
                html+='<input id="editCEmail" value="'+escA(c.email||'')+'" placeholder="Email" style="flex:2;padding:4px 6px;font-size:12px;border:1px solid #d2d2d7;border-radius:4px;">';
                html+='<input id="editCRole" value="'+escA(c.role||'')+'" placeholder="Role" style="flex:1;padding:4px 6px;font-size:12px;border:1px solid #d2d2d7;border-radius:4px;">';
                html+='<span style="color:#007AFF;cursor:pointer;font-size:11px;font-weight:600;padding:2px 6px;" onclick="saveContactEdit('+realIdx+')">Save</span>';
                html+='<span style="color:#8e8e93;cursor:pointer;font-size:11px;padding:2px 4px;" onclick="editingContactIdx=null;renderContactsList();">Cancel</span>';
                html+='</div>';
            } else {
                html+='<div style="display:flex;align-items:center;gap:8px;padding:5px 8px;border-bottom:1px solid #f0f0f5;font-size:12px;">';
                html+='<span style="flex:2;font-weight:500;">'+escH(c.name)+'</span>';
                html+='<span style="flex:2;color:#8e8e93;">'+escH(c.email||'')+'</span>';
                html+='<span style="flex:1;color:#8e8e93;">'+escH(c.role||'')+'</span>';
                html+='<span style="color:#aeaeb2;font-size:10px;width:30px;">'+((c.tagCount||0)+'x')+'</span>';
                html+='<span style="color:#007AFF;cursor:pointer;font-size:11px;" onclick="editingContactIdx='+realIdx+';renderContactsList();" title="Edit">&#9998;</span>';
                html+='<span style="color:#FF3B30;cursor:pointer;font-size:14px;margin-left:2px;" onclick="deleteContact('+i+')">&#215;</span></div>';
            }
        });
        html+='</div>';
    }
    document.getElementById('contactsBody').innerHTML=html;
    if(editingContactIdx!==null){var el=document.getElementById('editCName');if(el)el.focus();}
}
function saveContactEdit(realIdx){
    var c=data.contacts[realIdx];if(!c)return;
    var name=document.getElementById('editCName').value.trim();if(!name)return;
    c.name=name;c.email=document.getElementById('editCEmail').value.trim();c.role=document.getElementById('editCRole').value.trim();
    editingContactIdx=null;persist();renderContactsList();
}
function addSingleContact(){
    var name=document.getElementById('newContactName').value.trim();if(!name)return;
    data.contacts.push({name:name,email:document.getElementById('newContactEmail').value.trim(),role:document.getElementById('newContactRole').value.trim(),tagCount:0});
    persist();renderContactsList();
    document.getElementById('newContactName').value='';document.getElementById('newContactEmail').value='';document.getElementById('newContactRole').value='';
}
function bulkAddContacts(){
    var text=document.getElementById('contactsBulk').value.trim();if(!text)return;
    text.split('\n').forEach(function(line){var parts=line.split('\t');var name=(parts[0]||'').trim();
        if(!name)return;if(data.contacts.some(function(c){return c.name.toLowerCase()===name.toLowerCase();}))return;
        data.contacts.push({name:name,email:(parts[1]||'').trim(),role:(parts[2]||'').trim(),tagCount:0});});
    persist();renderContactsList();document.getElementById('contactsBulk').value='';
}
function deleteContact(idx){
    var sorted=data.contacts.slice().sort(function(a,b){return(b.tagCount||0)-(a.tagCount||0);});
    var contact=sorted[idx];data.contacts=data.contacts.filter(function(c){return c!==contact;});
    persist();renderContactsList();
}

/* ═══ HOLIDAYS ═══ */
function openHolidayModal(){renderHolidayList();document.getElementById('holidayModal').classList.add('active');}
function importHolidays(){
    var text=document.getElementById('holidayImportArea').value.trim();if(!text)return;
    text.split('\n').forEach(function(line){var parts=line.split('\t');var name=(parts[0]||'').trim();var start=(parts[1]||'').trim();
        if(!name||!start)return;var end=(parts[2]||'').trim()||start;
        start=normDate(start);end=normDate(end);
        if(!start)return;if(!end)end=start;
        data.holidays.push({name:name,startDate:start,endDate:end});});
    persist();renderCalendar();renderHolidayList();document.getElementById('holidayImportArea').value='';
}
/* Normalize any date input to YYYY-MM-DD zero-padded */
function normDate(s){
    if(!s)return '';
    s=s.trim();
    /* Already YYYY-MM-DD? just zero-pad */
    var m=s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if(m)return m[1]+'-'+(m[2].length===1?'0':'')+m[2]+'-'+(m[3].length===1?'0':'')+m[3];
    /* Try M/D/YYYY or MM/DD/YYYY */
    m=s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
    if(m){var mo=m[1],dy=m[2],yr=m[3];return yr+'-'+(mo.length===1?'0':'')+mo+'-'+(dy.length===1?'0':'')+dy;}
    /* Try Date parse as last resort */
    var d=new Date(s);
    if(!isNaN(d.getTime())){return d.getFullYear()+'-'+((d.getMonth()+1)<10?'0':'')+(d.getMonth()+1)+'-'+(d.getDate()<10?'0':'')+d.getDate();}
    return '';
}
function clearHolidays(){data.holidays=[];persist();renderCalendar();renderHolidayList();}
function renderHolidayList(){
    var html='';if(data.holidays.length>0){html+='<div style="max-height:150px;overflow-y:auto;margin-top:8px;">';
        data.holidays.forEach(function(h,i){
            html+='<div style="display:flex;align-items:center;gap:8px;padding:4px 8px;font-size:12px;border-bottom:1px solid #f0f0f5;">';
            html+='<span style="flex:1;">'+escH(h.name)+'</span>';
            html+='<span style="color:#8e8e93;">'+h.startDate+(h.endDate&&h.endDate!==h.startDate?' &ndash; '+h.endDate:'')+'</span>';
            html+='<span style="color:#FF3B30;cursor:pointer;" onclick="removeHoliday('+i+')">&#215;</span></div>';});
        html+='</div>';}
    document.getElementById('holidayList').innerHTML=html;
}
function removeHoliday(i){data.holidays.splice(i,1);persist();renderCalendar();renderHolidayList();}

/* ═══ EXPORT ═══ */
function openExportModal(){document.getElementById('exportModal').classList.add('active');}
function doExport(format){
    window.webkit.messageHandlers.taskManager.postMessage({action:'export',format:format,data:data});
    closeModal('exportModal');
}

/* ═══ TABS & RENDER ═══ */
function switchTab(tab){
    currentTab=tab;prefs.lastTab=tab;persist();
    document.querySelectorAll('.tab-btn').forEach(function(b){b.classList.toggle('active',b.dataset.tab===tab);});
    document.getElementById('filterBar').style.display=tab==='regular'?'flex':'none';
    renderCurrentTab();
}
function renderCurrentTab(){if(currentTab==='regular')renderRegularTasks();else renderRecurringTasks();}
function changeSortMode(mode){prefs.sortMode=mode;persist();renderCurrentTab();}
function closeModal(id){document.getElementById(id).classList.remove('active');}
function toggleHelp(){document.getElementById('helpModal').classList.toggle('active');}

/* ═══ @-MENTION ═══ */
function setupMentions(inputEl){
    inputEl.addEventListener('input',function(){
        var val=this.value;var pos=this.selectionStart;var before=val.substring(0,pos);
        var atIdx=before.lastIndexOf('@');
        if(atIdx>=0&&(atIdx===0||before[atIdx-1]===' ')){
            showMentionDropdown(this,before.substring(atIdx+1).toLowerCase(),atIdx);
        }else hideMentionDropdown();
    });
}
function showMentionDropdown(inputEl,query,atIdx){
    hideMentionDropdown();
    var sorted=data.contacts.slice().sort(function(a,b){return(b.tagCount||0)-(a.tagCount||0);});
    var filtered=sorted.filter(function(c){return c.name.toLowerCase().indexOf(query)>=0;});
    if(filtered.length===0)return;
    var dd=document.createElement('div');dd.className='mention-dropdown';dd.id='mentionDD';
    var rect=inputEl.getBoundingClientRect();dd.style.left=rect.left+'px';dd.style.top=(rect.bottom+2)+'px';
    filtered.slice(0,8).forEach(function(c){
        var item=document.createElement('div');item.className='mention-item';
        item.textContent=c.name+(c.role?' ('+c.role+')':'');
        item.onclick=function(){
            var val=inputEl.value;var before=val.substring(0,atIdx);var after=val.substring(inputEl.selectionStart);
            inputEl.value=before+'@'+c.name+' '+after;inputEl.focus();
            inputEl.selectionStart=inputEl.selectionEnd=atIdx+c.name.length+2;
            c.tagCount=(c.tagCount||0)+1;persist();hideMentionDropdown();
        };
        dd.appendChild(item);
    });
    document.body.appendChild(dd);
}
function hideMentionDropdown(){var dd=document.getElementById('mentionDD');if(dd)dd.remove();}
var observer=new MutationObserver(function(){
    var ti=document.getElementById('tf_title'),tn=document.getElementById('tf_notes');
    if(ti&&!ti.dataset.mb){setupMentions(ti);ti.dataset.mb='1';}
    if(tn&&!tn.dataset.mb){setupMentions(tn);tn.dataset.mb='1';}
});
observer.observe(document.body,{childList:true,subtree:true});

/* ═══ KEYBOARD ═══ */
document.addEventListener('keydown',function(e){
    var isInput=document.activeElement.tagName==='INPUT'||document.activeElement.tagName==='TEXTAREA'||document.activeElement.tagName==='SELECT';
    var anyModal=document.querySelector('.modal-overlay.active');
    if(e.key==='Escape'){e.preventDefault();if(anyModal){anyModal.classList.remove('active');hideMentionDropdown();return;}
        if(calDateFilter){clearCalDateFilter();return;}
        window.webkit.messageHandlers.taskManager.postMessage({action:'close'});return;}
    if((e.metaKey||e.ctrlKey)&&e.key==='Enter'&&document.getElementById('taskFormModal').classList.contains('active')){e.preventDefault();saveTaskForm();return;}
    if(anyModal)return;
    if(isInput&&document.activeElement.id!=='searchBar')return;
    if(e.key==='/'){e.preventDefault();document.getElementById('searchBar').focus();return;}
    if(isInput&&document.activeElement.id==='searchBar'){if(e.key==='Escape'){document.activeElement.blur();clearSearch();}return;}
    if(e.key==='?'){e.preventDefault();toggleHelp();return;}
    if(e.key==='Tab'){e.preventDefault();switchTab(currentTab==='regular'?'recurring':'regular');return;}
    if(e.key==='n'||e.key==='N'){e.preventDefault();if(currentTab==='regular')showTaskForm(null);else addRecurringTask();return;}
    if((e.key==='e'||e.key==='E')&&selectedTaskId&&currentTab==='regular'){e.preventDefault();showTaskForm(selectedTaskId);return;}
    if((e.key==='s'||e.key==='S')&&selectedTaskId&&currentTab==='regular'){e.preventDefault();toggleTimer(selectedTaskId);return;}
    if(e.key==='ArrowUp'){e.preventDefault();navigateTask(-1);return;}
    if(e.key==='ArrowDown'){e.preventDefault();navigateTask(1);return;}
    if(e.key==='ArrowRight'&&selectedTaskId){e.preventDefault();var t=findTask(selectedTaskId);if(t&&t.subtasks&&t.subtasks.length>0){prefs.expandedTasks[selectedTaskId]=true;persist();renderCurrentTab();}return;}
    if(e.key==='ArrowLeft'&&selectedTaskId){e.preventDefault();prefs.expandedTasks[selectedTaskId]=false;persist();renderCurrentTab();return;}
});

/* ═══ INIT ═══ */
document.getElementById('sortSelect').value=prefs.sortMode;
renderCalendar();
switchTab(currentTab);
timerInterval=setInterval(updateTimers,1000);
</script>
</body>
</html>
]==]
end

-- Open the task manager
local function openTaskManager()
    if taskWindow then
        local ok, hswin = pcall(function() return taskWindow:hswindow() end)
        if not ok or not hswin then
            taskWindow = nil
            previousWindow = nil
        else
            -- If opened from menu cal with a date, apply filter instead of closing
            if _G._menucalFilterDate then
                local filterDate = _G._menucalFilterDate
                _G._menucalFilterDate = nil
                hswin:focus()
                taskWindow:evaluateJavaScript("filterByCalDate('" .. filterDate .. "')")
                return
            end
            closeTaskManager()
            return
        end
    end

    previousWindow = hs.window.focusedWindow()

    local rawData = loadData()
    local dataJson
    if rawData then
        dataJson = hs.json.encode(rawData) or "{}"
    else
        local defaults = {
            tasks = {},
            recurringTasks = {},
            contacts = {},
            holidays = {
                {name="New Year's Day", startDate="2026-01-01", endDate="2026-01-01"},
                {name="MLK Day", startDate="2026-01-19", endDate="2026-01-19"},
                {name="Presidents' Day", startDate="2026-02-16", endDate="2026-02-16"},
                {name="Memorial Day", startDate="2026-05-25", endDate="2026-05-25"},
                {name="Independence Day", startDate="2026-07-03", endDate="2026-07-04"},
                {name="Labor Day", startDate="2026-09-07", endDate="2026-09-07"},
                {name="Thanksgiving", startDate="2026-11-26", endDate="2026-11-27"},
                {name="Christmas", startDate="2026-12-24", endDate="2026-12-25"},
            },
            categories = {"Milestones", "Initiative", "Jira", "Misc"},
            preferences = {
                calendarZoom = 1,
                sortMode = "smart",
                lastTab = "regular",
                completedExpanded = false,
                expandedTasks = {},
                recurringArchivedWeeks = {},
                recurringWeeksAhead = 6,
            }
        }
        dataJson = hs.json.encode(defaults)
        saveData(defaults)
    end

    local uc = hs.webview.usercontent.new("taskManager")
    uc:setCallback(function(msg)
        local body = msg.body

        if body.action == "save" then
            saveData(body.data)

        elseif body.action == "close" then
            closeTaskManager()

        elseif body.action == "openurl" then
            local url = body.url
            if url and url ~= "" then
                hs.urlevent.openURL(url)
            end

        elseif body.action == "export" then
            local format = body.format
            local exportData = body.data

            if format == "json" then
                local path = os.getenv("HOME") .. "/Desktop/TaskDeck_export.json"
                local f = io.open(path, "w")
                if f then
                    f:write(hs.json.encode(exportData, true))
                    f:close()
                    hs.alert.show("Exported JSON to Desktop", nil, nil, 2)
                end

            elseif format == "csv" then
                local path = os.getenv("HOME") .. "/Desktop/TaskDeck_tasks.csv"
                local f = io.open(path, "w")
                if f then
                    f:write("Title,Priority,Category,Status,Est Duration,Date Opened,Last Updated,Next Action,Due Date,Due Type,Notes\n")
                    local function writeTask(task, indent)
                        indent = indent or ""
                        local function csvEsc(s)
                            if not s then return "" end
                            s = tostring(s)
                            if s:find('[,"\n]') then return '"' .. s:gsub('"', '""') .. '"' end
                            return s
                        end
                        f:write(table.concat({
                            csvEsc(indent .. (task.title or "")),
                            csvEsc(task.priority or ""),
                            csvEsc(task.category or ""),
                            csvEsc(task.status or ""),
                            csvEsc(task.estDuration or ""),
                            csvEsc(task.dateOpened or ""),
                            csvEsc(task.lastUpdated or ""),
                            csvEsc(task.nextActionDate or ""),
                            csvEsc(task.finalDueDate or ""),
                            csvEsc(task.dueDateType or ""),
                            csvEsc(task.notes or "")
                        }, ",") .. "\n")
                        if task.subtasks then
                            for _, st in ipairs(task.subtasks) do writeTask(st, indent .. "  ") end
                        end
                    end
                    if exportData.tasks then
                        for _, task in ipairs(exportData.tasks) do writeTask(task) end
                    end
                    f:close()
                    hs.alert.show("Exported CSV to Desktop", nil, nil, 2)
                end

            elseif format == "csv_recurring" then
                local path = os.getenv("HOME") .. "/Desktop/TaskDeck_recurring.csv"
                local f = io.open(path, "w")
                if f then
                    f:write("Name,Meeting,Type,Owner,Day\n")
                    if exportData.recurringTasks then
                        for _, task in ipairs(exportData.recurringTasks) do
                            local function csvEsc(s)
                                if not s then return "" end
                                s = tostring(s)
                                if s:find('[,"\n]') then return '"' .. s:gsub('"', '""') .. '"' end
                                return s
                            end
                            f:write(table.concat({
                                csvEsc(task.name or ""),
                                csvEsc(task.meeting or ""),
                                csvEsc(task.type or ""),
                                csvEsc(task.owner or ""),
                                csvEsc(task.dayOfWeek or "")
                            }, ",") .. "\n")
                        end
                    end
                    f:close()
                    hs.alert.show("Exported recurring CSV to Desktop", nil, nil, 2)
                end
            end
        end
    end)

    local screen = hs.screen.mainScreen():frame()
    -- Restore saved geometry or use defaults
    local w, h = 920, 720
    local savedGeo = nil
    if rawData and rawData.preferences and rawData.preferences.windowGeometry then
        savedGeo = rawData.preferences.windowGeometry
    end
    local rect
    if savedGeo then
        rect = hs.geometry.rect(savedGeo.x, savedGeo.y, savedGeo.w, savedGeo.h)
    else
        rect = hs.geometry.rect((screen.w - w) / 2, (screen.h - h) / 2, w, h)
    end

    taskWindow = hs.webview.new(rect, {}, uc)
        :windowStyle({"titled", "closable", "resizable", "miniaturizable"})
        :html(buildHTML(dataJson))
        :allowTextEntry(true)
        :level(hs.drawing.windowLevels.normal)
        :behavior(4 + 32)
        :windowTitle("Task Deck")
        :shadow(true)
        :show()
        :bringToFront(true)

    -- Check if opened from menu calendar with a date filter
    if _G._menucalFilterDate then
        local filterDate = _G._menucalFilterDate
        _G._menucalFilterDate = nil
        hs.timer.doAfter(0.3, function()
            if taskWindow then
                taskWindow:evaluateJavaScript("filterByCalDate('" .. filterDate .. "')")
            end
        end)
    end

    taskWindow:windowCallback(function(action)
        if action == "closing" then
            -- Save geometry before losing the window
            local ok, hswin = pcall(function() return taskWindow:hswindow() end)
            if ok and hswin then
                local frame = hswin:frame()
                local currentData = loadData()
                if currentData then
                    if not currentData.preferences then currentData.preferences = {} end
                    currentData.preferences.windowGeometry = {
                        x = frame.x, y = frame.y, w = frame.w, h = frame.h
                    }
                    saveData(currentData)
                end
            end
            taskWindow = nil
            if previousWindow and previousWindow:application() then
                previousWindow:focus()
            end
            previousWindow = nil
        end
    end)

    hs.timer.doAfter(0.05, function()
        if taskWindow then
            local ok, hswin = pcall(function() return taskWindow:hswindow() end)
            if ok and hswin then hswin:focus() end
        end
    end)
end

hs.hotkey.bind({"ctrl", "alt"}, "C", openTaskManager)

return M
