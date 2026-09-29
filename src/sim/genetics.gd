class_name Genetics extends RefCounted
## tg genetics (code/datums/dna, code/datums/mutations, __DEFINES/DNA.dm, __HELPERS/dna.dm).
##
## Every carbon has DNA (CDna): unique enzymes (md5 of the real name, which blood carries),
## a unique identity (hex blocks for gender, skin, eyes, hair...), unique features, and a
## mutation index of eight genes - the monkey gene plus seven random ones - each a 32
## letter sequence with some letters knocked out to X. Fill in a gene to match its true
## sequence and the mutation turns on (domutcheck).
##
## This file is the round's genetic data (tg SSatoms.setupGenetics: every mutation's alias
## "Mutation N" and its true sequence), the mutation table (tg's 84 /datum/mutation types,
## generated from the .dm files), the block maths, the recipes the console combines, and
## instability meltdowns. What each mutation does lives in GeneFx.

const POSITIVE := 1
const NEGATIVE := 2
const MINOR_NEGATIVE := 4

## tg mutation sources: while a mutation has one, it stays
const SRC_ACTIVATED := "activated"
const SRC_MUTATOR := "mutator"
const SRC_GENE_SYMPTOM := "gene_symptom"
const STANDARD_SOURCES := [SRC_ACTIVATED, SRC_MUTATOR]

const DNA_BLOCK_SIZE := 3
const DNA_BLOCK_SIZE_COLOR := 6
const DNA_SEQUENCE_LENGTH := 4
const DNA_MUTATION_BLOCKS := 8
const DNA_UNIQUE_ENZYMES_LEN := 32

const CHROMOSOME_NEVER := 0
const CHROMOSOME_NONE := 1
const CHROMOSOME_USED := 2
const UNMODIFIABLE := -1.0

## tg genetic genders
const GENDERS := 4
const G_MALE := 1
const G_FEMALE := 2
const G_PLURAL := 3
const G_NEUTER := 4

const HEX := "0123456789abcdef" # tg GLOB.hex_characters

