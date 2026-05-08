/datum/job/roguetown/kingsfield_visitor
	title = "Kingsfield Visitor"
	faction = "Station"
	total_positions = 0
	spawn_positions = 0
	selection_color = "#8d8f78"
	allowed_races = RACES_ALL_KINDS
	allowed_sexes = list(MALE, FEMALE)
	tutorial = "You have left your old life and arrived in Kingsfield as a humble visitor."
	outfit = /datum/outfit/job/roguetown/kingsfield_visitor
	display_order = JDO_PILGRIM
	hidden_job = TRUE
	show_in_credits = FALSE
	announce_latejoin = FALSE
	can_random = FALSE
	bypass_jobban = TRUE
	bypass_lastclass = TRUE

/datum/outfit/job/roguetown/kingsfield_visitor/pre_equip(mob/living/carbon/human/H)
	. = ..()
	if(should_wear_femme_clothes(H))
		shirt = /obj/item/clothing/suit/roguetown/shirt/dress/silkdress
		pants = /obj/item/clothing/under/roguetown/tights/black
	else
		shirt = /obj/item/clothing/suit/roguetown/shirt/undershirt/vagrant
		pants = /obj/item/clothing/under/roguetown/tights/vagrant
	shoes = /obj/item/clothing/shoes/roguetown/shortboots
	belt = /obj/item/storage/belt/rogue/leather/rope
	beltl = /obj/item/storage/belt/rogue/pouch/coins/poor
	backr = /obj/item/storage/backpack/rogue/satchel
	backpack_contents = list(
		/obj/item/flashlight/flare/torch = 1,
		/obj/item/reagent_containers/food/snacks/rogue/bread = 1,
	)
