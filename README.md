# Paie Horaire & Budget

App iOS (SwiftUI + SwiftData) qui suit votre paie **et** votre budget du mois :
renseignez votre rémunération (à l'heure ou au mois), vos avantages, vos tickets
restaurant et vos dépenses fixes — l'app calcule en temps réel ce que vous gagnez
et ce qu'il vous reste à vivre.

## Fonctionnalités

### Suivi de paie
- **Deux modes de paie** :
  - **À l'heure** : démarrez une session, le montant gagné monte seconde par
    seconde (via `TimelineView`, sans `Timer` manuel).
  - **Au mois** : votre salaire net s'accumule au fil du mois, avec la part déjà
    « gagnée » à ce jour et une barre de progression du mois.
- **Saisie manuelle d'une journée** : renseignez l'heure d'arrivée, l'heure de
  départ et le temps de pause — les heures travaillées (amplitude − pause) et la
  paie estimée s'affichent en direct. Gère aussi les horaires de nuit.
- **Pause** : ajustable aussi pendant une session en direct ; elle est déduite
  des heures payées.
- **Avantages configurables** : *par heure* (s'ajoute au taux horaire) ou
  *par prise de poste* (montant fixe ajouté au démarrage d'une session).

### Budget
- **Tableau de bord** avec un anneau « reste à vivre » (revenus − dépenses fixes).
- **Dépenses fixes mensuelles** récurrentes (loyer, abonnements, transport,
  assurances…) rangées par catégorie.
- **Tickets restaurant** : valeur du ticket, part employeur (%), nombre de jours
  travaillés → l'app calcule la part offerte par l'employeur (comptée comme un
  avantage) et votre part.
- Le budget bascule automatiquement selon le mode de paie (heures cumulées du
  mois, ou salaire mensuel).

### Heures & historique
- **Cumul d'heures travaillées** par **jour / semaine / mois** (sélecteur), avec
  nombre de sessions et gains sur la période.
- **Graphique** en barres des heures de la semaine (jour en cours mis en avant).
- Sessions terminées listées avec durée et horaires.
- Chaque session garde un **snapshot** du taux et des avantages du moment :
  modifier vos réglages plus tard ne fausse pas l'historique.

### Notifications
- **Bilan quotidien à 18 h** : chaque jour, une notification récapitule les
  **heures faites** et l'**argent gagné** dans la journée, plus le **temps
  restant (h/min)** pour atteindre les **35 h de la semaine** (votre contrat
  hebdomadaire, configurable). Activable/désactivable dans les Réglages.
- Comme une notification locale a un contenu figé, les chiffres sont
  recalculés et replanifiés à chaque ouverture de l'app et à chaque changement
  de session — rien n'est envoyé en ligne.

### Assistant IA (onglet « IA »)
- **Ajouter, modifier ou supprimer** une journée en langage naturel — y compris
  un **jour passé** : « supprime mes heures d'avant-hier », « modifie lundi, je
  suis parti à 18h », « ajoute hier de 9h à 17h avec 30 min de pause ».
- **Barre de saisie clavier *et* vocale** : dictez votre demande au micro
  (reconnaissance vocale française) ou tapez-la.
- Comprend les dates relatives (hier, avant-hier, « il y a 3 jours »), les jours
  de la semaine (« mardi », « lundi dernier ») et les dates (« le 12 »,
  « 12 juillet », « 12/07 »).
- Chaque action est appliquée immédiatement à votre historique, avec un bouton
  **Annuler** dans la conversation.
- L'analyse se fait **sur l'appareil** : l'IA d'Apple (Foundation Models,
  iOS 26+) affine la compréhension quand elle est disponible, sinon un
  analyseur local prend le relais — rien n'est envoyé en ligne.

## Sécurité & vie privée

L'app ne fait **aucun appel réseau** : tout (y compris l'IA, via les Foundation
Models d'Apple) tourne sur l'iPhone. Les protections en place :

- **Verrouillage par Face ID / Touch ID** (Réglages → Confidentialité). Le code
  de l'iPhone sert de repli, donc le verrou fonctionne aussi sans biométrie.
  L'app se re-verrouille dès qu'elle passe en arrière-plan, et se masque dans le
  sélecteur d'applications — la capture d'écran que iOS enregistre sur le disque
  ne contient plus aucun montant.
- **Masquage des montants sur l'écran verrouillé** : le bilan quotidien et
  l'activité en direct n'affichent plus que les heures, jamais les euros.
- **Fichiers importés traités comme non fiables.** Une sauvegarde `.json` ou un
  emploi du temps `.ics` peut venir de n'importe où. Chaque import est donc
  plafonné en taille *avant* d'être lu (`BoundedFileReader`), limité en nombre
  d'entrées, et chaque valeur est bornée (`Sanitize`, `AppBackup.checked()`) :
  ni pause négative — qui *augmenterait* la paie, puisque le temps payé vaut
  amplitude − pause —, ni taux infini, ni départ avant l'arrivée.
- **Titres d'agenda isolés du modèle IA.** Un titre d'événement est écrit par
  un tiers (calendrier partagé, fichier reçu) : il est nettoyé, tronqué, et
  passé au modèle dans un bloc de données que les instructions lui demandent
  explicitement de ne jamais interpréter comme une consigne.
- **Textes affichés nettoyés** des caractères de contrôle et des inversions
  bidirectionnelles Unicode, qui permettent de faire lire à un libellé autre
  chose que ce qu'il contient.
- **Aucun plantage au démarrage** si le magasin SwiftData est illisible : l'app
  bascule sur un stockage mémoire et le signale, au lieu de devenir inutilisable.

> ⚠️ Le fichier produit par « Exporter mes données » n'est **pas chiffré** : il
> contient salaire, solde et dépenses en clair. À ranger dans un espace de
> confiance.

## Architecture

```
PayTracker/
  PayTrackerApp.swift          # Point d'entrée, ModelContainer SwiftData
  ContentView.swift            # TabView (IA / Budget / Agenda / Heures / Réglages)
  Theme.swift                  # Couleurs, dégradés + composant Card réutilisable
  Models/
    PayMode.swift              # Mode de paie + helpers (format €, fraction du mois)
    Benefit.swift              # Avantage (nom, montant, type, actif)
    Expense.swift              # Dépense fixe mensuelle (nom, montant, catégorie)
    Budget.swift               # Calcul du budget + config tickets restaurant
    WorkStats.swift            # Cumul d'heures jour/semaine/mois + série hebdo
    WorkSession.swift          # Session de travail (dates + snapshot des taux)
    SessionCommand.swift       # Ordre IA structuré (ajouter/modifier/supprimer)
    SessionCommandParser.swift # Analyse d'un ordre (dates FR) + IA on-device
    AISessionCommandParser.swift # Intention + heures via Foundation Models (iOS 26+)
    SpeechRecognizer.swift     # Dictée vocale (framework Speech) pour l'assistant
    SessionReminder.swift      # Notif locale : session en cours oubliée
    DailySummaryNotification.swift # Notif locale : bilan quotidien à 18 h
    AppLock.swift              # Verrou Face ID / Touch ID / code de l'iPhone
    Sanitize.swift             # Bornes sur tout ce qui vient de l'extérieur
    BoundedFileReader.swift    # Lecture de fichier plafonnée (imports)
    AppBackup.swift            # Export + import validé d'une sauvegarde
  Views/
    AIAssistantView.swift      # Onglet « IA » : chat + barre clavier/vocale
    TrackerView.swift          # Suivi live (heure) / salaire mensuel — intégré en tête de l'onglet Heures
    BudgetView.swift           # Tableau de bord budget
    BudgetRing.swift           # Anneau « reste à vivre »
    ExpensesView.swift         # Liste des dépenses fixes
    AddExpenseView.swift       # Ajout d'une dépense
    HistoryView.swift          # Heures (jour/semaine/mois) + graphique + sessions
    WeekBarChart.swift         # Graphique en barres des heures de la semaine
    AddSessionView.swift       # Saisie manuelle : arrivée, départ, pause
    SettingsView.swift         # Mode de paie, avantages, tickets restau, budget
    BenefitRowView.swift
    AddBenefitView.swift
  Resources/Assets.xcassets    # Icône (placeholder) + couleur d'accent
```

## Calcul du budget

```
Revenus du mois
  = salaire (mensuel fixe OU somme des sessions du mois)
  + part employeur des tickets restaurant

Part employeur tickets = valeur_ticket × (part_employeur % / 100) × jours_travaillés

Dépenses fixes = somme des dépenses récurrentes

Reste à vivre = Revenus − Dépenses fixes
```

## Ouvrir le projet

Le dépôt ne contient pas de `.xcodeproj` généré (il est ignoré par git) : le
projet est décrit par `project.yml` et généré avec
[XcodeGen](https://github.com/yonaskolb/XcodeGen), ce qui évite les conflits de
fichier projet binaire dans git.

1. Installer XcodeGen (une fois) : `brew install xcodegen`
2. À la racine du dépôt : `xcodegen generate`
3. Ouvrir `PayTracker.xcodeproj` dans Xcode 15+
4. Sélectionner un simulateur iOS 17+ et lancer (⌘R)

## Intégration continue (CI)

Le workflow GitHub Actions `.github/workflows/ci.yml` se déclenche à chaque
`push` et `pull request`. Aucun secret requis.
- **Sécurité** : scan de secrets (Gitleaks) + refus de tout fichier de
  signature sensible versionné (`.p12`, `.p8`, `.mobileprovision`, `.env`…) +
  contrôle du `.gitignore` + refus de toute exception App Transport Security ou
  URL `http://` + vérification que les garde-fous de sécurité (validation des
  imports, verrouillage, isolation des titres d'agenda) sont toujours en place.
- **Continuité** : génération XcodeGen → build sur simulateur iOS → tests
  (ignorés proprement tant qu'aucun test n'existe).

> Installer l'app sur l'iPhone se fait manuellement depuis Xcode avec un
> Apple ID gratuit (`⌘R`, à renouveler tous les 7 jours), ou via AltStore /
> SideStore. Une mise à jour automatique par pipeline (TestFlight) nécessite
> un compte Apple Developer payant et n'est donc pas incluse ici.

## Pistes d'évolution

- Majorations (nuit, dimanche, jours fériés) en % du taux horaire
- Widget iOS / Live Activity affichant le gain en direct sur l'écran verrouillé
- Objectifs d'épargne mensuels et alertes de dépassement de budget
- Export CSV / PDF de l'historique et du budget
- Synchronisation iCloud (CloudKit) entre appareils