## tg /datum/mutation types. quality 1 positive, 2 negative, 4 minor negative;
## instability as tg's *_STABILITY / *_INSTABILITY defines; difficulty 8 unless given;
## sync / power_c / energy are the chromosome coefficients (absent = unmodifiable).
const DEFS := {
	"adrenaline_rush": {"name": "Adrenaline Rush", "desc": "The subject gains the ability to trigger their body's adrenaline response at will.", "quality": 1, "instability": 25, "gain": "You feel pumped up!", "gain_k": "info", "power": "adrenaline", "sync": 1.0, "power_c": 1.0, "energy": 1.0},
	"adaptation": {"name": "Adaptation", "desc": "The subject gains immunity to damage from extreme temperatures. Does not protect from thin air.", "quality": 1, "instability": -40, "difficulty": 16, "locked": true, "gain": "Your body feels normal!", "gain_k": "info", "conflicts": ["adaptation", "adaptation_cold", "adaptation_heat", "adaptation_thermal", "adaptation_pressure"], "traits": ["waddling"]},
	"adaptation_cold": {"name": "Cold Adaptation", "desc": "The subject gains immunity to damage from low temperature environments, as well as stability when navigating on ice.", "quality": 1, "instability": 25, "difficulty": 16, "gain": "Your body feels refreshingly cold.", "gain_k": "info", "conflicts": ["adaptation", "adaptation_cold", "adaptation_heat", "adaptation_thermal", "adaptation_pressure"], "traits": ["resistcold", "no_slip_ice"], "icon": "cold"},
	"adaptation_heat": {"name": "Heat Adaptation", "desc": "The subject gains immunity to damage from high temperatures (including fire), as well as resistance to ash storms.", "quality": 1, "instability": 25, "difficulty": 16, "gain": "Your body feels invigoratingly warm.", "gain_k": "info", "conflicts": ["adaptation", "adaptation_cold", "adaptation_heat", "adaptation_thermal", "adaptation_pressure"], "traits": ["resistheat", "ashstorm_immune"], "icon": "fire"},
	"adaptation_thermal": {"name": "Thermal Adaptation", "desc": "The subject gains immunity to damage from both low and high temperature environments. Does not protect from high or low pressure environments, nor does it provide stability on ice or resistance to ash storms.", "quality": 1, "instability": 35, "difficulty": 32, "locked": true, "gain": "Your body feels pleasantly room temperature.", "gain_k": "info", "conflicts": ["adaptation", "adaptation_cold", "adaptation_heat", "adaptation_thermal", "adaptation_pressure"], "traits": ["resistheat", "resistcold"], "icon": "thermal"},
	"adaptation_pressure": {"name": "Pressure Adaptation", "desc": "The subject gains immunity to damage from both low and high pressure environments. Does not protect from temperature, including the cold of space.", "quality": 1, "instability": 25, "difficulty": 16, "gain": "Your body feels impressively pressurized.", "gain_k": "info", "conflicts": ["adaptation", "adaptation_cold", "adaptation_heat", "adaptation_thermal", "adaptation_pressure"], "traits": ["resistlowpressure", "resisthighpressure"], "icon": "pressure"},
	"antenna": {"name": "Antenna", "desc": "The subject sprouts an antenna, which is known to allow them to access common radio channels without any external devices.", "quality": 1, "instability": 10, "gain": "You feel an antenna sprout from your forehead.", "gain_k": "info", "lose": "Your antenna shrinks back down.", "lose_k": "info", "icon": "antenna"},
	"mindreader": {"name": "Mind Reader", "desc": "The subject can look into the recent memories of others.", "quality": 1, "instability": 10, "locked": true, "gain": "You hear distant voices at the corners of your mind.", "gain_k": "info", "lose": "The distant voices fade.", "lose_k": "info", "power": "mindread", "icon": "antenna"},
	"aoe_moodlet": {"name": "Extremely Unsightly", "desc": "The subject's body - and especially their face - is unnaturally unsightly, causing a negative reaction from those around them. Wearing a mask will dampen the effect.", "quality": 2, "instability": -10, "difficulty": 12, "gain": "You feel pretty in your own way.", "gain_k": "warn", "lose": "You feel less self-conscious.", "lose_k": "info"},
	"aoe_moodlet_positive": {"name": "Extremely Comely", "desc": "The subject's body - and especially their face - is unnaturally comely, causing a positive reaction from those around them. Wearing a mask will dampen the effect.", "quality": 1, "instability": 10, "difficulty": 12, "gain": "You feel pretty in your own way.", "gain_k": "info", "lose": "You feel less self-conscious.", "lose_k": "info"},
	"self_amputation": {"name": "Autotomy", "desc": "The subject gains the ability to voluntarily discard a random appendage.", "quality": 1, "instability": 10, "gain": "Your joints feel loose.", "gain_k": "info", "power": "self_amputation", "sync": 1.0, "energy": 1.0},
	"epilepsy": {"name": "Epilepsy", "desc": "The subject sporadically suffers from seizures.", "quality": 2, "instability": -30, "gain": "You get a headache.", "gain_k": "bad", "sync": 1.0, "power_c": 1.0},
	"bad_dna": {"name": "Unstable DNA", "desc": "The subject will randomly mutate other mutations or features.", "quality": 2, "instability": -40, "locked": true, "gain": "You feel strange.", "gain_k": "bad"},
	"cough": {"name": "Cough", "desc": "The subject has a chronic cough.", "quality": 4, "instability": -30, "gain": "You start coughing.", "gain_k": "bad", "sync": 1.0, "power_c": 1.0},
	"paranoia": {"name": "Paranoia", "desc": "The subject is easily terrified, and may suffer from hallucinations.", "quality": 2, "instability": -30, "gain": "You feel screams echo through your mind...", "gain_k": "bad", "lose": "The screaming in your mind fades.", "lose_k": "info"},
	"dwarfism": {"name": "Dwarfism", "desc": "The subject's cells are more compact, making the subject appear smaller.", "quality": 1, "instability": 10, "difficulty": 16, "locked": true, "conflicts": ["gigantism", "acromegaly"]},
	"acromegaly": {"name": "Acromegaly", "desc": "The subject's cells stack on top of one another, making the subject appear unusually tall.", "quality": 4, "instability": -30, "difficulty": 16, "conflicts": ["dwarfism"], "sync": 1.0},
	"gigantism": {"name": "Gigantism", "desc": "The subject's cells are more spread out, making the subject appear larger.", "quality": 4, "instability": 0, "difficulty": 12, "conflicts": ["dwarfism"]},
	"clumsy": {"name": "Clumsiness", "desc": "The subject's brain functions are impaired, causing them to exhibit fool-like behavior.", "quality": 4, "instability": -40, "gain": "You feel lightheaded.", "gain_k": "bad", "traits": ["clumsy"]},
	"tourettes": {"name": "Tourette's Syndrome", "desc": "The subject has a chronic twitching disorder, causing them to involuntarily shout or twitch.", "quality": 2, "instability": 0, "gain": "You twitch.", "gain_k": "bad", "sync": 1.0},
	"deaf": {"name": "Deafness", "desc": "The subject is completely deaf and cannot hear anything.", "quality": 2, "instability": -40, "gain": "You can't seem to hear anything.", "gain_k": "bad", "traits": ["deaf"]},
	"race": {"name": "Monkified", "desc": "A strange genome, believing to be what differentiates monkeys from humans.", "quality": 2, "instability": -40, "locked": true, "gain": "You feel unusually monkey-like.", "gain_k": "good", "lose": "You feel like your old self.", "lose_k": "info"},
	"glow": {"name": "Glowy", "desc": "The subject's skin emits a soft glow, illuminating the area around them.", "quality": 1, "instability": 5, "gain": "Your skin begins to glow softly.", "gain_k": "info", "conflicts": ["glow_anti"], "power_c": 1.0},
	"glow_anti": {"name": "Anti-Glow", "desc": "The subject's skin absorbs light, making the area around them darker.", "quality": 1, "instability": 10, "locked": true, "gain": "The light around you seems to disappear.", "gain_k": "info", "conflicts": ["glow"], "power_c": 1.0},
	"strong": {"name": "Strength", "desc": "The subject's muscles slightly expand, improving general strength and workout efficiency.", "quality": 1, "instability": 10, "difficulty": 16, "gain": "You feel strong.", "gain_k": "info", "traits": ["strength"]},
	"stimmed": {"name": "Stimmed", "desc": "The subject's chemical balance is more robust, improving workout efficiency.", "quality": 1, "instability": 5, "difficulty": 16, "gain": "You feel stimmed.", "gain_k": "info", "traits": ["stimmed"]},
	"insulated": {"name": "Insulated", "desc": "The subject does not conduct electricity.", "quality": 1, "instability": 25, "difficulty": 16, "gain": "Your fingertips go numb.", "gain_k": "info", "lose": "Your fingertips regain feeling.", "lose_k": "info", "traits": ["shockimmune"]},
	"fire": {"name": "Fiery Sweat", "desc": "The subject's skin will randomly combust, though ultimately becomes more resilient to burning.", "quality": 2, "instability": 0, "difficulty": 14, "gain": "You feel hot.", "gain_k": "warn", "lose": "You feel a lot cooler.", "lose_k": "info", "conflicts": ["adaptation_heat"], "sync": 1.0, "power_c": 1.0},
	"badblink": {"name": "Spatial Instability", "desc": "The subject has a very weak link to spatial reality, and may be displaced. Often causes extreme nausea.", "quality": 2, "instability": -30, "difficulty": 18, "gain": "The space around you twists sickeningly.", "gain_k": "warn", "lose": "The space around you settles back to normal.", "lose_k": "info", "sync": 1.0, "power_c": 1.0, "energy": 1.0},
	"acidflesh": {"name": "Acidic Flesh", "desc": "The subject has acidic chemicals building up underneath the skin. This is often lethal.", "quality": 2, "instability": -40, "difficulty": 18, "gain": "A horrible burning sensation envelops you as your flesh turns to acid!", "gain_k": "bad", "lose": "A feeling of relief fills you as your flesh goes back to normal.", "lose_k": "info"},
	"spastic": {"name": "Spastic", "desc": "The subject suffers from muscle spasms.", "quality": 2, "instability": -30, "difficulty": 16, "gain": "You flinch.", "gain_k": "warn", "lose": "Your flinching subsides.", "lose_k": "info"},
	"extrastun": {"name": "Two Left Feet", "desc": "The subject's right foot is replaced with another left foot. Symptoms include kissing the floor when taking a step.", "quality": 2, "instability": -30, "difficulty": 16, "gain": "Your right foot feels... left.", "gain_k": "warn", "lose": "Your right foot feels alright.", "lose_k": "info"},
	"martyrdom": {"name": "Internal Martyrdom", "desc": "The subject violently tears itself apart when near death. The process is irreversible. The effect is not known to damage anything nearby, but is very, VERY disorienting when observed.", "quality": 1, "instability": -40, "locked": true, "gain": "You get an intense feeling of heartburn.", "gain_k": "warn", "lose": "Your internal organs feel at ease.", "lose_k": "info"},
	"headless": {"name": "H.A.R.S.", "desc": "Short for \"Head Allergic Rejection Syndrome\", the subject's body rejects the head, causing its brain to recede into the chest. Reversing this mutation is very dangerous, though it will regenerate non-vital head organs.", "quality": 2, "instability": -40, "difficulty": 12, "gain": "Something feels off.", "gain_k": "warn"},
	"bloodier": {"name": "Hypermetabolic Blood", "desc": "The subject's becomes hypermetabolic, causing it to produce blood at a much faster rate.", "quality": 1, "instability": 10, "difficulty": 16, "gain": "You can feel your heartbeat pick up.", "gain_k": "info", "lose": "You heartbeat slows back down.", "lose_k": "info", "sync": 1.0, "power_c": 1.0},
	"rock_eater": {"name": "Rock Eater", "desc": "The subject's body is able to digest rocks and minerals.", "quality": 1, "instability": 5, "difficulty": 12, "gain": "You feel a craving for rocks.", "gain_k": "info", "lose": "You could go for a normal meal.", "lose_k": "info", "conflicts": ["rock_absorber"], "traits": ["rock_eater"]},
	"rock_absorber": {"name": "Rock Absorber", "desc": "The subject's body is able to digest rocks and minerals, taking on their properties.", "quality": 1, "instability": 35, "locked": true, "gain": "You feel a supreme craving for rocks.", "gain_k": "info", "lose": "You could go for a normal meal.", "lose_k": "info", "conflicts": ["rock_eater"], "traits": ["rock_eater", "rock_metamorphic"]},
	"inexorable": {"name": "Inexorable", "desc": "The subject's body can push on beyond the limits of normal human endurance, though the process causes internal damage to the body.", "quality": 1, "instability": 25, "difficulty": 24, "gain": "You feel inexorable.", "gain_k": "info", "lose": "You suddenly feel more human.", "lose_k": "info", "traits": ["nosoftcrit", "analgesia"], "sync": 1.0},
	"limb_regeneration": {"name": "Regeneration", "desc": "The subject's body is able to regenerate lost limbs or organs while sleeping, given ample rest and nutrients.", "quality": 1, "instability": 25, "difficulty": 20, "gain": "You feel a strange tingling.", "gain_k": "info", "lose": "The strange tingling feeling fades.", "lose_k": "info", "sync": 1.0, "power_c": 1.0},
	"chemical_allergy": {"name": "Chemical Allergy", "desc": "The subject's body is allergic to almost all forms of medicine or drug - causing a temporary flux of genetic instability, among other side effects.", "quality": 2, "instability": -40, "difficulty": 20, "gain": "You feel a strange irritation in your skin.", "gain_k": "warn", "lose": "The irritation in your skin subsides.", "lose_k": "info"},
	"venomous_strikes": {"name": "Venomous", "desc": "The subject's body produces a minor toxin that can be injected into others through scratches or bites. They will also filter out the same variety of toxin from their own bloodstream should they be exposed to it themselves.", "quality": 1, "instability": 25, "gain": "You teeth and nails feel sharper.", "gain_k": "info", "lose": "You teeth and nails feel duller.", "lose_k": "info"},
	"chameleon": {"name": "Chameleon", "desc": "The subject's skin becomes transparent over time while not moving.", "quality": 1, "instability": 35, "difficulty": 16, "gain": "You feel one with your surroundings.", "gain_k": "info", "lose": "You feel oddly exposed.", "lose_k": "info", "power_c": 1.0},
	"chameleon_changeling": {"name": "Chameleon", "desc": "The subject's skin becomes transparent over time while not moving.", "quality": 1, "instability": 0, "difficulty": 16, "locked": true, "gain": "You feel one with your surroundings.", "gain_k": "info", "lose": "You feel oddly exposed.", "lose_k": "info", "power_c": 2.5},
	"geladikinesis": {"name": "Geladikinesis", "desc": "The subject can solidify moisture in the air into snow at will.", "quality": 1, "instability": 10, "difficulty": 10, "gain": "Your hand feels cold.", "gain_k": "info", "power": "snow", "sync": 1.0},
	"cryokinesis": {"name": "Cryokinesis", "desc": "The subject can draw negative energy from the void to fire a bolt of freezing energy at will.", "quality": 1, "instability": 25, "difficulty": 12, "gain": "Your hand feels cold.", "gain_k": "info", "power": "cryo", "sync": 1.0, "energy": 1.0},
	"farsight": {"name": "Farsight", "desc": "The subject's eyes are able to see further than normal.", "quality": 1, "instability": 10, "difficulty": 16, "gain": "You feel your eyes tingle.", "gain_k": "info", "lose": "Your eyes feel normal.", "lose_k": "info", "power": "farsight", "power_c": 1.0},
	"firebreath": {"name": "Fire Breath", "desc": "The subject can breathe fire at will.", "quality": 1, "instability": 25, "difficulty": 12, "locked": true, "gain": "Your throat is burning!", "gain_k": "info", "lose": "Your throat is cooling down.", "lose_k": "info", "power": "fire_breath", "power_c": 1.0, "energy": 1.0},
	"cindikinesis": {"name": "Cindikinesis", "desc": "The subject can draw heat out of the air to produce a pile of ash at will.", "quality": 1, "instability": 10, "difficulty": 10, "locked": true, "gain": "Your hand feels warm.", "gain_k": "info", "power": "ash", "sync": 1.0},
	"pyrokinesis": {"name": "Pyrokinesis", "desc": "The subject can draw positive energy from the environment to fire a bolt of hot energy at will.", "quality": 1, "instability": 25, "difficulty": 12, "locked": true, "gain": "Your hand feels hot!", "gain_k": "info", "power": "pyro", "sync": 1.0, "energy": 1.0},
	"hulk": {"name": "Hulk", "desc": "The subject's muscles expand drastically, granting superhuman strength and resilience, but inhibit speech in the process. This heightened muscle density is more vulnerable to the cold, and cannot be maintained if critically injured.", "quality": 1, "instability": 35, "difficulty": 16, "locked": true, "gain": "Your muscles hurt!", "gain_k": "info", "conflicts": ["hulk_ork"], "species": ["human"], "health_req": 25, "traits": ["chunkyfingers", "hulk", "pushimmune", "stunimmune"]},
	"hulk_wizardly": {"name": "Hulk (Magical)", "desc": "The subject's muscles expand drastically, granting superhuman strength and resilience, but inhibit speech in the process. This heightened muscle density is more vulnerable to the cold, and cannot be maintained if critically injured.", "quality": 1, "instability": 0, "difficulty": 16, "locked": true, "gain": "Your muscles hurt!", "gain_k": "info", "conflicts": ["hulk_ork"], "traits": ["hulk", "pushimmune", "stunimmune"]},
	"hulk_superhuman": {"name": "Hulk (Super)", "desc": "The subject's muscles expand drastically, granting superhuman strength and resilience, but inhibit speech in the process. This heightened muscle density is more vulnerable to the cold, and cannot be maintained if critically injured.", "quality": 1, "instability": 0, "difficulty": 16, "locked": true, "gain": "Your muscles hurt!", "gain_k": "info", "conflicts": ["hulk_ork"], "species": ["human"], "traits": ["chunkyfingers", "hulk", "nosoftcrit", "nohardcrit", "pushimmune", "stunimmune", "analgesia", "no_oxyloss_passout"]},
	"hulk_ork": {"name": "Ork", "desc": "A variant of the hulk mutation that is also known to inhibit the subject's brain functions.", "quality": 1, "instability": 35, "difficulty": 16, "locked": true, "gain": "You feel significantly dumber!", "gain_k": "info", "conflicts": ["hulk"], "species": ["human"], "health_req": 25, "traits": ["chunkyfingers", "hulk", "pushimmune", "stunimmune"]},
	"olfaction": {"name": "Transcendent Olfaction", "desc": "The subject's sense of smell is comparable to that of a canine.", "quality": 1, "instability": 25, "difficulty": 12, "gain": "Smells begin to make more sense...", "gain_k": "info", "lose": "Your sense of smell goes back to normal.", "lose_k": "info", "power": "olfaction", "sync": 1.0},
	"biotechcompat": {"name": "Biotech Compatibility", "desc": "The subject is compatible with biotechnology such as skillchips.", "quality": 1, "instability": 5},
	"clever": {"name": "Clever", "desc": "The subject's intelligence level is raised to that of the average deckhand.", "quality": 1, "instability": 25, "gain": "You feel a little bit smarter.", "gain_k": "bad", "lose": "Your mind feels a little bit foggy.", "lose_k": "bad"},
	"radioactive": {"name": "Radioactivity", "desc": "The subject emits deadly beta radiation, affecting both the host and their surroundings.", "quality": 2, "instability": -40, "gain": "You can feel it in your bones!", "gain_k": "warn", "power_c": 1.0, "icon": "radiation"},
	"telekinesis": {"name": "Telekinesis", "desc": "The subject gains the ability to interact with objects through thought.", "quality": 1, "instability": 35, "difficulty": 18, "gain": "You feel smarter!", "gain_k": "info", "limb_req": "head", "icon": "telekinesishead"},
	"elastic_arms": {"name": "Elastic Arms", "desc": "The subject's arms become elastic, allowing them to stretch up to a meter away. However, this elasticity makes it difficult to wear gloves, handle complex tasks, or grab large objects.", "quality": 1, "instability": 35, "difficulty": 32, "gain": "You feel armstrong!", "gain_k": "warn", "lose": "Your arms stop feeling so saggy all the time.", "lose_k": "warn", "traits": ["chunkyfingers", "no_twohanding"]},
	"nearsight": {"name": "Near Sightness", "desc": "The subject has poor eyesight, and cannot see distant objects.", "quality": 4, "instability": -30, "gain": "You can't see very well.", "gain_k": "bad"},
	"blind": {"name": "Blindness", "desc": "The subject is completely blind and cannot see anything.", "quality": 2, "instability": -40, "gain": "You can't seem to see anything.", "gain_k": "bad"},
	"thermal": {"name": "Thermal Vision", "desc": "The subject gains the ability to temporarily focus their eyes, allowing them to perceive human thermal signatures. However, the process is known to cause eye damage on repeat use.", "quality": 1, "instability": 35, "difficulty": 18, "gain": "You can see the heat rising off of your skin...", "gain_k": "info", "lose": "You can no longer see the heat rising off of your skin...", "lose_k": "info", "power": "thermal_vision", "sync": 1.0, "power_c": 1.0, "energy": 1.0},
	"xray": {"name": "X Ray Vision", "desc": "The subject gains the ability to see between the spaces of walls.", "quality": 0, "instability": 35, "locked": true, "gain": "The walls suddenly disappear!", "gain_k": "info"},
	"laser_eyes": {"name": "Laser Eyes", "desc": "The subject gains the ability to reflect concentrated light back from the eyes.", "quality": 1, "instability": 0, "difficulty": 16, "locked": true, "gain": "You feel pressure building up behind your eyes.", "gain_k": "info", "limb_req": "head", "icon": "lasereyes"},
	"illiterate": {"name": "Illiterate", "desc": "The subject loses the ability to read or write.", "quality": 2, "instability": -40, "gain": "You feel unable to read or write.", "gain_k": "bad", "lose": "You feel able to read and write again.", "lose_k": "bad"},
	"night_vision": {"name": "Night Vision", "desc": "The subject can see in the dark.", "quality": 1, "instability": 35, "gain": "The darkness of the corners of the room fades away.", "gain_k": "info", "lose": "The darkness of the corners of the room returns.", "lose_k": "info"},
	"nervousness": {"name": "Nervousness", "desc": "The subject gains a nervous stutter.", "quality": 4, "instability": 0, "gain": "You feel nervous.", "gain_k": "bad"},
	"wacky": {"name": "Wacky", "desc": "The subject not only becomes a fool, but instead the entire troupe.", "quality": 4, "instability": 0, "gain": "You feel an off sensation in your voicebox.", "gain_k": "info", "lose": "The off sensation passes.", "lose_k": "info"},
	"heckacious": {"name": "Heckacious Larincks", "desc": "duge what is WISH your words man...........", "quality": 4, "instability": 0, "locked": true, "gain": "aw SHIT man. your throat feels like FUCKASS.", "gain_k": "info", "lose": "The demonic entity possessing your larynx has finally released its grasp.", "lose_k": "info"},
	"mute": {"name": "Mute", "desc": "The subject's vocal section of the brain is completely inhibited.", "quality": 2, "instability": -40, "gain": "You feel unable to express yourself at all.", "gain_k": "bad", "lose": "You feel able to speak freely again.", "lose_k": "bad"},
	"unintelligible": {"name": "Unintelligible", "desc": "The subject's vocal section of the brain is partially inhibited, distorting speech.", "quality": 2, "instability": -30, "gain": "You can't seem to form any coherent thoughts!", "gain_k": "bad", "lose": "Your mind feels more clear.", "lose_k": "bad"},
	"swedish": {"name": "Swedish", "desc": "A horrible mutation originating from the distant past, thought to be eradicated after the incident in 2037. The subject's speech becomes difficult to understand, and is often mistaken for a foreign language.", "quality": 4, "instability": 0, "gain": "You feel Swedish, however that works.", "gain_k": "info", "lose": "The feeling of Swedishness passes.", "lose_k": "info"},
	"chav": {"name": "Chav", "desc": "An unknown mutation that causes the subject to speak in a very specific dialect. The subject's speech becomes difficult to understand, and is often mistaken for a foreign language.", "quality": 4, "instability": 0, "gain": "Ye feel like a reet prat like, innit?", "gain_k": "info", "lose": "You no longer feel like being rude and sassy.", "lose_k": "info"},
	"elvis": {"name": "Elvis", "desc": "A terrifying mutation named after its 'patient-zero'. The subject begins to speak in strange rhythms, and often breaks into dance.", "quality": 4, "instability": 0, "gain": "You feel pretty good, honeydoll.", "gain_k": "info", "lose": "You feel a little less conversation would be great.", "lose_k": "info"},
	"stoner": {"name": "Stoner", "desc": "The subject's intelligence levels drop significantly, causing them to speak in words that only others on a similar level can understand.", "quality": 2, "instability": 0, "gain": "You feel...totally chill, man!", "gain_k": "info", "lose": "You feel like you have a better sense of time.", "lose_k": "info"},
	"medieval": {"name": "Medieval", "desc": "A horrible mutation originating from the distant past, thought to have once been a common gene in all of old Terran \"Europe\". The subject gains a verbal tick that causes them to speak very particularly.", "quality": 4, "instability": 0, "gain": "You feel like seeking the holy grail!", "gain_k": "info", "lose": "You no longer feel like seeking anything.", "lose_k": "info"},
	"piglatin": {"name": "Pig Latin", "desc": "Historians say five centuries ago, humanity spoke entirely in this mystical language. The subject becomes forced to speak in said language, which is often difficult to understand.", "quality": 4, "instability": 0, "gain": "Omethingsay eelsfay offyay.", "gain_k": "info", "lose": "The off sensation passes.", "lose_k": "info"},
	"telepathy": {"name": "Telepathy", "desc": "The subject gains the abililty to telepathically communicate to others.", "quality": 1, "instability": 10, "difficulty": 12, "gain": "You can hear your own voice echoing in your mind!", "gain_k": "info", "lose": "You don't hear your mind echo anymore.", "lose_k": "info", "power": "telepathy", "energy": 1.0},
	"tongue_spike": {"name": "Tongue Spike", "desc": "The subject gains the ability to voluntary shoot their tongue out as a deadly weapon.", "quality": 1, "instability": 5, "gain": "Your feel like you can throw your voice.", "gain_k": "info", "power": "tongue_spike", "sync": 1.0, "energy": 1.0},
	"tongue_spike_chem": {"name": "Chem Spike", "desc": "The subject gains the ability to voluntary shoot their tongue out as biomass, allowing a long range transfer of chemicals.", "quality": 1, "instability": 10, "locked": true, "gain": "Your feel like you can really connect with people by throwing your voice.", "gain_k": "info", "power": "chem_spike", "sync": 1.0, "energy": 1.0},
	"shock": {"name": "Shock Touch", "desc": "The subject gains the ability to channel excess ambient electricity through their hands, allowing them to shock others in a mostly harmless manner.", "quality": 1, "instability": 25, "difficulty": 16, "locked": true, "gain": "You feel power flow through your hands.", "gain_k": "info", "lose": "The energy in your hands subsides.", "lose_k": "info", "power": "shock_touch", "power_c": 1.0, "energy": 1.0},
	"lay_on_hands": {"name": "Mending Touch", "desc": "The subject gains the ability to lay their hands on others to transfer a small amount of their injuries to themselves.", "quality": 1, "instability": 35, "difficulty": 16, "gain": "Your hands feel blessed!", "gain_k": "info", "lose": "Your hands no longer feel blessed.", "lose_k": "info", "power": "lay_on_hands", "sync": 1.0, "power_c": 1.0, "energy": 1.0},
	"void": {"name": "Void Magnet", "desc": "The subject attracts odd forces which are not usually observed.", "quality": 4, "instability": 25, "gain": "You feel a heavy, dull force just beyond the walls watching you.", "gain_k": "info", "power": "void_cursed", "sync": 1.0, "energy": 1.0},
	"webbing": {"name": "Webbing Production", "desc": "The subject gains the ability to lay webbing, and travel through it.", "quality": 1, "instability": 25, "gain": "Your skin feels webby.", "gain_k": "info", "power": "lay_web", "energy": 1.0},
}

