local a=GetBot()local b=a:GetUnitName()if a==nil or a:IsInvulnerable()or not a:IsHero()or not a:IsAlive()or not string.find(b,"hero")or a:IsIllusion()then return end;if GAMEMODE_ARDM==nil then GAMEMODE_ARDM=20 end;local c=require(GetScriptDirectory()..'/FuncLib/systems/item')local d=require(GetScriptDirectory()..'/FuncLib/systems/role')local e=require(GetScriptDirectory()..'/FuncLib/func_utils')local f=require(GetScriptDirectory()..'/FuncLib/systems/utils')
local FarmTiming=require(GetScriptDirectory()..'/FuncLib/systems/farm_timing')
local InventoryPolicy=require(GetScriptDirectory()..'/FuncLib/systems/inventory_policy')
local g={}
-- Every diagnostic in this file went through the shared global PLog(), which
-- is a permanent no-op here (IsDebug is hardcoded off via
-- FuncLib/systems/utils.lua's DebugMode=false) - meaning [Purchase]/[ARDM]/
-- [PosSwap]/the purchase-failure line/the stuck-item-skip line have never
-- actually reached any match log, ever, regardless of what's going wrong.
-- Always-on print with the same TICB-tag convention as rune_policy.lua/
-- decision_log.lua, scoped to just this file's own diagnostics rather than
-- flipping the shared IsDebug flag (which would also turn on unrelated,
-- much noisier debug output elsewhere).
local function PLog(fmt,...)
    if select('#',...)==0 then print('[TICB-ITEM] '..fmt) else print('[TICB-ITEM] '..string.format(fmt,...)) end
end
-- Many hero buy lists bury their boots choice 5-10 items deep behind other
-- core items, so a mid-game snapshot shows no boots at all even though the
-- hero would eventually get them. list is popped from the END (highest
-- index bought first), so this pulls the earliest boots-tier entry up to
-- the 2nd item bought (never 1st, to preserve each hero's deliberate
-- starting item) without needing to hand-edit every hero file.
-- Only the CHEAP boots tiers get force-promoted to the 2nd item bought -
-- Travel Boots/Travel Boots 2/Guardian Greaves/Boots of Bearing are
-- expensive finished/upgrade items, not a starting-boots choice, and a
-- hero whose earliest boots-tier entry is one of those (e.g. Axe's pos_3,
-- which has no cheap item_boots at all) was getting a ~2500g item force-
-- inserted as purchase #2, ahead of everything else affordable - the
-- hero then sat stalled saving for it while items 3+ never got touched.
local BootsTierItems={item_boots=true,item_phase_boots=true,item_power_treads=true,item_tranquil_boots=true,item_arcane_boots=true}
local function PrioritizeBoots(list)
    local n=#list
    if n<2 then return end
    local bootsIndex=nil
    for idx=n,1,-1 do
        if BootsTierItems[list[idx]] then bootsIndex=idx break end
    end
    if bootsIndex==nil or bootsIndex>=n-1 then return end
    local bootsItem=list[bootsIndex]
    table.remove(list,bootsIndex)
    table.insert(list,#list,bootsItem)
end
-- list index 1 = last item bought (index n = first). These five items are
-- end-game/capstone purchases (item 17): if a hero's build already contains
-- any of them, pull them to the very end of the build (lowest indices),
-- in this fixed relative order, without ever ADDING one to a hero who
-- didn't already have it. No-op for a hero whose build didn't reference any
-- of them, and idempotent if they're already in this tail arrangement.
local LateGameOrder={"item_moon_shard","item_aghanims_shard","item_travel_boots_2","item_aghanims_blessing","item_ultimate_scepter","item_ultimate_scepter_2"}
local function PrioritizeLateGameItems(list)
    local n=#list
    if n<2 then return end
    local present={}
    for _,name in ipairs(LateGameOrder) do
        for idx=1,n do
            if list[idx]==name then present[#present+1]=name break end
        end
    end
    if #present==0 then return end
    local alreadyCorrect=true
    for idx=1,#present do
        if list[idx]~=present[idx] then alreadyCorrect=false break end
    end
    if alreadyCorrect then return end
    local rest={}
    local wanted={}
    for _,name in ipairs(present) do wanted[name]=true end
    for idx=1,n do
        if not wanted[list[idx]] then rest[#rest+1]=list[idx] end
    end
    local result={}
    for idx=1,#present do result[idx]=present[idx] end
    for idx=1,#rest do result[#present+idx]=rest[idx] end
    for idx=1,n do list[idx]=result[idx] end
end
-- Several heroes' opening kit was just a single Tango (e.g. Ursa: tango,
-- double_branches, faerie_fire, quelling_blade, circlet - one consumable
-- total). One Tango runs out fast under any real harass, leaving the hero
-- with no sustain for the rest of the laning phase. Rather than hand-edit
-- every hero's starting items (which would also flatten the intentional
-- per-hero variety), top up with a single Healing Salve whenever a hero's
-- starting segment is clearly regen-light and doesn't already carry one -
-- cheap (~110g out of the standard 600g starting bank), doesn't touch
-- anything else in the build, and heroes that already start with enough
-- sustain (a double tango, an existing flask, etc.) are left untouched.
local RegenSustainValue={item_tango=1,item_double_tango=2,item_flask=1.5,item_clarity=0.5,item_enchanted_mango=0.4,item_double_enchanted_mango=0.8}
local function EnsureStartingRegen(list)
    local n=#list
    if n==0 then return end
    local checkCount=math.min(n,6)
    local sustainScore=0
    local hasFlask=false
    for idx=n-checkCount+1,n do
        local name=list[idx]
        if name=='item_flask' then hasFlask=true end
        sustainScore=sustainScore+(RegenSustainValue[name]or 0)
    end
    -- Raised from >=2 to >=3: a single Tango alone used to score exactly 1
    -- and skip the top-up (>=2 was already satisfied only by a double
    -- tango/flask), which is how Monkey King/Viper/Shadow Shaman ended up
    -- with just one consumable total for the whole starting kit. >=3 means
    -- a lone Tango (score 1) still gets a Flask added on top of it.
    if hasFlask or sustainScore>=3 then return end
    list[n+1]='item_flask'
end
if a:IsInvulnerable()or not a:IsHero()or a:IsIllusion()then return end;local h=require(GetScriptDirectory().."/BotsLib/"..string.gsub(b,"npc_dota_",""))if h==nil then return end;a.purchaseListInReverseOrder={}a.currBuyingItemInPurchaseList=nil;a.currBuyingBasicItem=nil;a.currBuyingBasicItemList={}a.currBuyingBasicItemRefList={}a.currBuyingRequiredCounts=nil;a._lastPurchaseAttempt={name=nil,t=-999}a.rebuildCount=0;a.SecretShop=false;local i=h['sBuyList']local j=h['sSellList']
FarmTiming.ConfigurePurchaseList(a,i)
if i==nil then
 PLog("[ERROR] Can't load purchase list for: %s",b)PLog("Stack Trace:",debug.traceback())return end;PLog("[Purchase] %s loaded %d items: %s -> %s",b,#i,i[1]or"nil",i[#i]or"nil")for k=1,#i do a.purchaseListInReverseOrder[k]=i[#i-k+1]end;PrioritizeBoots(a.purchaseListInReverseOrder)PrioritizeLateGameItems(a.purchaseListInReverseOrder)EnsureStartingRegen(a.purchaseListInReverseOrder)a.sell_time=-90;local l=-90;a.countInvCheck=0;a.lastItemToBuy=nil;a.bPurchaseFromSecret=false;a.hasBuyShard=true;local m=0;local n=nil;local o=false;local p=-90;a.lastInvCheck=-90;a.fullInvCheck=-90;a.switchTime=0;a.hasBuyClarity=false;local q=-90;local r=false;local s=false;local t=-999;local u=0;local v=false;local w,x,y,z,A,B,C,D,E;local function F(G,H)local I=0;for J=0,14 do local K=G:GetItemInSlot(J)if K~=nil and K:GetName()==H then I=I+1 end end;return I end;local function L(M)local N={}for O,P in ipairs(M)do N[P]=(N[P]or 0)+1 end;return N end;local Q={item_tango=true,item_double_tango=true,item_clarity=true,item_faerie_fire=true,item_enchanted_mango=true,item_flask=true,item_blood_grenade=true,item_branches=true,item_double_branches=true,item_magic_stick=true,item_magic_wand=true,item_recipe_magic_wand=true,item_infused_raindrop=true,item_orb_of_venom=true,item_blight_stone=true,item_orb_of_frost=true,item_gauntlets=true,item_slippers=true,item_mantle=true,item_circlet=true,item_ring_of_protection=true,item_bracer=true,item_wraith_band=true,item_null_talisman=true,item_soul_ring=true}local function R(H)if H=='item_boots'then local S=a.currBuyingItemInPurchaseList;local T={item_power_treads=true,item_phase_boots=true,item_arcane_boots=true,item_tranquil_boots=true,item_travel_boots=true,item_travel_boots_2=true,item_guardian_greaves=true,item_boots_of_bearing=true}if c.HasBootsInMainSolt(a)and not T[S]then return false end end;if(H=='item_mekansm'or H=='item_buckler')and(c.HasItem(a,'item_guardian_greaves')or c.HasItem(a,'item_boots_of_bearing'))then return false end;if H=='item_urn_of_shadows'and c.HasItem(a,'item_spirit_vessel')then return false end;if GetGameMode()==GAMEMODE_ARDM and DotaTime()>2*60 and Q[H]then return false end;if not a.currBuyingRequiredCounts then return true end;local U=a.currBuyingRequiredCounts[H]if not U then return true end;local V=F(a,H)return V<U end;local function W()while#a.currBuyingBasicItemList>0 do local X=a.currBuyingBasicItemList[#a.currBuyingBasicItemList]if R(X)then return X else a.currBuyingBasicItemList[#a.currBuyingBasicItemList]=nil end end;return nil end;local function Y(X)local Z=DotaTime()if a._lastPurchaseAttempt.name==X and Z-a._lastPurchaseAttempt.t<0.4 then return true end;a._lastPurchaseAttempt.name,a._lastPurchaseAttempt.t=X,Z;return false end;local function _()local a0=c.GetItemCharges(a,'item_tpscroll')return a0>=2 or a0>=1 and c.HasItem(a,'item_travel_boots')or a0>=1 and c.HasItem(a,'item_travel_boots_2')end;local function a1()a.countInvCheck=0;a.currBuyingBasicItem=nil;a.currBuyingBasicItemList[#a.currBuyingBasicItemList]=nil end;local function a2()a.countInvCheck=0;a.currBuyingItemInPurchaseList=nil;a.currBuyingBasicItem=nil;a.currBuyingBasicItemList={}a.currBuyingBasicItemRefList={}a.currBuyingRequiredCounts=nil end;local function a3()if a.lastItemToBuy~=a.currBuyingBasicItem then a.lastItemToBuy=a.currBuyingBasicItem;a:SetNextItemPurchaseValue(GetItemCost(a.currBuyingBasicItem))a.bPurchaseFromSecret=IsItemPurchasedFromSecretShop(a.currBuyingBasicItem)m=GetItemCost(a.currBuyingBasicItem)end;if a.currBuyingBasicItem=="item_infused_raindrop"or a.currBuyingBasicItem=="item_tome_of_knowledge"or a.currBuyingBasicItem=="item_flask"then if GetItemStockCount(a.currBuyingBasicItem)<=0 then a1()return end end;local a4=W()if not a4 then return end;a.currBuyingBasicItem=a4;if Y(a.currBuyingBasicItem)then return end;local a5=m;if a.lastItemToBuy=='item_boots'and a.currBuyingItemInPurchaseList=='item_travel_boots'and c.HasBootsInMainSolt(a)then a5=GetItemCost('item_travel_boots')end;if a:GetLevel()>=18 and o==false and DotaTime()>p+1.0 then for k=2,8,3 do local a6=GetTower(GetTeam(),k)if a6==nil or a6:GetHealth()/a6:GetMaxHealth()<0.3 then o=true;break end end;for k=1,7,3 do local a6=GetTower(GetTeam(),k)if a6~=nil and a6:IsAlive()then o=false;break end end;for k=9,10,1 do local a6=GetTower(GetTeam(),k)if a6==nil or a6:GetHealth()/a6:GetMaxHealth()<0.9 then o=true;break end end;if DotaTime()>=54*60 then o=true end;p=DotaTime()elseif o==true and a:GetBuybackCooldown()<=10 then a5=m+a:GetBuybackCost()+a:GetNetWorth()/40-300 end;if#a.currBuyingBasicItemList==1 or d.IsPvNMode()then a5=m end;if not a.hasBuyShard and DotaTime()>12*60 then local a7=15*60-DotaTime()if a7<0 then a5=a5+1400 else a5=a5+1400*(1-a7/300)end end;if a.currBuyingBasicItem=="item_aghanims_shard"then a.hasBuyShard=false;a1()return end;if a:GetGold()>=a5 and (a:GetItemInSlot(14)==nil or f.CountBackpackEmptySpace(a)>0)then if n==nil then n=a.theCourier end;if a.SecretShop and n~=nil and n:DistanceFromSecretShop()==0 then local a8=n:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)if a8==PURCHASE_ITEM_SUCCESS then a1()a.SecretShop=false;return elseif GetItemStockCount(a.currBuyingBasicItem)<1 then a1()a.SecretShop=false;return end end;if a.bPurchaseFromSecret and a:DistanceFromSecretShop()>0 then a.SecretShop=true else if f.CountBackpackEmptySpace(a)>0 or a:DistanceFromSecretShop()>700 then if a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)==PURCHASE_ITEM_SUCCESS then a1()a.SecretShop=false;return else if GetItemStockCount(a.currBuyingBasicItem)<1 then a1()a.SecretShop=false else local a9=a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)PLog("%s 未能购买物品 %s : %s",b,a.currBuyingBasicItem,a9)end end end end else a.SecretShop=false end end;local function aa()local a4=W()if not a4 then return end;a.currBuyingBasicItem=a4;if Y(a.currBuyingBasicItem)then return end;if a.lastItemToBuy~=a.currBuyingBasicItem then a.lastItemToBuy=a.currBuyingBasicItem;a:SetNextItemPurchaseValue(GetItemCost(a.currBuyingBasicItem))m=GetItemCost(a.currBuyingBasicItem)a.lastItemToBuy=a.currBuyingBasicItem end;if a.currBuyingBasicItem=="item_infused_raindrop"or a.currBuyingBasicItem=="item_tome_of_knowledge"then if GetItemStockCount(a.currBuyingBasicItem)<=0 then a1()return end end;local a5=m;if a.lastItemToBuy=='item_boots'and a.currBuyingItemInPurchaseList=='item_travel_boots'and c.HasBootsInMainSolt(a)then a5=GetItemCost('item_travel_boots')end;if not a.hasBuyShard and DotaTime()>8*60 then local a7=10*60-DotaTime()if a7<0 then a5=a5+1400 else a5=a5+1400*(1-a7/180)end end;if a.currBuyingBasicItem=="item_aghanims_shard"then a.hasBuyShard=false;a1()return end;if a:GetGold()>=a5 and (a:GetItemInSlot(14)==nil or f.CountBackpackEmptySpace(a)>0)then if a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)==PURCHASE_ITEM_SUCCESS then a1()return else if GetItemStockCount(a.currBuyingBasicItem)<1 then a1()else local a9=a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)PLog("%s 未能购买物品 %s : %s",b,a.currBuyingBasicItem,a9)end end end end;-- Magic Wand (and any future stick->wand-style upgrade) is bought as a
-- single combo token ("item_magic_wand") with no manual component mapping
-- in item.lua's GetBasicItems - that's normally fine since the native
-- ActionImmediate_PurchaseItem call is expected to auto-assemble the whole
-- recipe tree. In practice, observed matches (Dragon Knight, Ursa) ended up
-- stuck for 20+ minutes holding a completed Magic Stick plus the Magic Wand
-- upgrade recipe, but missing the 2 Iron Branches that recipe also needs
-- as direct siblings (separate from the branches already consumed building
-- the Stick itself) - the opportunistic partial-buy behavior apparently
-- doesn't circle back to finish that specific gap on its own. This is a
-- narrow, explicit top-up: whenever that exact stuck state is detected and
-- affordable, buy the missing branches directly.
-- Expanded: the original patch only covered "has Stick+Recipe, missing
-- branches". Real matches (Radiant Monkey King, Shadow Shaman) showed the
-- same stuck-partial-Wand pattern past minute 25 with other combinations
-- of missing pieces too (e.g. Recipe bought but Stick never finished), and
-- trickling one component per gold-check tick let a hero sit on a
-- half-bought Wand for a long time even when affordable. This now treats
-- "any partial Wand progress" as one atomic top-up: once gold covers the
-- ENTIRE remaining cost of every missing piece, buy them all back-to-back
-- in a single think-tick instead of one component at a time.
local function TryCompleteMagicWandUpgrade(bot, heroName)
    if bot:FindItemSlot('item_magic_wand') >= 0 then return end
    local hasStick = bot:FindItemSlot('item_magic_stick') >= 0
    local hasRecipe = bot:FindItemSlot('item_recipe_magic_wand') >= 0
    if not hasStick and not hasRecipe then return end
    local branches = 0
    for slot = 0, 8 do
        local slotItem = bot:GetItemInSlot(slot)
        if slotItem ~= nil and slotItem:GetName() == 'item_branches' then branches = branches + 1 end
    end
    local needed = {}
    if not hasStick then needed[#needed + 1] = 'item_magic_stick' end
    for i = branches + 1, 2 do needed[#needed + 1] = 'item_branches' end
    if not hasRecipe then needed[#needed + 1] = 'item_recipe_magic_wand' end
    if #needed == 0 then return end
    local totalCost = 0
    for _, itemName in ipairs(needed) do totalCost = totalCost + (GetItemCost(itemName) or 0) end
    if bot:GetGold() < totalCost then return end
    for _, itemName in ipairs(needed) do
        if GetItemStockCount(itemName) >= 1 then
            bot:ActionImmediate_PurchaseItem(itemName)
        end
    end
    PLog("[Purchase] %s completing Magic Wand upgrade atomically: %s", heroName, table.concat(needed, ','))
end
function ItemPurchaseThink()w=DotaTime()local ab,ac,ad=e.IsStaleARDMHero(a,b)if ab then return end;if ad~=b then if not ac:IsAlive()then return end;PLog("[ARDM] Item purchase: hero changed from %s to %s",b,ad)a=ac;b=ad;local ae=string.gsub(b,"npc_dota_","")local af,ag=pcall(dofile,GetScriptDirectory().."/BotsLib/"..ae)if af and ag~=nil and ag['sBuyList']~=nil then h=ag;i=ag['sBuyList']j=ag['sSellList']else i={}j={}end;local ah=c.HasBuyBoots(a)or c.HasItem(a,'item_guardian_greaves')or c.HasItem(a,'item_travel_boots')or c.HasItem(a,'item_travel_boots_2')or c.HasItem(a,'item_boots_of_bearing')local ai={item_boots=true,item_phase_boots=true,item_power_treads=true,item_tranquil_boots=true,item_arcane_boots=true}a.purchaseListInReverseOrder={}local aj=0;for k=#i,1,-1 do local H=i[k]local ak=false;if c.IsItemInHero(H)then ak=true elseif GetGameMode()==GAMEMODE_ARDM and DotaTime()>2*60 and Q[H]then ak=true elseif ah and ai[H]then ak=true end;if not ak then aj=aj+1;a.purchaseListInReverseOrder[aj]=H end end;PrioritizeBoots(a.purchaseListInReverseOrder)PrioritizeLateGameItems(a.purchaseListInReverseOrder)EnsureStartingRegen(a.purchaseListInReverseOrder)local al={}for O,H in ipairs(i)do al[H]=true;if c[H]~=nil then for O,am in pairs(c[H])do al[am]=true end end end;local an={item_aegis=true,item_rapier=true,item_gem=true,item_cheese=true,item_refresher_shard=true,item_moon_shard=true,item_tpscroll=true,item_famango=true,item_great_famango=true,item_greater_famango=true}local ao={}for J=0,14 do local ap=a:GetItemInSlot(J)if ap~=nil then local X=ap:GetName()if not an[X]and not al[X]and not string.find(X,'token')then table.insert(ao,{slot=J,name=X,cost=GetItemCost(X)})end end end;table.sort(ao,function(aq,ar)return aq.cost<ar.cost end)local as=3;for O,at in ipairs(ao)do local ap=a:GetItemInSlot(at.slot)if ap~=nil then if string.find(at.name,'recipe')or at.cost<1000 then a:ActionImmediate_SellItem(ap)PLog("[ARDM] Sold: %s (cost: %s)",at.name,at.cost)end end end;local au=0;for J=0,8 do if a:GetItemInSlot(J)~=nil then au=au+1 end end;local av=9-au;if av<as then for O,at in ipairs(ao)do if av>=as then break end;local ap=a:GetItemInSlot(at.slot)if ap~=nil then a:ActionImmediate_SellItem(ap)PLog("[ARDM] Sold (full inv): %s (cost: %s)",at.name,at.cost)av=av+1 end end end;a.currBuyingItemInPurchaseList=nil;a.currBuyingBasicItem=nil;a.currBuyingBasicItemList={}a.currBuyingBasicItemRefList={}a.currBuyingRequiredCounts=nil;a.rebuildCount=0;a.countInvCheck=0 end;if a.needPurchaseRebuild then a.needPurchaseRebuild=nil;local aw=e.GetPosition(a)PLog("[PosSwap] Item purchase rebuild for %s -> pos%s",b,aw)local ae=string.gsub(b,"npc_dota_","")local af,ag=pcall(dofile,GetScriptDirectory().."/BotsLib/"..ae)if af and ag~=nil and ag['sBuyList']~=nil then h=ag;i=ag['sBuyList']j=ag['sSellList']end;if i then local ah=c.HasBuyBoots(a)or c.HasItem(a,'item_guardian_greaves')or c.HasItem(a,'item_travel_boots')or c.HasItem(a,'item_travel_boots_2')or c.HasItem(a,'item_boots_of_bearing')local ai={item_boots=true,item_phase_boots=true,item_power_treads=true,item_tranquil_boots=true,item_arcane_boots=true}a.purchaseListInReverseOrder={}local aj=0;for k=#i,1,-1 do local H=i[k]local ak=false;if c.IsItemInHero(H)then ak=true elseif ah and ai[H]then ak=true elseif DotaTime()>10*60 and Q[H]then ak=true end;if not ak then aj=aj+1;a.purchaseListInReverseOrder[aj]=H end end;PrioritizeBoots(a.purchaseListInReverseOrder)PrioritizeLateGameItems(a.purchaseListInReverseOrder)EnsureStartingRegen(a.purchaseListInReverseOrder)end;a.currBuyingItemInPurchaseList=nil;a.currBuyingBasicItem=nil;a.currBuyingBasicItemList={}a.currBuyingBasicItemRefList={}a.currBuyingRequiredCounts=nil;a.rebuildCount=0;a.countInvCheck=0;PLog("[PosSwap] Purchase list rebuilt with %s items",#a.purchaseListInReverseOrder)end;if a.lastItemPurchaseFrameProcessTime==nil then a.lastItemPurchaseFrameProcessTime=w end;if w>30 and w-a.lastItemPurchaseFrameProcessTime<1 then return end;a.lastItemPurchaseFrameProcessTime=w;if GetGameState()~=GAME_STATE_PRE_GAME and GetGameState()~=GAME_STATE_GAME_IN_PROGRESS then return end;local _mwOk,_mwErr=pcall(TryCompleteMagicWandUpgrade,a,b)if not _mwOk then PLog("[ERROR] TryCompleteMagicWandUpgrade: %s",tostring(_mwErr))end;
if InventoryPolicy.Optimize(a)then return end
InventoryPolicy.SellObsoleteItems(a)
InventoryPolicy.SellRedundantBoots(a)
if a:IsIllusion()or a:HasModifier('modifier_arc_warden_tempest_double')or w>0 and e.IsMeepoClone(a)or a:HasModifier('modifier_dazzle_nothl_projection_soul_debuff')then
 a.purchaseListInReverseOrder={}return end;x=a:GetLevel()y=a:GetGold()z=a:GetNetWorth()A=a:GetActiveMode()B=e.GetHP(a)C=a:GetCourierValue()D=a:GetStashValue()E=a:DistanceFromFountain()local ax=GetDroppedItemList()for O,ay in pairs(ax)do if ay~=nil and ay.owner==a and ay.item~=nil and not string.find(ay.item:GetName(),'token')then local az=GetUnitToLocationDistance(a,ay.location)if az>200 and az<1000 then a:Action_MoveToLocation(ay.location)elseif az<=100 then a:Action_PickUpItem(ay.item)return end end end;if f.IsBear(a)and a:IsAlive()then local aA=f.GetLoneDruid(a).bearItemsMap or{}local aB=GetDroppedItemList()for O,aC in pairs(aB)do if aC.owner==f.GetLoneDruid(a).hero and aC.item~=nil and not string.find(aC.item:GetName(),'token')then local H=aC.item:GetName()if aA[H]and not c.HasItem(a,H)then local aD=GetUnitToLocationDistance(a,aC.location)if aD>100 and aD<1000 then a:Action_MoveToLocation(aC.location)return elseif aD<=100 then a:Action_PickUpItem(aC.item)return end end end end end;if d['supportExist']==nil then d.UpdateSupportStatus(a)end;if d['invisEnemyExist']==false then d.UpdateInvisEnemyStatus(a)end;if r==false and w>q+2.0 then r=c.HasBuyBoots(a)q=w end;if e.GetMP(a)<0.3 and E>2000 and C==0 and GetItemStockCount('item_clarity')>1 and c.GetItemCharges(a,'item_clarity')<=0 and y>=GetItemCost("item_clarity")then a.hasBuyClarity=true;a:ActionImmediate_PurchaseItem("item_clarity")end;if e.GetPosition(a)>=4 then if w>30 and not a.hasBuyClarity and y>=GetItemCost("item_clarity")and not d.IsPvNMode()and f.CountBackpackEmptySpace(a)>=2 then a.hasBuyClarity=true;a:ActionImmediate_PurchaseItem("item_clarity")elseif x>=5 and d['invisEnemyExist']==true and r==true and y>=GetItemCost("item_dust")and c.GetEmptyInventoryAmount(a)>=2 and c.GetItemCharges(a,"item_dust")<=0 and C==0 and not e.HasItem(a,'item_ward_sentry')then a:ActionImmediate_PurchaseItem("item_dust")end end;if e.IsInLaningPhase()and not string.find(b,'lone_druid')then if x<8 and a:IsAlive()and C==0 and a:FindItemSlot('item_flask')<0 and a:FindItemSlot('item_tango')<0 and E>2000 and D==0 and not a:HasModifier('modifier_elixer_healing')and not a:HasModifier('modifier_filler_heal')and not a:HasModifier('modifier_flask_healing')and not a:HasModifier('modifier_fountain_aura_buff')and not a:HasModifier('modifier_juggernaut_healing_ward_heal')and not a:HasModifier('modifier_warlock_shadow_word')and not IsThereHealingInStash(a)and c.GetEmptyInventoryAmount(a)>=1 and e.GetHP(a)<0.65 then local aE=e.GetLanePartner(a)if a:GetHealthRegen()<=10 then if e.IsCore(a)then if aE~=nil then if aE:FindItemSlot('item_flask')<0 and aE:FindItemSlot('item_tango')<0 and c.GetItemCharges(a,'item_flask')<=0 and y>=GetItemCost('item_flask')and GetItemStockCount('item_flask')>1 then a:ActionImmediate_PurchaseItem('item_flask')end else if c.GetItemCharges(a,'item_flask')<=0 and y>=GetItemCost('item_flask')and GetItemStockCount('item_flask')>1 and(not e.HasItem(a,'item_bottle')or e.HasItem(a,'item_bottle')and c.GetItemCharges(a,'item_bottle')<=0)then a:ActionImmediate_PurchaseItem('item_flask')end end else if c.GetItemCharges(a,'item_flask')<=0 and y>=GetItemCost('item_flask')and GetItemStockCount('item_flask')>1 then a:ActionImmediate_PurchaseItem('item_flask')end end else if e.IsCore(a)then if aE~=nil then if aE:FindItemSlot('item_flask')<0 and aE:FindItemSlot('item_tango')<0 and aE~=nil and c.GetItemCharges(a,'item_tango')<=0 and y>=GetItemCost('item_tango')and GetItemStockCount('item_flask')>1 then a:ActionImmediate_PurchaseItem('item_tango')end else if c.GetItemCharges(a,'item_flask')<=0 and GetItemStockCount('item_flask')>1 and y>=GetItemCost('item_flask')and(not e.HasItem(a,'item_bottle')or e.HasItem(a,'item_bottle')and c.GetItemCharges(a,'item_bottle')<=0)then a:ActionImmediate_PurchaseItem('item_flask')end end else if c.GetItemCharges(a,'item_tango')<=0 and y>=GetItemCost('item_tango')then a:ActionImmediate_PurchaseItem('item_tango')end end end end end;if e.GetPosition(a)==4 and DotaTime()>300 and z<25000 then local aF='item_ward_sentry'if GetItemStockCount(aF)>1 and y>=GetItemCost(aF)and c.GetEmptyInventoryAmount(a)>=2 and c.GetItemCharges(a,aF)<1 and C==0 then a:ActionImmediate_PurchaseItem(aF)end end;if e.GetPosition(a)==5 and z<25000 then local aF='item_ward_observer'if GetItemStockCount(aF)>1 and y>=GetItemCost(aF)and c.GetEmptyInventoryAmount(a)>=2 and c.GetItemCharges(a,aF)<2 and C==0 then a:ActionImmediate_PurchaseItem(aF)end end;if e.GetPosition(a)==5 and z<10000 and f.CountBackpackEmptySpace(a)>=2 and GetItemStockCount('item_smoke_of_deceit')>1 and y>=GetItemCost('item_smoke_of_deceit')and c.GetEmptyInventoryAmount(a)>=3 and c.GetItemCharges(a,'item_smoke_of_deceit')==0 and C==0 then if DotaTime()<0 and not v then local aG=false;for O,aH in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES))do if e.IsValidHero(aH)and e.IsNotSelf(a,aH)and e.HasItem(aH,'item_smoke_of_deceit')then aG=true end end;if not aG then a:ActionImmediate_PurchaseItem('item_smoke_of_deceit')end else if not e.IsInLaningPhase()then a:ActionImmediate_PurchaseItem('item_smoke_of_deceit')end end end;if e.IsInLaningPhase()and(e.GetPosition(a)==4 or e.GetPosition(a)==5)and GetItemStockCount('item_blood_grenade')>0 and x<5 and y>=GetItemCost('item_blood_grenade')and c.GetEmptyInventoryAmount(a)>=3 and c.GetItemCharges(a,'item_blood_grenade')==0 and D>0 then a:ActionImmediate_PurchaseItem('item_blood_grenade')end;if not a.hasBuyShard and GetItemStockCount("item_aghanims_shard")>0 and y>=1400 then a.hasBuyShard=true;a:ActionImmediate_PurchaseItem("item_aghanims_shard")end;if s==false and w<0 then s=true end;local aI=GetItemCost("item_tpscroll")if w>4*60 and C<=100 and y>=aI and not _()and b~="npc_dota_hero_meepo"and b~="npc_dota_hero_lone_druid_bear"then local a0=c.GetItemCharges(a,'item_tpscroll')if a:HasModifier("modifier_teleporting")then a0=a0-1 end;if a0<=0 or x>=18 and a0<=1 then if y>=aI*2 and w>25*60 then a:ActionImmediate_PurchaseItem("item_tpscroll")end;a:ActionImmediate_PurchaseItem("item_tpscroll")end end;if w>180 and w<1800 and a.switchTime<w-5.6 then local aJ=a:FindItemSlot("item_infused_raindrop")local aK=c.GetItemCharges(a,"item_infused_raindrop")local aL=e.GetNearbyHeroes(a,1600,true,BOT_MODE_NONE)if aJ>=0 and aJ<=5 and(aL[1]~=nil or A==BOT_MODE_ROSHAN or a:WasRecentlyDamagedByAnyHero(3.1))and(aK==1 or aK>=7)then a.switchTime=w;a:ActionImmediate_SwapItems(aJ,6)end end;if e.GetPosition(a)>=4 and w>(a._lastWardSwapTime or 0)+3 then local aM=A==BOT_MODE_WARD;local aN={'item_ward_observer','item_ward_sentry','item_ward_dispenser'}for O,aO in ipairs(aN)do local aP=a:FindItemSlot(aO)if aP>=0 then if aM then if aP>=6 and aP<=8 then for aQ=0,5 do local aR=a:GetItemInSlot(aQ)if aR==nil then a:ActionImmediate_SwapItems(aP,aQ)a._lastWardSwapTime=w;break end end end else if aP>=0 and aP<=5 then for aS=6,8 do local aT=a:GetItemInSlot(aS)if aT==nil then a:ActionImmediate_SwapItems(aP,aS)a._lastWardSwapTime=w;break end end end end end end end;if GetGameMode()~=23 and x>6 and w>a.fullInvCheck+1.0 or GetGameMode()==23 and x>9 and w>a.fullInvCheck+1.0 then local aU=c.GetEmptyInventoryAmount(a)local aV=nil;local aW=2;if x<=17 then aW=1 end;if not e.IsCore(a)and x>10 then aW=2 end;if aU<=aW-1 then for k=1,#c['tEarlyItem']do local H=c['tEarlyItem'][k]local aX=a:FindItemSlot(H)if aX>=0 and aX<=8 then aV=aX;break end end;if aV==nil and not e.IsCore(a)then for k=1,#c['tSupportSellWhenFull']do local H=c['tSupportSellWhenFull'][k]local aX=a:FindItemSlot(H)if aX>=0 and aX<=8 then aV=aX;break end end end end;if aV==nil and z>10000 and a:GetItemInSlot(6)~=nil and a:GetItemInSlot(7)~=nil then local aY=a:FindItemSlot("item_magic_wand")local aZ=a:FindItemSlot("item_infused_raindrop")if aZ<0 then aZ=a:FindItemSlot("item_bracer")end;if aZ<0 then aZ=a:FindItemSlot("item_null_talisman")end;if aZ<0 then aZ=a:FindItemSlot("item_wraith_band")end;if aZ>=0 and aY>=6 and aY<=8 then aV=aZ end end;if aV~=nil then a:ActionImmediate_SellItem(a:GetItemInSlot(aV))end;a.fullInvCheck=w end;local a_=f.CountBackpackEmptySpace(a)if w>a.sell_time+0.5 and a_<=1 and(E<=100 or a:DistanceFromSecretShop()<=100)then a.sell_time=w;SetPairedItems(c.sSellList)SetPairedItems(j)if z>23000 then if c.HasItem(a,"item_hand_of_midas")then a:ActionImmediate_SellItem(a:GetItemInSlot(a:FindItemSlot('item_hand_of_midas')))end end;if(w>18*60 or z>20000)and(c.HasItem(a,"item_travel_boots")or c.HasItem(a,"item_travel_boots_2"))then for k=1,#c['tEarlyBoots']do local b0=a:FindItemSlot(c['tEarlyBoots'][k])if b0>=0 then a:ActionImmediate_SellItem(a:GetItemInSlot(b0))end end end end;if c.HasItem(a,'item_mask_of_madness')and c.HasItem(a,'item_satanic')then a:ActionImmediate_SellItem(a:GetItemInSlot(a:FindItemSlot('item_mask_of_madness')))end;if w>30*60 and e.IsCore(a)then local b1={'item_famango','item_great_famango'}for O,b2 in ipairs(b1)do local J=a:FindItemSlot(b2)if J>=0 then a:Action_DropItem(a:GetItemInSlot(J),a:GetLocation())PLog("[Item] Core %s dropped %s (past 30min)",b,b2)end end end;if#a.purchaseListInReverseOrder==0 then a2()a:SetNextItemPurchaseValue(0)return end;local b3={item_boots=true}if a.currBuyingItemInPurchaseList==nil and#a.currBuyingBasicItemList==0 then while#a.purchaseListInReverseOrder>0 do local b4=a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]if b3[b4]and(c.HasBuyBoots(a)or c.HasItem(a,'item_guardian_greaves')or c.HasItem(a,'item_travel_boots')or c.HasItem(a,'item_travel_boots_2')or c.HasItem(a,'item_boots_of_bearing'))then PLog("[Purchase] Skipping %s — already have boots",b4)a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]=nil else break end end;if#a.purchaseListInReverseOrder==0 then a2()a:SetNextItemPurchaseValue(0)return end;a.currBuyingItemInPurchaseList=a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]local b5=c.GetBasicItems({a.currBuyingItemInPurchaseList})for k=1,math.ceil(#b5/2)do a.currBuyingBasicItemList[k]=b5[#b5-k+1]a.currBuyingBasicItemList[#b5-k+1]=b5[k]end;a.currBuyingBasicItemRefList=f.Deepcopy(a.currBuyingBasicItemList)a.currBuyingRequiredCounts=L(a.currBuyingBasicItemRefList)W()end;if#a.currBuyingBasicItemList==0 then if c.IsItemInHero(a.currBuyingItemInPurchaseList)or a.currBuyingItemInPurchaseList=="item_aghanims_shard"or a==f.GetLoneDruid(a).hero and f.GetLoneDruid(a).bear~=nil and c.GetItemTotalWorthInSlots(f.GetLoneDruid(a).bear)<28000 and c.IsItemInTargetHero(a.currBuyingItemInPurchaseList,f.GetLoneDruid(a).bear)or a.countInvCheck>(GetGameMode()==GAMEMODE_ARDM and 30 or 30)or a.rebuildCount>=5 and C==0 and D==0 and a:GetGold()>=GetItemCost(a.currBuyingItemInPurchaseList)*0.5 then if a.countInvCheck>0 or a.rebuildCount>=5 then
local _refNames=""
for _rk=1,#(a.currBuyingBasicItemRefList or{})do _refNames=_refNames..tostring(a.currBuyingBasicItemRefList[_rk])..","end
PLog("[Purchase] %s skipping stuck item %s (rebuilds=%d invCheck=%d alreadyOwned=%s gold=%d courier=%d stash=%d needed=[%s])",b,tostring(a.currBuyingItemInPurchaseList),a.rebuildCount,a.countInvCheck,tostring(c.IsItemInHero(a.currBuyingItemInPurchaseList)),a:GetGold(),C,D,_refNames)
-- Before permanently deleting this item from the build, take one direct
-- shot at it via the raw shop purchase call instead of our own component
-- breakdown - real matches showed several combo items (Glimmer Cape,
-- Guardian Greaves, Aether Lens, Null Talisman, Manta, even the trivial
-- item_double_branches token) getting abandoned this way despite nothing
-- actually blocking them, which points at our basic-items tracking
-- occasionally reporting an item complete/empty when it isn't rather than
-- every one of these having its own genuine recipe gap like Magic Wand
-- did. A raw ActionImmediate_PurchaseItem call auto-assembles the whole
-- recipe tree the same way a human shop click does, sidestepping whatever
-- tracking state got confused, so it's worth trying once before giving up.
if not c.IsItemInHero(a.currBuyingItemInPurchaseList)and a.currBuyingItemInPurchaseList~="item_aghanims_shard"and a:GetGold()>=GetItemCost(a.currBuyingItemInPurchaseList)and GetItemStockCount(a.currBuyingItemInPurchaseList)>=1 then
local bc=a:ActionImmediate_PurchaseItem(a.currBuyingItemInPurchaseList)
if bc==PURCHASE_ITEM_SUCCESS then PLog("[Purchase] %s stuck-item fallback succeeded: bought %s directly",b,tostring(a.currBuyingItemInPurchaseList))end
end
end;a.countInvCheck=0;a2()a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]=nil elseif w>a.lastInvCheck+1.0 then a.lastInvCheck=w;if C>0 or D>0 then a.countInvCheck=0 elseif a.rebuildCount<5 and b~="npc_dota_hero_lone_druid"then a.rebuildCount=a.rebuildCount+1;for J=0,14 do local b6=a:GetItemInSlot(J)if b6 then local b7=b6:GetName()if string.find(b7,'recipe')then local b8=string.gsub(b7,'item_recipe_','item_')if b8==a.currBuyingItemInPurchaseList then local b9=c[b8]or c.GetComponentList(b8)if b9 and#b9>0 then for O,am in pairs(b9)do if not string.find(am,'recipe')and not c.IsItemInHero(am)then table.insert(a.currBuyingBasicItemList,1,am)end end;if#a.currBuyingBasicItemList>0 then a.currBuyingRequiredCounts=L(a.currBuyingBasicItemList)break end end end end end end;local ba=c.GetReducedPurchaseList(a,a.currBuyingBasicItemRefList)for O,bb in pairs(ba)do if not c.IsItemInHero(bb)then a.currBuyingBasicItemList[#a.currBuyingBasicItemList+1]=bb end end;a.currBuyingRequiredCounts=L(a.currBuyingBasicItemList)W()else a.countInvCheck=a.countInvCheck+1 end end elseif#a.currBuyingBasicItemList>0 then if a.currBuyingBasicItem==nil then a.currBuyingBasicItem=W()else if GetGameMode()==23 then aa()else a3()end end end end;function SetPairedItems(bc)for k=2,#bc,2 do local bd=a:FindItemSlot(bc[k-1])local be=a:FindItemSlot(bc[k])if bd>=0 and be>=0 then a:ActionImmediate_SellItem(a:GetItemInSlot(be))end end end;function IsThereHealingInStash(G)local bf=0;for k=9,14 do local ap=G:GetItemInSlot(k)if ap~=nil then if string.find(ap:GetName(),'item_flask')or string.find(ap:GetName(),'item_tango')or string.find(ap:GetName(),'item_bottle')then bf=bf+1 end end end;return bf>0 end;g.ItemPurchaseThink=ItemPurchaseThink;return g
