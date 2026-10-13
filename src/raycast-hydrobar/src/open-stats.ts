import { send } from "./lib/hydrobar";

export default async function Command() {
  await send("hydrobar://open/stats");
}
