--[[
	OneLostHero — talent classes.

	Custom special_bonus abilities won't instantiate post-patch without a real entity class
	(the engine logs "entity class is NULL" and AddAbility returns nil). Backing them with
	BaseClass "ability_lua" gives them a valid class so they register and can be learned.

	The talents have no behavior of their own: the value talents apply via the affected
	ability's AbilityValues value-block links (e.g. "special_bonus_unique_onelosthero_explosion"
	"+80"), and the behavior talents (charges, fear pierce) are read elsewhere via
	FindAbilityByName(...):GetLevel(). So these are intentionally empty classes.
]]

special_bonus_unique_onelosthero_invis         = class({})
special_bonus_unique_onelosthero_second_stroke = class({})
special_bonus_unique_onelosthero_explosion     = class({})
special_bonus_unique_onelosthero_charges       = class({})
special_bonus_unique_onelosthero_silence       = class({})
special_bonus_unique_onelosthero_fear_pierce   = class({})
special_bonus_unique_onelosthero_break         = class({})
