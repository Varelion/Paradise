// TODO: remove the robot.mmi and robot.cell variables and completely rely on the robot component system

/datum/robot_component
	var/name = "Component"
	var/installed = FALSE
	var/powered = TRUE
	var/toggled = TRUE
	var/brute_damage = 0
	var/electronics_damage = 0
	var/max_damage = 30
	var/component_disabled = 0
	var/mob/living/silicon/robot/owner
	var/external_type = null // The actual device object that has to be installed for this.
	var/obj/item/wrapped = null // The wrapped device(e.g. radio), only set if external_type isn't null

/datum/robot_component/New(mob/living/silicon/robot/R)
	owner = R

// Should only ever be destroyed when a borg gets destroyed
/datum/robot_component/Destroy(force, ...)
	owner = null
	QDEL_NULL(wrapped)
	return ..()

/datum/robot_component/proc/install(obj/item/I, update_health = TRUE)
	wrapped = I
	installed = TRUE
	go_online()
	if(update_health)
		owner.updatehealth("component '[src]' installed")

/datum/robot_component/proc/uninstall()
	wrapped = null
	installed = FALSE
	go_offline()
	owner.updatehealth("component '[src]' removed")

/datum/robot_component/proc/destroy()
	if(wrapped)
		qdel(wrapped)
	uninstall()
	wrapped = new/obj/item/broken_device

/datum/robot_component/proc/take_damage(brute, electronics, sharp, updating_health = TRUE)
	if(!installed)
		return

	if(owner && updating_health)
		owner.updatehealth("component '[src]' take damage")

	brute_damage += brute
	electronics_damage += electronics

	if(brute_damage + electronics_damage >= max_damage)
		destroy()

	SStgui.update_uis(owner.self_diagnosis)

/datum/robot_component/proc/heal_damage(brute, electronics, updating_health = TRUE)
	if(!installed)
		// If it's not installed, can't repair it.
		return 0

	if(owner && updating_health)
		owner.updatehealth("component '[src]' heal damage")

	brute_damage = max(0, brute_damage - brute)
	electronics_damage = max(0, electronics_damage - electronics)

	SStgui.update_uis(owner.self_diagnosis)

/datum/robot_component/proc/is_powered()
	return installed && (brute_damage + electronics_damage < max_damage) && (powered)

/datum/robot_component/proc/is_destroyed()
	return istype(wrapped, /obj/item/broken_device)


/datum/robot_component/proc/is_missing()
	return isnull(wrapped)

/datum/robot_component/proc/consume_power()
	if(!toggled)
		powered = FALSE
		return
	powered = TRUE

	SStgui.update_uis(owner.self_diagnosis)

/datum/robot_component/proc/disable()
	if(!component_disabled)
		go_offline()
	component_disabled++

/datum/robot_component/proc/enable()
	component_disabled--
	if(!component_disabled)
		go_online()

/datum/robot_component/proc/toggle()
	toggled = !toggled
	if(toggled)
		go_online()
	else
		go_offline()

	SStgui.update_uis(owner.self_diagnosis)

/datum/robot_component/proc/go_online()
	return

/datum/robot_component/proc/go_offline()
	return

/datum/robot_component/armour
	name = "armour plating"
	external_type = /obj/item/robot_parts/robot_component/armour
	max_damage = 100

/datum/robot_component/actuator
	name = "actuator"
	external_type = /obj/item/robot_parts/robot_component/actuator
	max_damage = 50

/datum/robot_component/cell
	name = "power cell"
	max_damage = 50

/datum/robot_component/cell/install(obj/item/stock_parts/cell/C)
	external_type = C.type // Update the cell component's `external_type` to the path of new cell
	owner.cell = C
	..()

/datum/robot_component/cell/uninstall()
	..()
	owner.cell = null

/datum/robot_component/cell/is_powered()
	return ..() && owner.cell

/datum/robot_component/cell/Destroy(force, ...)
	owner.cell = null
	return ..()

/datum/robot_component/cell/destroy()
	..()
	owner.cell = null

/datum/robot_component/radio
	name = "radio"
	external_type = /obj/item/robot_parts/robot_component/radio
	max_damage = 40

/datum/robot_component/binary_communication
	name = "binary communication device"
	external_type = /obj/item/robot_parts/robot_component/binary_communication_device
	max_damage = 30

/datum/robot_component/camera
	name = "camera"
	external_type = /obj/item/robot_parts/robot_component/camera
	max_damage = 40

/datum/robot_component/camera/go_online()
	owner.update_blind_effects()
	owner.update_sight()

/datum/robot_component/camera/go_offline()
	owner.update_blind_effects()
	owner.update_sight()

