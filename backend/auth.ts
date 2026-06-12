import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { db } from "./db";
import { organization } from "better-auth/plugins/organization";
import { admin } from "better-auth/plugins/admin";
import { bearer } from "better-auth/plugins/bearer";
import { magicLink } from "better-auth/plugins/magic-link";
import { organization as orgTable, member as memberTable } from "./db/schema";

export const auth = betterAuth({
  database: drizzleAdapter(db, {
    provider: "pg",
  }),
  trustedOrigins: ["http://localhost:*"],
  databaseHooks: {
    user: {
      create: {
        after: async (user) => {
          try {
            const orgId = crypto.randomUUID();
            const memberId = crypto.randomUUID();
            const orgName = `${user.name || 'User'}'s Team`;
            const orgSlug = `${user.id.substring(0, 8)}-org-${Math.floor(Math.random() * 1000)}`;

            await db.insert(orgTable).values({
              id: orgId,
              name: orgName,
              slug: orgSlug,
              createdAt: new Date(),
            });

            await db.insert(memberTable).values({
              id: memberId,
              organizationId: orgId,
              userId: user.id,
              role: "owner",
              createdAt: new Date(),
            });

            console.log(`[Database Hook] Automatically created default organization ${orgSlug} for user ${user.id}`);
          } catch (error) {
            console.error("[Database Hook] Failed to automatically create organization for user:", error);
          }
        },
      },
    },
  },
  plugins: [
    organization(),
    admin(),
    bearer(),
    magicLink({
      sendMagicLink: async ({ email, url, token }, ctx) => {
        const apiToken = process.env.ZEPTOMAIL_API_TOKEN;
        const senderEmail = process.env.ZEPTOMAIL_SENDER_EMAIL || "noreply@yourdomain.com";
        const senderName = process.env.ZEPTOMAIL_SENDER_NAME || "App Auth";

        console.log(`[Magic Link] Sending link to ${email}`);

        // Fallback for local development if ZeptoMail is not configured
        if (!apiToken) {
          console.log("----------------------------------------");
          console.log(`[DEVELOPMENT] Magic Link request for: ${email}`);
          console.log(`Link: ${url}`);
          console.log("----------------------------------------");
          return;
        }

        try {
          const response = await fetch("https://api.zeptomail.com/v1.1/email", {
            method: "POST",
            headers: {
              "Authorization": `Zoho-enczapikey ${apiToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: {
                address: senderEmail,
                name: senderName,
              },
              to: [
                {
                  email_address: {
                    address: email,
                  },
                },
              ],
              subject: "Sign in to your account",
              htmlbody: `
                <div style="font-family: sans-serif; padding: 20px; color: #333;">
                  <h2>Sign in to your account</h2>
                  <p>Click the button below to complete your sign-in request. This link will expire shortly.</p>
                  <a href="${url}" style="display: inline-block; padding: 10px 20px; background-color: #0070f3; color: white; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 15px 0;">Sign In</a>
                  <p style="color: #666; font-size: 12px;">If you did not request this email, you can safely ignore it.</p>
                </div>
              `,
              textbody: `Sign in to your account by visiting: ${url}`,
            }),
          });

          if (!response.ok) {
            const errorData = await response.json();
            console.error("ZeptoMail sending failed:", errorData);
            throw new Error("Failed to send Magic Link email via ZeptoMail API.");
          }
        } catch (error) {
          console.error("Error sending Magic Link via ZeptoMail:", error);
          throw error;
        }
      },
    }),
  ],
  socialProviders: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID || "placeholder",
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || "placeholder",
    },
  },
});
