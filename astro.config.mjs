import { defineConfig } from "astro/config";
import markdownIntegration from "@astropub/md";

// https://astro.build/config
export default defineConfig({
  site: "https://roothytx.github.io",
  base: "/",
  outDir: "./dist",
  build: {
    format: "directory",
  },
  integrations: [markdownIntegration()],
  markdown: {
    remarkPlugins: [],
    rehypePlugins: [],
    // syntaxHighlight: 'shiki'
    // syntaxHighlight: 'prism'
  },
});