/datum/robot_component/diagnosis_unit
	name = "self-diagnosis unit"
	external_type = /obj/item/robot_parts/robot_component/diagnosis_unit
	max_damage = 30

/mob/living/silicon/robot/proc/initialize_components()
	// This only initializes the components, it doesn't set them to installed.

	components["actuator"] = new/datum/robot_component/actuator(src)
	components["radio"] = new/datum/robot_component/radio(src)
	components["power cell"] = new/datum/robot_component/cell(src)
	components["diagnosis unit"] = new/datum/robot_component/diagnosis_unit(src)
	components["camera"] = new/datum/robot_component/camera(src)
	components["comms"] = new/datum/robot_component/binary_communication(src)
	components["armour"] = new/datum/robot_component/armour(src)

/mob/living/silicon/robot/proc/is_component_functioning(module_name)
	var/datum/robot_component/C = components[module_name]
	return C && C.installed && C.toggled && C.is_powered() && !C.component_disabled

/mob/living/silicon/robot/proc/disable_component(module_name, duration)
	var/datum/robot_component/D = get_component(module_name)
	D.disable()
	spawn(duration)
		D.enable()

// Returns component by it's string name
/mob/living/silicon/robot/proc/get_component(component_name)
	var/datum/robot_component/C = components[component_name]
	return C

/obj/item/broken_device
	name = "broken component"
	desc = "A component of a robot, broken to the point of being unidentifiable."
	icon = 'icons/obj/robot_component.dmi'
	icon_state = "broken"

/obj/item/robot_parts/robot_component
	icon = 'icons/obj/robot_component.dmi'
	desc = "One of the numerous parts required to make a robot work."
	icon_state = "working"
	var/brute = 0
	var/burn = 0


/obj/item/robot_parts/robot_component/binary_communication_device
	name = "binary communication device"
	desc = "A module used for binary communications over encrypted frequencies, commonly used by synthetic robots."
	icon_state = "binary_translator"

/obj/item/robot_parts/robot_component/actuator
	name = "actuator"
	desc = "A modular, hydraulic actuator used by robots for movement and manipulation."
	icon_state = "actuator"

/obj/item/robot_parts/robot_component/armour
	name = "armour plating"
	desc = "A pair of flexible, adaptable armor plates, used to protect the internals of robots."
	icon_state = "armor_plating"

/obj/item/robot_parts/robot_component/camera
	name = "camera"
	desc = "A modified camera module used as a visual receptor for robots and exosuits, also serving as a relay for wireless video feed."
	icon_state = "camera"

/obj/item/robot_parts/robot_component/diagnosis_unit
	name = "diagnosis unit"
	desc = "An internal computer and sensors used by robots and exosuits to accurately diagnose any system discrepancies on their components."
	icon_state = "diagnosis_unit"

/obj/item/robot_parts/robot_component/radio
	name = "radio"
	desc = "A modular, multi-frequency radio used by robots and exosuits to enable communication systems. Comes with built-in subspace receivers."
	icon_state = "radio"

//
//Robotic Component Analyzer, basically a health analyzer for robots
//
/obj/item/robotanalyzer
	name = "cyborg analyzer"
	icon = 'icons/obj/device.dmi'
	icon_state = "robotanalyzer"
	item_state = "analyzer"
	desc = "A hand-held scanner able to diagnose robotic injuries."
	flags = CONDUCT
	slot_flags = SLOT_FLAG_BELT
	throwforce = 3
	w_class = WEIGHT_CLASS_SMALL
	throw_speed = 5
	throw_range = 10
	origin_tech = "magnets=1;biotech=1"
	var/mode = 1

/obj/item/robotanalyzer/attack(mob/living/M as mob, mob/living/user as mob)
	if((HAS_TRAIT(user, TRAIT_CLUMSY) || user.getBrainLoss() >= 60) && prob(50))
		var/list/messages = list()
		user.visible_message("<span class='warning'>[user] has analyzed the floor's vitals!</span>", "<span class='warning'>You try to analyze the floor's vitals!</span>")
		messages.Add("<span class='notice'>Analyzing Results for The floor:\n\t Overall Status: Healthy</span>")
		messages.Add("<span class='notice'>\t Damage Specifics: [0]-[0]-[0]-[0]</span>")
		messages.Add("<span class='notice'>Key: Suffocation/Toxin/Burns/Brute</span>")
		messages.Add("<span class='notice'>Body Temperature: ???</span>")
		to_chat(user, chat_box_healthscan(messages.Join("<br>")))
		return

	user.visible_message("<span class='notice'>[user] has analyzed [M]'s components.</span>","<span class='notice'>You have analyzed [M]'s components.</span>")
	robot_healthscan(user, M)
	add_fingerprint(user)


