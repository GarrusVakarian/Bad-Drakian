//==============================================================================
// Dendor's Vigil Status Effect (applied by Cat 2 ritual)
//==============================================================================

/atom/movable/screen/alert/status_effect/buff/dendor_vigil
	name = "Dendor's Vigil"
	desc = "The Treefather's blessing quickens my steps and wards me against natural obstacles."
	icon_state = "buff"

/datum/status_effect/buff/dendor_vigil
	id = "dendor_vigil"
	alert_type = /atom/movable/screen/alert/status_effect/buff/dendor_vigil
	effectedstats = list("perception" = 2, "speed" = 1)
	duration = 30 MINUTES

/datum/status_effect/buff/dendor_vigil/dendorite
	effectedstats = list("perception" = 2, "speed" = 2, "willpower" = 1)

/datum/status_effect/buff/dendor_vigil/on_apply()
	. = ..()
	ADD_TRAIT(owner, TRAIT_LONGSTRIDER, "DENDOR_VIGIL")
	ADD_TRAIT(owner, TRAIT_KNEESTINGER_IMMUNITY, "DENDOR_VIGIL")
	to_chat(owner, span_green("The Treefather's vigil embraces me — my steps are swift and the thorns will not bite."))

/datum/status_effect/buff/dendor_vigil/on_remove()
	. = ..()
	REMOVE_TRAIT(owner, TRAIT_LONGSTRIDER, "DENDOR_VIGIL")
	REMOVE_TRAIT(owner, TRAIT_KNEESTINGER_IMMUNITY, "DENDOR_VIGIL")
	to_chat(owner, span_warning("The Treefather's vigil fades from me."))

//==============================================================================
// Blessed Druid Armor (reward from Cat 6 ritual)
//==============================================================================

/obj/item/clothing/suit/roguetown/armor/leather/druid/blessed
	name = "blessed druid armor"
	desc = "Druid armor hallowed by the Treefather's rite. The bark pulses with faint living light; it feels as though the forest itself watches over whoever wears it."
	armor = list("blunt" = 90, "slash" = 70, "stab" = 130, "piercing" = 40, "fire" = 0, "acid" = 0)
	prevent_crits = list(BCLASS_CUT, BCLASS_STAB, BCLASS_BLUNT, BCLASS_CHOP)
	max_integrity = ARMOR_INT_CHEST_LIGHT_MASTER
	color = "#73c47a"

/obj/structure/flora/roguetree/wise/sanctified/proc/is_valid_vigil_follower(mob/living/carbon/human/H)
	if(!H)
		return FALSE
	// Psydon followers have no patron datum — identified by trait.
	if(HAS_TRAIT(H, TRAIT_PSYDONITE))
		return FALSE
	// Old-god worshippers and all inhumen (Zizo, Baotha, Graggar, Matthios) patrons are excluded.
	if(istype(H.patron, /datum/patron/old_god))
		return FALSE
	if(istype(H.patron, /datum/patron/inhumen))
		return FALSE
	return TRUE

//==============================================================================
// Sanctified Tree Data Datum
//==============================================================================

/// Tracks per-tree ritual state, aura flags, and the per-player soulbind registry.
/datum/sanctified_tree_data
	/// Back-reference to the owning sanctified tree.
	var/obj/structure/flora/roguetree/wise/sanctified/tree
	/// Once-per-tree ritual completion flags. Values: "cat4", "cat5", "cat6".
	var/list/rituals_completed = list()
	/// Per-player soulbind registry: list of ckey strings.
	var/list/soulbound_players = list()
	/// Ckey of the player who just completed cat7 offerings and must now bleed to confirm.
	var/awaiting_soulbind_ckey = null

	// ---- Ritual state -------------------------------------------------------
	/// Currently active ritual category string, or null if none.
	var/active_ritual = null
	/// Progress for the active ritual: associative list of "key" = deposited_count.
	var/list/ritual_progress = list()
	/// Cat1 berry-only tracking: TRUE while current cat1 ritual has only received berry food.
	var/cat1_all_berries = TRUE
	/// Armor held for cat6 transmutation. Stored at the tree's turf until completion.
	var/obj/item/ritual_armor = null

	// ---- Aura state ---------------------------------------------------------
	/// TRUE once cat4 (Treefather's Bulwark) ritual is completed.
	var/has_slow_aura = FALSE
	/// TRUE once cat5 (Living Light) ritual is completed.
	var/has_heal_aura = FALSE
	/// Mobs currently slowed by the bulwark aura. Tracked for cleanup.
	var/list/slowed_mobs = list()
	/// dt accumulator for slow-aura 5-second ticks.
	var/slow_aura_elapsed = 0
	/// dt accumulator for heal-aura 60-second ticks.
	var/heal_aura_elapsed = 0
	/// Cooldown flag for the middle-click manual heal from cat5.
	var/manual_heal_cooldown = FALSE

	// ---- Wedding ceremony state ------------------------------------------
	/// TRUE while an eoran bud has been offered and the tree awaits a bitten apple.
	var/wedding_active = FALSE
	/// Ckey of the player who offered the eoran bud to start the ceremony.
	var/wedding_officiant_ckey = null

/datum/sanctified_tree_data/New(obj/structure/flora/roguetree/wise/sanctified/owner)
	..()
	tree = owner

//==============================================================================
// Sanctified Tree
//==============================================================================
/obj/structure/flora/roguetree/wise/sanctified
	name = "sanctified tree"
	desc = "A great tree consecrated by the Treefather. Its bark glows with faint light, and the air around it thrums with primal holiness. A nexus of druidic power."
	/// Base max_integrity before nearby-tree bonus.
	max_integrity = 400
	/// Disable wise-tree autonomous retaliation. The sanctified tree
	/// cooperates with its druid warden rather than lashing out autonomously.
	activated = FALSE

	/// Datum holding ritual completion flags and the soulbind registry.
	var/datum/sanctified_tree_data/tree_data
	/// If FALSE (for sanctified_wise trees), hides ritual and wedding hints in examine.
	var/show_ritual_hints = TRUE
	/// Current max_integrity bonus from nearby living trees.
	var/integrity_bonus = 0
	/// SSprocessing dt accumulator — recalculates bonus every 60 seconds.
	var/bonus_check_elapsed = 0
	/// SSprocessing dt accumulator — restores integrity periodically.
	var/integrity_regen_elapsed = 0

/obj/structure/flora/roguetree/wise/sanctified/Initialize(mapload)
	. = ..()
	tree_data = new /datum/sanctified_tree_data(src)
	set_light(3, 3, 3, l_color = "#FFD700")
	START_PROCESSING(SSprocessing, src)
	recalculate_integrity_bonus()

