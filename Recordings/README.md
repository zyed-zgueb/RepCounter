# Enregistrements de séances

Fichiers `.jsonl` produits par l'app (bouton ● pendant une séance), pour analyser une séance
qui compte mal. Pour les rejouer et tracer les courbes :

    python3 Simulation/replay.py Recordings/<fichier>.jsonl

Le script affiche le nombre réel de répétitions, celui compté par l'app et celui du compteur
Python rejoué, et écrit une image `<fichier>.png` avec le signal de chaque capteur.
