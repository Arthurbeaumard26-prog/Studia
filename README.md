# Studia — application iPhone pour Pronote (Collège Françoise Dolto)

Application **native SwiftUI** (pas de site web déguisé). La webview ne sert **qu'à la
connexion unique** (Pronote mobile → ÉduConnect). Toutes les données sont ensuite
récupérées automatiquement, rangées par rubrique, stockées localement et affichées
avec un design sobre noir + bleu.

## Ouvrir le projet
1. Ouvrir `Studia.xcodeproj` dans **Xcode 16 ou plus récent**.
2. Brancher ton iPhone ou lancer le simulateur.
3. `Product ▸ Run`.

- Cible : iOS 16.0+, iPhone uniquement, thème sombre.
- Bundle : `college.dolto.studia` — ajoute une équipe de signature dans les réglages de la cible pour installer sur ton iPhone.

## Fonctionnement
- Écran **Connexion** : webview ouverte sur
  https://0170010u.index-education.net/pronote/mobile.html (ÉduConnect).
  Dès que la session Pronote est reconnue, la récupération automatique démarre.
- Écran **Synchronisation** : barre de progression + libellés
  (« récupération de l'emploi du temps », « des devoirs », « des notes », « de la vie scolaire »…).
- Les rubriques sont récupérées **séparément** : emploi du temps, devoirs, notes,
  vie scolaire, cahier de textes, informations, compétences, documents, agenda,
  messagerie, profil.
- Cinq onglets natifs : Accueil · Cours (jour par jour, balayage) · Devoirs
  (semaine par semaine, case fait/non fait) · Notes · Vie scolaire.
- Données stockées localement (`snapshot.json`) : l'app fonctionne hors ligne,
  s'ouvre directement sur tes données et se rafraîchit en arrière-plan
  (bouton ↻ et « tirer pour rafraîchir » sur chaque écran).
- Détection d'expiration de session : bannière « Reconnecte-toi pour actualiser tes données ».
- Déduplication par empreinte (jour + matière + texte) ; aucune donnée inventée :
  une rubrique vide affiche clairement qu'il n'y a rien.

## Limites connues (honnêteté === qualité)
- La case « devoir fait » est mémorisée localement : Pronote web mobile 2026
  n'expose pas d'écriture fiable pour cet état, l'app n'envoie donc pas de
  fausse écriture.
- Parsing HTML heuristique : si l'établissement désactive une rubrique
  (ex. messagerie), elle s'affiche vide avec son motif, jamais avec du contenu inventé.
