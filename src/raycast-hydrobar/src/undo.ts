import { send } from "./lib/hydrobar";

export default async function Command() {
  // Impossible de savoir d'ici s'il y avait quelque chose à annuler : on dit
  // seulement que la demande est partie.
  await send("hydrobar://undo", "Undo sent to HydroBar");
}
