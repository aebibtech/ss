// Aspire TypeScript AppHost
// For more information, see: https://aspire.dev
import { createBuilder } from './.modules/aspire.js';
const builder = await createBuilder();
const redis = await builder.addRedis("cache");
const postgres = await builder
    .addPostgres("db")
    .withDataVolume()
    .withPersistentLifetime()
    .withPgAdmin();
const minio = await builder
    .addContainer("minio", "minio/minio")
    .withEnvironment("MINIO_ROOT_USER", "minioadmin")
    .withEnvironment("MINIO_ROOT_PASSWORD", "minioadmin")
    .withEnvironment("MINIO_API_CORS_ALLOW_ORIGIN", "*")
    .withHttpEndpoint({ targetPort: 9000, name: "s3" })
    .withHttpEndpoint({ targetPort: 9001, name: "console" })
    .withArgs(["server", "/data", "--console-address", ":9001"]);
const backend = await builder
    .addBunApp("backend", "./backend", "index.ts")
    .withHttpEndpoint({ env: "PORT" })
    .withReference(postgres)
    .withReference(redis)
    .withReference(minio.getEndpoint("s3"));
const brandSite = await builder
    .addViteApp("brand", "./brand");
await builder
    .addExecutable("frontend", "/bin/bash", "./frontend", ["./scripts/run_aspire.sh", "web"])
    .withReference(brandSite)
    .withReference(backend)
    .waitFor(backend)
    .withHttpEndpoint({
    env: "PORT"
});
await builder.build().run();
