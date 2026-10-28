#!/bin/bash
# Crée RepCounter-Local.xcworkspace : le projet Xcode, plus les autres dossiers du dossier
# RepCounter (Design, Simulation, Recordings…), visibles dans Xcode mais jamais compilés.
#
# L'espace de travail reste sur ce Mac (exclu de Git par .gitignore). Les dossiers présents
# sur ce Mac mais absents du dépôt (le marketing, par exemple) sont exclus de Git ici même,
# dans .git/info/exclude : ce fichier n'est jamais versionné, leurs noms non plus.
#
# Usage : Tools/make_workspace.sh   (à relancer après l'ajout d'un dossier)
set -euo pipefail
cd "$(dirname "$0")/.."

workspace=RepCounter-Local.xcworkspace
mkdir -p "$workspace"
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<Workspace'
    echo '   version = "1.0">'
    echo '   <FileRef'
    echo '      location = "group:RepCounter.xcodeproj">'
    echo '   </FileRef>'
    for item in */ README.md LICENSE NOTICE; do
        item=${item%/}
        [ -e "$item" ] || continue
        case "$item" in
            RepCounter | *.xcodeproj | *.xcworkspace | build | DerivedData) continue ;;
        esac
        name=${item//&/&amp;}
        echo '   <FileRef'
        echo "      location = \"group:$name\">"
        echo '   </FileRef>'
    done
    echo '</Workspace>'
} > "$workspace/contents.xcworkspacedata"

# Dossiers sans aucun fichier suivi par Git : exclus de Git sur ce Mac seulement
exclude=.git/info/exclude
touch "$exclude"
for dir in */; do
    dir=${dir%/}
    case "$dir" in *.xcworkspace | *.xcodeproj) continue ;; esac
    [ -z "$(git ls-files -- "$dir" | head -n 1)" ] || continue
    if ! grep -qxF "/$dir/" "$exclude"; then
        echo "/$dir/" >> "$exclude"
        echo "Exclu de Git sur ce Mac : $dir/"
    fi
done

echo "Ouvre $workspace dans Xcode (à la place de RepCounter.xcodeproj)."
