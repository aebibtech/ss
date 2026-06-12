import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

const connStr = process.env.ConnectionStrings__db || process.env.DATABASE_URL;

if (!connStr) {
  // We'll use a placeholder URL for build/generating schemas when connection string is not yet present
  console.warn("Warning: ConnectionStrings__db or DATABASE_URL not set. Using fallback URL for schema generation.");
}

function getConnectionStringUri(connStr: string): string {
  if (connStr.startsWith("postgres://") || connStr.startsWith("postgresql://")) {
    return connStr;
  }

  const parts = connStr.split(";").reduce((acc, part) => {
    const index = part.indexOf("=");
    if (index !== -1) {
      const key = part.substring(0, index).trim().toLowerCase();
      const val = part.substring(index + 1).trim();
      acc[key] = val;
    }
    return acc;
  }, {} as Record<string, string>);

  const host = parts.host || parts.server || "localhost";
  const port = parts.port || "5432";
  const database = parts.database || parts.db || "";
  const username = parts.username || parts.user || parts["user id"] || "postgres";
  const password = parts.password || "";

  return `postgresql://${encodeURIComponent(username)}:${encodeURIComponent(password)}@${host}:${port}/${database}`;
}

const pgUri = connStr ? getConnectionStringUri(connStr) : "postgresql://postgres:postgres@localhost:5432/db";
const queryClient = postgres(pgUri);
export const db = drizzle(queryClient, { schema });
