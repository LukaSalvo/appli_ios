# Paie Horaire

App iOS (SwiftUI + SwiftData) de suivi de paie à l'heure : renseignez votre taux
horaire et vos avantages, démarrez une session, et le montant gagné se calcule
en temps réel pendant que vous travaillez.

## Fonctionnalités

- **Suivi en direct** : chronomètre + compteur de gains qui se met à jour
  chaque seconde (via `TimelineView`, sans `Timer` manuel).
- **Avantages configurables** : chaque avantage est soit *par heure* (s'ajoute
  au taux horaire), soit *par prise de poste* (montant fixe ajouté une fois au
  démarrage, ex. prime panier repas).
- **Historique** : liste des sessions terminées avec le détail, total de la
  semaine en cours.
- Les sessions passées gardent une **photo (snapshot)** du taux et des
  avantages du moment, donc modifier vos réglages plus tard ne change pas
  l'historique.

## Architecture

```
PayTracker/
  PayTrackerApp.swift        # Point d'entrée, ModelContainer SwiftData
  ContentView.swift          # TabView (Suivi / Historique / Réglages)
  Models/
    Benefit.swift            # Avantage (nom, montant, type, actif)
    WorkSession.swift        # Session de travail (dates + snapshot des taux)
  Views/
    TrackerView.swift        # Écran principal : démarrer/arrêter + calcul live
    HistoryView.swift        # Historique des sessions
    SettingsView.swift       # Taux horaire + gestion des avantages
    BenefitRowView.swift
    AddBenefitView.swift
  Resources/Assets.xcassets  # Icône (placeholder) + couleur d'accent
```

## Calcul

Pour une session en cours à l'instant `t` :

```
heures       = (t - début) / 3600
gain de base = heures × taux_horaire
avantages/h  = heures × somme(avantages "par heure" actifs)
avantages fixes = somme(avantages "par prise de poste" actifs)

total = gain de base + avantages/h + avantages fixes
```

## Ouvrir le projet

Ce dépôt ne contient pas de `.xcodeproj` généré (il est ignoré par git) : le
projet est décrit par `project.yml` et généré avec
[XcodeGen](https://github.com/yonaskolb/XcodeGen), ce qui évite les conflits
de fichier projet binaire dans git.

1. Installer XcodeGen (une fois) : `brew install xcodegen`
2. À la racine du dépôt : `xcodegen generate`
3. Ouvrir `PayTracker.xcodeproj` dans Xcode 15+
4. Sélectionner un simulateur iOS 17+ et lancer (⌘R)

## Pistes d'évolution

- Majorations (nuit, dimanche, jours fériés) en % du taux horaire
- Widget iOS / Live Activity affichant le gain en direct sur l'écran verrouillé
- Export CSV / PDF de l'historique pour la fiche de paie
- Synchronisation iCloud (CloudKit) entre appareils
- Pause pendant une session (pause déjeuner) sans arrêter le suivi
