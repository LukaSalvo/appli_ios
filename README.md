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

## Architecture

```
PayTracker/
  PayTrackerApp.swift          # Point d'entrée, ModelContainer SwiftData
  ContentView.swift            # TabView (Suivi / Budget / Historique / Réglages)
  Theme.swift                  # Couleurs, dégradés + composant Card réutilisable
  Models/
    PayMode.swift              # Mode de paie + helpers (format €, fraction du mois)
    Benefit.swift              # Avantage (nom, montant, type, actif)
    Expense.swift              # Dépense fixe mensuelle (nom, montant, catégorie)
    Budget.swift               # Calcul du budget + config tickets restaurant
    WorkStats.swift            # Cumul d'heures jour/semaine/mois + série hebdo
    WorkSession.swift          # Session de travail (dates + snapshot des taux)
  Views/
    TrackerView.swift          # Suivi live (heure) ou salaire cumulé (mois)
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

## Intégration continue (CI/CD)

Deux workflows GitHub Actions sont fournis dans `.github/workflows/` :

### `ci.yml` — Sécurité & continuité (actif immédiatement)
Se déclenche à chaque `push` et `pull request`. Aucun secret requis.
- **Sécurité** : scan de secrets (Gitleaks) + refus de tout fichier de
  signature sensible versionné (`.p12`, `.p8`, `.mobileprovision`, `.env`…) +
  contrôle du `.gitignore`.
- **Continuité** : génération XcodeGen → build sur simulateur iOS → tests
  (ignorés proprement tant qu'aucun test n'existe).

### `deploy-testflight.yml` — Mise à jour sur iPhone (à activer)
Se déclenche sur `push` vers `main`. Construit l'app signée et l'envoie sur
**TestFlight** : tu reçois alors une notification sur ton iPhone et la mise à
jour s'installe en un tap. Apple n'autorise pas l'installation OTA silencieuse
pour une app grand public — c'est le plus proche possible d'une « mise à jour
directe ».

Le workflow reste **inerte tant que les secrets Apple ne sont pas configurés**
(il s'arrête proprement). Prérequis : un **compte Apple Developer payant**, une
clé API App Store Connect, un certificat de distribution et un provisioning
profile. La liste exacte des secrets à créer est documentée en tête du fichier
`deploy-testflight.yml`.

## Pistes d'évolution

- Majorations (nuit, dimanche, jours fériés) en % du taux horaire
- Widget iOS / Live Activity affichant le gain en direct sur l'écran verrouillé
- Objectifs d'épargne mensuels et alertes de dépassement de budget
- Export CSV / PDF de l'historique et du budget
- Synchronisation iCloud (CloudKit) entre appareils
