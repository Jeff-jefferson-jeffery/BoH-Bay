/obj/item/projectile/bullet
	name = "bullet"
	icon_state = "bullet"
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 50
	damage_type = BRUTE
	damage_flags = DAM_BULLET | DAM_SHARP
	nodamage = 0
	embed = 1
	shrapnel_chance_multiplier = 1
	arterial_bleed_chance_multiplier = 1
	var/mob_passthrough_check = 0

	muzzle_type = /obj/effect/projectile/bullet/muzzle
	miss_sounds = list('sound/weapons/guns/miss1.ogg','sound/weapons/guns/miss2.ogg','sound/weapons/guns/miss3.ogg','sound/weapons/guns/miss4.ogg')
	ricochet_sounds = list('sound/weapons/guns/ricochet1.ogg', 'sound/weapons/guns/ricochet2.ogg',
							'sound/weapons/guns/ricochet3.ogg', 'sound/weapons/guns/ricochet4.ogg')
	impact_sounds = list(BULLET_IMPACT_MEAT = SOUNDS_BULLET_MEAT, BULLET_IMPACT_METAL = SOUNDS_BULLET_METAL)

/obj/item/projectile/bullet/on_hit(var/atom/target, var/blocked = 0)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/bullet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if(penetrating > 0 && damage > 20 && prob(damage))
		mob_passthrough_check = 1
	else
		mob_passthrough_check = 0
	. = ..()

	if(. == 1 && iscarbon(target_mob))
		damage *= 0.7 //squishy mobs absorb KE

/obj/item/projectile/bullet/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if(mob_passthrough_check)
		return 0
	return ..()

/obj/item/projectile/bullet/check_penetrate(var/atom/A)
	if(QDELETED(A) || !A.density) return 1 //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	if(ismob(A))
		if(!mob_passthrough_check)
			return 0
		return 1

	var/chance = damage
	if(has_extension(A, /datum/extension/penetration))
		var/datum/extension/penetration/P = get_extension(A, /datum/extension/penetration)
		chance = P.PenetrationProbability(chance, damage, damage_type)

	if(prob(chance))
		if(A.opacity)
			//display a message so that people on the other side aren't so confused
			A.visible_message("<span class='warning'>\The [src] pierces through \the [A]!</span>")
		return 1

	return 0

//For projectiles that actually represent clouds of projectiles
/obj/item/projectile/bullet/pellet
	name = "shrapnel" //'shrapnel' sounds more dangerous (i.e. cooler) than 'pellet'
	damage = 37.5
	//icon_state = "bullet" //TODO: would be nice to have it's own icon state
	var/pellets = 4			//number of pellets
	var/range_step = 2		//projectile will lose a fragment each time it travels this distance. Can be a non-integer.
	var/base_spread = 90	//lower means the pellets spread more across body parts. If zero then this is considered a shrapnel explosion instead of a shrapnel cone
	var/spread_step = 10	//higher means the pellets spread more across body parts with distance

/obj/item/projectile/bullet/pellet/Bumped()
	. = ..()
	bumped = 0 //can hit all mobs in a tile. pellets is decremented inside attack_mob so this should be fine.

/obj/item/projectile/bullet/pellet/proc/get_pellets(var/distance)
	var/pellet_loss = round((distance - 1)/range_step) //pellets lost due to distance
	return max(pellets - pellet_loss, 1)

/obj/item/projectile/bullet/pellet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if (pellets < 0) return 1

	var/total_pellets = get_pellets(distance)
	var/spread = max(base_spread - (spread_step*distance), 0)

	//shrapnel explosions miss prone mobs with a chance that increases with distance
	var/prone_chance = 0
	if(!base_spread)
		prone_chance = max(spread_step*(distance - 2), 0)

	var/hits = 0
	for (var/i in 1 to total_pellets)
		if(target_mob.lying && target_mob != original && prob(prone_chance))
			continue

		//pellet hits spread out across different zones, but 'aim at' the targeted zone with higher probability
		//whether the pellet actually hits the def_zone or a different zone should still be determined by the parent using get_zone_with_miss_chance().
		var/old_zone = def_zone
		def_zone = ran_zone(def_zone, spread)
		if (..()) hits++
		def_zone = old_zone //restore the original zone the projectile was aimed at

	pellets -= hits //each hit reduces the number of pellets left
	if (hits >= total_pellets || pellets <= 0)
		return 1
	return 0

