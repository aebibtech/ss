import { defineConfig } from "drizzle-kit";

// We fallback to a default PostgreSQL URL if the environment variable is not defined yet (e.g., during build time)
const dbUrl = process.env.ConnectionStrings__db || process.env.DATABASE_URL || "postgresql://postgres:postgres@localhost:5432/db";

// Handle parsing of ADO.NET connection strings for drizzle-kit
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

export default defineConfig({
  schema: "./db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: getConnectionStringUri(dbUrl),
  },
});
