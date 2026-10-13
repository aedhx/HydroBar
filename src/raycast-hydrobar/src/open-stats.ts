import { open, showToast, Toast } from "@raycast/api";

export default async function Command() {
  try {
    await open("hydrobar://open/stats");
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not reach HydroBar",
      message: "Make sure HydroBar 2.0 or later is installed and has been opened once.",
    });
  }
}