/proc/robot_healthscan(mob/user, mob/living/M)
	var/scan_type
	if(isrobot(M))
		scan_type = "robot"
	else if(ishuman(M))
		scan_type = "prosthetics"
	else
		to_chat(user, "<span class='warning'>You can't analyze non-robotic things!</span>")
		return

	var/list/messages = list()
	switch(scan_type)
		if("robot")
			var/BU = M.getFireLoss() > 50 	? 	"<b>[M.getFireLoss()]</b>" 		: M.getFireLoss()
			var/BR = M.getBruteLoss() > 50 	? 	"<b>[M.getBruteLoss()]</b>" 	: M.getBruteLoss()
			messages.Add("<span class='notice'>Analyzing Results for [M]:\n\t Overall Status: [M.stat > 1 ? "fully disabled" : "[M.health]% functional"]</span>")
			messages.Add("\t Key: <font color='#FFA500'>Electronics</font>/<font color='red'>Brute</font>")
			messages.Add("\t Damage Specifics: <font color='#FFA500'>[BU]</font> - <font color='red'>[BR]</font>")
			if(M.timeofdeath && M.stat == DEAD)
				messages.Add("<span class='notice'>Time of Disable: [station_time_timestamp("hh:mm:ss", M.timeofdeath)]</span>")
			var/mob/living/silicon/robot/H = M
			var/list/damaged = H.get_damaged_components(TRUE, TRUE, TRUE) // Get all except the missing ones
			var/list/missing = H.get_missing_components()
			messages.Add("<span class='notice'>Localized Damage:</span>")
			if(!LAZYLEN(damaged) && !LAZYLEN(missing))
				messages.Add("<span class='notice'>\t Components are OK.</span>")
			else
				if(LAZYLEN(damaged))
					for(var/datum/robot_component/org in damaged)
						messages.Add(text("<span class='notice'>\t []: [][] - [] - [] - []</span>",	\
						capitalize(org.name),					\
						(org.is_destroyed())	?	"<font color='red'><b>DESTROYED</b></font> "							:"",\
						(org.electronics_damage > 0)	?	"<font color='#FFA500'>[org.electronics_damage]</font>"	:0,	\
						(org.brute_damage > 0)	?	"<font color='red'>[org.brute_damage]</font>"							:0,		\
						(org.toggled)	?	"Toggled ON"	:	"<font color='red'>Toggled OFF</font>",\
						(org.powered)	?	"Power ON"		:	"<font color='red'>Power OFF</font>"),1)
				if(LAZYLEN(missing))
					for(var/datum/robot_component/org in missing)
						messages.Add("<span class='warning'>\t [capitalize(org.name)]: MISSING</span>")

			if(H.emagged && prob(5))
				messages.Add("<span class='warning'>\t ERROR: INTERNAL SYSTEMS COMPROMISED</span>")

		if("prosthetics")
			var/mob/living/carbon/human/H = M
			messages.Add("<span class='notice'>Analyzing Results for \the [H]:</span>")
			messages.Add("Key: <font color='#FFA500'>Electronics</font>/<font color='red'>Brute</font>")

			to_chat(user, "<span class='notice'>External prosthetics:</span>")
			var/organ_found
			if(LAZYLEN(H.internal_organs))
				for(var/obj/item/organ/external/E in H.bodyparts)
					if(!E.is_robotic())
						continue
					organ_found = TRUE
					messages.Add("[E.name]: <font color='red'>[E.brute_dam]</font> <font color='#FFA500'>[E.burn_dam]</font>")
			if(!organ_found)
				messages.Add("<span class='warning'>No prosthetics located.</span>")
			messages.Add("<hr>")
			messages.Add("<span class='notice'>Internal prosthetics:</span>")
			organ_found = null
			if(LAZYLEN(H.internal_organs))
				for(var/obj/item/organ/internal/O in H.internal_organs)
					if(!O.is_robotic() || istype(O, /obj/item/organ/internal/cyberimp))
						continue
					organ_found = TRUE
					messages.Add("[capitalize(O.name)]: <font color='red'>[O.damage]</font>")
			if(!organ_found)
				messages.Add("<span class='warning'>No prosthetics located.</span>")
			messages.Add("<hr>")
			messages.Add("<span class='notice'>Cybernetic implants:</span>")
			organ_found = null
			if(LAZYLEN(H.internal_organs))
				for(var/obj/item/organ/internal/cyberimp/I in H.internal_organs)
					organ_found = TRUE
					messages.Add("[capitalize(I.name)]: <font color='red'>[I.crit_fail ? "CRITICAL FAILURE" : I.damage]</font>")
			if(!organ_found)
				messages.Add("<span class='warning'>No implants located.</span>")

	to_chat(user, chat_box_healthscan(messages.Join("<br>")))