/obj/structure/flora/roguetree/wise/sanctified/Destroy()
	remove_filter("sanctified_outline")
	STOP_PROCESSING(SSprocessing, src)
	if(tree_data)
		// Notify and debuff any soulbound players before clearing data.
		if(tree_data.soulbound_players.len)
			curse_soulbound_players()
		// Clean up aura slow on destroy.
		for(var/mob/living/M in tree_data.slowed_mobs)
			if(!QDELETED(M))
				var/datum/status_effect/debuff/sanctified_tree_slow/SE = M.has_status_effect(/datum/status_effect/debuff/sanctified_tree_slow)
				if(SE)
					qdel(SE)
		tree_data.slowed_mobs = list()
		// Return any stored ritual armor to the ground.
		if(tree_data.ritual_armor && !QDELETED(tree_data.ritual_armor))
			tree_data.ritual_armor.forceMove(get_turf(src))
			tree_data.ritual_armor = null
		qdel(tree_data)
		tree_data = null
	return ..()

/// Applies the permanent soulbind-broken debuff to all online soulbound players.
/// Called from Destroy() before tree_data is cleared.
/obj/structure/flora/roguetree/wise/sanctified/proc/curse_soulbound_players()
	for(var/ckey in tree_data.soulbound_players)
		for(var/mob/living/carbon/human/H in GLOB.alive_mob_list)
			if(H.ckey != ckey)
				continue
			H.apply_status_effect(/datum/status_effect/debuff/soulbind_broken)
			H.add_stress(/datum/stressevent/soulbind_tree_loss)
			REMOVE_TRAIT(H, "DENDOR_SOULBOUND", "SOULBIND")
			for(var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/S in H.mind?.spell_list)
				H.mind.RemoveSpell(S)
			for(var/obj/effect/proc_holder/spell/targeted/lesser_dryad_special/S in H.mind?.spell_list)
				H.mind.RemoveSpell(S)
			for(var/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/S in H.mind?.spell_list)
				H.mind.RemoveSpell(S)
			break

/obj/structure/flora/roguetree/wise/sanctified/process(dt)
	bonus_check_elapsed += dt
	if(bonus_check_elapsed >= 60 SECONDS)
		bonus_check_elapsed = 0
		recalculate_integrity_bonus()
	integrity_regen_elapsed += dt
	if(integrity_regen_elapsed >= 30 SECONDS)
		integrity_regen_elapsed = 0
		if(obj_integrity < max_integrity)
			obj_integrity = min(obj_integrity + 10, max_integrity)
	if(!tree_data)
		return
	if(tree_data.has_slow_aura)
		tree_data.slow_aura_elapsed += dt
		if(tree_data.slow_aura_elapsed >= 5 SECONDS)
			tree_data.slow_aura_elapsed = 0
			update_slow_aura()
	if(tree_data.has_heal_aura)
		tree_data.heal_aura_elapsed += dt
		if(tree_data.heal_aura_elapsed >= 60 SECONDS)
			tree_data.heal_aura_elapsed = 0
			pulse_heal_aura()

//==============================================================================
// Integrity Bonus
//==============================================================================

/// Recounts living trees within 10 tiles and updates max_integrity.
/// Qualifying trees: /obj/structure/flora/newtree (not burnt) and
/// /obj/structure/flora/roguetree (not wise, burnt, or stump subtypes).
/// Each tree contributes +10 integrity, capped at +200 (20 trees).
/obj/structure/flora/roguetree/wise/sanctified/proc/recalculate_integrity_bonus()
	var/tree_count = 0
	for(var/obj/structure/flora/newtree/T in range(10, src))
		if(!T.burnt)
			tree_count++
	for(var/obj/structure/flora/roguetree/T in range(10, src))
		if(istype(T, /obj/structure/flora/roguetree/wise))
			continue  // exclude wise and sanctified subtypes
		if(istype(T, /obj/structure/flora/roguetree/burnt))
			continue
		if(istype(T, /obj/structure/flora/roguetree/stump))
			continue
		tree_count++
	var/new_bonus = min(tree_count * 10, 200)
	if(new_bonus == integrity_bonus)
		return
	integrity_bonus = new_bonus
	max_integrity = 400 + integrity_bonus
	obj_integrity = min(obj_integrity, max_integrity)

//==============================================================================
// Ritual Framework
//==============================================================================

/obj/structure/flora/roguetree/wise/sanctified/proc/open_ritual_menu(mob/living/user)
	if(!tree_data)
		return

	if(tree_data.active_ritual)
		// Show progress and only allow cancellation from the amulet menu.
		show_ritual_requirements(user, tree_data.active_ritual)
		var/choice = alert(user, "[get_ritual_display_name(tree_data.active_ritual)] is active.\n\nOffer items by clicking the tree while holding them.\n\nCancel this ritual?", "Sanctified Tree", "Keep Ritual", "Cancel Ritual")
		if(choice != "Cancel Ritual" || QDELETED(src) || QDELETED(user))
			return
		cancel_ritual(user)
		return

	// No active ritual — show the category picker.
	var/list/cat_opts = list()
	var/list/cat_map = list()
	for(var/cat in list("cat1", "cat2", "cat3", "cat4", "cat5", "cat6", "cat7", "cat8"))
		var/cat_name = get_ritual_display_name(cat)
		if(is_once_per_tree(cat) && (cat in tree_data.rituals_completed))
			cat_opts["[cat_name] (completed)"] = null
			continue
		cat_opts[cat_name] = cat
		cat_map[cat_name] = cat
	var/choice = input(user, "Choose a ritual to perform:", "Sanctified Tree Rituals") as null|anything in cat_opts
	if(isnull(choice) || QDELETED(src) || QDELETED(user))
		return
	var/selected = cat_map[choice]
	if(!selected)
		to_chat(user, span_info("That ritual has already been completed on this tree and cannot be repeated."))
		return
	if(!confirm_start_ritual(user, selected))
		return
	tree_data.active_ritual = selected
	var/req = get_required_offerings(selected)
	tree_data.ritual_progress = list()
	for(var/key in req)
		tree_data.ritual_progress[key] = 0
	if(selected == "cat1")
		tree_data.cat1_all_berries = TRUE
	to_chat(user, span_notice("I begin the [get_ritual_display_name(selected)] ritual. Offer items by clicking the tree while holding them. Use the amulet only if I need to cancel."))
	show_ritual_requirements(user, selected)

/obj/structure/flora/roguetree/wise/sanctified/proc/confirm_start_ritual(mob/living/user, category)
	var/list/req = get_required_offerings(category)
	var/list/lines = list()
	for(var/key in req)
		lines += "- [req[key]]x [get_offering_desc(key)]"
	var/text = "Begin [get_ritual_display_name(category)]?\n\nRequired offerings:\n[jointext(lines, "\n")]"
	var/choice = alert(user, text, "Sanctified Tree Bounty", "Begin", "Cancel")
	return (choice == "Begin")

