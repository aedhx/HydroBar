import { open, showToast, Toast } from "@raycast/api";

// Preset 3 tel que configuré dans HydroBar — la quantité suit les réglages de
// l'utilisateur, elle n'est pas figée ici.
const PRESET_NUMBER = 3;

export default async function Command() {
  try {
    await open(`hydrobar://add?preset=${PRESET_NUMBER}`);
    await showToast({ style: Toast.Style.Success, title: `Added preset ${PRESET_NUMBER}` });
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not reach HydroBar",
      message: "Make sure HydroBar 1.3 or later is installed and has been opened once.",
    });
  }
}
