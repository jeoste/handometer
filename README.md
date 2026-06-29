# Handometer

> Un **podomètre pour tes mains** 🖐️ — Handometer mesure, **par jour**, la distance
> physique parcourue par ton curseur et le nombre de fois que tu appuies sur chaque touche.

- 📏 **Distance souris** en cm réels (taper 5 cm avec la souris = 5 cm comptés).
- 🏎️ **Vitesse** souris moyenne et maximale en km/h.
- 🖱️ **Clics** comptés par bouton : gauche, droit et molette (clic central).
- ⌨️ **Fréquence des touches** : taper « bonjour » → b×1, **o×2**, n×1, j×1, u×1, r×1.
- 📊 Dashboard du jour + historique en graphiques.
- 💾 Export CSV / JSON.
- 🔄 Mises à jour automatiques (Sparkle).

> L'interface de l'app est en **anglais**.

Tout reste **100 % local et privé** : seuls des compteurs par caractère sont
stockés — jamais les mots ni l'ordre des frappes.

## Installation

1. Télécharge la dernière version sur la [page Releases](https://github.com/jeoste/handometer/releases).
2. Dézippe et glisse `Handometer.app` dans `/Applications`.
3. **Premier lancement** — l'app n'est pas signée par Apple, donc macOS la bloque.
   Fais un **clic-droit sur l'app ▸ Ouvrir**, puis confirme. (À ne faire qu'une fois.)
   - Alternative en terminal : `xattr -dr com.apple.quarantine /Applications/Handometer.app`
4. macOS demande la permission **Accessibilité** (indispensable pour compter les
   frappes) : *Réglages Système ▸ Confidentialité et sécurité ▸ Accessibilité* →
   active **Handometer**, puis relance l'app.

L'icône apparaît dans la **barre de menu** (pas dans le Dock). Clique dessus pour
voir tes stats ou ouvrir le dashboard.

## Compilation depuis les sources

Prérequis : macOS 13+ et la toolchain Swift.

```bash
./build.sh            # produit Handometer.app (version par défaut)
VERSION=1.2.3 ./build.sh   # avec une version précise
open Handometer.app
```

## Comment ça marche

- Surveillance via `NSEvent` (moniteurs global + local).
- Conversion pixels → cm grâce à `CGDisplayScreenSize` (taille physique de
  l'écran), calculée par moniteur (multi-écrans gérés).
- Persistance JSON dans `~/Library/Application Support/Handometer/stats.json`.
- Auto-update via [Sparkle](https://sparkle-project.org) et un flux `appcast.xml`.

## Releases & mises à jour

Chaque push sur `main` déclenche automatiquement le workflow
[`.github/workflows/release.yml`](.github/workflows/release.yml) : il incrémente
le numéro de version (patch), compile l'app, signe l'archive (EdDSA Sparkle),
publie une [GitHub Release](https://github.com/jeoste/handometer/releases) et
met à jour `appcast.xml`.

Les apps installées détectent les mises à jour via Sparkle (menu barre →
**Check for updates…**). Le flux lit `appcast.xml` sur `main` et télécharge le
zip depuis la GitHub Release correspondante.

> L'auto-update ne fonctionne qu'avec un bundle `.app` complet (build via
> `./build.sh` ou release téléchargée), pas avec `swift run`.

## Licence

[MIT](LICENSE).