/obj/item/projectile/bullet/pellet/get_structure_damage()
	var/distance = get_dist(loc, starting)
	return ..() * get_pellets(distance)

/obj/item/projectile/bullet/pellet/Move()
	. = ..()

	//If this is a shrapnel explosion, allow mobs that are prone to get hit, too
	if(. && !base_spread && isturf(loc))
		for(var/mob/living/M in loc)
			if(M.lying || !M.CanPass(src, loc, 0.5, 0)) //Bump if lying or if we would normally Bump.
				if(Bump(M)) //Bump will make sure we don't hit a mob multiple times
					return

/* short-casing projectiles, like the kind used in pistols or SMGs */

/obj/item/projectile/bullet/pistol
	fire_sound = 'sound/weapons/gunshot/gunshot_pistol.ogg'
	damage = 45
	distance_falloff = 3

/obj/item/projectile/bullet/pistol/holdout
	damage = 40
	armor_penetration = 5
	shrapnel_chance_multiplier = 1.2
	arterial_bleed_chance_multiplier = 1.2
	distance_falloff = 4

/obj/item/projectile/bullet/pistol/xo
	fire_sound = 'sound/weapons/gunshot/gunshot_pistol.ogg'
	damage = 45
	armor_penetration = 10
	distance_falloff = 3

/obj/item/projectile/bullet/pistol/strong
	fire_sound = 'sound/weapons/gunshot/gunshot_strong.ogg'
	damage = 50
	shrapnel_chance_multiplier = 0.8
	arterial_bleed_chance_multiplier = 0.8
	distance_falloff = 2.5
	armor_penetration = 15

//"rubber" bullets
//Armor pen is to prevent them from being invalidated by ARMOR_BALLISTIC_MINOR, as has been the case.
/obj/item/projectile/bullet/pistol/rubber
	name = "rubber bullet"
	damage_flags = 0
	damage = 10
	agony = 40
	embed = 0
	armor_penetration = 5

/obj/item/projectile/bullet/pistol/rubber/holdout
	agony = 25
	armor_penetration = 5

//4mm. Tiny, very low damage, does not embed, but has very high penetration. Only to be used for the experimental SMG.
/obj/item/projectile/bullet/flechette
	fire_sound = 'sound/weapons/gunshot/gunshot_4mm.ogg'
	damage = 23
	penetrating = 1
	armor_penetration = 70
	embed = 0
	distance_falloff = 2

/* shotgun projectiles */

/obj/item/projectile/bullet/shotgun
	name = "slug"
	fire_sound = 'sound/weapons/gunshot/shotgun.ogg'
	damage = 60
	armor_penetration = 10
	distance_falloff = 1.5

/obj/item/projectile/bullet/shotgun/beanbag		//because beanbags are not bullets
	name = "beanbag"
	damage = 10
	damage_flags = 0
	agony = 65
	armor_penetration = 10
	embed = 0

//Spreads damage across more body parts than slugs, but is more effective up close and against unarmored opponents
//High number of pellets with low velocity lends itself to more embeds
/obj/item/projectile/bullet/pellet/shotgun
	name = "shrapnel"
	fire_sound = 'sound/weapons/gunshot/shotgun.ogg'
	damage = 30
	armor_penetration = 10
	pellets = 8
	range_step = 2
	spread_step = 10
	shrapnel_chance_multiplier = 2.0

/* "Rifle" rounds */

/obj/item/projectile/bullet/rifle
	fire_sound = 'sound/weapons/gunshot/gunshot3.ogg'
	damage = 45
	armor_penetration = 25
	shrapnel_chance_multiplier = 1.5
	arterial_bleed_chance_multiplier = 1.5
	penetrating = 1

