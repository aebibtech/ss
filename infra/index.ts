import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import * as cloudflare from "@pulumi/cloudflare";
import * as https from "https";

// Load configuration
const config = new pulumi.Config();

// GCP Settings
const gcpProject = config.require("gcpProject");
const gcpRegion = config.get("gcpRegion") || "us-central1";

// Cloudflare Settings
const cloudflareAccountId = config.require("cloudflareAccountId");
const domainName = config.get("domainName"); // optional
const cloudflareZoneId = config.get("cloudflareZoneId"); // optional

// Application secrets
const betterAuthSecret = config.requireSecret("betterAuthSecret");
const r2AccessKeyId = config.requireSecret("r2AccessKeyId");
const r2SecretAccessKey = config.requireSecret("r2SecretAccessKey");
const backendImageTag = config.get("backendImageTag") || "latest";

// Optional social/email auth configs
const zeptomailApiToken = config.getSecret("zeptomailApiToken") || "";
const zeptomailSenderEmail = config.get("zeptomailSenderEmail") || "";
const zeptomailSenderName = config.get("zeptomailSenderName") || "";
const googleClientId = config.get("googleClientId") || "";
const googleClientSecret = config.getSecret("googleClientSecret") || "";

// ==========================================
// Neon Database Custom Dynamic Provider
// ==========================================

interface NeonProjectInputs {
    apiKey: pulumi.Input<string>;
    projectName: pulumi.Input<string>;
}

