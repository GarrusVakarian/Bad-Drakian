// Druid
/obj/effect/proc_holder/spell/targeted/blesscrop
	name = "Bless Crops"
	desc = "Bless a targeted soil plot or tree. Holy skill increases stored charges. Revives dead plants, gives them nutrition and water if low & boosts their growth. Blessed seed powder can expend all charges to bless up to five nearby planted soils at once."
	range = 5
	selection_type = "range"
	overlay_state = "blesscrop"
	releasedrain = 30
	charge_type = "charges"
	recharge_time = 1
	req_items = list(/obj/item/clothing/neck/roguetown/psicross)
	max_targets = 1
	cast_without_targets = FALSE
	sound = 'sound/magic/churn.ogg'
	associated_skill = /datum/skill/magic/holy
	invocations = list("The Treefather commands thee, be fruitful!")
	invocation_type = "shout" //can be none, whisper, emote and shout
	miracle = TRUE
	devotion_cost = 20
	var/max_bless_charges = 1
	var/charge_regen_elapsed = 0
	var/empty_refill_elapsed = 0
	var/empty_refill_active = FALSE
	var/active_sound = null

/obj/effect/proc_holder/spell/targeted/blesscrop/update_icon()
	if(!action)
		return
	action.button_icon_state = "[base_icon_state][active]"
	if(overlay_state)
		action.overlay_state = overlay_state
	action.name = name
	action.UpdateButtonIcon()

/obj/effect/proc_holder/spell/targeted/blesscrop/Click()
	var/mob/living/user = usr
	if(!istype(user))
		return
	if(!can_cast(user))
		deactivate(user)
		return
	if(active)
		deactivate(user)
	else
		if(active_sound)
			user.playsound_local(user, active_sound, 100, vary = FALSE)
		active = TRUE
		add_ranged_ability(user, null, TRUE)
	update_icon()

/obj/effect/proc_holder/spell/targeted/blesscrop/deactivate(mob/living/user)
	active = FALSE
	remove_ranged_ability(null)
	update_icon()

/obj/effect/proc_holder/spell/targeted/blesscrop/InterceptClickOn(mob/living/caller, params, atom/target)
	. = ..()
	if(.)
		return TRUE
	if(ismob(target))
		to_chat(caller, span_warning("Bless Crops must be aimed at a tree, long log, or soil plot."))
		return TRUE
	if(!can_cast(caller) || !cast_check(FALSE, ranged_ability_user))
		return TRUE
	if(perform(list(target), TRUE, user = ranged_ability_user))
		return TRUE
	return TRUE

/obj/effect/proc_holder/spell/targeted/blesscrop/Initialize(mapload)
	. = ..()
	charge_counter = 1
	max_bless_charges = 1

/obj/effect/proc_holder/spell/targeted/blesscrop/proc/get_max_bless_charges(mob/user)
	if(!user)
		return max(1, max_bless_charges)
	return max(1, 1 + user.get_skill_level(associated_skill))

/obj/effect/proc_holder/spell/targeted/blesscrop/proc/sync_bless_charges(mob/user)
	max_bless_charges = get_max_bless_charges(user)
	if(!empty_refill_active)
		charge_counter = clamp(charge_counter, 0, max_bless_charges)

/obj/effect/proc_holder/spell/targeted/blesscrop/proc/start_empty_refill()
	if(empty_refill_active)
		return
	empty_refill_active = TRUE
	empty_refill_elapsed = 0
	charge_regen_elapsed = 0
	charge_counter = 0
	START_PROCESSING(SSfastprocess, src)
	if(action)
		action.UpdateButtonIcon()

/obj/effect/proc_holder/spell/targeted/blesscrop/proc/spend_all_bless_charges()
	charge_counter = 0
	start_empty_refill()

/obj/effect/proc_holder/spell/targeted/blesscrop/charge_check(mob/user, silent = FALSE)
	sync_bless_charges(user)
	if(empty_refill_active || charge_counter <= 0)
		if(!empty_refill_active)
			start_empty_refill()
		if(!silent)
			to_chat(user, span_warning("[name] is exhausted and must recover before it can be used again."))
		return FALSE
	return TRUE

/obj/effect/proc_holder/spell/targeted/blesscrop/start_recharge()
	START_PROCESSING(SSfastprocess, src)

