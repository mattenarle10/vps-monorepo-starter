import cors from "cors";
import express from "express";
import helmet from "helmet";

const app = express();
const PORT = process.env.PORT ?? 4000;

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGINS?.split(",") ?? "*", credentials: true }));
app.use(express.json());

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.get("/api/hello", (_req, res) => {
  res.json({ message: "Hello from the API 🦀" });
});

app.listen(PORT, () => {
  console.log(`API running on port ${PORT}`);
});
