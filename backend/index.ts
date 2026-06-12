import express from "express";
import cors from "cors";
import { toNodeHandler } from "better-auth/node";
import { auth } from "./auth";

const app = express();
const port = process.env.PORT || 8080;

// Configure CORS to allow cookie/session sharing across origins
app.use(cors({
  origin: true,
  credentials: true
}));

// Better Auth route handler
app.all("/api/auth/*splat", toNodeHandler(auth));

app.get("/", (req, res) => {
  res.send("Hello World!");
});

app.listen(port, () => {
  console.log(`Listening on port ${port}...`);
});