class NeonProjectProvider implements pulumi.dynamic.ResourceProvider {
    async create(inputs: any): Promise<pulumi.dynamic.CreateResult> {
        const apiKey = inputs.apiKey;
        const name = inputs.projectName;

        const response = await new Promise<any>((resolve, reject) => {
            const reqData = JSON.stringify({ project: { name } });
            const req = https.request({
                hostname: "console.neon.tech",
                path: "/api/v2/projects",
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${apiKey}`,
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                }
            }, (res) => {
                let data = "";
                res.on("data", chunk => data += chunk);
                res.on("end", () => {
                    if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(JSON.parse(data));
                    } else {
                        reject(new Error(`Neon API returned status ${res.statusCode}: ${data}`));
                    }
                });
            });
            req.on("error", reject);
            req.write(reqData);
            req.end();
        });

        const projectId = response.project.id;
        const connectionUri = response.connection_uris && response.connection_uris[0] 
            ? response.connection_uris[0].connection_uri 
            : "";

        return {
            id: projectId,
            outs: {
                projectId,
                connectionUri,
                apiKey, // save API key to outputs so delete() can access it
            }
        };
    }

    async delete(id: string, outs: any): Promise<void> {
        const apiKey = outs.apiKey;
        if (!apiKey) return;

        await new Promise<void>((resolve, reject) => {
            const req = https.request({
                hostname: "console.neon.tech",
                path: `/api/v2/projects/${id}`,
                method: "DELETE",
                headers: {
                    "Authorization": `Bearer ${apiKey}`,
                    "Accept": "application/json",
                }
            }, (res) => {
                let data = "";
                res.on("data", chunk => data += chunk);
                res.on("end", () => {
                    if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
                        resolve();
                    } else {
                        if (res.statusCode === 404) {
                            resolve(); // already deleted
                        } else {
                            reject(new Error(`Neon API returned status ${res.statusCode}: ${data}`));
                        }
                    }
                });
            });
            req.on("error", reject);
            req.end();
        });
    }
}

export class NeonProject extends pulumi.dynamic.Resource {
    public readonly projectId!: pulumi.Output<string>;
    public readonly connectionUri!: pulumi.Output<string>;

    constructor(name: string, args: NeonProjectInputs, opts?: pulumi.CustomResourceOptions) {
        super(new NeonProjectProvider(), name, {
            projectId: undefined,
            connectionUri: undefined,
            apiKey: args.apiKey,
            projectName: args.projectName,
        }, opts);
    }
}

// ==========================================
// 1. Neon Database Setup
// ==========================================

const neonApiKey = process.env.NEON_API_KEY || config.requireSecret("neonApiKey");

const neonProject = new NeonProject("db-project", {
    apiKey: neonApiKey,
    projectName: "ss-db-production",
});

const databaseUrl = neonProject.connectionUri;

// ==========================================
// 2. Cloudflare R2 Object Storage
// ==========================================

const uploadsBucket = new cloudflare.R2Bucket("uploads", {
    accountId: cloudflareAccountId,
    name: "ss-uploads-production",
});

// ==========================================
// 3. GCP Container Registry Setup
// ==========================================

const repository = new gcp.artifactregistry.Repository("backend-repo", {
    repositoryId: "backend",
    format: "DOCKER",
    location: gcpRegion,
    description: "Docker repository for Bun backend service",
    project: gcpProject,
});

// Construct the Docker image path in Artifact Registry
const imageUrn = pulumi.interpolate`${gcpRegion}-docker.pkg.dev/${gcpProject}/${repository.repositoryId}/backend:${backendImageTag}`;

// ==========================================
// 4. GCP Cloud Run Backend Setup
// ==========================================

// Declare the variable first to resolve the circular reference in TypeScript and Node.js
let backendService: gcp.cloudrunv2.Service;

// Define the BETTER_AUTH_URL dynamically using a closure to resolve at runtime
const betterAuthUrl = domainName 
    ? pulumi.output(`https://api.${domainName}`)
    : pulumi.output(undefined).apply(() => backendService.uri);

// Create the Cloud Run service. Notice we use a placeholder image for the initial deployment
// if the real image hasn't been built/pushed yet.
backendService = new gcp.cloudrunv2.Service("backend-service", {
    name: "backend-api",
    location: gcpRegion,
    project: gcpProject,
    ingress: "INGRESS_TRAFFIC_ALL",
    template: {
        containers: [
            {
                image: imageUrn,
                ports: [
                    {
                        containerPort: 8080,
                    },
                ],
                envs: [
                    { name: "PORT", value: "8080" },
                    { name: "DATABASE_URL", value: databaseUrl },
                    { name: "R2_ENDPOINT", value: pulumi.interpolate`https://${cloudflareAccountId}.r2.cloudflarestorage.com` },
                    { name: "R2_ACCESS_KEY_ID", value: r2AccessKeyId },
                    { name: "R2_SECRET_ACCESS_KEY", value: r2SecretAccessKey },
                    { name: "BUCKET_NAME", value: uploadsBucket.name },
                    { name: "BETTER_AUTH_SECRET", value: betterAuthSecret },
                    {
                        name: "BETTER_AUTH_URL",
                        value: betterAuthUrl
                    },
                    {
                        name: "FRONTEND_URL",
                        value: domainName 
                            ? `https://app.${domainName}` 
                            : pulumi.interpolate`https://ss-frontend.pages.dev` // default fallback
                    },
                    { name: "ZEPTOMAIL_API_TOKEN", value: zeptomailApiToken },
                    { name: "ZEPTOMAIL_SENDER_EMAIL", value: zeptomailSenderEmail },
                    { name: "ZEPTOMAIL_SENDER_NAME", value: zeptomailSenderName },
                    { name: "GOOGLE_CLIENT_ID", value: googleClientId },
                    { name: "GOOGLE_CLIENT_SECRET", value: googleClientSecret },
                ],
            },
        ],
    },
});

// Allow unauthenticated invocations (make API public)
const noauth = new gcp.cloudrunv2.ServiceIamMember("backend-noauth", {
    project: gcpProject,
    location: gcpRegion,
    name: backendService.name,
    role: "roles/run.invoker",
    member: "allUsers",
});

// ==========================================
// 5. Cloudflare Pages Setup (Frontend & Brand)
// ==========================================

// Landing Page (Astro App)
const landingPageProject = new cloudflare.PagesProject("landing-page-project", {
    accountId: cloudflareAccountId,
    name: "ss-landing-page",
    productionBranch: "main",
});

// Flutter Web Frontend
const frontendProject = new cloudflare.PagesProject("frontend-project", {
    accountId: cloudflareAccountId,
    name: "ss-frontend",
    productionBranch: "main",
});

// ==========================================
// 6. Optional: Custom DNS & Domain Bindings
// ==========================================

if (domainName && cloudflareZoneId) {
    // Bind root domain to Astro Landing Page
    const landingPageDomain = new cloudflare.PagesDomain("landing-page-domain", {
        accountId: cloudflareAccountId,
        projectName: landingPageProject.name,
        domain: domainName,
    });

    new cloudflare.Record("landing-page-dns", {
        zoneId: cloudflareZoneId,
        name: "@",
        type: "CNAME",
        value: landingPageProject.subdomain,
        proxied: true,
    });

    // Bind app subdomain to Flutter Web Frontend
    const frontendDomain = new cloudflare.PagesDomain("frontend-domain", {
        accountId: cloudflareAccountId,
        projectName: frontendProject.name,
        domain: `app.${domainName}`,
    });

    new cloudflare.Record("frontend-dns", {
        zoneId: cloudflareZoneId,
        name: "app",
        type: "CNAME",
        value: frontendProject.subdomain,
        proxied: true,
    });

    // CNAME API subdomain to Cloud Run URL
    const runHost = backendService.uri.apply((uri: string) => uri.replace("https://", ""));
    new cloudflare.Record("backend-dns", {
        zoneId: cloudflareZoneId,
        name: "api",
        type: "CNAME",
        value: runHost,
        proxied: true,
    });
}

// ==========================================
// 7. Outputs
// ==========================================

export const backendRawUrl = backendService.uri;
export const backendApiUrl = domainName ? `https://api.${domainName}` : backendService.uri;
export const landingPageUrl = domainName ? `https://${domainName}` : landingPageProject.subdomain.apply(sub => `https://${sub}`);
export const frontendUrl = domainName ? `https://app.${domainName}` : frontendProject.subdomain.apply(sub => `https://${sub}`);
export const dbConnectionUri = neonProject.connectionUri;
export const registryUrl = pulumi.interpolate`${gcpRegion}-docker.pkg.dev/${gcpProject}/${repository.repositoryId}`;
export const r2BucketName = uploadsBucket.name;
