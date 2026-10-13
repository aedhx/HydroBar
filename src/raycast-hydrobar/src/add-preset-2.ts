import { send } from "./lib/hydrobar";

// Preset 2 tel que configuré dans HydroBar — la quantité suit les réglages de
// l'utilisateur, elle n'est pas figée ici.
export default async function Command() {
  await send("hydrobar://add?preset=2", "Preset 2 logged");
}