/obj/effect/proc_holder/spell/targeted/blesscrop/process()
	if(empty_refill_active)
		empty_refill_elapsed += 2
		if(empty_refill_elapsed >= 30 SECONDS)
			empty_refill_active = FALSE
			empty_refill_elapsed = 0
			charge_regen_elapsed = 0
			charge_counter = max_bless_charges
			if(action)
				action.UpdateButtonIcon()
			STOP_PROCESSING(SSfastprocess, src)
		return
	if(charge_counter < max_bless_charges)
		charge_regen_elapsed += 2
		while(charge_regen_elapsed >= 10 SECONDS && charge_counter < max_bless_charges)
			charge_regen_elapsed -= 10 SECONDS
			charge_counter++
		if(action)
			action.UpdateButtonIcon()
		if(charge_counter >= max_bless_charges)
			charge_counter = max_bless_charges
			STOP_PROCESSING(SSfastprocess, src)
		return
	STOP_PROCESSING(SSfastprocess, src)

/obj/effect/proc_holder/spell/targeted/blesscrop/after_cast(list/targets, mob/user = usr)
	. = ..()
	sync_bless_charges(user)
	if(active)
		add_ranged_ability(user, null, TRUE)
	if(charge_counter <= 0)
		start_empty_refill()
	else
		empty_refill_active = FALSE
		empty_refill_elapsed = 0
		charge_regen_elapsed = 0
		START_PROCESSING(SSfastprocess, src)

/obj/effect/proc_holder/spell/targeted/blesscrop/revert_cast(mob/user = usr)
	. = ..()
	sync_bless_charges(user)
	if(active)
		add_ranged_ability(user, null, TRUE)
	empty_refill_active = FALSE
	empty_refill_elapsed = 0
	if(charge_counter < max_bless_charges)
		START_PROCESSING(SSfastprocess, src)

