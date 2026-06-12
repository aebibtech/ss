// Aspire TypeScript AppHost
// For more information, see: https://aspire.dev

import { createBuilder } from './.modules/aspire.js';

const builder = await createBuilder();

const redis = await builder.addRedis("cache");
const postgres = await builder
    .addPostgres("db")
    .withDataVolume()
    .withPersistentLifetime()
    .withPgWeb();

const backend = await builder
    .addBunApp("backend", "./backend", "index.ts")
    .withHttpEndpoint({ env: "PORT" })
    .withReference(postgres)
    .withReference(redis);

const brandSite = await builder
    .addViteApp("brand", "./brand");

await builder
    .addExecutable(
        "frontend",
        "/bin/bash",
        "./frontend",
        ["./scripts/run_aspire.sh", "web"]
    )
    .withReference(brandSite)
    .withReference(backend)
    .waitFor(backend)
    .withHttpEndpoint({
        env: "PORT"
    });

await builder.build().run();