/obj/structure/flora/roguetree/wise/sanctified/proc/get_ritual_display_name(category)
	switch(category)
		if("cat1") return "Dendor's Harvest"
		if("cat2") return "Fungal Vigil"
		if("cat3") return "Fae Weaving"
		if("cat4") return "Treefather's Bulwark"
		if("cat5") return "Living Light"
		if("cat6") return "Nature's Temper"
		if("cat7") return "Soulbind"
		if("cat8") return "Nature's Union"
	return "Unknown Ritual"

/obj/structure/flora/roguetree/wise/sanctified/proc/is_once_per_tree(category)
	return (category in list("cat4", "cat5", "cat6", "cat7"))

/// Returns associative list of offering key -> required count for the given category.
/obj/structure/flora/roguetree/wise/sanctified/proc/get_required_offerings(category)
	switch(category)
		if("cat1") return list("food_item" = 6)
		if("cat2") return list("manabloom_or_manacrystal" = 10)
		if("cat3") return list("runed_or_leyline" = 5)
		if("cat4") return list("enchanted_stone_or_boulder" = 5)
		if("cat5") return list("vital_item" = 10, "ash" = 10, "compost" = 10)
		if("cat6") return list("zizobane" = 5, "runed_artifact" = 2, "druid_armor" = 1, "volf_head" = 1, "spider_head" = 1, "tree_seed" = 1, "blessed_seed_powder" = 1, "holy_water_container" = 1)
		if("cat7") return list("leechtick" = 1, "bones" = 4)
		if("cat8") return list("wedding_flower" = 1)
	return list()

/obj/structure/flora/roguetree/wise/sanctified/proc/get_offering_desc(key)
	switch(key)
		if("food_item") return "Any fresh or rotten produce"
		if("manabloom_or_manacrystal") return "Mana bloom OR crystalized mana"
		if("runed_or_leyline") return "Runed artifact OR leyline shard"
		if("enchanted_stone_or_boulder") return "Enchanted stone (magic power 5+) OR boulder"
		if("vital_item") return "Sinew, viscera, bonemeal, or skull"
		if("ash") return "Ash"
		if("compost") return "Compost"
		if("zizobane") return "Zizo's bane mushroom"
		if("runed_artifact") return "Runed artifact"
		if("druid_armor") return "Druid armor"
		if("volf_head") return "Volf head"
		if("spider_head") return "Spider head"
		if("tree_seed") return "Tree seed"
		if("blessed_seed_powder") return "Blessed seed powder"
		if("holy_water_container") return "Stone mortar or bucket with 30+ drams of blessed water"
		if("lux") return "Lux"
		if("leechtick") return "Bloated leech tick"
		if("bones") return "Bones"
		if("wedding_flower") return "Eoran peace flower"
	return key

/obj/structure/flora/roguetree/wise/sanctified/proc/show_ritual_requirements(mob/living/user, category)
	var/req = get_required_offerings(category)
	to_chat(user, span_info("=== [get_ritual_display_name(category)] requirements ==="))
	for(var/key in req)
		var/current = tree_data.ritual_progress[key] || 0
		var/needed = req[key]
		if(current >= needed)
			to_chat(user, span_notice("  [get_offering_desc(key)]: [current]/[needed] (fulfilled)"))
		else
			to_chat(user, span_warning("  [get_offering_desc(key)]: [current]/[needed]"))

/obj/structure/flora/roguetree/wise/sanctified/proc/offer_item(mob/living/user)
	if(!tree_data?.active_ritual)
		return FALSE
	var/obj/item/held = user.get_active_held_item()
	if(!held)
		to_chat(user, span_warning("I am not holding anything to offer."))
		return FALSE
	var/req = get_required_offerings(tree_data.active_ritual)
	for(var/key in req)
		var/current = tree_data.ritual_progress[key] || 0
		if(current >= req[key])
			continue
		if(!check_offering_match(key, held))
			continue
		// Track whether cat1 offering is a berry
		if(tree_data.active_ritual == "cat1" && key == "food_item")
			if(!istype(held, /obj/item/reagent_containers/food/snacks/grown/berries))
				tree_data.cat1_all_berries = FALSE
		consume_offering(key, held, user)
		tree_data.ritual_progress[key] = current + 1
		playsound(get_turf(src), 'sound/magic/churn.ogg', 40, FALSE)
		if(check_ritual_complete())
			complete_ritual(user)
		return TRUE
	to_chat(user, span_warning("The tree does not need [held.name] right now."))
	return FALSE

/obj/structure/flora/roguetree/wise/sanctified/proc/is_harvest_offering(obj/item/held)
	if(!istype(held, /obj/item/reagent_containers/food/snacks))
		return FALSE
	if(istype(held, /obj/item/reagent_containers/food/snacks/grown/berries))
		return TRUE
	var/obj/item/reagent_containers/food/snacks/food = held
	if(food.foodtype & (FRUIT | VEGETABLES | GRAIN))
		return TRUE
	var/static/list/extra_harvest_types = list(
		/obj/item/reagent_containers/food/snacks/grown/garlick/rogue,
		/obj/item/reagent_containers/food/snacks/grown/onion/rogue,
		/obj/item/reagent_containers/food/snacks/grown/vegetable/turnip,
		/obj/item/reagent_containers/food/snacks/grown/cabbage/rogue,
		/obj/item/reagent_containers/food/snacks/grown/potato/rogue,
		/obj/item/reagent_containers/food/snacks/grown/rice,
		/obj/item/reagent_containers/food/snacks/grown/cucumber,
		/obj/item/reagent_containers/food/snacks/grown/eggplant,
		/obj/item/reagent_containers/food/snacks/grown/carrot,
		/obj/item/reagent_containers/food/snacks/grown/wheat,
		/obj/item/reagent_containers/food/snacks/grown/oat,
		/obj/item/reagent_containers/food/snacks/grown/sugarcane,
		/obj/item/reagent_containers/food/snacks/grown/coffeebeans,
		/obj/item/reagent_containers/food/snacks/grown/rogue/poppy,
		/obj/item/reagent_containers/food/snacks/grown/nut,
		/obj/item/reagent_containers/food/snacks/grown/tea,
		/obj/item/reagent_containers/food/snacks/grown/apple,
		/obj/item/reagent_containers/food/snacks/grown/fruit/pear,
		/obj/item/reagent_containers/food/snacks/grown/fruit/lemon,
		/obj/item/reagent_containers/food/snacks/grown/fruit/lime,
		/obj/item/reagent_containers/food/snacks/grown/fruit/tangerine,
		/obj/item/reagent_containers/food/snacks/grown/fruit/plum,
		/obj/item/reagent_containers/food/snacks/grown/fruit/strawberry,
		/obj/item/reagent_containers/food/snacks/grown/fruit/blackberry,
		/obj/item/reagent_containers/food/snacks/grown/fruit/raspberry,
		/obj/item/reagent_containers/food/snacks/grown/fruit/tomato,
		/obj/item/natural/shellplant/pumpkin,
		/obj/item/reagent_containers/food/snacks/grown/berries/rogue
	)
	for(var/path in extra_harvest_types)
		if(istype(held, path))
			return TRUE
	return FALSE