/obj/effect/proc_holder/spell/targeted/blesscrop/cast(list/targets,mob/user = usr)
	. = ..()
	var/atom/target_atom = targets?.len ? targets[1] : null
	var/turf/target_turf = get_turf(target_atom)
	sync_bless_charges(user)
	if(!target_turf)
		target_turf = get_turf(user)
	var/list/target_long_logs = list()
	for(var/obj/item/grown/log/tree/log in target_turf)
		if(log.type == /obj/item/grown/log/tree)
			target_long_logs += log
	var/obj/item/alch/blessedseedpowder/blessed_seed_powder = user.get_active_held_item()
	if(!istype(blessed_seed_powder))
		blessed_seed_powder = user.get_inactive_held_item()
	if(!istype(blessed_seed_powder))
		blessed_seed_powder = null
	// Detect a held bucket or mortar containing holy water for log blessing.
	var/obj/item/reagent_containers/water_container = null
	for(var/obj/item/held in list(user.get_active_held_item(), user.get_inactive_held_item()))
		if(held?.reagents && (istype(held, /obj/item/reagent_containers/glass/bucket) || istype(held, /obj/item/reagent_containers/glass/mortar)))
			if(held.reagents.get_reagent_amount(/datum/reagent/water/blessed) >= 2)
				water_container = held
				break

	// Targeted long-log blessing: consume blessed seed powder + all holy water in held mortar/bucket,
	// and bless up to 6 long logs on the targeted tile.
	if(target_long_logs.len || istype(target_atom, /obj/item/grown/log/tree))
		if(istype(target_atom, /obj/item/grown/log/tree) && target_atom.type != /obj/item/grown/log/tree)
			to_chat(user, span_warning("Only long logs can be blessed by this rite."))
			return FALSE
		if(!target_long_logs.len)
			to_chat(user, span_warning("There are no large logs at that location to sanctify."))
			return FALSE
		if(!blessed_seed_powder)
			to_chat(user, span_warning("I need blessed seed powder in-hand to sanctify logs."))
			return FALSE
		if(!water_container)
			to_chat(user, span_warning("I need a stone mortar or bucket with blessed water in-hand to sanctify logs."))
			return FALSE
		var/blessed_amt = water_container.reagents.get_reagent_amount(/datum/reagent/water/blessed)
		if(blessed_amt < 1)
			to_chat(user, span_warning("My container has no blessed water to fuel the blessing."))
			return FALSE
		var/blessed_logs = 0
		for(var/obj/item/grown/log/tree/log in target_long_logs)
			if(!log.bless_log())
				continue
			blessed_logs++
			if(blessed_logs >= 6)
				break
		if(blessed_logs <= 0)
			to_chat(user, span_warning("There are no unblessed long logs here to sanctify."))
			return FALSE
		water_container.reagents.remove_reagent(/datum/reagent/water/blessed, blessed_amt)
		qdel(blessed_seed_powder)
		visible_message(span_green("[usr] sanctifies the long logs with Dendor's favor!"))
		return TRUE

	// Soil plots are now blessed one-by-one unless blessed seed powder is used to bypass it.
	var/obj/structure/soil/target_soil = null
	if(istype(target_atom, /obj/structure/soil))
		target_soil = target_atom
	else
		target_soil = locate(/obj/structure/soil) in target_turf
	if(target_soil)
		if(target_soil.blessed_time > 0 && !blessed_seed_powder)
			to_chat(user, span_warning("That soil is already blessed. It can be blessed again in [DisplayTimeText(target_soil.blessed_time)]."))
			revert_cast(user)
			return FALSE
		if(blessed_seed_powder)
			var/amount_blessed = 0
			for(var/obj/structure/soil/soil in range(4, user))
				if(!soil.plant)
					continue
				soil.bless_soil()
				amount_blessed++
				if(amount_blessed >= 5)
					break
			if(amount_blessed <= 0)
				to_chat(user, span_warning("There are no nearby planted soil plots for the powder to bless."))
				return FALSE
			qdel(blessed_seed_powder)
			spend_all_bless_charges()
			visible_message(span_green("[usr] scatters blessed seed powder and Dendor's favor refreshes nearby crops!"))
			return TRUE
		target_soil.bless_soil()
		visible_message(span_green("[usr] blesses [target_soil] with Dendor's favor!"))
		return TRUE

	// Non-soil target mode: bless exactly what was targeted.
	if(istype(target_atom, /obj/structure/flora/roguetree))
		var/obj/structure/flora/roguetree/tree = target_atom
		if(blessed_seed_powder && tree.reinvigorate_tree(user))
			if(blessed_seed_powder == user.get_active_held_item() || blessed_seed_powder == user.get_inactive_held_item())
				qdel(blessed_seed_powder)
			visible_message(span_green("[usr] invokes Dendor's favor upon [tree]."))
			return TRUE
		if(tree.bless_tree(user))
			visible_message(span_green("[usr] invokes Dendor's favor upon [tree]."))
			return TRUE
	if(istype(target_atom, /obj/structure/flora/newtree))
		var/obj/structure/flora/newtree/tree = target_atom
		if(tree.bless_tree(user))
			visible_message(span_green("[usr] invokes Dendor's favor upon [tree]."))
			return TRUE

	to_chat(user, span_warning("That target cannot receive this blessing."))
	return FALSE

//At some point, this spell should Awaken beasts, allowing a ghost to possess them. Not for this PR though.
/obj/effect/proc_holder/spell/targeted/beasttame
	name = "Tame Beast"
	desc = "Tames a targeted saiga, chicken, cow, goat, volf or spider to be non hostile and tamed."
	range = 5
	overlay_state = "tamebeast"
	releasedrain = 30
	recharge_time = 30 SECONDS
	req_items = list(/obj/item/clothing/neck/roguetown/psicross)
	max_targets = 0
	cast_without_targets = TRUE
	sound = 'sound/magic/churn.ogg'
	associated_skill = /datum/skill/magic/holy
	invocations = list("Be still and calm, brotherbeast.")
	invocation_type = "whisper" //can be none, whisper, emote and shout
	miracle = TRUE
	devotion_cost = 20
	var/beast_tameable_factions = list("saiga", "chickens", "cows", "goats", "wolfs", "spiders")

