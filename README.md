Projet : Quoridor & IA recherche de chemin (Godot 4)

Petit jeu de plateau réalisé avec Godot 4 :
deux pions partent chacun d’un bord du plateau (13×13) et doivent être les premiers à atteindre la ligne opposée.
Les joueurs peuvent se déplacer ou poser des murs pour gêner l’adversaire.
Certaines cases sont des cases “stun” qui font perdre un tour.

Le jeu propose :
un mode VS IA (contre l’ordinateur)
un mode 1v1 local (deux joueurs sur le même clavier)
deux algos de pathfinding : Dijkstra et A*

## 1. Prérequis
Godot 4.x (le projet a été développé en 4.4.1 stable)
Cloner ou extraire le projet, puis ouvrir le dossier dans Godot.

## 2. Lancement
Ouvrir le projet dans Godot.
Lancer la scène principale (menu) : Menu_scene.tscn.
Depuis le menu, choisir :
l’algorithme : A* ou Dijkstra
le mode de jeu : VS IA ou 1v1
Dans le menu, deux IA jouent en automatique en arrière-plan pour montrer le comportement de l’algorithme choisi.

## 3. Règles du jeu
Plateau : 13 x 13 cases.
Joueur rouge en bas, joueur bleu en haut.
Objectif :
- Le rouge doit atteindre la ligne du haut.
- Le bleu doit atteindre la ligne du bas.

À chaque tour, un joueur peut :
Se déplacer d’une case (haut / bas / gauche / droite)
Poser un mur sur une case libre.

Murs
Un mur rend une case infranchissable (bloquée).
Le jeu vérifie qu’il reste au moins un chemin pour les deux joueurs.
Si un mur bloque complètement un joueur, il est refusé et un message apparaît.

Cases stun
Certaines cases spéciales (stun) sont générées aléatoirement.
L’algorithme leur donne un coût plus élevé (3 au lieu de 1).

Si un joueur (ou l’IA) marche dessus :
son prochain tour est sauté (stun 1 tour),
un message de notification s’affiche.

Victoire
Si le pion rouge atteint la ligne du haut => victoire du Joueur rouge.
Si le pion bleu atteint la ligne du bas => victoire du Joueur bleu.
En mode VS IA, un écran différent s’affiche selon victoire / défaite.

## 4. Modes de jeu
Mode VS IA

Joueur rouge : contrôlé par le joueur.
Joueur bleu : contrôlé par l’IA.
L’IA utilise l’algorithme sélectionné (A* ou Dijkstra) et tient compte :
- des murs,
- des cases stun (coût 3),
et peut poser des murs pour ralentir l’adversaire.

Mode 1v1 (MULTI)
Joueur bleu = Joueur 1
Joueur rouge = Joueur 2

Les deux joueurs jouent à tour de rôle :
le tour actuel est affiché par :
- une flèche animée au-dessus du pion qui doit jouer,
- un compteur de tours en haut à gauche.

## 5. Contrôles

Joueur 1 (rouge)

Déplacements
- Z : haut
- Q : gauche
- S : bas
- D : droite

Poser un mur

Clic gauche sur la case où poser le mur (pendant le tour du joueur rouge).

Joueur 2 (bleu) – Mode 1v1 seulement

Déplacements

- Flèche haut
- Flèche bas
- Flèche gauche
- Flèche droite

Poser un mur

Clic gauche sur la case (pendant le tour du joueur bleu).

Commun

- ECHAP : ouvrir / fermer le menu pause (reprendre, aide, retour menu).

- Bouton Debug : afficher ou cacher les valeurs de distance (Dijkstra / A*) sur le plateau pour visualiser les coûts.

## 6. Structure principale du code

### board.gd

Gère toute la logique du plateau :

grille, murs, cases stun,

pathfinding (Dijkstra, A*),

tours de jeu, stun, victoire, HUD (compteur de tours, flèches).

### player.gd
Contrôle les entrées du Joueur 1 (ZQSD) :

déplacement,

pose de mur,

activation de la flèche animée.

### ia.gd

En VS IA : logique du tour IA (chemin, pose mur, déplacement).

En 1v1 : gestion des entrées du Joueur 2 (flèches + murs).

Gère aussi la flèche animée au-dessus du pion bleu.

### game_settings.gd (autoload)

Stocke la configuration globale :
algo_mode : ASTAR ou DIJKSTRA
game_mode : VS_IA ou MULTI

### Scènes de menu (Menu_scene.tscn, menu_panel.gd, menuwalk.gd)

Choix du mode / algo,
affichage des IA qui jouent en fond,
boutons pour lancer une partie, retourner au menu, etc.
