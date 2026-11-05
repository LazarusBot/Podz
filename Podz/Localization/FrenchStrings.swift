import SwiftUI

/// The app in French. Every sentence the app writes is English in the code; when
/// the app's language is French (the phone's language, or Podz's own in
/// Settings), `tr` swaps it for its French twin. The sentences Lenny builds
/// (with numbers and names inside) are matched by *templates*: `{}` stands for
/// whatever is there ("{} beds" -> "{1} lits"), translated in turn, so "2 nights
/// for 3 guests, from Sat 7 Nov" is found piece by piece.
///
/// Tone: "tu" (hikers talk like that), Lenny too.
enum FrenchStrings {
    /// The app is showing French.
    static let isActive: Bool = Bundle.main.preferredLocalizations.first == "fr"

    /// The French for `text`, or `text` itself (another language, or nothing to
    /// say for it).
    static func translate(_ text: String) -> String { translate(text, depth: 0) }

    /// Names typed by people (a folder, a profile) pass through here too: a
    /// very long one, or one built to nest templates ("Shared with Shared
    /// with…"), is left as it is instead of being matched over and over.
    private static let templateMaxLength = 1_000
    private static let templateMaxDepth = 6

    private static func translate(_ text: String, depth: Int) -> String {
        guard isActive, !text.isEmpty else { return text }
        if let hit = exact[text] { return hit }
        guard depth < templateMaxDepth, text.utf16.count <= templateMaxLength else { return text }
        for template in templates {
            guard let captures = template.match(text) else { continue }
            return template.fill(captures.map { translate($0, depth: depth + 1) })
        }
        return text
    }

    // MARK: - Templates

    private struct Template {
        let regex: NSRegularExpression
        let french: String

        init?(_ english: String, _ french: String) {
            var pattern = "^"
            var rest = Substring(english)
            while let open = rest.range(of: "{}") {
                pattern += NSRegularExpression.escapedPattern(for: String(rest[..<open.lowerBound])) + "(.+?)"
                rest = rest[open.upperBound...]
            }
            pattern += NSRegularExpression.escapedPattern(for: String(rest)) + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
            self.regex = regex
            self.french = french
        }