/obj/structure/flora/roguetree/wise/sanctified/proc/check_offering_match(key, obj/item/held)
	if(!held)
		return FALSE
	switch(key)
		if("food_item")
			return is_harvest_offering(held)
		if("manabloom_or_manacrystal")
			return istype(held, /obj/item/reagent_containers/food/snacks/grown/manabloom) || istype(held, /obj/item/magic/manacrystal)
		if("runed_or_leyline")
			return istype(held, /obj/item/magic/artifact) || istype(held, /obj/item/magic/leyline)
		if("enchanted_stone_or_boulder")
			if(istype(held, /obj/item/natural/stone))
				var/obj/item/natural/stone/stone = held
				return stone.magic_power >= 5
			return istype(held, /obj/item/natural/rock)
		if("vital_item")
			return istype(held, /obj/item/alch/sinew) || istype(held, /obj/item/alch/viscera) || istype(held, /obj/item/alch/bonemeal) || istype(held, /obj/item/skull)
		if("ash")
			return istype(held, /obj/item/ash)
		if("compost")
			return istype(held, /obj/item/compost)
		if("zizobane")
			return istype(held, /obj/item/reagent_containers/food/snacks/zizo_bane)
		if("runed_artifact")
			return istype(held, /obj/item/magic/artifact)
		if("druid_armor")
			return held.type == /obj/item/clothing/suit/roguetown/armor/leather/druid
		if("volf_head")
			return istype(held, /obj/item/natural/head/volf)
		if("spider_head")
			return istype(held, /obj/item/natural/head/honeyspider) || istype(held, /obj/item/natural/head/mirespider)
		if("tree_seed")
			return istype(held, /obj/item/seeds/treesap)
		if("blessed_seed_powder")
			return istype(held, /obj/item/alch/blessedseedpowder)
		if("holy_water_container")
			if(!(istype(held, /obj/item/reagent_containers/glass/mortar) || istype(held, /obj/item/reagent_containers/glass/bucket)))
				return FALSE
			if(!held.reagents)
				return FALSE
			return held.reagents.get_reagent_amount(/datum/reagent/water/blessed) >= 30
		if("lux")
			return istype(held, /obj/item/reagent_containers/lux)
		if("leechtick")
			return istype(held, /obj/item/leechtick_bloated)
		if("bones")
			return istype(held, /obj/item/natural/bone) || istype(held, /obj/item/alch/bone)
		if("wedding_flower")
			return istype(held, /obj/item/clothing/head/peaceflower)
	return FALSE

/obj/structure/flora/roguetree/wise/sanctified/proc/consume_offering(key, obj/item/held, mob/living/user)
	switch(key)
		if("food_item", "manabloom_or_manacrystal", "runed_or_leyline", "enchanted_stone_or_boulder")
			qdel(held)
		if("vital_item", "ash", "compost")
			qdel(held)
		if("zizobane", "runed_artifact", "volf_head", "spider_head", "tree_seed", "blessed_seed_powder")
			qdel(held)
		if("druid_armor")
			// Move armor to tree's turf and store reference for transmutation.
			held.forceMove(get_turf(src))
			tree_data.ritual_armor = held
		if("holy_water_container")
			// Drain blessed water but leave the container.
			held.reagents.remove_reagent(/datum/reagent/water/blessed, 30)
		if("leechtick", "bones")
			qdel(held)
		if("wedding_flower")
			qdel(held)

/obj/structure/flora/roguetree/wise/sanctified/proc/check_ritual_complete()
	if(!tree_data?.active_ritual)
		return FALSE
	var/req = get_required_offerings(tree_data.active_ritual)
	for(var/key in req)
		if((tree_data.ritual_progress[key] || 0) < req[key])
			return FALSE
	return TRUE

/obj/structure/flora/roguetree/wise/sanctified/proc/complete_ritual(mob/living/user)
	var/cat = tree_data.active_ritual
	tree_data.active_ritual = null
	tree_data.ritual_progress = list()
	if(is_once_per_tree(cat))
		tree_data.rituals_completed |= cat
	playsound(get_turf(src), 'sound/ambience/noises/mystical (4).ogg', 70, TRUE)
	visible_message(span_green("The [src.name] blazes with golden light as [user.name] completes a sacred ritual!"))
	switch(cat)
		if("cat1") reward_cat1(user)
		if("cat2") reward_cat2(user)
		if("cat3") reward_cat3(user)
		if("cat4") reward_cat4(user)
		if("cat5") reward_cat5(user)
		if("cat6") reward_cat6(user)
		if("cat7") on_soulbind(user)
		if("cat8") reward_cat8(user)

/obj/structure/flora/roguetree/wise/sanctified/proc/cancel_ritual(mob/living/user)
	if(!tree_data?.active_ritual)
		return
	var/cat_name = get_ritual_display_name(tree_data.active_ritual)
	if(tree_data.ritual_armor && !QDELETED(tree_data.ritual_armor))
		tree_data.ritual_armor.forceMove(get_turf(src))
		to_chat(user, span_notice("The offered armor returns to my feet."))
		tree_data.ritual_armor = null
	tree_data.active_ritual = null
	tree_data.ritual_progress = list()
	to_chat(user, span_warning("I cancel the [cat_name] ritual. All progress is lost."))

//==============================================================================
// Ritual Rewards
//==============================================================================

