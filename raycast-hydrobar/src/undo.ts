import { open, showToast, Toast } from "@raycast/api";

export default async function Command() {
  try {
    await open("hydrobar://undo");
    // Le schéma d'URL ne renvoie rien : impossible de savoir d'ici si la pile
    // d'annulation était vide. HydroBar affiche lui-même une notification dans
    // ce cas, donc on reste neutre plutôt que d'annoncer un succès incertain.
    await showToast({ style: Toast.Style.Success, title: "Undo sent to HydroBar" });
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not reach HydroBar",
      message: "Make sure HydroBar 1.3 or later is installed and has been opened once.",
    });
  }
}