        func match(_ text: String) -> [String]? {
            let range = NSRange(text.startIndex..., in: text)
            guard let m = regex.firstMatch(in: text, range: range) else { return nil }
            return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: text).map { String(text[$0]) } }
        }

        /// The French with the captures put in: `{}` in order, or `{2}` by number.
        func fill(_ captures: [String]) -> String {
            var result = ""
            var next = 0
            var rest = Substring(french)
            while let open = rest.range(of: "{") , let close = rest[open.upperBound...].firstIndex(of: "}") {
                result += rest[..<open.lowerBound]
                let key = rest[open.upperBound..<close]
                let index = Int(key).map { $0 - 1 } ?? next
                if key.isEmpty { next += 1 }
                result += captures.indices.contains(index) ? captures[index] : ""
                rest = rest[rest.index(after: close)...]
            }
            return result + rest
        }
    }

    /// Longest (most specific) first.
    private static let templates: [Template] = pairs
        .filter { $0.0.contains("{}") }
        .sorted { $0.0.count > $1.0.count }
        .compactMap { Template($0.0, $0.1) }

    private static let exact: [String: String] = Dictionary(
        pairs.filter { !$0.0.contains("{}") }.map { ($0.0, $0.1) },
        uniquingKeysWith: { first, _ in first }
    )

    // MARK: - The words

    private static let pairs: [(String, String)] = [
        // Units
        ("{} guest", "{1} personne"), ("{} guests", "{1} personnes"),
        ("{} night", "{1} nuit"), ("{} nights", "{1} nuits"),
        ("{} bed", "{1} lit"), ("{} beds", "{1} lits"),
        ("{} stay", "{1} séjour"), ("{} stays", "{1} séjours"),
        ("{} hut", "{1} refuge"), ("{} huts", "{1} refuges"),
        ("{} friends", "{1} amis"), ("{} likes", "{1} favoris"),
        ("{} day", "{1} jour"), ("{} days", "{1} jours"), ("from {}", "à partir du {1}"),
        (" ({})", " ({1})"), ("{} · {}", "{1} · {2}"), ("{} · {} · {}", "{1} · {2} · {3}"),
        ("{} night per stop", "{1} nuit par étape"), ("{} nights per stop", "{1} nuits par étape"),
        ("{} per stop", "{1} par étape"),
        ("{} free now", "{1} libres"),
        ("{} · {} free now", "{1} · {2} libres"),
        ("{} m altitude", "{1} m d'altitude"),
        ("{} / night", "{1} / nuit"),
        ("guest", "personne"), ("guests", "personnes"), ("night", "nuit"), ("nights", "nuits"),
        ("night per stop", "nuit par étape"), ("nights per stop", "nuits par étape"),

        // Months (Closed until June)
        ("January", "janvier"), ("February", "février"), ("March", "mars"), ("April", "avril"),
        ("May", "mai"), ("June", "juin"), ("July", "juillet"), ("August", "août"),
        ("September", "septembre"), ("October", "octobre"), ("November", "novembre"), ("December", "décembre"),
        ("Open now", "Ouvert"), ("Closed until {}", "Fermé jusqu'en {1}"),
        // The next trip beside Reservations on Profile (before "In {}", which
        // would match "In 5 days" too).
        ("In {} days", "Dans {1} jours"), ("Today", "Aujourd'hui"), ("Tomorrow", "Demain"), ("Under way", "En cours"),

        // Tabs, titles
        ("Home", "Accueil"), ("Likes", "Favoris"), ("Profile", "Profil"),
        ("Where to tonight?", "Où ce soir ?"), ("Available tonight", "Disponibles ce soir"),
        ("See all", "Tout voir"), ("Search a region", "Chercher une région"),
        ("Ask Lenny to find it", "Demande à Lenny de le trouver"),
        ("Describe your trip and Lenny finds the huts", "Décris ton séjour et Lenny trouve les refuges"),
        ("Chamonix to Zermatt in 5 days", "De Chamonix à Zermatt en 5 jours"),
        ("One moment, I'm getting things ready.", "Un instant, je prépare tout."),
        ("One moment, {}. I'm getting things ready.", "Un instant, {1}, je prépare tout."),
        ("All good, you're all set.", "Tout est bon, c'est prêt."),
        ("Go to Home", "Aller à l'accueil"),
        // Lenny's notes and questions (instead of system alerts)
        ("Sorry, that didn't work. {}", "Désolé, ça n'a pas marché. {1}"),
        ("I couldn't send that request. {}", "Je n'ai pas pu envoyer la demande. {1}"),
        ("I couldn't update the sharing. {}", "Je n'ai pas pu changer le partage. {1}"),
        ("I couldn't save your photo. {}", "Je n'ai pas pu enregistrer ta photo. {1}"),
        ("I couldn't upload your photo. {}", "Je n'ai pas pu envoyer ta photo. {1}"),
        ("I couldn't add the pass to Wallet. {}", "Je n'ai pas pu ajouter le billet à Wallet. {1}"),
        ("Delete “{}” and the likes inside it?", "Supprimer « {1} » et les favoris qu'il contient ?"),
        ("Share", "Partager"), ("Shared", "Partagé"), ("Stop sharing", "Arrêter de partager"),
        ("Keep", "Garder"), ("Loading", "Chargement"),
        ("Cancel this trip? This cancels all {} stays and can't be undone.", "Annuler ce voyage ? Cela annule les {1} séjours, sans retour possible."),
        ("Remove this stay? This only removes it from your list. To cancel the stay itself, tell the hut.", "Retirer ce séjour ? Il disparaît seulement de ta liste. Pour annuler le séjour, préviens le refuge."),
        ("Cancel this reservation? You'll need to reserve again if you change your mind.", "Annuler cette réservation ? Tu devras réserver de nouveau si tu changes d'avis."),
        ("No huts available yet.", "Aucun refuge disponible pour le moment."),
        ("No huts match “{}”.", "Aucun refuge ne correspond à « {1} »."),
        ("Hand-picked", "Sélection"), ("Highest", "Les plus hauts"), ("Room for groups", "Pour les groupes"),
        ("In {}", "En {1}"), ("Refuges", "Refuges"), ("Cabins", "Cabanes"),

        // Pod detail
        ("Book", "Réserver"), ("Book through the hut", "Réserver auprès du refuge"),
        ("Book through {}", "Réserver auprès de {1}"),
        ("Back", "Retour"), ("Add to likes", "Ajouter aux favoris"), ("Remove from likes", "Retirer des favoris"),
        ("Details", "Détails"), ("Not yet", "Pas encore"), ("Yes, I booked it", "Oui, j'ai réservé"),
        ("Welcome back! Did you book {} with the hut?", "Te revoilà ! As-tu réservé {1} auprès du refuge ?"),
        ("Price at the hut", "Prix au refuge"), ("Unverified", "Non vérifié"), ("Verified", "Vérifié"), ("Verified by Podz", "Vérifié par Podz"), ("Not checked by Podz", "Non vérifié par Podz"),
        ("This hut books through Podz: its beds, prices and availability come from the hut itself.", "Ce refuge réserve via Podz : ses lits, ses prix et ses disponibilités viennent du refuge lui-même."),
        ("This hut comes from OpenStreetMap and nobody at Podz has checked its details. Call ahead before you go.", "Ce refuge vient d'OpenStreetMap et personne chez Podz n'a vérifié ses informations. Appelle avant de partir."),
        ("{}. Pick dates after that and I'll book it.", "{1}. Choisis des dates après et je réserve."),
        ("{}. Call ahead if you're going sooner.", "{1}. Appelle avant si tu y vas plus tôt."),
        ("Heads up: {} looks closed on those dates.", "Attention : {1} a l'air fermé à ces dates."),
        ("{} for {}, from {}. Shall I add it to your reservations? {}", "{1} pour {2}, à partir du {3}. Je l'ajoute à tes réservations ? {4}"), ("Unverified listing", "Fiche non vérifiée"),
        ("About", "À propos"), ("On site", "Sur place"), ("Good to know", "Bon à savoir"),
        ("Getting there", "Pour y aller"), ("Contact", "Contact"), ("About this listing", "À propos de cette fiche"),
        ("Beds", "Lits"), ("Price", "Prix"), ("Set by the hut", "Fixé par le refuge"), ("Opening", "Ouverture"),
        ("Ask the hut", "Demande au refuge"), ("Booking", "Réservation"), ("In Podz", "Dans Podz"),
        ("Through the hut", "Auprès du refuge"), ("Offline", "Hors ligne"), ("Saved on this phone", "Enregistré sur ce téléphone"),
        ("Directions", "Itinéraire"), ("Directions to {}", "Itinéraire vers {1}"),
        ("Facilities aren't listed. Ask the hut before you go.", "Les équipements ne sont pas indiqués. Demande au refuge avant de partir."),
        ("Information © OpenStreetMap contributors. Not checked by Podz.", "Informations © contributeurs OpenStreetMap. Non vérifiées par Podz."),
        ("Listed hut. Not checked by Podz.", "Refuge référencé. Non vérifié par Podz."),
        ("Photo: {}", "Photo : {1}"),
        ("Phone", "Téléphone"), ("Email", "E-mail"), ("Website", "Site web"),
        ("Call {}", "Appeler {1}"), ("Email {}", "Écrire à {1}"),
        ("Open the booking page", "Ouvrir la page de réservation"), ("Open the website", "Ouvrir le site web"),
        ("Cancel", "Annuler"), ("Done", "Terminé"), ("OK", "OK"),
        ("This hut takes bookings itself. Mention the dates and how many of you there are.", "Ce refuge prend lui-même ses réservations. Indique les dates et combien vous êtes."),
        ("Reservation required", "Réservation obligatoire"), ("Meals", "Repas"), ("Showers", "Douches"),
        ("Drinking water", "Eau potable"), ("Electricity", "Électricité"), ("Wi-Fi", "Wi-Fi"), ("Heating", "Chauffage"),
        ("Toilets", "Toilettes"), ("Winter room", "Local d'hiver"), ("Self-catering", "Cuisine en autonomie"),
        ("Dogs welcome", "Chiens acceptés"), ("Wheelchair access", "Accès fauteuil roulant"),

        // Lenny on the pod
        ("{} free tonight. Tell me your dates and I'll book it.", "{1} libres ce soir. Dis-moi tes dates et je réserve."),
        ("Full tonight. Another date may work: tell me when and I'll check.", "Complet ce soir. Une autre date peut marcher : dis-moi quand et je regarde."),
        ("You can book this hut right here. Tell me your dates.", "Tu peux réserver ce refuge ici. Dis-moi tes dates."),
        ("Open {}. Call ahead, as huts fill up.", "Ouvert {1}. Appelle avant, les refuges se remplissent vite."),
        ("This hut takes bookings itself. Tap Book through the hut to reach it.", "Ce refuge prend lui-même ses réservations. Touche Réserver auprès du refuge pour le contacter."),
        ("I have no way to reach this hut from here. Check it's open before you set off.", "Je n'ai aucun moyen de joindre ce refuge d'ici. Vérifie qu'il est ouvert avant de partir."),
        ("Bookable right here in Podz.", "Réservable ici, dans Podz."),
        ("Details come from OpenStreetMap: confirm with the hut.", "Les infos viennent d'OpenStreetMap : confirme auprès du refuge."),
        ("Nothing listed: ask the hut what it offers.", "Rien d'indiqué : demande au refuge ce qu'il propose."),
        ("Reserve first: it doesn't take walk-ups.", "Réserve d'abord : pas d'arrivée sans réservation."),
        ("On site: {}.", "Sur place : {1}."),
        ("At {} m it's cold, even in summer: bring a warm layer.", "À {1} m il fait froid, même l'été : prends une couche chaude."),
        ("Pick your dates and Book.", "Choisis tes dates et réserve."),
        ("Opening dates and prices: ask the hut.", "Dates d'ouverture et prix : demande au refuge."),
        ("Save the map offline: there's often no signal up there.", "Enregistre la carte hors ligne : il n'y a souvent pas de réseau là-haut."),
        ("Happy with it? Tap Book.", "Ça te va ? Touche Réserver."),
        ("Contact the hut to book a bed.", "Contacte le refuge pour réserver un lit."),
        ("No contact listed. Check it's open before you go.", "Aucun contact indiqué. Vérifie qu'il est ouvert avant d'y aller."),
        ("Volunteers edit OpenStreetMap, so details can be out of date.", "OpenStreetMap est édité par des bénévoles : les infos peuvent être périmées."),
        ("Next", "Suivant"), ("Top", "Haut"), ("Contact the hut", "Contacter le refuge"),

        // Booking flow
        ("Add guest", "Ajouter des personnes"), ("Add date", "Ajouter une date"), ("Add nights", "Ajouter des nuits"),
        ("Add to my list", "Ajouter à ma liste"), ("Adding…", "Ajout…"), ("Reserve", "Réserver"), ("Reserving…", "Réservation…"),
        ("View reservations", "Voir les réservations"), ("Continue", "Continuer"),
        ("Fewer guests", "Moins de personnes"), ("More guests", "Plus de personnes"),
        ("Fewer nights", "Moins de nuits"), ("More nights", "Plus de nuits"),
        ("Day earlier", "Un jour plus tôt"), ("Day later", "Un jour plus tard"),
        ("{}. Change", "{1}. Modifier"),
        ("Start date, {}. Opens the calendar", "Date de début, {1}. Ouvre le calendrier"),
        ("Set each stop", "Choisir pour chaque étape"), ("Same for every stop", "Pareil pour chaque étape"), ("Previous stop", "Étape précédente"),
        ("How many of you are going?", "Combien êtes-vous ?"),
        ("And when do you arrive?", "Et quand arrives-tu ?"), ("And when do you start?", "Et quand pars-tu ?"),
        ("And for how many nights?", "Et pour combien de nuits ?"),
        ("How many nights per stop?", "Combien de nuits par étape ?"),
        ("How many nights at {}?", "Combien de nuits à {1} ?"), ("And at {}?", "Et à {1} ?"),
        ("I'd say {} per stop. Does that work?", "Je dirais {1} par étape. Ça te va ?"),
        // The recap says what it costs and how it's paid; these come before the
        // shorter templates, which would match the longer sentence too.
        ("{} for {}, from {}. {} Shall I book it?", "{1} pour {2}, à partir du {3}. {4} Je réserve ?"),
        ("{} for {}, from {}. {} Shall I book it? {}", "{1} pour {2}, à partir du {3}. {4} Je réserve ? {5}"),
        ("{}, paid at the hut.", "{1}, à payer au refuge."), ("About {}", "Environ {1}"),
        ("You pay at the hut.", "Tu paies au refuge."),
        ("{} for {}, from {}. Shall I add it to your reservations?", "{1} pour {2}, à partir du {3}. Je l'ajoute à tes réservations ?"),
        ("Booked! {} for {}. Your pass is in Reservations, even offline.", "Réservé ! {1} pour {2}. Ton billet est dans Réservations, même hors ligne."),
        ("Booked! {} for {}. Your pass is in Reservations, even offline. {}", "Réservé ! {1} pour {2}. Ton billet est dans Réservations, même hors ligne. {3}"),
        ("Added! It's in your reservations, as booked with the hut. Have a great stay.", "Ajouté ! C'est dans tes réservations, réservé auprès du refuge. Bon séjour."),
        ("I booked {} of {}. {}", "J'ai réservé {1} sur {2}. {3}"),
        ("I couldn't book {} for {}. It may be full, so try other dates.", "Je n'ai pas pu réserver {1} pour le {2}. Il est peut-être complet, essaie d'autres dates."),
        ("{} is listed only, so book it through the hut.", "{1} est seulement référencé : réserve auprès du refuge."),
        ("{} of the huts are listed only, so book them through the huts.", "{1} des refuges sont seulement référencés : réserve auprès des refuges."),
        ("These huts take their bookings themselves. Tap Book through the hut to call, email or visit their site.", "Ces refuges prennent eux-mêmes leurs réservations. Touche Réserver auprès du refuge pour appeler, écrire ou voir leur site."), ("Which hut?", "Quel refuge ?"),

        // Lenny plan and search
        ("Your plan", "Ton plan"), ("Check your plan", "Vérifie ton plan"), ("{} stops, one hut each", "{1} étapes, un refuge chacune"),
        ("1 stop, one hut each", "1 étape, un refuge"), ("See summary", "Voir le résumé"), ("Lenny's pick", "Le choix de Lenny"),
        ("{} · {} of {}", "{1} · {2} sur {3}"), ("Next stop: {}", "Étape suivante : {1}"), ("{} away", "à {1}"),
        ("Listed  ·  book through the hut", "Référencé  ·  réserver auprès du refuge"),
        ("View selected huts", "Voir les refuges choisis"), ("Lenny is searching", "Lenny cherche"),
        ("No huts found", "Aucun refuge trouvé"), ("1 hut found", "1 refuge trouvé"), ("{} huts found", "{1} refuges trouvés"),
        ("I couldn't find any huts on that route.", "Je n'ai trouvé aucun refuge sur cet itinéraire."),
        ("I found 1 hut along your route{}. Want to take a look?", "J'ai trouvé 1 refuge sur ton itinéraire{1}. Tu veux voir ?"),
        ("I found {} huts along your route{}. Want to take a look?", "J'ai trouvé {1} refuges sur ton itinéraire{2}. Tu veux voir ?"),
        ("Reading your itinerary…", "Lecture de ton itinéraire…"), ("Spotting peaks and lakes…", "Repérage des sommets et des lacs…"),
        ("Peeking into the huts…", "Un coup d'œil dans les refuges…"), ("Counting free beds…", "Comptage des lits libres…"),
        ("Can take up to 2 minutes…", "Peut prendre jusqu'à 2 minutes…"), ("Asking the marmots for tips…", "On demande conseil aux marmottes…"),
        ("Lacing up the boots…", "On lace les chaussures…"), ("Checking the sunrise views…", "Vérification des levers de soleil…"),
        ("Packing one very small snack…", "On emballe un tout petit encas…"), ("Following the trail markers…", "On suit le balisage…"),

        // Reservations
        ("Reservations", "Réservations"), ("Plan with Lenny", "Planifier avec Lenny"), ("Upcoming", "À venir"), ("Past", "Passés"),
        ("Cancel this trip?", "Annuler ce voyage ?"), ("Remove this stay?", "Retirer ce séjour ?"),
        ("Cancel this reservation?", "Annuler cette réservation ?"), ("Keep it", "Garder"), ("Cancel trip", "Annuler le voyage"),
        ("Remove", "Retirer"), ("Cancel reservation", "Annuler la réservation"),
        ("This cancels all {} stays and can't be undone.", "Cela annule les {1} séjours, sans retour possible."),
        ("This only removes it from your list. To cancel the stay itself, tell the hut.", "Cela ne fait que le retirer de ta liste. Pour annuler le séjour, préviens le refuge."),
        ("Another tip", "Un autre conseil"), ("No trips yet", "Pas encore de voyage"),
        ("Tell Lenny where you'd like to go, and for how long. He finds the huts and plans the stays for you.", "Dis à Lenny où tu veux aller et pour combien de temps. Il trouve les refuges et planifie les séjours."),
        ("Planned with Lenny", "Planifié avec Lenny"), ("Hut", "Refuge"), ("cancelled", "annulé"),
        ("{}  ·  Booked with the hut", "{1}  ·  Réservé auprès du refuge"), ("{}  ·  Cancelled", "{1}  ·  Annulé"),
        ("{}  ·  {}", "{1}  ·  {2}"), ("{}  ·  {}  ·  {}", "{1}  ·  {2}  ·  {3}"),
        ("Booked with the hut", "Réservé auprès du refuge"), ("Cancelled", "Annulé"),
        ("Starts today", "Commence aujourd'hui"), ("Starts tomorrow", "Commence demain"), ("Starts in {} days", "Commence dans {1} jours"),
        ("Copied", "Copié"), ("Confirmation code", "Code de confirmation"),
        ("Saved on this phone. It opens without signal.", "Enregistré sur ce téléphone. Il s'ouvre sans réseau."),
        ("View hut", "Voir le refuge"), ("Wallet isn't available on this device.", "Wallet n'est pas disponible sur cet appareil."),
        ("Couldn't create your Wallet pass. Check your connection and try again.", "Impossible de créer ton pass Wallet. Vérifie ta connexion et réessaie."),

        // Lenny trip tips
        ("Your trip starts today. Have a great first night!", "Ton voyage commence aujourd'hui. Belle première nuit !"),
        ("Your trip starts today. Have a great first night at {}!", "Ton voyage commence aujourd'hui. Belle première nuit à {1} !"),
        ("Your trip starts tomorrow. Time to pack!", "Ton voyage commence demain. C'est l'heure de faire le sac !"),
        ("Your trip starts in {} days: {}, {}.", "Ton voyage commence dans {1} jours : {2}, {3}."),
        ("Your trip starts in {} days: {}, {}, beginning at {}.", "Ton voyage commence dans {1} jours : {2}, {3}, en commençant par {4}."),
        (", beginning at {}", ", en commençant par {1}"),
        ("Your highest night is at {} m. It gets cold up there, even in summer, so pack a warm layer, a hat and a headlamp.", "Ta nuit la plus haute est à {1} m. Il y fait froid, même l'été : prends une couche chaude, un bonnet et une frontale."),
        ("You'll sleep as high as {} m. Evenings cool down fast, so keep a warm layer within reach.", "Tu dormiras jusqu'à {1} m. Les soirées se rafraîchissent vite : garde une couche chaude à portée de main."),
        ("At {} m the evenings cool down fast. Keep a warm layer within reach.", "À {1} m les soirées se rafraîchissent vite. Garde une couche chaude à portée de main."),
        ("Snow can linger on the trails at this time of year. Check the conditions before each leg and start early.", "La neige peut rester sur les sentiers à cette période. Vérifie les conditions avant chaque étape et pars tôt."),
        ("Afternoon storms are common in summer. Aim to reach each hut by early afternoon.", "Les orages de l'après-midi sont fréquents l'été. Vise une arrivée au refuge en début d'après-midi."),
        ("Mountain huts serve dinner at a set time. If you'll be late, let them know. A sleeping bag liner and earplugs help too.", "Les refuges servent le dîner à heure fixe. Si tu seras en retard, préviens-les. Un sac à viande et des bouchons d'oreilles aident aussi."),
        ("Between stops, check the weather the evening before and keep a margin in your day.", "Entre les étapes, regarde la météo la veille et garde de la marge dans ta journée."),
        ("With {} of you, pick one person to confirm arrival times with each hut.", "À {1}, choisissez une personne pour confirmer les heures d'arrivée avec chaque refuge."),
        ("Tap a stay to see its hut again, and you can cancel the whole trip from here if plans change.", "Touche un séjour pour revoir son refuge, et annule tout le voyage d'ici si les plans changent."),

        // Likes, folders, profile
        ("Delete", "Supprimer"),
        ("\"{}\" will be deleted, along with the likes inside it.", "« {1} » sera supprimé, ainsi que les favoris qu'il contient."),
        ("Shared by {}", "Partagé par {1}"), ("by {}", "par {1}"),
        ("No likes yet", "Pas encore de favoris"),
        ("Tap the heart on a hut and it lands here, in a folder.", "Touche le cœur sur un refuge et il atterrit ici, dans un dossier."),
        ("Find huts", "Trouver des refuges"),
        ("Save to folder", "Enregistrer dans un dossier"), ("New folder", "Nouveau dossier"), ("Folder name", "Nom du dossier"),
        ("Remove folder", "Retirer le dossier"), ("Share folder", "Partager le dossier"),
        ("Share \"{}\"", "Partager « {1} »"),
        ("Friends you turn on can view this folder, read-only.", "Les amis que tu actives peuvent voir ce dossier, en lecture seule."),
        ("Add some friends first — nobody to share with yet.", "Ajoute d'abord des amis : personne avec qui partager pour l'instant."),
        ("Someone", "Quelqu'un"),
        ("Edit profile", "Modifier le profil"), ("Friends", "Amis"), ("Login and security", "Connexion et sécurité"),
        ("Log out", "Se déconnecter"), ("Delete account", "Supprimer le compte"),
        ("Delete your account?", "Supprimer ton compte ?"),
        ("This permanently deletes your account, profile, and liked huts. This can't be undone.", "Cela supprime définitivement ton compte, ton profil et tes favoris. Impossible de revenir en arrière."),
        ("Guest", "Invité"), ("{} friends · {} likes", "{1} amis · {2} favoris"),
        ("Coming soon", "Bientôt"),
        ("Open", "Ouvrir"), ("Add huts?", "Ajouter des refuges ?"),
        ("Search by username", "Chercher par nom d'utilisateur"),
        ("Remove from folder", "Retirer du dossier"),
        ("Shared with {}", "Partagé avec {1}"), ("Shared with {} and {}", "Partagé avec {1} et {2}"), ("Shared with {} and {} others", "Partagé avec {1} et {2} autres"),
        ("Best", "Meilleurs"), ("Highest first", "Plus hauts d'abord"), ("Most beds", "Plus de lits"), ("A–Z", "A–Z"),

        // Lenny's search
        ("Extracting your stops.", "Repérage de tes étapes."), ("Finding the best huts around here.", "Recherche des meilleurs refuges autour."),
        ("Loading your itinerary.", "Chargement de ton itinéraire."), ("Extracting {}.", "Repérage de {1}."),
        ("Around each stop", "Autour de chaque étape"), ("Nothing found", "Rien trouvé"), ("Your plan is ready", "Ton plan est prêt"),
        ("zero", "zéro"), ("one", "une"), ("two", "deux"), ("three", "trois"), ("four", "quatre"), ("five", "cinq"),
        ("six", "six"), ("seven", "sept"), ("eight", "huit"), ("nine", "neuf"),
        ("{} stop", "{1} étape"), ("{} stops", "{1} étapes"),
        ("List", "Liste"), ("Map", "Carte"), ("Save plan", "Enregistrer le plan"), ("Saved", "Enregistré"),
        ("Saved. Tap to remove", "Enregistré. Touche pour retirer"), ("Plans", "Plans"), ("No plans yet", "Aucun plan"),
        ("Plan a trip with Lenny, then save it here to book later.", "Prépare un voyage avec Lenny, puis enregistre-le ici pour réserver plus tard."),
        ("Delete this plan?", "Supprimer ce plan ?"), ("Across {}", "À travers {1}"),
        ("Make it a loop", "En faire une boucle"), ("Make it one way", "En faire un aller simple"),
        ("Beginner hiker", "Randonneur débutant"), ("Regular hiker", "Randonneur régulier"), ("Expert hiker", "Randonneur expert"),
        ("Easy days, then: huts closer together, less climbing, and a stop where a day was long.", "Des étapes faciles, alors : des refuges plus proches, moins de dénivelé, et une halte là où la journée était longue."),
        ("Regular days again.", "Retour aux étapes habituelles."), ("Long days for an expert, then.", "De longues étapes pour un expert, alors."),
        ("A stop to break up a long day after {}", "Une halte pour couper une longue journée après {1}"),
        ("beginner pace", "rythme débutant"), ("expert pace", "rythme expert"),
        ("Only huts I can book", "Seulement les refuges réservables"), ("Include listed huts", "Inclure les refuges listés"),
        ("One way again.", "De nouveau un aller simple."), ("Done, it comes back to where it starts.", "C'est fait, ça revient au point de départ."),
        ("I can't close a loop with the huts around there.", "Je ne peux pas faire de boucle avec les refuges de la zone."),
                ("I can't find a route with that.", "Je ne trouve pas d'itinéraire comme ça."),
        ("Listed huts are back in.", "Les refuges listés sont de retour."), ("Only huts you can book here.", "Seulement les refuges réservables ici."),
        ("There aren't enough huts you can book there.", "Il n'y a pas assez de refuges réservables là-bas."),
        ("Loop", "Boucle"), ("The route, {} huts", "L'itinéraire, {1} refuges"),
        ("Planning {} across {}.", "Préparation de {1} à travers {2}."), ("A day's walk apart", "À une journée de marche"),
        ("A good place to start in {}", "Un bon point de départ : {1}"), ("About {} km on from {}", "À environ {1} km après {2}"),
        ("the Alps", "les Alpes"), ("the Dolomites", "les Dolomites"), ("the Pyrenees", "les Pyrénées"),
        ("the Julian Alps", "les Alpes juliennes"), ("the Tatras", "les Tatras"),
        ("I can't see any huts right now. Check your connection and try again.", "Je ne vois aucun refuge pour l'instant. Vérifie ta connexion et réessaie."),
        ("Tell me where you're heading and I'll look for huts with {}.", "Dis-moi où tu vas et je cherche des refuges avec {1}."),
        ("with {}", "avec {1}"), ("{} and {}", "{1} et {2}"), ("{}, {} and {}", "{1}, {2} et {3}"),
        ("{}. None lists {}", "{1}. Aucun ne mentionne {2}"), ("{}, with {}", "{1}, avec {2}"),
        ("showers", "douches"), ("drinking water", "eau potable"), ("winter room", "local d'hiver"), ("meals", "repas"),
        ("self-catering", "cuisine en autonomie"), ("electricity", "électricité"), ("wi-fi", "wi-fi"), ("heating", "chauffage"),
        ("toilets", "toilettes"), ("dogs welcome", "chiens acceptés"), ("wheelchair access", "accès fauteuil roulant"),
        ("I couldn't make out a place in that. Try a town, a lake or a peak.", "Je n'ai pas reconnu de lieu là-dedans. Essaie une ville, un lac ou un sommet."),
        ("I couldn't find any huts along that route. Try another stop, or a wider area.", "Je n'ai trouvé aucun refuge sur ce trajet. Essaie une autre étape, ou une zone plus large."),
        // Onboarding and login
        ("Book a hut.", "Réserve un refuge."), ("In an instant", "En un instant"),
        ("Ask Lenny about your trip, select and you’re all set.", "Parle de ton séjour à Lenny, choisis, et c'est réglé."),
        ("Touch to start →", "Touche pour commencer →"),
        ("Find the perfect hut", "Trouve le refuge idéal"),
        ("Discover unique, architectural stays and cozy huts hidden deep within nature's most stunning landscapes.", "Découvre des refuges uniques et des cabanes chaleureuses, cachés au cœur des plus beaux paysages de montagne."),
        ("Meet Lenny", "Voici Lenny"),
        ("Tell him where and when. He finds you a bed in a mountain hut.", "Dis-lui où et quand. Il te trouve un lit dans un refuge de montagne."),
        ("Only this needed", "Rien de plus"), ("No stress, no multiple fields, just your mail.", "Pas de stress, pas de formulaire : juste ton e-mail."),
        ("Tap your email", "Écris ton e-mail"),
        ("Check your inbox", "Regarde ta boîte mail"), ("We sent you a 6-digit code. Enter it to get in.", "On t'a envoyé un code à 6 chiffres. Saisis-le pour entrer."),
        ("Enter your code", "Saisis ton code"), ("Resend code", "Renvoyer le code"), ("Change email", "Changer d'e-mail"),
        ("New code sent.", "Nouveau code envoyé."),
        ("Where to first?", "Par où commencer ?"), ("Pick a region. You can change it anytime.", "Choisis une région. Tu pourras en changer à tout moment."),
        ("Get started", "C'est parti"), ("Dolomites", "Dolomites"), ("Mont Blanc", "Mont Blanc"), ("Julian Alps", "Alpes juliennes"), ("Pyrenees", "Pyrénées"),
        ("Security: wait {}s", "Sécurité : attends {1} s"), ("Too many emails, try later", "Trop d'e-mails, réessaie plus tard"),
        ("Wrong or expired code", "Code incorrect ou expiré"), ("Invalid email", "E-mail invalide"),
        ("Couldn't send, try again", "Envoi impossible, réessaie"), ("No connection", "Pas de connexion"),

        // Login, accessibility, profile edit
        ("Sign-in method", "Méthode de connexion"), ("Send password reset email", "Envoyer un e-mail de réinitialisation"),
        ("Check {} for a link to reset your password.", "Vérifie {1} : tu y trouveras un lien pour réinitialiser ton mot de passe."),
        ("Podz follows your iPhone's VoiceOver and Reduce Motion settings.", "Podz suit les réglages VoiceOver et Réduction des animations de ton iPhone."),
        ("Saving…", "Enregistrement…"), ("Save", "Enregistrer"), ("Username", "Nom d'utilisateur"), ("Name", "Nom"), ("Age", "Âge"), ("Location", "Lieu"),
        ("Your photo", "Ta photo"), ("Change photo", "Changer de photo"), ("Press and hold the photo to adjust it", "Maintiens la photo pour l'ajuster"),
        ("Profile photo. Double tap to change, press and hold to adjust", "Photo de profil. Touche deux fois pour changer, maintiens pour ajuster"),
        ("Adjust photo", "Ajuster la photo"), ("Pinch to zoom, drag to move", "Pince pour zoomer, glisse pour déplacer"),
        ("Rotate", "Pivoter"), ("Reset", "Réinitialiser"),
        ("Couldn't open your photo.", "Impossible d'ouvrir ta photo."), ("Couldn't prepare the photo.", "Impossible de préparer la photo."),

        ("Expanded", "Déplié"), ("Collapsed", "Replié"),
        ("Close", "Fermer"), ("Change profile photo", "Changer la photo de profil"), ("Lenny is typing", "Lenny écrit"),
        ("Listed", "Référencé"),
        ("Friends you share it with can view this folder, read-only.", "Les amis avec qui tu le partages peuvent voir ce dossier, en lecture seule."),
        ("Add friends in Profile, then share this folder with them.", "Ajoute des amis dans ton profil, puis partage ce dossier avec eux."),

        // About, legal, sign-up
        ("About Podz", "À propos de Podz"), ("Version {}", "Version {1}"), ("Terms of Service", "Conditions d'utilisation"),
        ("Privacy Policy", "Politique de confidentialité"), ("Last updated {}", "Dernière mise à jour : {1}"), ("November 2026", "novembre 2026"),
        ("Share anonymous usage", "Partager l'usage anonyme"), ("On", "Activé"), ("Off", "Désactivé"),
        ("Hut data © OpenStreetMap contributors. Photos from Wikimedia Commons, with their credits. Not every hut is checked by Podz.", "Données des refuges © contributeurs d'OpenStreetMap. Photos de Wikimedia Commons, avec leurs crédits. Podz ne vérifie pas tous les refuges."),
        ("By continuing you accept the [Terms](podz-legal://terms) and the [Privacy Policy](podz-legal://privacy).", "En continuant, tu acceptes les [Conditions](podz-legal://terms) et la [Politique de confidentialité](podz-legal://privacy)."),

        // Friends
        ("Add friend", "Ajouter un ami"), ("Add a friend", "Ajouter un ami"), ("Requests", "Demandes"), ("Friends ({})", "Amis ({1})"),
        ("No friends yet", "Pas encore d'amis"),
        ("Add someone to plan trips together.", "Ajoute quelqu'un pour planifier vos séjours ensemble."),
        ("Decline", "Refuser"), ("Accept", "Accepter"), ("Remove friend", "Retirer l'ami"), ("Remove this friend?", "Retirer cet ami ?"),
        ("Requested", "Demandé"), ("Respond in Friends", "Répondre dans Amis"), ("Add", "Ajouter"),

    ]
}

/// The French for an English sentence of the app (see `FrenchStrings`).
func tr(_ text: String) -> String { FrenchStrings.translate(text) }

/// `Text` that speaks the app's language: the French twin when there is one.
func T(_ text: String) -> Text { Text(tr(text)) }
