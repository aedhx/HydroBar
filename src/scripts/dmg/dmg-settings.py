# Réglages dmgbuild de l'image disque de HydroBar (voir src/scripts/package-dmg.sh).
#
# dmgbuild écrit lui-même le .DS_Store du volume : la mise en page ne dépend
# plus d'un AppleScript adressé au Finder, qui échouait sans permission
# d'automatisation et laissait une fenêtre en désordre.
#
# Les coordonnées sont en points, origine en haut à gauche de la fenêtre. Le
# fond (DMG-background.tiff, 660 × 400 en 1x et 2x) est dessiné pour elles :
# la flèche relie (180, 170) à (480, 170). Changer l'un sans l'autre décale tout.

app = defines["app"]  # noqa: F821 — fourni par dmgbuild (-D app=…)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
# Pas de hide_extensions : il pose un attribut Finder sur HydroBar.app, que
# `codesign --verify --strict` refuse. Le Finder masque déjà « .app » par défaut.

background = defines["background"]  # noqa: F821
window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    "HydroBar.app": (180, 170),
    "Applications": (480, 170),
}
