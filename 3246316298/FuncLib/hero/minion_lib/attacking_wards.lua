local a=require(GetScriptDirectory()..'/FuncLib/func_utils')local b=require(GetScriptDirectory()..'/FuncLib/hero/minion_lib/utils')local c={}
-- Hierarchy: enemy heroes -> enemy-controlled summons (familiars, dominated
-- creeps, treants, etc.) -> towers/buildings -> plain enemy creeps. Previously
-- towers were checked last, behind ALL creeps, so a ward sitting near a
-- tower with nothing else in its short attack range just stayed idle.
-- Tower detection also used to be capped at the ward's own attack range, so
-- a tower that was genuinely nearby but a little outside that short range
-- (say a Serpent Ward planted just behind the wave) was never even
-- considered, let alone approached - the ward just stood still. Detection
-- now looks further than the attack range and walks the ward in if a tower
-- is found but not yet in range.
-- Previous version measured raw center-to-center distance against the
-- ward's own short attack range to decide whether to Action_AttackUnit vs.
-- Action_MoveToLocation at a tower. That never accounts for the tower's
-- large hull radius, so a ward standing right next to a tower (genuinely
-- in attack range per the engine) could still read as "too far" by that
-- raw distance check and just walk in place forever without ever
-- attacking - matches the reported "tower is the only attackable target
-- but the ward never fires" case. Action_AttackUnit already walks a unit
-- into range and then attacks on its own (every other target type here -
-- heroes/minions/creeps - already relies on exactly that instead of a
-- manual distance check), so towers now use the same call with no special
-- casing at all.
local _lastWardLog={}
function c.Think(d,e)local f=e:GetAttackRange()if f==nil or f<400 then f=500 end;local g=b.GetWeakestHero(f,e)if g==nil then g=b.GetWeakestControlledMinion(f,e)end;local _towerNearby=nil;if g==nil then local h=b.GetWeakestTower(math.max(f,900),e)_towerNearby=h;if h~=nil and not b.IsNotAllowedToAttack(h)then g=h end end;if g==nil then g=b.GetWeakestCreep(f,e)end;
do local now=DotaTime()local key=tostring(e)if now>=(_lastWardLog[key]or-1e9)+10 then _lastWardLog[key]=now;print('[TICB-WARD] '..tostring(e:GetUnitName())..' target='..tostring(g and g:GetUnitName())..' towerSeen='..tostring(_towerNearby~=nil and _towerNearby:GetUnitName()))end end;
if g==nil or b.IsNotAllowedToAttack(g)then return end;if e._lastWardTarget==g and e:GetAttackTarget()==g then return end;e._lastWardTarget=g;e:Action_AttackUnit(g,false)end;return c