/obj/effect/proc_holder/spell/targeted/beasttame/cast(list/targets,mob/user = usr)
	. = ..()
	visible_message(span_green("[usr] soothes the beastblood with Dendor's whisper."))
	var/tamed = FALSE
	for(var/mob/living/simple_animal/hostile/retaliate/animal in get_hearers_in_view(2, usr))
		if((animal.mob_biotypes & MOB_UNDEAD))
			continue
		if(faction_check(animal.faction, beast_tameable_factions))
			animal.tamed(TRUE)
			animal.aggressive = FALSE
			if(animal.ai_controller)
				animal.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
				animal.ai_controller.clear_blackboard_key(BB_BASIC_MOB_RETALIATE_LIST)
				animal.ai_controller.set_blackboard_key(BB_BASIC_MOB_TAMED, TRUE)
			to_chat(usr, "With Dendor's aide, you soothe [animal] of their anger.")
	return tamed

/obj/effect/proc_holder/spell/targeted/conjure_glowshroom
	name = "Fungal Illumination"
	desc = "Summons glowing mushrooms that shock people that try moving into them. Dendorites are immune."
	range = 1
	action_icon_state = "glowshroom"
	action_icon = 'icons/mob/actions/genericmiracles.dmi'
	overlay_state = "blesscrop"
	releasedrain = 30
	recharge_time = 30 SECONDS
	chargetime = 1 SECONDS
	req_items = list(/obj/item/clothing/neck/roguetown/psicross)
	max_targets = 0
	cast_without_targets = TRUE
	sound = 'sound/items/dig_shovel.ogg'
	associated_skill = /datum/skill/magic/holy
	invocations = list("Treefather light the way.")
	invocation_type = "whisper" //can be none, whisper, emote and shout
	devotion_cost = 30

/obj/effect/proc_holder/spell/targeted/conjure_glowshroom/cast(list/targets, mob/user = usr)
	. = ..()

	to_chat(user, span_notice("I begin enriching the soil around me!"))
	if(!do_after(user, 0.5 SECONDS, progress = TRUE))
		revert_cast()
		return FALSE

	// Spawn a 3x1 line across the tile in front of the caster.
	var/turf/center_turf = get_step(user, user.dir)
	var/list/spawn_turfs = list(get_step(center_turf, turn(user.dir, 90)), center_turf, get_step(center_turf, turn(user.dir, -90)))
	for(var/turf/spawn_turf as anything in spawn_turfs)
		if(!istype(spawn_turf))
			continue
		if(!isclosedturf(spawn_turf) && !locate(/obj/structure/glowshroom) in spawn_turf)
			new /obj/structure/glowshroom(spawn_turf)
	return TRUE

/obj/effect/proc_holder/spell/targeted/conjure_vines
	name = "Vine Sprout"
	desc = "Summon vines nearby."
	overlay_state = "blesscrop"
	releasedrain = 90
	invocations = list("Treefather, bring forth vines.")
	invocation_type = "shout"
	devotion_cost = 30
	range = 1
	recharge_time = 30 SECONDS
	req_items = list(/obj/item/clothing/neck/roguetown/psicross)
	max_targets = 0
	cast_without_targets = TRUE
	sound = 'sound/items/dig_shovel.ogg'
	associated_skill = /datum/skill/magic/holy
	miracle = TRUE

/obj/effect/proc_holder/spell/targeted/conjure_vines/cast(list/targets, mob/user = usr)
	. = ..()
	var/turf/target_turf = get_step(user, user.dir)
	var/turf/target_turf_two = get_step(target_turf, turn(user.dir, 90))
	var/turf/target_turf_three = get_step(target_turf, turn(user.dir, -90))
	if(!locate(/obj/structure/vine/dendor) in target_turf)
		new /obj/structure/vine/dendor(target_turf)
	if(!locate(/obj/structure/vine/dendor) in target_turf_two)
		new /obj/structure/vine/dendor(target_turf_two)
	if(!locate(/obj/structure/vine/dendor) in target_turf_three)
		new /obj/structure/vine/dendor(target_turf_three)

	return TRUE

/obj/effect/proc_holder/spell/self/howl/call_of_the_moon
	name = "Call of the Moon"
	desc = "Draw upon the the secrets of the hidden firmament to converse with the mooncursed."
	overlay_state = "howl"
	antimagic_allowed = FALSE
	recharge_time = 600
	ignore_cockblock = TRUE
	use_language = TRUE
	var/first_cast = FALSE