## tg /datum/generecipe (_combined.dm): two stored mutations -> a new one
const RECIPES := [
	["strong", "radioactive", "hulk"],
	["antenna", "paranoia", "mindreader"],
	["insulated", "radioactive", "shock"],
	["geladikinesis", "fire", "cindikinesis"],
	["cryokinesis", "fire", "pyrokinesis"],
	["adaptation_cold", "adaptation_heat", "adaptation_thermal"],
	["glow", "void", "glow_anti"],
	["tongue_spike", "stimmed", "tongue_spike_chem"],
	["strong", "stimmed", "martyrdom"],
	["wacky", "stoner", "heckacious"],
	["hulk", "clumsy", "hulk_ork"],
	["rock_eater", "stoner", "rock_absorber"],
]

## tg /datum/instability_meltdown subtypes: id -> [weight, fatal]
const MELTDOWNS := {
	"monkey": [1, false], "paraplegic": [1, false], "corgi": [1, false], "alright": [1, false],
	"not_alright": [1, false], "slime": [1, false], "yeet": [1, false], "decloning": [1, false],
	"organ_vomit": [1, false], "snail": [2, false], "crab": [1, false],
	"gib": [1, true], "dust": [1, true], "petrify": [1, true], "dismember": [1, true],
	"skeletonize": [1, true], "ceiling": [1, true], "psyker": [1, true],
}

