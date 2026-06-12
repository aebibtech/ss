# 🚀 SaaS Starter Template

A production-ready, highly-optimized SaaS starter template designed to accelerate modern web and mobile application development. This template integrates a cross-platform frontend, a high-performance backend, a fast landing page, and a robust Infrastructure-as-Code (IaC) setup.

---

## 🏗️ Architecture & Technology Stack

This project is structured as a monorepo containing the following core services:

```mermaid
graph TD
    subgraph Client Tier
        Brand[Astro Brand Site / Tailwind CSS]
        Flutter[Flutter Web & App / Dart]
    end

    subgraph Service Tier
        AppHost[TypeScript Aspire AppHost]
        Backend[Bun + Express + GraphQL API]
    end

    subgraph Infrastructure Tier
        DB[(PostgreSQL / Drizzle ORM)]
        Cache[(Redis Cache)]
        S3[(MinIO / Cloudflare R2 Storage)]
    end

    AppHost -->|Orchestrates| Brand
    AppHost -->|Orchestrates| Backend
    AppHost -->|Orchestrates| Flutter
    Backend --> DB
    Backend --> Cache
    Backend --> S3
    Flutter -->|GraphQL & Auth API| Backend
```

### 1. **Orchestrator & Local Development**
- **Technology**: **Aspire (TypeScript/Node.js Host)** via `apphost.ts`
- **Role**: Automatically spins up database, cache, storage, and server services in development, providing an interactive dashboard for logs, metrics, and distributed tracing.

### 2. **Marketing & Landing Page**
- **Technology**: **Astro v6** + **React 19** + **TailwindCSS v4** (located in `./brand`)
- **Role**: High-speed, SEO-optimized landing page designed for content marketing, blog posts, and converting visitors into users.

### 3. **Application Frontend**
- **Technology**: **Flutter SDK (Dart)** (located in `./frontend`)
- **Role**: Rich, cross-platform client (supports Flutter Web, Android, iOS, Desktop) featuring a modern dark theme and custom animations.
- **Routing**: Multi-route system integrating a landing menu, stateful counter, organization-management dashboard, admin settings, and a fully interactive movie library interface.

### 4. **Backend API**
- **Technology**: **Bun Runtime** + **Express** + **Apollo Server (GraphQL)** + **Drizzle ORM** (located in `./backend`)
- **Role**: Secure API gateway handling authentication requests, file storage operations, database queries, and administrative commands.

### 5. **Authentication & Multi-Tenancy**
- **Technology**: **Better Auth** (configured in `backend/auth.ts`)
- **Features**:
  - Drizzle-based PostgreSQL session adapter.
  - Multi-tenant organization support (workspaces, member roles, invite verification).
  - Database hooks that automatically create a default workspace/team for new users upon sign-up.
  - Development console logger and production **ZeptoMail** integration for transactional emails (magic links and organization invitations).
  - Bearer tokens for native application auth, and HttpOnly cookies for web browsers.

### 6. **Database & Cache**
- **Database**: **PostgreSQL** (local Docker in dev, serverless **Neon DB** in production) configured via **Drizzle ORM**.
- **Cache**: **Redis** used for backend session caching and rate-limiting.

### 7. **Object Storage (S3)**
- **Technology**: AWS S3 API (**MinIO** in development, **Cloudflare R2** in production).
- **Features**: Presigned URL generation for secure, direct file uploads from the client.

### 8. **Infrastructure-as-Code (IaC)**
- **Technology**: **Pulumi (TypeScript)** (located in `./infra`)
- **Role**: Provisions production environments including GCP Artifact Registry/Cloud Run, Cloudflare R2/Pages, and Neon PostgreSQL databases.

---

## 📂 Directory Structure

Here is a map of the repository's layout:

```text
ss/
├── .aspire/                 # Aspire local state and configurations
├── .github/
│   └── workflows/           # CI/CD deployment pipelines
│       ├── deploy.yml       # Production deployment workflow
│       └── pr-validation.yml# Pull request validation workflow
├── apphost.ts               # Core Aspire typescript orchestrator
├── package.json             # Root dependencies & command scripts
├── tsconfig.apphost.json    # TypeScript configurations for AppHost
├── backend/                 # Bun GraphQL + Express backend service
│   ├── db/                  # Drizzle ORM schema and DB clients
│   ├── auth.ts              # Better Auth service & plugins
│   ├── graphql.ts           # Apollo Server schema & resolvers
│   └── s3.ts                # MinIO & Cloudflare R2 object storage client
├── brand/                   # Astro static/marketing web application
├── frontend/                # Flutter client application
│   ├── lib/
│   │   ├── main.dart        # Flutter entry point & route definitions
│   │   ├── screens/         # Flutter pages (Auth, Orgs, Movies, Admin)
│   │   └── services/        # HTTP client & GraphQL service (AuthService)
│   └── scripts/             # Startup scripts mapping Aspire environment to Dart
├── infra/                   # Pulumi IaC configs (GCP + Cloudflare + Neon)
└── scripts/                 # Administrative scripts (e.g. GitHub secrets setup)
```

