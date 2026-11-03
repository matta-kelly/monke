/**
 * monke: its notes, on the note types of it. It defines no types of its own.
 */

import { defineSchema } from "@mku1tra/basis";
import it from "@mku1tra/it";

/** Whether a path of the repo, from its root, is not a note: a README, or a prompt in share/ that help gives a model, or a build in dist/. */
const skip = (path: string) => path.split("/").at(-1) === "README.md" || path.startsWith("share/") || path.startsWith("dist/");

export default defineSchema({
  name: "monke",
  description: "monke's notes, on the note types of it.",
  types: {},
  imports: [it],
  notes: new URL("./", import.meta.url),
  skip,
  exports: () => import("./schema.ts"),
});
