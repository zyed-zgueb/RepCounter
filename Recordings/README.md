# Enregistrements de séances

Fichiers `.jsonl` produits par l'app (bouton ● pendant une séance), pour analyser une séance
qui compte mal. Pour les rejouer et tracer les courbes :

    python3 Simulation/replay.py Recordings/<fichier>.jsonl

Le script affiche le nombre réel de répétitions, celui compté par l'app et celui du compteur
Python rejoué, et écrit une image `<fichier>.png` avec le signal de chaque capteur.

Pour rejouer tout le corpus d'un coup, résumer la précision par exercice et détecter une
régression (un enregistrement exact qui ne l'est plus) :

    python3 Simulation/benchmark.py            # --update pour enregistrer une nouvelle référence

Le protocole de collecte et les critères de lancement sont dans `PROTOCOLE.md`.
