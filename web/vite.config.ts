import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import tailwindcss from "@tailwindcss/vite"
import path from "node:path"

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  base: "./",
  build: {
    outDir: "build",
    emptyOutDir: true,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules")) {
            if (id.includes("react")) return "react"
            if (id.includes("recharts")) return "charts"
            if (id.includes("framer-motion")) return "animation"
            if (id.includes("@radix-ui")) return "radix"
            return "vendor"
          }
        },
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
})