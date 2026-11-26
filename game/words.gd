class_name Words
extends RefCounted
## What the game writes and the written lines its people say, in the nine languages that Lokutor both hears and speaks.
## The king's own answers are his: what he is told is in prompts.gd.

const LANGUAGES := ["en", "es", "ca", "gl", "eu", "pt", "fr", "it", "de"]
const NAMES := {"en": "English", "es": "Español", "ca": "Català", "gl": "Galego", "eu": "Euskara", "pt": "Português", "fr": "Français", "it": "Italiano", "de": "Deutsch"}

const TEXT := {
	"en": {
		"dare!": "HOW DARE YOU!", "headphones": "headphones", "auto": "auto", "yes": "yes", "no": "no",
		"tagline": "Make the king laugh. With your voice.", "space": "Press SPACE", "again": "Press SPACE to try again",
		"no_key": "Set LOKUTOR_API_KEY to play, or run the dev server",
		"pardoned": "PARDONED", "pardoned!": "PARDONED!", "next!": "NEXT!", "not_amused": "NOT AMUSED",
		"laughed": "The king laughed in %d seconds.", "got_to": "You got him to %d of 100.",
		"silence": "silence", "default": "system default", "full": "full screen", "change": "change", "next": "Next!",
		"r": ["Psst. Do a silly voice.", "He likes cheese. Do something about cheese.", "Mention the hat. Everybody is afraid to mention the hat."],
		"l": ["Psst. Puns. The worse the better.", "My mother laughs at anything about horses.", "Ten seconds! Say something! Anything!"]},
	"es": {
		"dare!": "¡CÓMO TE ATREVES!", "headphones": "auriculares", "auto": "auto", "yes": "sí", "no": "no",
		"tagline": "Haz reír al rey. Con tu voz.", "space": "Pulsa ESPACIO", "again": "Pulsa ESPACIO para repetir",
		"no_key": "Define LOKUTOR_API_KEY para jugar",
		"pardoned": "PERDONADO", "pardoned!": "¡PERDONADO!", "next!": "¡SIGUIENTE!", "not_amused": "NO TIENE GRACIA",
		"laughed": "El rey se rio en %d segundos.", "got_to": "Lo has llevado a %d de 100.",
		"silence": "silencio", "default": "el del sistema", "full": "pantalla completa", "change": "cambiar", "next": "¡Siguiente!",
		"r": ["Psst. Pon una voz tonta.", "Le gusta el queso. Haz algo con queso.", "Menciona el sombrero. Todos tienen miedo de mencionar el sombrero."],
		"l": ["Psst. Juegos de palabras. Cuanto peores, mejor.", "Mi madre se ríe con cualquier cosa de caballos.", "¡Diez segundos! ¡Di algo! ¡Lo que sea!"]},
	"ca": {
		"dare!": "COM GOSES!", "headphones": "auriculars", "auto": "auto", "yes": "sí", "no": "no",
		"tagline": "Fes riure el rei. Amb la teva veu.", "space": "Prem ESPAI", "again": "Prem ESPAI per tornar-hi",
		"no_key": "Defineix LOKUTOR_API_KEY per jugar",
		"pardoned": "PERDONAT", "pardoned!": "PERDONAT!", "next!": "EL SEGÜENT!", "not_amused": "NO FA RIURE",
		"laughed": "El rei ha rigut en %d segons.", "got_to": "L'has portat a %d de 100.",
		"silence": "silenci", "default": "el del sistema", "full": "pantalla completa", "change": "canviar", "next": "El següent!",
		"r": ["Pst. Posa una veu ridícula.", "Li agrada el formatge. Fes alguna cosa amb formatge.", "Parla del barret. Tothom té por de parlar del barret."],
		"l": ["Pst. Jocs de paraules. Com més dolents, millor.", "La meva mare riu amb qualsevol cosa de cavalls.", "Deu segons! Digues alguna cosa! El que sigui!"]},
	"gl": {
		"dare!": "COMO TE ATREVES!", "headphones": "auriculares", "auto": "auto", "yes": "si", "no": "non",
		"tagline": "Fai rir ao rei. Coa túa voz.", "space": "Preme ESPAZO", "again": "Preme ESPAZO para repetir",
		"no_key": "Define LOKUTOR_API_KEY para xogar",
		"pardoned": "PERDOADO", "pardoned!": "PERDOADO!", "next!": "SEGUINTE!", "not_amused": "NON TEN GRAZA",
		"laughed": "O rei riu en %d segundos.", "got_to": "Levácheno a %d de 100.",
		"silence": "silencio", "default": "o do sistema", "full": "pantalla completa", "change": "cambiar", "next": "Seguinte!",
		"r": ["Psst. Pon unha voz parva.", "Gústalle o queixo. Fai algo con queixo.", "Fala do sombreiro. Todos teñen medo de falar do sombreiro."],
		"l": ["Psst. Xogos de palabras. Canto peores, mellor.", "A miña nai ri con calquera cousa de cabalos.", "Dez segundos! Di algo! O que sexa!"]},
	"eu": {
		"dare!": "NOLA AUSARTZEN ZARA!", "headphones": "entzungailuak", "auto": "auto", "yes": "bai", "no": "ez",
		"tagline": "Eragin barrea erregeari. Zure ahotsaz.", "space": "Sakatu ZURIUNEA", "again": "Sakatu ZURIUNEA berriro saiatzeko",
		"no_key": "Ezarri LOKUTOR_API_KEY jokatzeko",
		"pardoned": "BARKATUTA", "pardoned!": "BARKATUTA!", "next!": "HURRENGOA!", "not_amused": "EZ DU GRAZIARIK",
		"laughed": "Erregeak %d segundotan egin du barre.", "got_to": "%d / 100 lortu duzu.",
		"silence": "isiltasuna", "default": "sistemakoa", "full": "pantaila osoa", "change": "aldatu", "next": "Hurrengoa!",
		"r": ["Pst. Egin ahots barregarri bat.", "Gazta gustatzen zaio. Egin zerbait gaztarekin.", "Aipatu txapela. Denek diote beldur txapela aipatzeari."],
		"l": ["Pst. Hitz-jokoak. Zenbat eta txarragoak, orduan eta hobeto.", "Nire amak zaldiei buruzko edozerekin egiten du barre.", "Hamar segundo! Esan zerbait! Edozer!"]},
	"pt": {
		"dare!": "COMO TE ATREVES!", "headphones": "auscultadores", "auto": "auto", "yes": "sim", "no": "não",
		"tagline": "Faz o rei rir. Com a tua voz.", "space": "Prime ESPAÇO", "again": "Prime ESPAÇO para repetir",
		"no_key": "Define LOKUTOR_API_KEY para jogar",
		"pardoned": "PERDOADO", "pardoned!": "PERDOADO!", "next!": "PRÓXIMO!", "not_amused": "NÃO TEM GRAÇA",
		"laughed": "O rei riu-se em %d segundos.", "got_to": "Levaste-o a %d de 100.",
		"silence": "silêncio", "default": "o do sistema", "full": "ecrã inteiro", "change": "mudar", "next": "Próximo!",
		"r": ["Psst. Faz uma voz ridícula.", "Ele gosta de queijo. Faz alguma coisa com queijo.", "Fala do chapéu. Toda a gente tem medo de falar do chapéu."],
		"l": ["Psst. Trocadilhos. Quanto piores, melhor.", "A minha mãe ri-se com qualquer coisa de cavalos.", "Dez segundos! Diz alguma coisa! Qualquer coisa!"]},
	"fr": {
		"dare!": "COMMENT OSES-TU !", "headphones": "casque", "auto": "auto", "yes": "oui", "no": "non",
		"tagline": "Fais rire le roi. Avec ta voix.", "space": "Appuie sur ESPACE", "again": "Appuie sur ESPACE pour rejouer",
		"no_key": "Définis LOKUTOR_API_KEY pour jouer",
		"pardoned": "GRACIÉ", "pardoned!": "GRACIÉ !", "next!": "SUIVANT !", "not_amused": "PAS DRÔLE",
		"laughed": "Le roi a ri en %d secondes.", "got_to": "Tu l'as amené à %d sur 100.",
		"silence": "silence", "default": "celui du système", "full": "plein écran", "change": "changer", "next": "Au suivant !",
		"r": ["Psst. Prends une voix ridicule.", "Il aime le fromage. Fais quelque chose avec du fromage.", "Parle du chapeau. Tout le monde a peur de parler du chapeau."],
		"l": ["Psst. Des jeux de mots. Plus ils sont mauvais, mieux c'est.", "Ma mère rit dès qu'on parle de chevaux.", "Dix secondes ! Dis quelque chose ! N'importe quoi !"]},
	"it": {
		"dare!": "COME OSI!", "headphones": "cuffie", "auto": "auto", "yes": "sì", "no": "no",
		"tagline": "Fai ridere il re. Con la tua voce.", "space": "Premi SPAZIO", "again": "Premi SPAZIO per riprovare",
		"no_key": "Imposta LOKUTOR_API_KEY per giocare",
		"pardoned": "GRAZIATO", "pardoned!": "GRAZIATO!", "next!": "AVANTI!", "not_amused": "NON FA RIDERE",
		"laughed": "Il re ha riso in %d secondi.", "got_to": "L'hai portato a %d su 100.",
		"silence": "silenzio", "default": "quello di sistema", "full": "schermo intero", "change": "cambia", "next": "Avanti un altro!",
		"r": ["Psst. Fai una voce buffa.", "Gli piace il formaggio. Fai qualcosa col formaggio.", "Parla del cappello. Hanno tutti paura di parlare del cappello."],
		"l": ["Psst. Giochi di parole. Più sono brutti, meglio è.", "Mia madre ride per qualsiasi cosa sui cavalli.", "Dieci secondi! Di' qualcosa! Qualsiasi cosa!"]},
	"de": {
		"dare!": "WAS FÄLLT DIR EIN!", "headphones": "Kopfhörer", "auto": "auto", "yes": "ja", "no": "nein",
		"tagline": "Bring den König zum Lachen. Mit deiner Stimme.", "space": "Drück die LEERTASTE", "again": "LEERTASTE: noch einmal",
		"no_key": "Setze LOKUTOR_API_KEY zum Spielen",
		"pardoned": "BEGNADIGT", "pardoned!": "BEGNADIGT!", "next!": "DER NÄCHSTE!", "not_amused": "NICHT LUSTIG",
		"laughed": "Der König hat nach %d Sekunden gelacht.", "got_to": "Du hast ihn auf %d von 100 gebracht.",
		"silence": "Stille", "default": "das des Systems", "full": "Vollbild", "change": "ändern", "next": "Der Nächste!",
		"r": ["Psst. Mach eine alberne Stimme.", "Er mag Käse. Mach etwas mit Käse.", "Erwähn den Hut. Alle haben Angst, den Hut zu erwähnen."],
		"l": ["Psst. Wortspiele. Je schlechter, desto besser.", "Meine Mutter lacht über alles mit Pferden.", "Zehn Sekunden! Sag etwas! Irgendetwas!"]},
}


## The computer's language if the game has it, English if not.
static func of_this_computer() -> String:
	var code := OS.get_locale_language()
	return code if code in LANGUAGES else "en"