/obj/effect/proc_holder/spell/self/howl/call_of_the_moon/cast(mob/living/carbon/human/user)
	// only usable at night
	if (!GLOB.tod == "night")
		to_chat(user, span_warning("I must wait for the hidden moon to rise before I may call upon it."))
		revert_cast()
		return
	// if they don't have beast language somehow, give it to them
	if (!user.has_language(/datum/language/beast))
		user.grant_language(/datum/language/beast)
		to_chat(user, span_boldnotice("The vestige of the hidden moon high above reveals His truth: the knowledge of beast-tongue was in me all along."))

	if (!first_cast)
		to_chat(user, span_boldwarning("So it is murmured in the Earth and Air: the Call of the Moon is sacred, and to share knowledge gleaned from it with those not of Him is a SIN."))
		to_chat(user, span_boldwarning("Ware thee well, child of Dendor."))
		first_cast = TRUE
	. = ..()

/obj/effect/proc_holder/spell/invoked/spiderspeak
	name = "Spider Speak"
	desc = "Makes spiders not attack the target."
	overlay_state = "tamebeast"
	releasedrain = 15
	chargedrain = 0
	chargetime = 1 SECONDS
	range = 2
	warnie = "sydwarning"
	movement_interrupt = FALSE
	sound = 'sound/magic/churn.ogg'
	invocations = list("Spiders of Psydonia, allow me to pass safely!")
	invocation_type = "shout"
	associated_skill = /datum/skill/magic/holy
	recharge_time = 4 SECONDS
	miracle = TRUE
	devotion_cost = 25

/obj/effect/proc_holder/spell/invoked/spiderspeak/cast(list/targets, mob/living/user)
	. = ..()
	if(isliving(targets[1]))
		var/mob/living/target = targets[1]
		user.visible_message("<font color='yellow'>[user] infuses [target] with swirling strands of spectral webs!</font>")
		target.visible_message("<font color='yellow'>You feel your tongue shift strangely, producing odd clicking noises.</font>")
		target.apply_status_effect(/datum/status_effect/buff/spider_speak)
		return TRUE
	revert_cast()
	return FALSE

// --- T4 Miracle: Sanctify Tree -----------------------------------------------
/obj/effect/proc_holder/spell/invoked/sanctify_tree
	name = "Sanctify Tree"
	desc = "Channel Dendor's most sacred blessing to consecrate a living, unburnt tree into a sanctified tree of the Treefather — a nexus of druidic power."
	invocation_type = "shout"
	overlay_state = "blesscrop"
	range = 1
	recharge_time = 60 SECONDS
	associated_skill = /datum/skill/magic/holy
	sound = 'sound/ambience/noises/mystical (4).ogg'
	invocations = list("Treefather, consecrate this living tree into your eternal embrace!")
	miracle = TRUE
	devotion_cost = 1000