## tg identity blocks (GLOB.dna_identity_blocks, in order) and their lengths
const UI_BLOCKS := [["gender", 3], ["skin_tone", 3], ["eye_colors", 12], ["hair_style", 3], ["hair_color", 6],
	["facial_style", 3], ["facial_color", 6], ["hair_gradient", 3], ["hair_gradient_color", 6],
	["facial_gradient", 3], ["facial_gradient_color", 6], ["height", 3]]
## tg feature blocks (GLOB.dna_feature_blocks): the mutant colour then the species accessories
const UF_BLOCKS := [["mcolor", 6], ["ears", 3], ["tail_cat", 3], ["tail_lizard", 3], ["fish_tail", 3], ["snout", 3],
	["marking_lizard", 3], ["horns", 3], ["frills", 3], ["spines", 3], ["moth_wings", 3], ["moth_antennae", 3],
	["moth_markings", 3], ["caps", 3], ["pod_hair", 3]]
## how many options each accessory has (tg SSaccessories feature lists)
const FEATURE_OPTIONS := {"ears": 2, "tail_cat": 2, "tail_lizard": 5, "fish_tail": 5, "snout": 3, "marking_lizard": 4, "horns": 6,
	"frills": 4, "spines": 7, "moth_wings": 24, "moth_antennae": 20, "moth_markings": 9, "caps": 2, "pod_hair": 7}
