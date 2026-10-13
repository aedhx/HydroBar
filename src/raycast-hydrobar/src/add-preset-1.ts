import { send } from "./lib/hydrobar";

// Preset 1 tel que configuré dans HydroBar — la quantité suit les réglages de
// l'utilisateur, elle n'est pas figée ici.
export default async function Command() {
  await send("hydrobar://add?preset=1", "Preset 1 logged");
}
