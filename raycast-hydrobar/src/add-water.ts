import { open, showToast, Toast } from "@raycast/api";

export default async function Command({ arguments: args }: { arguments: { ml: string } }) {
  const ml = args.ml.trim();
  const num = parseFloat(ml);
  if (!ml || isNaN(num) || num <= 0) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Invalid amount",
      message: "Enter a positive number (e.g. 250).",
    });
    return;
  }
  const url = `hydrobar://add?ml=${encodeURIComponent(String(num))}`;
  try {
    await open(url);
    await showToast({ style: Toast.Style.Success, title: `Added ${num} ml` });
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "HydroBar not running?",
      message: "Open HydroBar from the menu bar first.",
    });
  }
}