## tg dna_heights: shortest, short, medium, tall, taller (a DNA height is an index into it)
const HEIGHTS := ["shortest", "short", "medium", "tall", "taller"]
const GRADIENTS := ["none", "fadeup", "fadedown", "vertical", "horizontal", "reflected", "wavy", "long", "sidecut", "fade_up_soft"]

# ------------------------------------------------------------------ the round's genetics
static var aliases := {} # mutation id -> "Mutation N"
static var alias_to_id := {}
static var sequences := {} # mutation id -> its true 32 letter sequence (tg GLOB.full_sequences)
static var good: Array = [] # tg GLOB.good_mutations (unlocked positives)
static var bad: Array = []
static var not_good: Array = []
## tg stored_research.discovered_mutations: what the station's DNA consoles have found
static var discovered := {}
static var _ready := false

static func ensure() -> void:
	if not _ready:
		setup_round()

## tg SSatoms.setupGenetics: shuffle every mutation type, number them, give each a true
## sequence, and sort the unlocked ones into the good / bad / not-good pools.
static func setup_round() -> void:
	_ready = true
	aliases.clear()
	alias_to_id.clear()
	sequences.clear()
	good.clear()
	bad.clear()
	not_good.clear()
	discovered.clear()
	var ids: Array = DEFS.keys()
	shuffle(ids)
	for i in ids.size():
		var mid: String = ids[i]
		var d: Dictionary = DEFS[mid]
		var al := "Mutation %d" % (i + 1)
		aliases[mid] = al
		alias_to_id[al] = mid
		sequences[mid] = generate_gene_sequence(d.get("blocks", 4))
		if d.get("locked", false):
			continue
		match int(d.get("quality", 0)):
			POSITIVE: good.append(mid)
			NEGATIVE: bad.append(mid)
			MINOR_NEGATIVE: not_good.append(mid)

