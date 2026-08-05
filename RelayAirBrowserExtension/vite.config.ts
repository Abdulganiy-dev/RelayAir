import { defineConfig, build as viteBuild } from "vite";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { rmSync } from "node:fs";
import { viteStaticCopy } from "vite-plugin-static-copy";

const rootDir = dirname(fileURLToPath(import.meta.url));

/**
 * Headless extension build: content script (IIFE) + service worker (ESM).
 * No popup / React UI.
 */
export default defineConfig({
  publicDir: false,
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "public/manifest.json", dest: "." },
        { src: "public/icons/*", dest: "icons" },
      ],
    }),
    {
      name: "relayair-extension-scripts",
      apply: "build",
      async closeBundle() {
        const outDir = resolve(rootDir, "dist");

        await viteBuild({
          configFile: false,
          publicDir: false,
          build: {
            outDir,
            emptyOutDir: false,
            sourcemap: true,
            lib: {
              entry: resolve(rootDir, "src/content/index.ts"),
              name: "RelayAirContent",
              formats: ["iife"],
              fileName: () => "content/content.js",
            },
            rollupOptions: {
              output: {
                extend: true,
                inlineDynamicImports: true,
              },
            },
          },
        });

        await viteBuild({
          configFile: false,
          publicDir: false,
          build: {
            outDir,
            emptyOutDir: false,
            sourcemap: true,
            lib: {
              entry: resolve(rootDir, "src/background/service-worker.ts"),
              formats: ["es"],
              fileName: () => "background/service-worker.js",
            },
            rollupOptions: {
              output: {
                inlineDynamicImports: true,
              },
            },
          },
        });

        // Remove the outer stub entry used only to drive Vite's build lifecycle.
        for (const stub of ["_stub.js", "_stub.js.map"]) {
          try {
            rmSync(resolve(outDir, stub));
          } catch {
            // ignore
          }
        }
      },
    },
  ],
  build: {
    outDir: "dist",
    emptyOutDir: true,
    // Stub entry so Vite runs; real bundles are emitted in closeBundle.
    lib: {
      entry: resolve(rootDir, "src/background/service-worker.ts"),
      formats: ["es"],
      fileName: () => "_stub.js",
    },
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
      },
    },
  },
});