/obj/effect/proc_holder/spell/invoked/sanctify_tree/cast(list/targets, mob/living/user)
	. = ..()

	var/mob/living/carbon/human/H = user
	if(!istype(H))
		return FALSE

	var/atom/target_atom = targets[1]
	var/obj/structure/flora/newtree/target = null

	// Use for-in-list idiom: the loop var gets the correct static type regardless of source type.
	for(var/obj/structure/flora/newtree/NT_target in list(target_atom))
		if(!NT_target.burnt)
			target = NT_target
		break  // only check the first (and only) element
	if(!target && target_atom.loc && (get_dist(user, target_atom.loc) <= 1))
		for(var/obj/structure/flora/newtree/NT in target_atom.loc)
			if(!NT.burnt)
				target = NT
				break

	// If no living newtree found, search for an unsanctified wise tree to bless instead.
	var/obj/structure/flora/roguetree/wise/wise_target = null
	if(!target)
		for(var/obj/structure/flora/roguetree/wise/WT in list(target_atom))
			if(!istype(WT, /obj/structure/flora/roguetree/wise/sanctified))
				wise_target = WT
				break
		if(!wise_target && target_atom.loc && (get_dist(user, target_atom.loc) <= 1))
			for(var/obj/structure/flora/roguetree/wise/WT in target_atom.loc)
				if(!istype(WT, /obj/structure/flora/roguetree/wise/sanctified))
					wise_target = WT
					break

	if(!target && !wise_target)
		to_chat(H, span_warning("I must target a living tree directly adjacent to me. Old trees, burnt trees, and already-sanctified trees cannot be consecrated."))
		return FALSE

	// For newtree consecration, block if a full sanctified tree (not sanctified_wise) is within 10 tiles.
	if(target)
		for(var/obj/structure/flora/roguetree/wise/sanctified/ST in range(10, target))
			if(istype(ST, /obj/structure/flora/roguetree/wise/sanctified/wise))
				continue  // sanctified wise trees do not block grove anchor placement
			to_chat(H, span_warning("A sanctified tree already stands nearby. The Treefather will not allow another grove anchor so close."))
			return FALSE

	var/atom/cast_target = target || wise_target
	H.visible_message(
		span_notice("[H] presses both hands to the bark of [cast_target] and begins a long, reverent invocation."),
		span_notice("I press my hands to the bark and channel the Treefather's blessing into the tree...")
	)

	if(!do_after(H, 10 SECONDS, target = cast_target))
		to_chat(H, span_warning("The consecration ritual was interrupted — the blessing fades & must be restarted."))
		return FALSE

	// ---- Newtree → full sanctified tree ----
	if(target)
		if(QDELETED(target) || target.burnt)
			to_chat(H, span_warning("The tree is no longer a valid target for sanctification."))
			return FALSE

		var/turf/T = get_turf(target)

		// Clean up branches and leaves from the old newtree.
		// Mirrors the wise tree conversion in create_wise_tree.dm.
		for(var/turf/adjacent in range(1, T))
			for(var/obj/structure/flora/newbranch/B in adjacent)
				qdel(B)
			for(var/obj/structure/flora/newleaf/L in adjacent)
				qdel(L)
		var/turf/above = get_step_multiz(T, UP)
		if(istype(above, /turf/open/transparent/openspace))
			for(var/obj/structure/flora/newtree/upper_tree in above)
				qdel(upper_tree)

		qdel(target)

		var/obj/structure/flora/roguetree/wise/sanctified/new_tree = new(T)
		playsound(T, 'sound/ambience/noises/mystical (4).ogg', 70, TRUE)
		H.visible_message(
			span_green("[H]'s hands blaze with golden light as [new_tree] is consecrated and transfigured into a sanctified tree of Dendor!"),
			span_notice("I feel the Treefather's power flow through me as [new_tree] is sanctified.")
		)
		SEND_SIGNAL(H, COMSIG_TREE_TRANSFORMED)
		return TRUE

	// ---- Wise tree → sanctified wise tree ----
	if(wise_target)
		if(QDELETED(wise_target) || istype(wise_target, /obj/structure/flora/roguetree/wise/sanctified))
			to_chat(H, span_warning("The sacred tree is no longer a valid target for blessing."))
			return FALSE

		var/turf/T = get_turf(wise_target)
		qdel(wise_target)

		var/obj/structure/flora/roguetree/wise/sanctified/wise/new_tree = new(T)
		playsound(T, 'sound/ambience/noises/mystical (4).ogg', 70, TRUE)
		H.visible_message(
			span_green("[H]'s hands blaze with golden light as [new_tree] is consecrated — the ancient tree is touched by the Treefather forever!"),
			span_notice("I feel the Treefather's power flow through me as the ancient tree is sanctified.")
		)
		SEND_SIGNAL(H, COMSIG_TREE_TRANSFORMED)
		return TRUE

	return FALSE

//==============================================================================
// Soulbind & dryad control spells (granted by Cat 7 soulbind ritual)
//==============================================================================

/// Summon (or unsummon) a lesser dryad bound to this player.
/// First cast: spawns the lesser dryad adjacent to the caster and tags it.
/// Second cast (if already summoned): qdels the dryad, returning it to the grove.
/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad
	name = "Summon Lesser Dryad"
	desc = "Call forth a lesser dryad from the grove to serve as your guardian. Cast again to send it back."
	overlay_state = "blesscrop"
	action_icon_state = "blessing"
	action_icon = 'icons/mob/actions/genericmiracles.dmi'
	releasedrain = 60
	recharge_time = 60 SECONDS
	chargetime = 1 SECONDS
	max_targets = 0
	cast_without_targets = TRUE
	associated_skill = /datum/skill/magic/holy
	invocations = list("Treefather, lend me your guardian.")
	invocation_type = "whisper"
	/// Reference to the currently summoned lesser dryad.
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/conjured_dryad = null
	/// TRUE while the player is intentionally unsummoning the dryad.
	var/manual_unsummon = FALSE
	/// Absolute world.time when summon is allowed again after dryad death.
	var/death_cooldown_until = 0