static func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := Game.rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

static func rand_pick(a: Array):
	return a[Game.rng.randi() % a.size()] if not a.is_empty() else null

static func prob(p: float) -> bool:
	return Game.rng.randf() * 100.0 < p

## tg SPT_PROB: prob per second, for a tick of dt seconds
static func spt_prob(p: float, dt: float) -> bool:
	return Game.rng.randf() < 1.0 - pow(1.0 - clampf(p / 100.0, 0.0, 1.0), dt)

## tg generate_gene_sequence: 4 blocks of 4 pairs, each AT, TA, GC or CG
static func generate_gene_sequence(length := 4) -> String:
	var pairs := ["AT", "TA", "GC", "CG"]
	var s := ""
	for i in length * DNA_SEQUENCE_LENGTH:
		s += pairs[Game.rng.randi() % 4]
	return s

static func sequence(mid: String) -> String:
	ensure()
	return sequences.get(mid, "")

static func alias(mid: String) -> String:
	ensure()
	return aliases.get(mid, mid)

## tg create_sequence: the true sequence with difficulty + rand(-2, 4) letters knocked out
## (the same letter can be hit twice, so sometimes fewer X's show).
static func create_sequence(mid: String, active := false, difficulty := 0) -> String:
	var s := sequence(mid)
	if s == "":
		return ""
	if difficulty == 0:
		difficulty = DEFS.get(mid, {}).get("difficulty", 8)
	difficulty += Game.rng.randi_range(-2, 4)
	if active:
		return s
	while difficulty > 0:
		var n := Game.rng.randi_range(0, s.length() - 1)
		s = s.substr(0, n) + "X" + s.substr(n + 1)
		difficulty -= 1
	return s