/// Cat 1 — Dendor's Harvest: seed bounty (repeatable).
/// Offerings: 5 any fruit/grain/vegetable food items (rotten okay).
/// Reward (normal): 1 random misc seed + 1 tree seed (2% sakura, 10% pine, 88% regular).
/// Reward (berry special case, all 5 berries): 1 wild bush seed + 50% chance flower seed.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat1(mob/living/user)
	var/turf/T = get_turf(user)
	if(tree_data.cat1_all_berries)
		// Berry special case: all 5 were berries → wild thorny berry hedge seed + possible flower
		new /obj/item/seeds/bush(T)
		if(prob(50))
			new /obj/item/seeds/flower(T)
		to_chat(user, span_green("The roots twist with thorny energy — a wild hedge sapling seed tumbles forth."))
		return
	// Normal reward: 1 misc seed from Dendor's garden + 1 tree seed
	var/misc = pickweight(list(
		/obj/item/seeds/tea                          = 10,
		/obj/item/seeds/coffee                       = 10,
		/obj/item/herbseed/manabloom                 = 8,
		/obj/item/seeds/swampweed                    = 8,
		/obj/item/seeds/apple                        = 6,
		/obj/item/seeds/pear                         = 6,
		/obj/item/seeds/plum                         = 6,
		/obj/item/seeds/strawberry                   = 5,
		/obj/item/seeds/blackberry                   = 5,
		/obj/item/seeds/raspberry                    = 5,
		/obj/item/seeds/tomato                       = 5,
		/obj/item/seeds/potato                       = 5,
		/obj/item/seeds/onion                        = 5,
		/obj/item/seeds/cabbage                      = 5,
		/obj/item/seeds/wheat                        = 5,
		/obj/item/seeds/garlick                      = 5,
		/obj/item/seeds/turnip                       = 5,
		/obj/item/seeds/rice                         = 5,
		/obj/item/seeds/cucumber                     = 5,
		/obj/item/seeds/eggplant                     = 5,
		/obj/item/seeds/carrot                       = 5,
		/obj/item/seeds/wheat/oat                    = 5,
		/obj/item/seeds/sugarcane                    = 4,
		/obj/item/seeds/poppy                        = 4,
		/obj/item/seeds/nut                          = 4,
		/obj/item/seeds/lemon                        = 4,
		/obj/item/seeds/lime                         = 4,
		/obj/item/seeds/tangerine                    = 4,
		/obj/item/seeds/pumpkin                      = 3,
		/obj/item/seeds/berryrogue                   = 3
	))
	new misc(T)
	// Tree seed: 2% sakura, 10% pine, 88% regular
	var/tree_type = pickweight(list(
		/obj/item/seeds/treesap/sakura = 2,
		/obj/item/seeds/treesap/pine   = 10,
		/obj/item/seeds/treesap        = 88
	))
	new tree_type(T)
	to_chat(user, span_green("Seeds tumble from the roots — Dendor's harvest is generous."))

/// Cat 2 — Fungal Vigil: kneestinger ring + 30-min vigil buff to nearby mobs (repeatable).
/// Offerings: 10 mana blooms OR crystalized mana.
/// Buff: longstrider + +2 Perception + +1 Speed + kneestinger immunity, 30 minutes.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat2(mob/living/user)
	var/turf/T = get_turf(src)
	// Plant kneestingers in a full ring (8 directions) around the tree.
	for(var/D in GLOB.alldirs)
		var/turf/adj = get_step(T, D)
		if(adj && !isclosedturf(adj) && !locate(/obj/structure/glowshroom) in adj)
			new /obj/structure/glowshroom(adj)
	// Buff nearby conscious pantheon followers except excluded patrons.
	for(var/mob/living/carbon/human/H in range(6, src))
		if(!is_valid_vigil_follower(H))
			continue
		if(H.stat != CONSCIOUS || H.incapacitated())
			continue
		if(H.patron?.type == /datum/patron/divine/dendor)
			H.apply_status_effect(/datum/status_effect/buff/dendor_vigil/dendorite)
		else
			H.apply_status_effect(/datum/status_effect/buff/dendor_vigil)
	to_chat(user, span_green("Kneestingers erupt in a ring — the Treefather's vigil strengthens his faithful."))

/// Cat 3 — Fae Weaving: mushroom fae circle seed (repeatable).
/// Offerings: 5 runed artifacts OR leyline shards. Reward: 1 mushroom_fae seed.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat3(mob/living/user)
	var/turf/T = get_turf(user)
	new /obj/item/seeds/mushroom_fae(T)
	to_chat(user, span_green("A single handful of mushroom fae spores rises from the roots — the Treefather rewards patience."))

/// Cat 4 — Treefather's Bulwark: slow aura + integrity boost (once per tree).
/// Offerings: 5 enchanted stones (magic_power 5+) OR boulders.
/// Reward: +100 integrity, -4 speed debuff aura to non-Dendor mobs within 5 tiles.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat4(mob/living/user)
	tree_data.has_slow_aura = TRUE
	max_integrity += 100
	obj_integrity = min(obj_integrity + 100, max_integrity)
	visible_message(span_green("The bark of [src.name] hardens like ironwood. A silent ward settles around the tree — those who would defile it will find their feet heavy."))

/// Cat 5 — Living Light: passive healing aura + middle-click manual heal (once per tree).
/// Offerings: 10 mixed sinew/viscera/tailbone/bone/skull + 10 ash + 10 compost.
/// Aura: wide green glow, periodic healing for Dendor followers.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat5(mob/living/user)
	tree_data.has_heal_aura = TRUE
	set_light(5, 5, 5, l_color = "#44AA44")
	add_filter("sanctified_outline", 2, list("type" = "outline", "color" = "#58C86A", "alpha" = 60, "size" = 1))
	visible_message(span_green("A warm green aura blooms from [src.name]. The Treefather's life flows to those who revere him."))

/// Cat 6 — Nature's Temper: blessed druid armor + possible elven armor piece (once per tree).
/// Offerings: 5 zizo bane + 2 runed artifacts + druid armor + volf head + spider head +
///             tree seed + blessed seed powder + stone mortar/bucket with 30+ drams holy water.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat6(mob/living/user)
	var/turf/T = get_turf(user)
	if(!tree_data.ritual_armor || QDELETED(tree_data.ritual_armor))
		to_chat(user, span_warning("The druid armor offering was lost — something disrupted the ritual."))
		return
	// Destroy the offered druid armor.
	qdel(tree_data.ritual_armor)
	tree_data.ritual_armor = null
	// Yield blessed druid armor (upgraded chest).
	var/obj/item/clothing/suit/roguetown/armor/leather/druid/blessed/BA = new(T)
	to_chat(user, span_green("[BA.name] rises from the ritual — the Treefather has blessed this armor with living power."))
	// 50% chance: random wood armor piece from elven black oak mercenaries (excluding chest).
	if(prob(50))
		var/list/bonus_pool = list(/obj/item/clothing/head/roguetown/helmet/heavy/elven_helm, /obj/item/clothing/gloves/roguetown/elven_gloves, /obj/item/clothing/shoes/roguetown/boots/leather/elven_boots)
		var/bonus_type = pick(bonus_pool)
		var/obj/item/bonus = new bonus_type(T)
		to_chat(user, span_green("The roots also yield [bonus.name] — an additional gift."))

