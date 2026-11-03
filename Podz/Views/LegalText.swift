import Foundation

/// The words of the Terms and the Privacy Policy, in English and French (they
/// are long, so they don't go through `tr`). Plain facts about what Podz
/// actually does today; have them read by a lawyer before the App Store.
enum LegalText {
    struct Section {
        let heading: String
        let text: String
    }

    static let updated = "November 2026"

    static func sections(_ document: LegalDocument) -> [Section] {
        let french = FrenchStrings.isActive
        switch document {
        case .terms: return french ? termsFR : termsEN
        case .privacy: return french ? privacyFR : privacyEN
        }
    }

    // MARK: - Terms

    private static let termsEN = [
        Section(heading: "What Podz is", text: "Podz helps you find mountain huts and reserve a bed. Some huts are partners you can reserve in the app. Others are listed from public data and are booked directly with the hut."),
        Section(heading: "Your account", text: "You sign in with your email and a code. Keep your email safe and give us true information. You can delete your account at any time in Profile."),
        Section(heading: "Reservations", text: "A reservation at a partner hut is a request between you and that hut, and the hut's own conditions apply. For a listed hut, Podz only keeps a note of the stay you tell us about; the booking itself is between you and the hut."),
        Section(heading: "Information on huts", text: "Hours, beds, prices and facilities come from the huts and from public sources such as OpenStreetMap, and can be out of date or wrong. Check with the hut before you go. Mountains are dangerous: Podz is not a safety service, and the weather, the route and your choices stay yours."),
        Section(heading: "Your content", text: "Your photo, folders and likes stay yours. We keep and show them in the app only as needed to run it, for example to friends you share a folder with."),
        Section(heading: "Fair use", text: "Don't misuse Podz: no illegal content, no harassment, no attempts to break or overload the service."),
        Section(heading: "Ending", text: "We can suspend an account that breaks these terms. You can leave whenever you want."),
        Section(heading: "Changes", text: "These terms can change as Podz grows. If you keep using the app after a change, you accept the new version."),
        Section(heading: "Contact", text: "Write to us with the support address shown on Podz's page in the App Store.")
    ]

    private static let termsFR = [
        Section(heading: "Ce qu'est Podz", text: "Podz t'aide à trouver des refuges de montagne et à réserver un lit. Certains refuges sont partenaires et se réservent dans l'app. Les autres viennent de données publiques et se réservent directement auprès du refuge."),
        Section(heading: "Ton compte", text: "Tu te connectes avec ton e-mail et un code. Garde ton e-mail en sécurité et donne-nous des informations exactes. Tu peux supprimer ton compte à tout moment dans Profil."),
        Section(heading: "Réservations", text: "Une réservation dans un refuge partenaire est une demande entre toi et ce refuge, dont les propres conditions s'appliquent. Pour un refuge simplement listé, Podz garde seulement une note du séjour que tu nous indiques ; la réservation elle-même se fait entre toi et le refuge."),
        Section(heading: "Informations sur les refuges", text: "Horaires, lits, prix et équipements viennent des refuges et de sources publiques comme OpenStreetMap, et peuvent être périmés ou inexacts. Vérifie auprès du refuge avant de partir. La montagne est dangereuse : Podz n'est pas un service de sécurité, et la météo, l'itinéraire et tes choix restent les tiens."),
        Section(heading: "Ton contenu", text: "Ta photo, tes dossiers et tes likes restent à toi. Nous les conservons et ne les montrons dans l'app que si c'est nécessaire à son fonctionnement, par exemple aux amis avec qui tu partages un dossier."),
        Section(heading: "Usage correct", text: "N'utilise pas Podz de travers : pas de contenu illégal, pas de harcèlement, pas de tentative de casser ou de surcharger le service."),
        Section(heading: "Fin", text: "Nous pouvons suspendre un compte qui ne respecte pas ces conditions. Tu peux partir quand tu veux."),
        Section(heading: "Changements", text: "Ces conditions peuvent évoluer avec Podz. Si tu continues d'utiliser l'app après un changement, tu acceptes la nouvelle version."),
        Section(heading: "Contact", text: "Écris-nous à l'adresse d'assistance indiquée sur la page de Podz dans l'App Store.")
    ]

    // MARK: - Privacy

    private static let privacyEN = [
        Section(heading: "What we keep", text: "Your email, and the name, username, age, place and photo you choose to add. Your reservations, likes, folders and friends. That's what the app needs to work."),
        Section(heading: "How the app is used", text: "Podz notes simple events, such as opening a pod or booking, and crash reports, under a random number made on your phone. It is not linked to your account, and what you type in a search is never kept. You can turn it off in Profile > About Podz."),
        Section(heading: "What we don't do", text: "No ads, no tracking across other apps, no selling your data, and we don't use your phone's location."),
        Section(heading: "Who helps us run Podz", text: "Supabase hosts the database and your sign-in. Resend sends your sign-in code by email. Apple Maps draws the maps. Hut data comes from OpenStreetMap contributors and photos from Wikimedia Commons, with their credits."),
        Section(heading: "On your phone", text: "To work in the mountains without signal, Podz saves your likes, reservations, passes and some photos and maps on your phone."),
        Section(heading: "Your choices", text: "Edit your profile at any time. Delete your account in Profile and your profile, likes, folders and reservations are deleted with it."),
        Section(heading: "Children", text: "Podz is not made for children under 13."),
        Section(heading: "Contact", text: "Write to us with the support address shown on Podz's page in the App Store.")
    ]

    private static let privacyFR = [
        Section(heading: "Ce que nous gardons", text: "Ton e-mail, et le nom, le nom d'utilisateur, l'âge, le lieu et la photo que tu choisis d'ajouter. Tes réservations, tes likes, tes dossiers et tes amis. C'est ce dont l'app a besoin pour fonctionner."),
        Section(heading: "Comment l'app est utilisée", text: "Podz note des événements simples, comme l'ouverture d'un refuge ou une réservation, et les rapports de plantage, sous un numéro aléatoire créé sur ton téléphone. Il n'est pas lié à ton compte, et ce que tu écris dans une recherche n'est jamais conservé. Tu peux le désactiver dans Profil > À propos de Podz."),
        Section(heading: "Ce que nous ne faisons pas", text: "Pas de publicité, pas de suivi entre les apps, pas de vente de tes données, et nous n'utilisons pas la position de ton téléphone."),
        Section(heading: "Qui nous aide à faire tourner Podz", text: "Supabase héberge la base de données et ta connexion. Resend envoie ton code de connexion par e-mail. Apple Plans dessine les cartes. Les données des refuges viennent des contributeurs d'OpenStreetMap et les photos de Wikimedia Commons, avec leurs crédits."),
        Section(heading: "Sur ton téléphone", text: "Pour marcher sans réseau, Podz enregistre sur ton téléphone tes likes, tes réservations, tes pass, et certaines photos et cartes."),
        Section(heading: "Tes choix", text: "Modifie ton profil à tout moment. Supprime ton compte dans Profil : ton profil, tes likes, tes dossiers et tes réservations sont supprimés avec."),
        Section(heading: "Enfants", text: "Podz n'est pas conçu pour les enfants de moins de 13 ans."),
        Section(heading: "Contact", text: "Écris-nous à l'adresse d'assistance indiquée sur la page de Podz dans l'App Store.")
    ]
}