## tg get_mixed_mutation
static func mixed(a: String, b: String) -> String:
	if a == "" or b == "" or a == b:
		return ""
	for r in RECIPES:
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			return r[2]
	return ""

# ------------------------------------------------------------------ block maths
static func random_hex(n: int) -> String:
	var s := ""
	for i in n:
		s += HEX[Game.rng.randi() % 16]
	return s

static func num2hex(v: int, len: int) -> String:
	var s := ""
	for i in len:
		s = HEX[v & 15] + s
		v >>= 4
	return s

static func hex2num(s: String) -> int:
	return s.hex_to_int() if s != "" and s.is_valid_hex_number() else 0

## tg construct_block: value 1..values spread over the block's range
static func construct_block(value: int, values: int, blocksize := DNA_BLOCK_SIZE) -> String:
	var width := int(floor(pow(16, blocksize) / float(values)))
	if value < 1:
		value = 1
	value = value * width - Game.rng.randi_range(1, width)
	return num2hex(value, blocksize)

## tg deconstruct_block
static func deconstruct_block(hex: String, values: int, blocksize := DNA_BLOCK_SIZE) -> int:
	var width := int(floor(pow(16, blocksize) / float(values)))
	var v := int(floor(hex2num(hex) / float(width))) + 1
	return mini(v, values)