/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/Destroy()
	if(conjured_dryad && !QDELETED(conjured_dryad))
		UnregisterSignal(conjured_dryad, COMSIG_QDELETING)
	conjured_dryad = null
	return ..()

/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/cast(list/targets, mob/user = usr)
	. = ..()
	if(!istype(user, /mob/living/carbon/human))
		return FALSE
	var/mob/living/carbon/human/H = user
	if(world.time < death_cooldown_until)
		to_chat(H, span_warning("The bond to my sould-bound tree is unstable. I must wait [DisplayTimeText(death_cooldown_until - world.time)] before summoning another dryad."))
		revert_cast()
		return FALSE

	// If already summoned, unsummon
	if(conjured_dryad && !QDELETED(conjured_dryad))
		manual_unsummon = TRUE
		conjured_dryad.visible_message(span_boldwarning("[conjured_dryad] dissolves back into the grove."))
		qdel(conjured_dryad)
		manual_unsummon = FALSE
		conjured_dryad = null
		to_chat(H, span_notice("My dryad returns to the grove."))
		return TRUE

	// Summon the lesser dryad
	var/turf/spawn_turf = null
	for(var/D in GLOB.alldirs)
		var/turf/adj = get_step(get_turf(H), D)
		if(adj && !isclosedturf(adj))
			spawn_turf = adj
			break
	if(!spawn_turf)
		to_chat(H, span_warning("There is no room to summon the dryad here."))
		revert_cast()
		return FALSE

	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/D = new(spawn_turf, H)
	conjured_dryad = D
	D.summoner_spell = src
	// Register cleanup if the dryad dies on its own
	RegisterSignal(D, COMSIG_QDELETING, PROC_REF(on_dryad_deleted))
	to_chat(H, span_green("A lesser dryad emerges from the roots, answering my call."))
	D.visible_message(span_notice("[D] takes form beside [H]."))
	return TRUE

/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/proc/on_dryad_deleted(datum/source)
	if(!manual_unsummon)
		death_cooldown_until = max(death_cooldown_until, world.time + 2 MINUTES)
	conjured_dryad = null
	UnregisterSignal(source, COMSIG_QDELETING)

/// Triggers the lesser dryad's surge by activating a targeting cursor and clicking a location.
/obj/effect/proc_holder/spell/targeted/lesser_dryad_special
	name = "Dryad Surge"
	desc = "Activate, then middle-click a turf or creature to command your lesser dryad to surge there with thorns and vines."
	overlay_state = "blesscrop"
	action_icon_state = "blessing"
	action_icon = 'icons/mob/actions/genericmiracles.dmi'
	releasedrain = 50
	recharge_time = 25 SECONDS
	chargetime = 0 SECONDS
	max_targets = 1
	cast_without_targets = FALSE
	associated_skill = /datum/skill/magic/holy
	invocations = list("Tangle my enemies and sting their feet. Grove, arise!")
	invocation_type = "shout"
	range = 10

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/update_icon()
	if(!action)
		return
	action.button_icon_state = "[base_icon_state][active]"
	if(overlay_state)
		action.overlay_state = overlay_state
	action.name = name
	action.UpdateButtonIcon()

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/Click()
	var/mob/living/user = usr
	if(!istype(user))
		return
	if(!can_cast(user))
		deactivate(user)
		return
	if(active)
		deactivate(user)
	else
		active = TRUE
		add_ranged_ability(user, null, TRUE)
	update_icon()

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/deactivate(mob/living/user)
	active = FALSE
	remove_ranged_ability(null)
	update_icon()

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/InterceptClickOn(mob/living/caller, params, atom/target)
	. = ..()
	if(.)
		return TRUE
	if(!can_cast(caller) || !cast_check(FALSE, ranged_ability_user))
		deactivate(caller)
		return TRUE
	if(perform(list(target), TRUE, user = ranged_ability_user))
		deactivate(caller)
	return TRUE

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/cast(list/targets, mob/user = usr)
	. = ..()
	if(!istype(user, /mob/living/carbon/human))
		return FALSE
	var/atom/target = targets?.len ? targets[1] : null
	if(!target)
		return FALSE
	var/mob/living/carbon/human/H = user

	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/D = null
	for(var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad in view(14, H))
		if(dryad.conjurer_ckey == H.ckey)
			D = dryad
			break
	if(!D)
		to_chat(H, span_warning("My dryad is not nearby."))
		return FALSE

	var/turf/target_turf = get_turf(target)
	if(!target_turf || isclosedturf(target_turf))
		to_chat(H, span_warning("The dryad cannot reach that location."))
		return FALSE

	if(D.ai_controller)
		D.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	D.Goto(target_turf, D.move_to_delay, 1)
	addtimer(CALLBACK(src, PROC_REF(try_execute_surge), D, target_turf, H, 12), 0.5 SECONDS)
	return TRUE

