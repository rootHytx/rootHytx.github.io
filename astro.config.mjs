import { defineConfig } from "astro/config";

// https://astro.build/config
export default defineConfig({
  site: "https://roothytx.github.io",
  base: "/",
  outDir: "./dist",
  build: {
    format: "directory",
  },
  integrations: [],
});
