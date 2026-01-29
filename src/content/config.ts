import { defineCollection, z } from "astro:content";

const utilities = defineCollection({
  type: "content",
  schema: z.object({
    title: z.string(),
    description: z.string(),
    category: z.enum([
      "system",
      "docker",
      "security",
      "networking",
      "general",
      "nix",
      "utility",
    ]),
    tags: z.array(z.string()).optional(),
    created: z.date().optional(),
    updated: z.date().optional(),
  }),
});

export const collections = {
  utilities,
};