/obj/item/projectile/bullet/rifle/military
	fire_sound = 'sound/weapons/gunshot/gunshot2.ogg'
	damage = 35
	armor_penetration = 35
	shrapnel_chance_multiplier = 1
	arterial_bleed_chance_multiplier = 1

/obj/item/projectile/bullet/rifle/military/large
	fire_sound = 'sound/weapons/gunshot/hornet.ogg'
	damage = 45
	armor_penetration = 45
	penetrating = 2
	distance_falloff = 0.50
	shrapnel_chance_multiplier = 1.1
	arterial_bleed_chance_multiplier = 1.3

/obj/item/projectile/bullet/rifle/shell
	fire_sound = 'sound/weapons/gunshot/sniper.ogg'
	damage = 80
	stun = 3
	weaken = 3
	penetrating = 3
	armor_penetration = 70
	shrapnel_chance_multiplier = 1.2
	arterial_bleed_chance_multiplier = 1.2
	distance_falloff = 0.5

/obj/item/projectile/bullet/rifle/shell/apds
	damage = 70
	penetrating = 5
	armor_penetration = 80
	shrapnel_chance_multiplier = 1.5
	arterial_bleed_chance_multiplier = 1.5

/* Miscellaneous */
/obj/item/projectile/bullet/gyro
	name = "minirocket"
	fire_sound = 'sound/effects/Explosion1.ogg'
	var/gyro_devastation = -1
	var/gyro_heavy_impact = 0
	var/gyro_light_impact = 2

/obj/item/projectile/bullet/gyro/on_hit(var/atom/target, var/blocked = 0)
	if(isturf(target))
		explosion(target, gyro_devastation, gyro_heavy_impact, gyro_light_impact)
	..()

/obj/item/projectile/bullet/blank
	invisibility = 101
	damage = 1
	embed = 0

/obj/item/projectile/bullet/nail
	name = "nail"
	icon_state = "nail"
	fire_sound = 'sound/weapons/genhit.ogg'
	damage = 0.5
	damage_type = BRUTE
	damage_flags = DAM_BULLET | DAM_SHARP
	nodamage = 0
	embed = 1
	shrapnel_chance_multiplier = 0.1
	arterial_bleed_chance_multiplier = 0.1
	muzzle_type = null

/* Practice */

/obj/item/projectile/bullet/pistol/practice
	damage = 5

/obj/item/projectile/bullet/rifle/military/practice
	damage = 5

/obj/item/projectile/bullet/shotgun/practice
	name = "practice"
	damage = 5

/obj/item/projectile/bullet/pistol/cap
	name = "cap"
	invisibility = 101
	fire_sound = null
	damage_type = PAIN
	damage_flags = 0
	damage = 0
	nodamage = 1
	embed = 0

/obj/item/projectile/bullet/pistol/cap/Process()
	qdel(src)
	return PROCESS_KILL

/obj/item/projectile/bullet/rock //spess dust
	name = "micrometeor"
	icon_state = "rock"
	damage = 40
	armor_penetration = 25
	life_span = 255
	distance_falloff = 0

/obj/item/projectile/bullet/rock/New()
	icon_state = "rock[rand(1,3)]"
	pixel_x = rand(-10,10)
	pixel_y = rand(-10,10)
	..()

/////////
/*
Courtesy of Mazian.
They've given me the go ahead to rip their code from Citadel, and place it here.
Thanks a bunch! :n
*/
/////////

/obj/item/projectile/bullet/pistol/pepperball
	name = "pepperball"
	damage = 0
	agony = 0
	embed = 0
	sharp = 0
	nodamage = 1

