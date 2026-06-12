import express from "express";
import cors from "cors";
import { toNodeHandler } from "better-auth/node";
import { auth } from "./auth";
import { expressMiddleware } from "@as-integrations/express4";
import { createGraphQLServer } from "./graphql";
import { initializeBucket } from "./s3";

const app = express();
const port = process.env.PORT || 8080;

// Configure CORS to allow cookie/session sharing across origins
app.use(cors({
  origin: true,
  credentials: true
}));

// Better Auth route handler
app.all("/api/auth/*splat", toNodeHandler(auth));

// Setup GraphQL endpoint
const server = createGraphQLServer();
await server.start();

// Initialize upload bucket
await initializeBucket();

app.use(
  "/graphql",
  express.json(),
  expressMiddleware(server, {
    context: async ({ req }) => {
      try {
        const sessionData = await auth.api.getSession({
          headers: req.headers,
        });
        return {
          user: sessionData?.user ?? null,
          session: sessionData?.session ?? null,
        };
      } catch (error) {
        console.error("[GraphQL Context] Error getting session:", error);
        return { user: null, session: null };
      }
    },
  })
);

app.get("/", (req, res) => {
  res.send("Hello World!");
});

app.listen(port, () => {
  console.log(`Listening on port ${port}...`);
});