import { open, showHUD, showToast, Toast } from "@raycast/api";

// Ce que HydroBar accepte pour un ajout : entre 1 et 5 000 ml
// (HydrationLimits.single). On valide ici pour répondre tout de suite, plutôt que
// de laisser l'app rejeter le lien sans pouvoir le dire à Raycast.
const MIN_ML = 1;
const MAX_ML = 5000;

// Les unités du schéma d'URL : hydrobar://add?ml=250, ?cl=25, ?l=0.25, ?oz=8.
const ML_PER_UNIT = { ml: 1, cl: 10, l: 1000, oz: 29.5735295625 } as const;
type Unit = keyof typeof ML_PER_UNIT;

export type Amount = { value: number; unit: Unit; label: string };

/**
 * Lit « 250 », « 33cl », « 0,5 L » ou « 8 oz ». Sans unité, ce sont des
 * millilitres. Renvoie `null` si le texte n'est pas une quantité, ou si elle
 * sort des bornes de HydroBar.
 */
export function parseAmount(input: string): Amount | null {
  const match = input
    .trim()
    .toLowerCase()
    .replace(",", ".")
    .match(/^(\d+(?:\.\d+)?)\s*(ml|cl|l|oz)?$/);
  if (!match) return null;
  const value = parseFloat(match[1]);
  const unit = (match[2] ?? "ml") as Unit;
  const ml = value * ML_PER_UNIT[unit];
  if (!(ml >= MIN_ML && ml <= MAX_ML)) return null;
  return { value, unit, label: `${value} ${unit === "l" ? "L" : unit}` };
}

/**
 * Ouvre un lien hydrobar://. `done` s'affiche une fois le lien parti : le
 * schéma d'URL ne répond pas, donc c'est « envoyé », pas « accepté » — si
 * HydroBar refuse la demande, il le dit lui-même dans une notification.
 */
export async function send(url: string, done?: string) {
  try {
    await open(url);
    if (done) await showHUD(done);
  } catch {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not reach HydroBar",
      message: "Make sure HydroBar 2.0 or later is installed and has been opened once.",
    });
  }
}
