import vike from "vike/plugin";
import { defineConfig } from "vite";
import solid from "vite-plugin-solid";

export default defineConfig({
  plugins: [vike(), solid()],
  server: { port: 3001 },
});
