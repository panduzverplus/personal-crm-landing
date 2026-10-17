// @ts-check
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, fontProviders } from "astro/config";

// Fonts are downloaded from Google Fonts at build time and served from our own server.
const google = fontProviders.google();

export default defineConfig({
  output: "static",
  vite: {
    plugins: [tailwindcss()],
  },
  fonts: [
    {
      provider: google,
      name: "Geologica",
      cssVariable: "--font-geologica",
      weights: [300, 400, 500],
      styles: ["normal"],
      subsets: ["cyrillic", "latin"],
      // Geologica has no "→": the button arrow must come from plain sans-serif as in the design,
      // not from a size-adjusted fallback font
      optimizedFallbacks: false,
    },
    {
      provider: google,
      name: "Unbounded",
      cssVariable: "--font-unbounded",
      weights: [900],
      styles: ["normal"],
      subsets: ["cyrillic", "latin"],
    },
    {
      provider: google,
      name: "Onest",
      cssVariable: "--font-onest",
      weights: [400, 600],
      styles: ["normal"],
      // "symbols" holds the arrow used between the search chips
      subsets: ["cyrillic", "latin", "symbols"],
    },
    {
      provider: google,
      name: "IBM Plex Mono",
      cssVariable: "--font-ibm-plex-mono",
      weights: [400],
      styles: ["normal"],
      subsets: ["cyrillic", "latin"],
    },
  ],
});
