/// Reusable seal items for sealing letters and documents
/// Seals work like signet rings: dipped into heated tallow, then pressed onto paper
/// Only the tallow is consumed; the seal item remains for reuse

/obj/item/seal
	name = "wax seal"
	desc = "A small seal for marking official documents. It has a small loop to attach it to a keyring."
	icon = 'icons/roguetown/clothing/rings.dmi'
	icon_state = "signet"
	item_state = "signet"
	w_class = WEIGHT_CLASS_TINY
	var/tallowed = FALSE
	var/seal_label = "Official Seal"
	var/seal_color = "#8b6914"
	var/seal_is_official = TRUE

/obj/item/seal/attack_right(mob/user)
	if(is_blind(user))
		return TRUE
	user.visible_message(span_notice("[user] scrapes the tallow off of [src]."))
	tallowed = FALSE
	update_icon()
	return TRUE

/obj/item/seal/update_icon()
	if(tallowed)
		icon_state = "signet_stamp"
	else
		icon_state = "signet"

/obj/item/seal/examine(mob/user)
	. = ..()
	. += "<span style='color:[seal_color]'>It imprints a seal of [seal_label].</span>"

/obj/item/seal/attackby(obj/item/I, mob/living/user, params)
	if(istype(I, /obj/item/inqarticles/tallowpot))
		var/obj/item/inqarticles/tallowpot/pot = I
		if(!pot.tallow)
			to_chat(user, span_warning("The [pot] has no tallow in it."))
			return
		if(!pot.heatedup)
			to_chat(user, span_warning("The [pot.tallow] in [pot] is hardened. I need to heat it first."))
			return
		tallowed = TRUE
		update_icon()
		to_chat(user, span_notice("I coat [src] with melted [pot.tallow]."))
		return

	return ..()

/obj/item/seal/custom
	name = "blank custom seal"
	desc = "A blank seal head ready to be engraved once."
	seal_label = "Custom Seal"
	seal_color = "#8b6914"
	seal_is_official = FALSE
	var/customized = FALSE

/obj/item/seal/custom/attack_self(mob/user)
	if(customized)
		to_chat(user, span_warning("[src] is already engraved and cannot be changed."))
		return
	if(is_blind(user))
		return
	var/new_label = stripped_input(user, "Engrave your seal text (once only):", "Custom Seal Engraving", "", 64)
	if(!new_label)
		return
	new_label = trim(STRIP_HTML_SIMPLE(new_label, 64))
	if(!length(new_label))
		to_chat(user, span_warning("The engraving must contain text."))
		return
	var/new_color = sanitize_hexcolor(color_pick_sanitized(user, "Choose wax color:", "Custom Seal Color", seal_color, 0.2, 1), 6, TRUE)
	if(!new_color)
		new_color = "#8b6914"
	seal_label = new_label
	seal_color = new_color
	customized = TRUE
	name = "custom seal"
	desc = "A personalized wax seal with a unique engraving."
	to_chat(user, span_notice("I engrave [src] and set its wax color."))

/datum/crafting_recipe/roguetown/survival/custom_seal
	name = "Blank Custom Seal (1 Small Log)"
	result = /obj/item/seal/custom
	reqs = list(
		/obj/item/grown/log/tree/small = 1,
	)
	time = 8 SECONDS
	skillcraft = /datum/skill/craft/crafting
	craftdiff = 3
	verbage_simple = "carve"
	verbage = "carves"

/datum/crafting_recipe/roguetown/survival/custom_seal/TurfCheck(mob/user, turf/T)
	if(user.get_skill_level(/datum/skill/craft/crafting) < SKILL_LEVEL_JOURNEYMAN)
		to_chat(user, span_warning("I need Journeyman crafting skill to carve a usable custom seal."))
		return FALSE
	return ..()

// Seal of the Crown
/obj/item/seal/crown
	name = "crown seal"
	seal_label = "The Crown of Rotwood Vale"
	seal_color = "#8b6914"

// Steward's seal
/obj/item/seal/steward
	name = "steward's seal"
	seal_label = "The Steward of Rotwood Vale"
	seal_color = "#8b6914"

// Marshal's seal
/obj/item/seal/marshal
	name = "marshal's seal"
	seal_label = "The Marshal's Office"
	seal_color = "#2c1a0e"

// Councillor's seal
/obj/item/seal/councillor
	name = "councillor's seal"
	seal_label = "The Royal Council"
	seal_color = "#1a3a1a"

// Merchant's seal
/obj/item/seal/merchant
	name = "merchant's seal"
	seal_label = "The Rotwood Vale Official Merchant"
	seal_color = "#c9a84c"

// Nightmaster/Mistress seal
/obj/item/seal/nightmaster
	name = "night seal"
	seal_label = "The Nightmaster's Authority"
	seal_color = "#2a2a2a"

// Guildmaster's seal
/obj/item/seal/guildmaster
	name = "guild master's seal"
	seal_label = "The Guildmaster of Rotwood Vale"
	seal_color = "#8b6914"

// Prelate's seal
/obj/item/seal/prelate
	name = "prelate's seal"
	seal_label = "High Prelate of Rotwood Vale"
	seal_color = "#d4af37"

// Court Magos seal
/obj/item/seal/court_magos
	name = "court magos seal"
	seal_label = "The Court Magos"
	seal_color = "#6b0099"

// Master Warden's seal
/obj/item/seal/master_warden
	name = "master warden's seal"
	seal_label = "Master of the Wardens of Rotwood Vale"
	seal_color = "#2d5a2d"

// Seneschal's seal
/obj/item/seal/seneschal
	name = "seneschal's seal"
	seal_label = "The Seneschal of The Keep of Rotwood Vale"
	seal_color = "#8b0000"

// Hand of the Ruler seal
/obj/item/seal/hand
	name = "hand's seal"
	seal_label = "The Hand of the Crown of Rotwood Vale"
	seal_color = "#8b6914"

// Knight Captain's seal
/obj/item/seal/knight_captain
	name = "knight captain's seal"
	seal_label = "The Knight Captain of Rotwood Vale"
	seal_color = "#1a1a1a"
