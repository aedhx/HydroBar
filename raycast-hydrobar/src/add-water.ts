import { open, showToast, Toast } from "@raycast/api";

// HydroBar borne un ajout unique à 5 000 ml (HydrationLimits.single) et rejette
// toute URL hors bornes : on valide ici pour donner un message utile tout de suite.
const MIN_ML = 1;
const MAX_ML = 5000;

export default async function Command({ arguments: args }: { arguments: { ml: string } }) {
  const ml = args.ml.trim();
  const num = parseFloat(ml);
  if (!ml || isNaN(num) || num < MIN_ML || num > MAX_ML) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Invalid amount",
      message: `Enter a number between ${MIN_ML} and ${MAX_ML} (e.g. 250).`,
    });
    return;
  }
  try {
    await open(`hydrobar://add?ml=${encodeURIComponent(String(num))}`);
    await showToast({ style: Toast.Style.Success, title: `Added ${num} ml` });
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not reach HydroBar",
      message: "Make sure HydroBar 1.3 or later is installed and has been opened once.",
    });
  }
}