/// Cat 8 — Nature's Union: begins a wedding ceremony (repeatable).
/// Offering: 1 eoran peace flower. The betrothed must each bite the same apple,
/// then offer it to the tree to complete the pact.
/obj/structure/flora/roguetree/wise/sanctified/proc/reward_cat8(mob/living/user)
	if(tree_data.wedding_active)
		to_chat(user, span_warning("A wedding ceremony is already being held at this tree."))
		return
	tree_data.wedding_active = TRUE
	tree_data.wedding_officiant_ckey = user.ckey
	visible_message(span_green("A peace flower drifts to the roots of [src.name] — the blessings of Dendor and Eora are invoked. Two souls may now offer their bitten apple to be wed beneath this tree."))
	to_chat(user, span_notice("The ceremony has begun. Both partners should bite the same apple once each, then hand it to the tree to be wed. The one handing the apple over will decide the last name."))

//==============================================================================
// Aura Procs
//==============================================================================

/// Applies or removes the bulwark slow on non-Dendor mobs within 5 tiles.
/// Called every 5 seconds when has_slow_aura is TRUE.
/// Applies a -4 speed stat debuff via status effect (8-second duration),
/// refreshed each tick so it stays active while in range.
/obj/structure/flora/roguetree/wise/sanctified/proc/update_slow_aura()
	var/list/in_range = list()
	for(var/mob/living/carbon/human/H in range(5, src))
		if(H.patron && H.patron.type == /datum/patron/divine/dendor)
			continue
		if(H.stat != CONSCIOUS || H.incapacitated())
			continue
		in_range |= H
	// Remove modifier from mobs that left range or are now Dendor-eligible.
	// Collect removals first — mutating slowed_mobs during iteration skips elements in BYOND.
	var/list/to_remove = list()
	for(var/mob/living/M in tree_data.slowed_mobs)
		if(QDELETED(M) || !(M in in_range))
			if(!QDELETED(M))
				var/datum/status_effect/debuff/sanctified_tree_slow/SE = M.has_status_effect(/datum/status_effect/debuff/sanctified_tree_slow)
				if(SE)
					qdel(SE)
			to_remove += M
	tree_data.slowed_mobs -= to_remove
	// Apply/refresh debuff on mobs in range.
	for(var/mob/living/carbon/human/H in in_range)
		var/datum/status_effect/debuff/sanctified_tree_slow/SE = H.has_status_effect(/datum/status_effect/debuff/sanctified_tree_slow)
		if(SE)
			SE.refresh()
		else
			H.apply_status_effect(/datum/status_effect/debuff/sanctified_tree_slow)
			tree_data.slowed_mobs |= H

/// Heals Dendor followers within 5 tiles periodically.
/// Called every 60 seconds when has_heal_aura is TRUE.
/// Uses green visual effect matching the wider wise-tree glow aesthetic.
/obj/structure/flora/roguetree/wise/sanctified/proc/pulse_heal_aura()
	var/healed_any = FALSE
	for(var/mob/living/carbon/human/H in range(7, src))
		if(H.patron?.type != /datum/patron/divine/dendor)
			continue
		if(H.stat != CONSCIOUS || H.incapacitated())
			continue
		if(H.getBruteLoss() <= 0 && H.getFireLoss() <= 0)
			continue
		H.adjustBruteLoss(-8, 0)
		H.adjustFireLoss(-5, 0)
		new /obj/effect/temp_visual/heal_rogue(get_turf(H))
		healed_any = TRUE
	if(healed_any)
		playsound(get_turf(src), 'sound/magic/churn.ogg', 30, FALSE)

//==============================================================================
// Middle-Click Manual Heal (Cat 5)
//==============================================================================