---

## 🚀 Local Development Setup

### Prerequisites
Make sure you have the following installed on your machine:
- **Node.js** (v20+ or v22+)
- **Bun** (v1.1+ - used for backend execution)
- **Docker Desktop** (required by Aspire to boot Redis, Postgres, and MinIO)
- **Flutter SDK** (configured for web or mobile development)

### Quickstart

1. **Install Root Dependencies**:
   ```bash
   npm install
   ```

2. **Boot the Aspire Dashboard & Services**:
   ```bash
   npm run dev
   ```
   This command starts the local Aspire orchestrator. It will spin up your backing Docker containers and bind your applications:
   - **Postgres Database**: Local Docker DB.
   - **Redis Cache**: Local Docker cache.
   - **MinIO S3 Server**: Running local object storage (Console at `http://localhost:9001`).
   - **Backend Server**: Bun application.
   - **Brand Website**: Astro application.
   - **App Frontend**: Flutter web-server application.

3. **Open the Aspire Dashboard**:
   Look for the dashboard URL in your terminal (typically `https://localhost:17227` or similar). Here you can see:
   - Healthy running states of all services.
   - Real-time application logs.
   - Tracing requests (OTLP) across backend, brand, and frontend.

---

## 💾 Database Migrations

Database structures are defined in `backend/db/schema.ts` using Drizzle ORM.

To apply schema modifications:

1. **Navigate to the Backend directory**:
   ```bash
   cd backend
   ```

2. **Generate a migration**:
   ```bash
   bunx drizzle-kit generate
   ```

3. **Apply the migration locally**:
   ```bash
   # Make sure the local database is running (npm run dev in root)
   bunx drizzle-kit migrate
   ```

> [!TIP]
   > During local development, Aspire automatically passes database connection parameters to Drizzle through environment variables. If running backend scripts independently, Drizzle will fall back to `postgresql://postgres:postgres@localhost:5432/db`.

---

## 🔐 Authentication & Session Flow

The authentication system leverages **Better Auth**:
1. Users authenticate via Magic Link, Social Login (Google), or standard flows.
2. Better Auth processes the request and returns a session token.
3. In browser environments, this session is stored in an HttpOnly cookie. For native apps, a Bearer token is supported.
4. On every request to the `/graphql` endpoint, the backend Express middleware retrieves the user session:
   ```ts
   const sessionData = await auth.api.getSession({ headers: req.headers });
   ```
5. Resolvers receive this authenticated session as context (`context.user` and `context.session`).
6. A default database hook auto-creates a workspace/organization named `"{User's Name}'s Team"` on the first sign-up.

---

## 📦 Object Storage & File Uploads

Direct, secure file uploads are performed using presigned S3 URLs:
1. The client requests a presigned upload URL from the GraphQL Query:
   ```graphql
   query {
     presignedUploadUrl(fileName: "my_banner.png", contentType: "image/png") {
       uploadUrl
       publicUrl
       key
     }
   }
   ```
2. The server generates a PUT signature (expires in 1 hour).
3. The client uploads the file directly to the S3 bucket using a `PUT` request containing the file payload.
4. The file can then be accessed publicly at `publicUrl` (which maps to the MinIO instance locally, and Cloudflare R2 in production).

---

## ☁️ Infrastructure & Cloud Deployment

We use **Pulumi** to manage resources. The setup spans three cloud systems:
- **GCP**: Hosts GCP Artifact Registry for containers and GCP Cloud Run for serving the backend API.
- **Cloudflare**: Hosts the R2 Storage Bucket and two Cloudflare Pages sites (for Astro Brand and Flutter Web).
- **Neon DB**: Auto-creates serverless PostgreSQL databases.

### Setting Up Secrets (GitHub Actions)

A script is provided to easily upload development and deployment credentials into your GitHub Repository Secrets.

1. Install the GitHub CLI (`brew install gh` on macOS) and run `gh auth login`.
2. Execute the setup script:
   ```bash
   ./scripts/setup_github_secrets.sh
   ```
3. Input your secret keys when prompted:
   - `PULUMI_ACCESS_TOKEN` (from Pulumi Cloud console)
   - `GCP_SA_KEY` (service account JSON key file content)
   - `CLOUDFLARE_API_TOKEN` & `CLOUDFLARE_ACCOUNT_ID`
   - `NEON_API_KEY`

### Production Pipelines

- **PR Validation Workflow** (`.github/workflows/pr-validation.yml`): Runs on any pull request targeting the `main` branch. It performs linting, TypeScript compiling, and validates client/backend builds.
- **Deployment Workflow** (`.github/workflows/deploy.yml`): Triggered automatically when code is pushed or merged to `main`.
  1. Deploys database and storage configurations through **Pulumi**.
  2. Builds the Backend Docker image and pushes it to GCP Artifact Registry.
  3. Executes Drizzle DB Migrations against the Neon Database.
  4. Deploys the brand marketing site to Cloudflare Pages.
  5. Compiles Flutter Web and deploys the application to Cloudflare Pages.