/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/proc/try_execute_surge(mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/D, turf/target_turf, mob/living/carbon/human/user, attempts_left)
	if(QDELETED(D) || QDELETED(user) || !target_turf)
		return
	if(get_dist(D, target_turf) > 1)
		if(attempts_left <= 0)
			to_chat(user, span_warning("My dryad cannot reach the commanded target."))
			return
		D.Goto(target_turf, D.move_to_delay, 1)
		addtimer(CALLBACK(src, PROC_REF(try_execute_surge), D, target_turf, user, attempts_left - 1), 0.5 SECONDS)
		return
	if(!D.dryad_surge(target_turf))
		to_chat(user, span_warning("My dryad's power has not yet recovered."))

/mob/living/proc/try_handle_middle_targeted_spell(atom/target)
	return FALSE

/mob/living/carbon/human/try_handle_middle_targeted_spell(atom/target)
	return FALSE

/// Minion order subtype for controlling the lesser dryad faction.
/// Middle-click yourself to command the dryad to follow; middle-click a mob or object to attack.
/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad
	name = "Order Dryad"
	desc = "Command your lesser dryad. Middle-click yourself to make it follow you. Middle-click a mob or creature to make it chase and attack them."
	faction_ordering = FALSE

/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/cast(list/targets, mob/user)
	to_chat(user, span_notice("Middle-click yourself to make my dryad follow, or middle-click a target to set it to attack."))

/// Called from mob/living/carbon/human/MiddleClickOn to process Order Dryad commands.
/mob/living/carbon/human/proc/try_handle_order_dryad(atom/A)
	if(!mind)
		return FALSE
	var/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/S = null
	for(var/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/spell in mind.spell_list)
		S = spell
		break
	if(!S)
		return FALSE

	var/faction_tag = "[mind.current.real_name]_faction"
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/D = null
	for(var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad in oview(14, src))
		if(faction_tag in dryad.faction)
			D = dryad
			break
	if(!D)
		return FALSE

	if(A == src)
		// Follow command — make dryad neutral and follow owner
		if(D.ai_controller)
			D.ai_controller.CancelActions()
			D.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			D.ai_controller.clear_blackboard_key(BB_TRAVEL_DESTINATION)
			D.ai_controller.clear_blackboard_key(BB_BASIC_MOB_RETALIATE_LIST)
			D.ai_controller.set_blackboard_key(BB_FOLLOW_TARGET, src)
		D.aggressive = FALSE
		if(!("neutral" in D.faction))
			D.faction += "neutral"
		D.enemies = list()
		D.LoseTarget()
		to_chat(src, span_notice("[D.name] will follow me."))
		return TRUE

	if(isliving(A) && A != src)
		// Attack command — direct the dryad at the target
		if(D.ai_controller)
			D.ai_controller.CancelActions()
			D.ai_controller.clear_blackboard_key(BB_FOLLOW_TARGET)
			D.ai_controller.clear_blackboard_key(BB_TRAVEL_DESTINATION)
			D.ai_controller.clear_blackboard_key(BB_BASIC_MOB_RETALIATE_LIST)
			D.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, A)
		D.aggressive = TRUE
		if("neutral" in D.faction)
			D.faction -= "neutral"
		to_chat(src, span_notice("[D.name] charges at [A.name]!"))
		return TRUE

	return FALSE

/mob/living/carbon/human/MiddleClickOn(atom/A, params)
	if(try_handle_order_dryad(A))
		return
	return ..()

