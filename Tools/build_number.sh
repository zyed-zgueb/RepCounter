#!/bin/sh
# Phase de build « Numéro de build » (Xcode) : inscrit dans l'Info.plist de l'app
# - CFBundleVersion : le nombre de commits jusqu'au commit compilé (croissant, exigé par l'App Store) ;
# - RepsCommit : l'empreinte courte du commit, suivie de « + » si des fichiers suivis ont été
#   modifiés sans être commités.
# L'app les affiche en bas des Réglages (« 0.1 (91) · 4a6762c ») ; `git show 4a6762c` retrouve
# le code exact. Sans Git (archive du code), le build garde CURRENT_PROJECT_VERSION.
set -e
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
cd "$SRCROOT"
if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    build=$(git rev-list --count HEAD)
    commit=$(git rev-parse --short=7 HEAD)
    git diff --quiet HEAD -- || commit="$commit+"
else
    build="$CURRENT_PROJECT_VERSION"
    commit="?"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"
/usr/libexec/PlistBuddy -c "Delete :RepsCommit" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :RepsCommit string $commit" "$plist"
