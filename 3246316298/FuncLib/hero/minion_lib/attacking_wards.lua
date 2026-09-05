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
function c.Think(d,e)local f=e:GetAttackRange()if f==nil or f<400 then f=500 end;local g=b.GetWeakestHero(f,e)if g==nil then g=b.GetWeakestControlledMinion(f,e)end;if g==nil then local h=b.GetWeakestTower(math.max(f,900),e)if h~=nil and not b.IsNotAllowedToAttack(h)then if GetUnitToUnitDistance(e,h)<=f then g=h else e:Action_MoveToLocation(h:GetLocation())return end end end;if g==nil then g=b.GetWeakestCreep(f,e)end;if g==nil or b.IsNotAllowedToAttack(g)then return end;if e._lastWardTarget==g and e:GetAttackTarget()==g then return end;e._lastWardTarget=g;e:Action_AttackUnit(g,false)end;return c