/obj/item/projectile/bullet/pistol/pepperball/on_hit(var/atom/target, var/blocked = 0, var/alien)
	..()
	var/eyes_covered = 0
	var/mouth_covered = 0

	var/head_covered = 0
	var/arms_covered = 0
	var/legs_covered = 0
	var/hands_covered = 0
	var/feet_covered = 0
	var/chest_covered = 0
	var/groin_covered = 0

	var/obj/item/safe_thing = null

	var/effective_strength = 5
	if(!istype(target, /mob/living/carbon/human))
		return
	if(alien == IS_SKRELL)	//Larger eyes means bigger targets.
		effective_strength = 8

	if(alien == IS_DIONA)
		effective_strength = 4
	var/mob/living/carbon/human/M = target
	if(istype(target, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = M
		if(!H.can_feel_pain())
			return
		if(H.head)
			if(H.head.body_parts_covered & EYES)
				eyes_covered = 1
				safe_thing = H.head
			if((H.head.body_parts_covered & FACE) && !(H.head.item_flags & ITEM_FLAG_FLEXIBLEMATERIAL))
				mouth_covered = 1
				safe_thing = H.head
		if(H.wear_mask)
			if(!eyes_covered && H.wear_mask.body_parts_covered & EYES)
				eyes_covered = 1
				safe_thing = H.wear_mask
			if(!mouth_covered && (H.wear_mask.body_parts_covered & FACE) && !(H.wear_mask.item_flags & ITEM_FLAG_FLEXIBLEMATERIAL))
				mouth_covered = 1
				safe_thing = H.wear_mask
		if(H.glasses && H.glasses.body_parts_covered & EYES)
			if(!eyes_covered)
				eyes_covered = 1
				if(!safe_thing)
					safe_thing = H.glasses
	if(eyes_covered && mouth_covered)
		to_chat(M, "<span class='warning'>Your [safe_thing] protects you from the pepperball!</span>")
		if(alien != IS_SLIME)
			return
	else if(eyes_covered)
		to_chat(M, "<span class='warning'>Your [safe_thing] protects you from most of the pepperball!</span>")
		to_chat(M, "<span class='warning'>Oh god, it burns!</span>")
		M.eye_blurry = max(M.eye_blurry, effective_strength * 3)
		M.eye_blind = max(M.eye_blind, effective_strength)
		M.apply_effect(6 * effective_strength, PAIN, 0)
		if(alien != IS_SLIME)
			return
	else if(mouth_covered) // Mouth cover is better than eye cover
		to_chat(M, "<span class='warning'>Your [safe_thing] protects your face from the pepperball!</span>")
		M.eye_blurry = max(M.eye_blurry, effective_strength)
		if(alien != IS_SLIME)
			return
	else// Oh dear :D
		to_chat(M, "<span class='warning'>Your eyes are affected by the pepperball!</span>")
		to_chat(M, "<span class='warning'>Oh god, it burns!</span>")
		M.eye_blurry = max(M.eye_blurry, effective_strength * 5)
		M.eye_blind = max(M.eye_blind, effective_strength)
		M.apply_effect(6 * effective_strength, PAIN, 0)
		if(alien != IS_SLIME)
			return
	if(alien == IS_SLIME)
		if(!head_covered)
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your head burns!</span>")
			M.apply_effect(5 * effective_strength, PAIN, 0)
		if(!chest_covered)
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your chest burns!</span>")
			M.apply_effect(5 * effective_strength, PAIN, 0)
		if(!groin_covered && prob(75))
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your groin burns!</span>")
			M.apply_effect(3 * effective_strength, PAIN, 0)
		if(!arms_covered && prob(45))
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your arms burns!</span>")
			M.apply_effect(3 * effective_strength, PAIN, 0)
		if(!legs_covered && prob(45))
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your legs burns!</span>")
			M.apply_effect(3 * effective_strength, PAIN, 0)
		if(!hands_covered && prob(20))
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your hands burns!</span>")
			M.apply_effect(effective_strength / 2, PAIN, 0)
		if(!feet_covered && prob(20))
			if(prob(33))
				to_chat(M, "<span class='warning'>The exposed flesh on your feet burns!</span>")
			M.apply_effect(effective_strength / 2, PAIN, 0)
