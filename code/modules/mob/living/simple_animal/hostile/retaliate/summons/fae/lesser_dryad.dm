/// A lesser dryad bound to a sanctified tree by the Dendor soulbind ritual.
/// Differs from the regular dryad:
///   - Does not spread vines passively
///   - No inherent vine-create spell
///   - Special attack (triggered by player's summon_lesser_dryad spell):
///       kneestingers on all 4 cardinals + 5×5 solid vine field around self
///   - Lighter, lower health than the full dryad
/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser
	name = "lesser dryad"
	health = 300
	maxHealth = 300
	melee_damage_lower = 12
	melee_damage_upper = 18
	aggressive = FALSE
	inherent_spells = list()
	/// Cooldown for the special attack (set by the trigger spell).
	var/special_cd = 0
	/// The conjuring player's ckey — used for faction tagging.
	var/conjurer_ckey = null
	/// Back-reference to the spell instance that summoned this dryad.
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/summoner_spell

/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/Initialize(mapload, mob/living/carbon/human/owner)
	. = ..()
	faction |= "neutral"
	if(owner)
		conjurer_ckey = owner.ckey
		// Tag with owner faction so minion_order/lesser_dryad can command it.
		var/faction_tag = "[owner.real_name]_faction"
		faction |= faction_tag

/// Override vine() to do nothing — lesser dryad does not spread vines passively.
/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/vine()
	return

/// Special attack: kneestingers on all 4 cardinal tiles + 5×5 solid vine area.
/// Called by /obj/effect/proc_holder/spell/targeted/lesser_dryad_special when the
/// caster targets a turf within range of their lesser dryad.
/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/proc/dryad_surge(turf/surge_turf)
	if(world.time < special_cd + 20 SECONDS)
		return FALSE
	special_cd = world.time
	visible_message(span_boldwarning("[src] raises its arms — thorns and vines heed the call!"))
	playsound(get_turf(src), 'sound/magic/churn.ogg', 60, TRUE)
	var/turf/T = surge_turf || get_turf(src)
	if(!T)
		return FALSE
	// Kneestingers on cardinal tiles
	for(var/D in GLOB.cardinals)
		var/turf/adj = get_step(T, D)
		if(adj && !isclosedturf(adj) && !locate(/obj/structure/glowshroom) in adj)
			new /obj/structure/glowshroom(adj)
	// 5×5 solid vine field (RANGE_TURFS(2) = 5×5 area)
	for(var/turf/V in RANGE_TURFS(2, T))
		if(!isclosedturf(V) && !locate(/obj/structure/vine) in V)
			new /obj/structure/vine(V)
	return TRUE

/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/death(gibbed)
	visible_message(span_boldwarning("[src] dissolves into greenish light..."))
	playsound(get_turf(src), 'sound/items/dig_shovel.ogg', 70, TRUE)
	if(summoner_spell)
		summoner_spell.on_dryad_deleted(src)
	spill_embedded_objects()
	qdel(src)
