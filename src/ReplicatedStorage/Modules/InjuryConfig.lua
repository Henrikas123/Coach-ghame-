-- ModuleScript: ReplicatedStorage/Modules/InjuryConfig
-- Banga 2, #4: traumų sistema -- rizika susižeisti po kovos, pasyvus pagijimas laikui bėgant,
-- ir mokamas pagreitinimas per "Poilsio kambarį" (Recovery Room).

local InjuryConfig = {}

InjuryConfig.ChanceOnFightWin = 0.05
InjuryConfig.ChanceOnFightLoss = 0.18
-- Papildoma rizika kai fatigue kovos metu buvo aukštas -- skalė 0..1 (fatiguePenalty / FightConfig.FatiguePenaltyMax)
-- padauginta iš šio maksimumo.
InjuryConfig.FatigueChanceBonusMax = 0.15

InjuryConfig.MinRecoverySeconds = 180 -- 3 min
InjuryConfig.MaxRecoverySeconds = 600 -- 10 min
InjuryConfig.PassiveRecoveryPerTick = 40 -- sekundžių sumažėjimas kas 60s (TrainingHandler pasyvus ciklas)

InjuryConfig.RecoveryRoomCost = 40
InjuryConfig.RecoveryRoomReduceSeconds = 240
InjuryConfig.RecoveryRoomCooldown = 60 -- sek. tarp Poilsio kambario panaudojimų tam pačiam nariui

-- Grubi sunkumo etiketė pagal likusį pagijimo laiką (vien UI/pranešimams, nekeičia mechanikos)
function InjuryConfig.severityLabel(recoverySeconds)
	local s = recoverySeconds or 0
	if s >= 420 then
		return "Severe injury"
	elseif s >= 240 then
		return "Moderate injury"
	else
		return "Minor injury"
	end
end

return InjuryConfig
