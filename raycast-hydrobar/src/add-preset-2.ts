import { open, showToast, Toast } from "@raycast/api";

const HYDROBAR_ADD_PRESET = "hydrobar://add/preset/";

export default async function Command() {
  const url = `${HYDROBAR_ADD_PRESET}1`;
  try {
    await open(url);
    await showToast({ style: Toast.Style.Success, title: "Added Preset 2" });
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "HydroBar not running?",
      message: "Open HydroBar from the menu bar first.",
    });
  }
}