/// Middle-click handler for cat5 healing aura.
/// Dendor followers middle-click the tree to receive campfire-style healing
/// (2x faster than campfire) with a progress bar. Cooldown: 2 minutes.
/obj/structure/flora/roguetree/wise/sanctified/MiddleClick(mob/user, params)
	if(!tree_data?.has_heal_aura)
		return
	if(!istype(user, /mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = user
	if(H.patron?.type != /datum/patron/divine/dendor)
		return
	if(H.stat != CONSCIOUS || H.incapacitated())
		return
	if(tree_data.manual_heal_cooldown)
		to_chat(H, span_warning("The tree's healing has not yet recovered — wait a moment."))
		return
	if(get_dist(H, src) > 1)
		to_chat(H, span_warning("I must be adjacent to the tree to draw from its power."))
		return
	to_chat(H, span_notice("I press my palms to the sacred bark and channel the Treefather's warmth."))
	if(!do_after(H, 3 SECONDS, target = src))
		return
	if(tree_data.manual_heal_cooldown || QDELETED(src))
		return
	H.adjustBruteLoss(-30, 0)
	H.adjustFireLoss(-15, 0)
	new /obj/effect/temp_visual/heal_rogue(get_turf(H))
	playsound(get_turf(src), 'sound/magic/churn.ogg', 50, FALSE)
	to_chat(H, span_green("The Treefather's warmth flows into my wounds."))
	tree_data.manual_heal_cooldown = TRUE
	addtimer(VARSET_CALLBACK(tree_data, manual_heal_cooldown, FALSE), 2 MINUTES)

/// Temporary -4 speed debuff applied by the Treefather's Bulwark aura.
/// Duration is 8 seconds — slightly longer than the 5-second aura tick —
/// so it stays on continuously while the player remains in range.
/datum/status_effect/debuff/sanctified_tree_slow
	id = "sanctified_tree_slow"
	duration = 8 SECONDS
	effectedstats = list("speed" = -4, "strength" = -2)

/datum/status_effect/debuff/sanctified_tree_slow/on_apply()
	. = ..()
	to_chat(owner, span_warning("An oppressive weight and gnarled roots press against my feet near this tree, causing my movement to slow down."))

//==============================================================================
// Soulbind Broken Status Effect (permanent, applied on tree destruction)
//==============================================================================

/atom/movable/screen/alert/status_effect/debuff/soulbind_broken
	name = "Soulbind Broken"
	desc = "A piece of my soul has been torn away — my body and mind are diminished."
	icon_state = "debuff"

/datum/status_effect/debuff/soulbind_broken
	id = "soulbind_broken"
	alert_type = /atom/movable/screen/alert/status_effect/debuff/soulbind_broken
	effectedstats = list("strength" = -4, "speed" = -4, "perception" = -4, "intelligence" = -4, "constitution" = -4)
	duration = -1

/datum/status_effect/debuff/soulbind_broken/on_apply()
	. = ..()
	playsound(owner, 'sound/magic/soulsteal.ogg', 80, FALSE)
	to_chat(owner, span_userdanger("A piece of my soul has been torn away — my sacred bond is shattered. I am incredibly weakened."))

/datum/status_effect/debuff/soulbind_broken/on_remove()
	. = ..()
	// Permanent — blocked by living code, but implement for completeness.

/datum/stressevent/soulbind_tree_loss
	timer = 60 MINUTES
	stressadd = 5
	desc = span_boldred("My soulbound tree has fallen. I feel a permanent part of myself torn away.")

//==============================================================================
// Soulbind (Cat 7)
//==============================================================================

/// Called when cat7 offerings are complete. Sets the tree into soulbind-ready state.
/// The player must then attack the tree with harm intent + empty hand + bleeding arm to confirm.
/obj/structure/flora/roguetree/wise/sanctified/proc/on_soulbind(mob/living/user)
	if(!istype(user, /mob/living/carbon/human))
		to_chat(user, span_warning("Only a living person may soulbind with this tree."))
		return
	var/mob/living/carbon/human/H = user
	if(H.ckey in tree_data.soulbound_players)
		to_chat(H, span_warning("I am already soulbound to this tree."))
		return
	// Check once-per-player: has this player soulbound to any sanctified tree?
	if(HAS_TRAIT(H, "DENDOR_SOULBOUND"))
		to_chat(H, span_userdanger("My soul is already bound to a sanctified tree. I cannot bind twice."))
		return
	tree_data.awaiting_soulbind_ckey = H.ckey
	to_chat(H, span_warning("The ritual is set. To complete the soulbind, I must attack this tree with harm intent, my hand empty and my arm bleeding."))

/// Triggered when a player attacks the tree with harm intent + empty hand + bleeding arm.
/obj/structure/flora/roguetree/wise/sanctified/proc/attempt_soulbind(mob/living/carbon/human/H)
	if(!tree_data)
		return
	if(tree_data.awaiting_soulbind_ckey != H.ckey)
		return
	if(HAS_TRAIT(H, "DENDOR_SOULBOUND"))
		to_chat(H, span_userdanger("My soul is already bound — I cannot bind again."))
		return
	if(H.ckey in tree_data.soulbound_players)
		to_chat(H, span_warning("I am already soulbound to this tree."))
		return

	// Check intent
	if(H.used_intent?.type != INTENT_HARM)
		to_chat(H, span_warning("I must be on harm intent to complete the soulbind."))
		return
	// Check empty active hand
	if(H.get_active_held_item())
		to_chat(H, span_warning("My hand must be empty to complete the soulbind."))
		return
	// Check arm bleeding
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	if(!(r_arm?.get_bleed_rate() > 0) && !(l_arm?.get_bleed_rate() > 0))
		to_chat(H, span_warning("My arm must be bleeding to seal the soulbind in blood."))
		return

	to_chat(H, span_notice("I press my bleeding palm against the sacred bark, binding my soul to the sanctified tree."))
	if(!do_after(H, 3 SECONDS, target = src))
		return
	if(QDELETED(src) || QDELETED(H))
		return
	if(H.ckey in tree_data.soulbound_players || HAS_TRAIT(H, "DENDOR_SOULBOUND"))
		return

	// Finalize bind
	var/confirm = alert(H, "You will bind your soul to this sanctified tree. If the tree is destroyed, you will suffer a permanent, irreversible penalty to all your attributes. Proceed?", "Soulbind", "Yes", "No")
	if(confirm != "Yes" || QDELETED(src) || QDELETED(H))
		to_chat(H, span_warning("I withdraw from the sacred pact."))
		return

	// 50 brute to active arm
	var/active_zone = H.active_hand_index == 1 ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	var/obj/item/bodypart/active_arm = H.get_bodypart(active_zone)
	if(active_arm)
		active_arm.receive_damage(50, 0)
	else
		H.adjustBruteLoss(50, 0)

	// Mark as soulbound
	ADD_TRAIT(H, "DENDOR_SOULBOUND", "SOULBIND")
	tree_data.soulbound_players |= H.ckey
	tree_data.awaiting_soulbind_ckey = null

	// Grant soulbind spells
	H.mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/summon_lesser_dryad)
	H.mind.AddSpell(new /obj/effect/proc_holder/spell/targeted/lesser_dryad_special)
	H.mind.AddSpell(new /obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad)

	// Register tree destruction signal is no longer needed — cleanup is handled in Destroy().

	visible_message(span_boldwarning("[H.name]'s hand is pressed against the bark — a flash of gold seals the pact!"))
	playsound(get_turf(src), 'sound/ambience/noises/mystical (4).ogg', 70, TRUE)
	to_chat(H, span_green("My soul is bound to this sanctified tree. Should it fall, a part of me falls with it."))

/// Called when the tree is destroyed while a player is soulbound to it.
/// Actual debuffing happens via curse_soulbound_players() in Destroy().

//==============================================================================
// Examine / Interaction// Wedding ritual procs
//==============================================================================

/// Called when a bitten apple (2 names) is offered to the sanctified tree during a wedding ceremony.
/obj/structure/flora/roguetree/wise/sanctified/proc/perform_wedding(mob/living/user, obj/item/reagent_containers/food/snacks/grown/apple/A)
	var/mob/living/carbon/human/thegroom = null
	var/mob/living/carbon/human/thebride = null
	for(var/bite_name in A.bitten_names)
		var/found = FALSE
		for(var/mob/M in viewers(src, 7))
			if(!ishuman(M)) continue
			var/mob/living/carbon/human/C = M
			if(C.stat == DEAD) continue
			if(!C.client) continue
			if(C.marriedto) continue
			if(C.real_name == bite_name)
				if(!thegroom)
					thegroom = C
				else if(!thebride)
					thebride = C
				found = TRUE
				break
		if(found && thegroom && thebride)
			break

	if(!(thegroom && thebride))
		A.become_rotten()
		to_chat(user, span_danger("The Treefather's blessing falters — the bitten souls are not present or have already been wed. The apple rots."))
		tree_data.wedding_active = FALSE
		tree_data.wedding_officiant_ckey = null
		return

	var/surname = input(user, "Enter a shared surname for the couple:", "Nature's Union") as text|null
	if(QDELETED(src) || QDELETED(user))
		return
	if(!surname || !length(trim(surname)))
		surname = thegroom.dna.species.random_surname()

	priority_announce("[thegroom.real_name] and [thebride.real_name] have been wed beneath the Treefather's boughs!", title = "Nature's Union!", sound = 'sound/misc/bell.ogg')

	var/list/titles = list("Sir", "Ser", "Dame", "Lord", "Lady", "Knight-Captain", "Duke", "Duchess", "Father", "Mother", "Brother", "Sister", "Prelate", "Devotee", "Votary")

	var/list/groom_name_parts = splittext(thegroom.real_name, " ")
	var/title_found = (titles.Find(groom_name_parts[1]) != 0)
	if(title_found)
		thegroom.real_name = "[groom_name_parts[1]] [groom_name_parts[2]] [surname]"
	else
		thegroom.real_name = "[groom_name_parts[1]] [surname]"

	var/list/bride_name_parts = splittext(thebride.real_name, " ")
	title_found = (titles.Find(bride_name_parts[1]) != 0)
	if(title_found)
		thebride.real_name = "[bride_name_parts[1]] [bride_name_parts[2]] [surname]"
	else
		thebride.real_name = "[bride_name_parts[1]] [surname]"

	to_chat(thegroom, span_notice("Your new shared surname is [surname]."))
	to_chat(thebride, span_notice("Your new shared surname is [surname]."))

	thegroom.marriedto = thebride.real_name
	thebride.marriedto = thegroom.real_name
	thegroom.adjust_triumphs(1)
	thebride.adjust_triumphs(1)

	visible_message(span_green("The [src.name] blazes with golden light — Dendor and Eora both bless this union!"))
	playsound(get_turf(src), 'sound/misc/bell.ogg', 80, FALSE)
	qdel(A)
	tree_data.wedding_active = FALSE
	tree_data.wedding_officiant_ckey = null
//==============================================================================

/obj/structure/flora/roguetree/wise/sanctified/examine(mob/user)
	. = ..()
	SEND_SOUND(user, sound(null))
	var/tree_count = 0
	for(var/obj/structure/flora/newtree/T in range(5, src))
		if(!T.burnt)
			tree_count++
	for(var/obj/structure/flora/roguetree/T in range(5, src))
		if(istype(T, /obj/structure/flora/roguetree/wise) || istype(T, /obj/structure/flora/roguetree/burnt) || istype(T, /obj/structure/flora/roguetree/stump))
			continue
		tree_count++
	. += span_info("[src] draws strength from [tree_count] nearby living tree\s, granting [integrity_bonus] bonus integrity.")
	. += span_info("Integrity: [round(obj_integrity)]/[max_integrity]")
	if(show_ritual_hints)
		. += span_info("Open the ritual menu with the Dendor amulet to begin a 'Nature's Union' wedding ceremony; the betrothed must each bite the same apple once and offer it to the tree to seal the pact.")
	if(!istype(user, /mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = user
	if(H.patron?.type != /datum/patron/divine/dendor)
		return
	if(show_ritual_hints)
		. += span_notice("Hold the Dendor amulet against this tree to start or cancel a Treefather bounty.")
		. += span_notice("To offer while a bounty is active, click the tree with the required item in-hand.")
	if(show_ritual_hints && tree_data?.active_ritual)
		. += span_notice("Active bounty: [get_ritual_display_name(tree_data.active_ritual)]")
		var/list/req = get_required_offerings(tree_data.active_ritual)
		for(var/key in req)
			var/current = tree_data.ritual_progress[key] || 0
			var/needed = req[key]
			if(current >= needed)
				. += span_notice("  [get_offering_desc(key)]: [current]/[needed] (fulfilled)")
			else
				. += span_warning("  [get_offering_desc(key)]: [current]/[needed]")
	if(tree_data?.has_slow_aura)
		. += span_info("A guardian ward repels those who would defile this grove.")
	if(tree_data?.has_heal_aura)
		. += span_info("A healing aura emanates from this tree. Middle-click the tree while adjacent to channel its healing energies.")

/obj/structure/flora/roguetree/wise/sanctified/attack_hand(mob/user)
	if(istype(user, /mob/living/carbon/human) && tree_data?.awaiting_soulbind_ckey)
		var/mob/living/carbon/human/H = user
		if(H.ckey == tree_data.awaiting_soulbind_ckey)
			attempt_soulbind(H)
			return
	return ..()

/obj/structure/flora/roguetree/wise/sanctified/attackby(obj/item/I, mob/living/user, params)
	// Bitten apple: completes the Nature's Union wedding ceremony.
	if(tree_data?.wedding_active && istype(I, /obj/item/reagent_containers/food/snacks/grown/apple))
		var/obj/item/reagent_containers/food/snacks/grown/apple/A = I
		if(A.bitten_names.len < 2)
			to_chat(user, span_warning("Both partners must bite the apple before offering it to the tree."))
			return
		perform_wedding(user, A)
		return

	// Dendor amulet: entry point for ritual menu.
	if(istype(I, /obj/item/clothing/neck/roguetown/psicross/dendor))
		if(!istype(user, /mob/living/carbon/human))
			return
		var/mob/living/carbon/human/H = user
		if(H.patron?.type != /datum/patron/divine/dendor)
			to_chat(user, span_warning("Only a follower of Dendor may commune with this sacred tree."))
			return
		open_ritual_menu(user)
		return

	// While a ritual is active, offerings are made by clicking the tree with an item in-hand.
	if(tree_data?.active_ritual && istype(user, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = user
		if(H.patron?.type == /datum/patron/divine/dendor)
			if(offer_item(user))
				return
	return ..()

/obj/structure/flora/roguetree/wise/sanctified/obj_destruction(damage_flag)
	set_light(0)
	visible_message(span_warning("The sanctified tree's golden light dies as it falls — the Treefather's blessing is broken!"))
	return ..()

//==============================================================================
// Sanctified Wise Tree
// A sacred (wise) tree blessed by a Dendorite acolyte into a sanctified wise tree.
// Has the slow aura (cat4) and heal aura (cat5) active from creation, but cannot
// receive rituals, soulbind, or officiate weddings.
//==============================================================================
/obj/structure/flora/roguetree/wise/sanctified/wise
	name = "sanctified wise tree"
	desc = "An ancient sacred tree directly blessed by a Dendorite acolyte. The Treefather's power flows through its roots — it radiates healing and repels those who would defile the grove — but its deeper mysteries are locked away."
	show_ritual_hints = FALSE

/obj/structure/flora/roguetree/wise/sanctified/wise/Initialize(mapload)
	. = ..()
	// Both auras are active from creation — no rituals needed.
	tree_data.has_slow_aura = TRUE
	tree_data.has_heal_aura = TRUE
	// Replace the standard golden glow with the living-light green (normally granted by cat5).
	set_light(5, 5, 5, l_color = "#44AA44")
	add_filter("sanctified_outline", 2, list("type" = "outline", "color" = "#58C86A", "alpha" = 60, "size" = 1))

/obj/structure/flora/roguetree/wise/sanctified/wise/attackby(obj/item/I, mob/living/user, params)
	// Block ritual menu — this tree holds no further rites.
	if(istype(I, /obj/item/clothing/neck/roguetown/psicross/dendor))
		to_chat(user, span_warning("This blessed tree holds no further rites — its power is already given."))
		return
	// Block wedding initiation — sanctified wise trees cannot officiate ceremonies.
	if(istype(I, /obj/item/clothing/head/peaceflower))
		to_chat(user, span_warning("Only a fully sanctified tree may officiate a wedding ceremony."))
		return
	return ..()