## Where a block starts in its hash (0-based) and how long it is.
static func block_pos(blocks: Array, id: String) -> Vector2i:
	var at := 0
	for b in blocks:
		if b[0] == id:
			return Vector2i(at, b[1])
		at += b[1]
	return Vector2i(-1, 0)

static func hash_len(blocks: Array) -> int:
	var n := 0
	for b in blocks:
		n += b[1]
	return n

## tg get_block / modified_hash
static func get_block(hash_str: String, blocks: Array, id: String) -> String:
	var p := block_pos(blocks, id)
	return hash_str.substr(p.x, p.y) if p.x >= 0 else ""

static func modified_hash(hash_str: String, blocks: Array, id: String, value: String) -> String:
	var p := block_pos(blocks, id)
	if p.x < 0:
		return hash_str
	return hash_str.substr(0, p.x) + value + hash_str.substr(p.x + p.y)

static func hex_color(c: Color) -> String:
	return c.to_html(false).to_lower()

static func color_of(hex: String) -> Color:
	return Color("#" + hex) if hex.length() == 6 and hex.is_valid_hex_number() else Color.WHITE

# ------------------------------------------------------------------ helpers
static func dna(e: Entity) -> CDna:
	return e.c(&"dna") if e != null and is_instance_valid(e) else null

## tg can_mutate: an organic carbon with DNA that isn't geneless or husked
static func can_mutate(e: Entity) -> bool:
	var d := dna(e)
	return d != null and not Traits.has(e, "geneless") and not Traits.has(e, "baddna")

static func is_monkey(e: Entity) -> bool:
	var d := dna(e)
	return d != null and d.species == "monkey"

## TG reach_length: Elastic Arms adds one tile, with a clear physical path.
static func can_reach(user: Entity, target: Entity) -> bool:
	if user.adjacent(target):
		return true
	var d := dna(user)
	if d == null or not d.has_mutation("elastic_arms") or user.dist_to(target) > 2:
		return false
	var a := user.root_cell()
	var b := target.root_cell()
	for offset in Defs.DIRS8:
		var middle: Vector2i = a + offset
		if Game.map.inb(middle) and not Game.map.blocks_move_static(middle) and Entity.cells_adjacent(a, middle) and Entity.cells_adjacent(middle, b):
			return true
	return false

## tg pick_weight over the meltdowns
static func pick_meltdown(fatal: bool) -> String:
	var total := 0
	for k in MELTDOWNS:
		if MELTDOWNS[k][1] == fatal:
			total += MELTDOWNS[k][0]
	var r := Game.rng.randi_range(1, total)
	for k in MELTDOWNS:
		if MELTDOWNS[k][1] != fatal:
			continue
		r -= MELTDOWNS[k][0]
		if r <= 0:
			return k
	return "alright"

# ------------------------------------------------------------------ sim timers (tg addtimer)
static var _timers: Array = [] # [{t, cb}]

static func after(seconds: float, cb: Callable) -> void:
	_timers.append({"t": Game.time + seconds, "cb": cb})

static func clear_timers() -> void:
	# Release callbacks capturing entities before the scene and scripts are torn down.
	_timers.clear()

static func process(_dt: float) -> void:
	if _timers.is_empty():
		return
	var due := []
	for i in range(_timers.size() - 1, -1, -1):
		if _timers[i]["t"] <= Game.time:
			due.append(_timers[i])
			_timers.remove_at(i)
	due.reverse()
	for t in due:
		var cb: Callable = t["cb"]
		if cb.is_valid():
			cb.call()

## A fresh round (a new game in the same session).
static func reset() -> void:
	_timers.clear()
	_ready = false
	setup_round()
