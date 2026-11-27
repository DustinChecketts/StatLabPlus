local addon = ...
local frame = CreateFrame("Frame")
local db, session, pending, lastKey
local paused = false
local MAX = 2000
local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
local function probe(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return {status="missing"} end
    local r = pack(pcall(fn, ...))
    if not r[1] then return {status="error"} end
    local out = {status="ok", n=r.n-1, values={}}
    for i=2,r.n do
        local v = r[i]
        if type(issecretvalue)=="function" and issecretvalue(v) then
            out.values[i-1]={status="restricted"}
        elseif type(v)=="number" or type(v)=="string" or type(v)=="boolean" then
            out.values[i-1]=v
        else
            out.values[i-1]={status=type(v)}
        end
    end
    return out
end
local function key(v)
    if type(v)~="table" then return type(v)..":"..tostring(v) end
    local ks={}
    for k in pairs(v) do ks[#ks+1]=k end
    table.sort(ks,function(a,b) return tostring(a)<tostring(b) end)
    local s={}
    for _,k in ipairs(ks) do s[#s+1]=key(k).."="..key(v[k]) end
    return "{"..table.concat(s,";").."}"
end
local function first(r)
    local v=r.values and r.values[1]
    if type(v)=="number" then return v end
end
local unitAPIs={"UnitLevel","UnitRace","UnitClass","UnitArmor","UnitAttackPower","UnitRangedAttackPower","UnitDamage","UnitRangedDamage","UnitAttackSpeed","UnitDefense","UnitHealthMax","UnitPowerMax","UnitPowerType","UnitHPPerStamina"}
local scalarAPIs={"GetCritChance","GetRangedCritChance","GetDodgeChance","GetParryChance","GetBlockChance","GetShieldBlock","GetHitModifier","GetSpellHitModifier","GetSpellBonusHealing","GetManaRegen","GetPowerRegen","GetCritChanceFromAgility","GetSpellCritChanceFromIntellect","GetShapeshiftForm","GetCombatRatingBonus","GetNumTalentTabs","GetNumSkillLines"}
local function collect()
    local s={stats={},equipment={},talents={},auras={},skills={}}
    local a=s.stats
    for _,n in ipairs(unitAPIs) do a[n]=probe(n,"player") end
    for _,n in ipairs(scalarAPIs) do a[n]=probe(n) end
    for i=1,5 do
        a["UnitStat:"..i]=probe("UnitStat","player",i)
        a["GetAttackPowerForStat:"..i]=probe("GetAttackPowerForStat",i)
    end
    for i=1,7 do
        a["GetSpellBonusDamage:"..i]=probe("GetSpellBonusDamage",i)
        a["GetSpellCritChance:"..i]=probe("GetSpellCritChance",i)
        a["UnitResistance:"..i]=probe("UnitResistance","player",i)
    end
    for i=1,19 do
        s.equipment[i]={id=probe("GetInventoryItemID","player",i),link=probe("GetInventoryItemLink","player",i)}
    end
    local tabs=first(a.GetNumTalentTabs) or 0
    for t=1,math.min(tabs,10) do
        local tab={info=probe("GetTalentTabInfo",t),entries={}}
        local count=first(probe("GetNumTalents",t)) or 0
        for i=1,math.min(count,100) do tab.entries[i]=probe("GetTalentInfo",t,i) end
        s.talents[t]=tab
    end
    s.auraAPI=type(UnitBuff)=="function" and "UnitBuff" or "missing"
    for i=1,40 do
        local r=probe("UnitBuff","player",i)
        if r.status~="ok" or not r.values or type(r.values[1])~="string" then
            s.auraEnd=r
            break
        end
        s.auras[i]=r
    end
    local count=first(a.GetNumSkillLines) or 0
    for i=1,math.min(count,200) do s.skills[i]=probe("GetSkillLineInfo",i) end
    return s
end
local function now() return time() end
local function capture(reason,force)
    if not session or paused then return end
    if #session.snapshots>=MAX then
        if not session.full then print("StatLabPlus: session limit reached; /slp new to continue.") end
        session.full=true
        return
    end
    local s=collect()
    local k=key(s)
    if not force and k==lastKey then return end
    lastKey=k
    s.time=now()
    s.reason=reason
    session.snapshots[#session.snapshots+1]=s
    session.lastTime=s.time
end
local function start()
    session={started=now(),build=probe("GetBuildInfo"),character=probe("UnitName","player"),realm=probe("GetRealmName"),snapshots={}}
    db.sessions[#db.sessions+1]=session
    lastKey=nil
    paused=false
    capture("session_start",true)
end
local function queue(event)
    if paused or not session then return end
    if pending then pending.reasons[event]=true; pending.delay=0.5; return end
    pending={delay=0.5,reasons={[event]=true}}
end
frame:SetScript("OnUpdate",function(_,elapsed)
    if not pending then return end
    pending.delay=pending.delay-elapsed
    if pending.delay>0 then return end
    local reasons={}
    for r in pairs(pending.reasons) do reasons[#reasons+1]=r end
    table.sort(reasons)
    pending=nil
    capture(table.concat(reasons,","))
end)
frame:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" and arg==addon then
        StatLabPlusDB=StatLabPlusDB or {schema=1,sessions={}}
        db=StatLabPlusDB
    elseif event=="PLAYER_LOGIN" and db then
        start()
    elseif event=="PLAYER_LOGOUT" and session then
        session.ended=now()
    elseif event:sub(1,5)=="UNIT_" and arg~="player" then
        return
    else queue(event) end
end)
local events={"ADDON_LOADED","PLAYER_LOGIN","PLAYER_LOGOUT","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","UNIT_STATS","UNIT_AURA","UNIT_ATTACK_POWER","UNIT_RANGED_ATTACK_POWER","UNIT_DAMAGE","UNIT_RANGEDDAMAGE","UNIT_RESISTANCES","UNIT_MAXHEALTH","UNIT_MAXPOWER","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","SKILL_LINES_CHANGED","UPDATE_SHAPESHIFT_FORM","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","COMBAT_RATING_UPDATE"}
for _,e in ipairs(events) do pcall(frame.RegisterEvent,frame,e) end
SLASH_STATLABPLUS1="/slp"
SlashCmdList.STATLABPLUS=function(msg)
    msg=msg:lower():match("^%s*(.-)%s*$")
    if not session then return end
    if msg=="snap" or msg=="scan" then capture(msg,true)
    elseif msg=="pause" then paused=not paused; pending=nil; if not paused then capture("resume",true) end
    elseif msg=="new" then session.ended=now(); pending=nil; start()
    elseif msg=="export" then print("StatLabPlus: /reload then upload WTF/Account/<account>/SavedVariables/StatLabPlus.lua")
    end
    print("StatLabPlus: "..(paused and "paused" or "recording").."; "..#session.snapshots.." snapshots; "..#db.sessions.." sessions. Commands: snap, scan, pause, new, export.")
end
