// The config of `basis lint`, from monke's root: its schema gives its notes and what is not a note.
import type { Config } from "@mku1tra/basis";
import monke from "./schema.ts";

export default { schema: monke } satisfies Config;
