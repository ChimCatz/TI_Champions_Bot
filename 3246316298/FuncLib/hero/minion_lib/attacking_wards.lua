local a=require(GetScriptDirectory()..'/FuncLib/func_utils')local b=require(GetScriptDirectory()..'/FuncLib/hero/minion_lib/utils')local c={}
-- Hierarchy: enemy heroes -> enemy-controlled summons (familiars, dominated
-- creeps, treants, etc.) -> towers/buildings -> plain enemy creeps. Previously
-- towers were checked last, behind ALL creeps, so a ward sitting near a
-- tower with nothing else in its short attack range just stayed idle.
function c.Think(d,e)local f=e:GetAttackRange()if f==nil or f<400 then f=500 end;local g=b.GetWeakestHero(f,e)if g==nil then g=b.GetWeakestControlledMinion(f,e)end;if g==nil then g=b.GetWeakestTower(f,e)end;if g==nil then g=b.GetWeakestCreep(f,e)end;if g==nil or b.IsNotAllowedToAttack(g)then return end;if e._lastWardTarget==g and e:GetAttackTarget()==g then return end;e._lastWardTarget=g;e:Action_AttackUnit(g,false)end;return c