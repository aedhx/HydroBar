# GlobalHotkeyManager - Documentation

## Implémentation actuelle

Le `GlobalHotkeyManager` utilise l'API **Carbon native** de macOS pour enregistrer des raccourcis clavier globaux. Cette implémentation est robuste et ne nécessite pas de dépendances externes.

## Utilisation

### Enregistrer un raccourci pour un preset

```swift
// Exemple : Cmd+Shift+1 pour le premier preset
GlobalHotkeyManager.shared.registerShortcut(
    for: 0,  // Index du preset (0, 1, ou 2)
    keyCode: VirtualKeyCodes.one,
    modifiers: ModifierFlags.commandShift()
)

// Exemple : Cmd+Shift+2 pour le deuxième preset
GlobalHotkeyManager.shared.registerShortcut(
    for: 1,
    keyCode: VirtualKeyCodes.two,
    modifiers: ModifierFlags.commandShift()
)
```

### Désenregistrer un raccourci

```swift
GlobalHotkeyManager.shared.unregisterShortcut(for: 0)
```

### Désenregistrer tous les raccourcis

```swift
GlobalHotkeyManager.shared.unregisterAllShortcuts()
```

## Codes de touches disponibles

Voir `VirtualKeyCodes` dans `GlobalHotkeyManager.swift` pour la liste complète.

Exemples courants :
- `VirtualKeyCodes.one` à `VirtualKeyCodes.nine` : Chiffres
- `VirtualKeyCodes.a` à `VirtualKeyCodes.z` : Lettres
- `VirtualKeyCodes.f1` à `VirtualKeyCodes.f12` : Touches de fonction
- `VirtualKeyCodes.space` : Barre d'espace

## Modificateurs disponibles

- `ModifierFlags.command` : Cmd (⌘)
- `ModifierFlags.shift` : Shift (⇧)
- `ModifierFlags.option` : Option (⌥)
- `ModifierFlags.control` : Control (⌃)

Combinaisons :
- `ModifierFlags.commandShift()` : Cmd+Shift
- `ModifierFlags.commandOption()` : Cmd+Option
- `ModifierFlags.commandControl()` : Cmd+Control

## Alternative : HotKey via SPM

Si vous préférez utiliser une librairie moderne, voici comment ajouter **HotKey** de Sindre Sorhus :

### 1. Ajouter la dépendance dans Xcode

1. Ouvrez le projet dans Xcode
2. Sélectionnez le projet dans le navigateur
3. Allez dans l'onglet "Package Dependencies"
4. Cliquez sur le "+"
5. Entrez l'URL : `https://github.com/sindresorhus/HotKey`
6. Sélectionnez la version (recommandé : "Up to Next Major Version" avec "2.0.0")

### 2. Importer et utiliser

```swift
import HotKey

class GlobalHotkeyManager {
    private var hotkeys: [Int: HotKey] = [:]
    
    func registerShortcut(for presetIndex: Int, keyCode: Int, modifiers: Int) {
        // Convertir en Key et Modifiers de HotKey
        let key = Key(carbonKeyCode: UInt32(keyCode))
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        
        let hotkey = HotKey(key: key, modifiers: mods)
        hotkey.keyDownHandler = {
            if let amount = self.getPresetAmount(for: presetIndex) {
                HydrationManager.shared.addWater(amount: amount)
                NSSound.beep()
            }
        }
        
        hotkeys[presetIndex] = hotkey
    }
}
```

## Avantages de chaque approche

### Carbon (implémentation actuelle)
- ✅ Pas de dépendances externes
- ✅ API native macOS
- ✅ Robuste et testée
- ❌ Code plus verbeux
- ❌ API legacy (mais toujours supportée)

### HotKey (SPM)
- ✅ API moderne et simple
- ✅ Code plus lisible
- ✅ Maintenance active
- ❌ Dépendance externe
- ❌ Nécessite SPM

## Notes importantes

1. **Permissions** : Les raccourcis globaux fonctionnent sans permissions spéciales sur macOS.

2. **Conflits** : Si un raccourci est déjà utilisé par le système ou une autre app, l'enregistrement peut échouer. Vérifiez la valeur de retour de `registerShortcut()`.

3. **Performance** : Les raccourcis sont traités de manière asynchrone sur le thread principal pour éviter de bloquer l'interface.

4. **Son de feedback** : Actuellement, le système utilise `NSSound.beep()`. Vous pouvez le remplacer par un son personnalisé si nécessaire.
