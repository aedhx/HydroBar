import { showToast, Toast } from "@raycast/api";
import { parseAmount, send } from "./lib/hydrobar";

export default async function Command({ arguments: args }: { arguments: { amount: string } }) {
  const amount = parseAmount(args.amount);
  if (!amount) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Not an amount HydroBar can log",
      message: "Try 250, 33cl, 0.5l or 8oz. One drink is between 1 ml and 5 L.",
    });
    return;
  }
  await send(`hydrobar://add?${amount.unit}=${amount.value}`, `${amount.label} logged`);
}
