import { S3Client, CreateBucketCommand, HeadBucketCommand, PutObjectCommand, GetObjectCommand, PutBucketPolicyCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// Read environment variables
const r2Endpoint = process.env.R2_ENDPOINT;
const r2AccessKeyId = process.env.R2_ACCESS_KEY_ID;
const r2SecretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
const r2Region = process.env.R2_REGION || "auto";

const minioEndpoint = process.env.services__minio__s3__0 || "http://localhost:9000";
const minioAccessKeyId = process.env.MINIO_ROOT_USER || "minioadmin";
const minioSecretAccessKey = process.env.MINIO_ROOT_PASSWORD || "minioadmin";

export const isProduction = !!(r2Endpoint && r2AccessKeyId && r2SecretAccessKey);

export const bucketName = process.env.BUCKET_NAME || "uploads";

let s3Client: S3Client;

if (isProduction) {
  console.log("[S3 Client] Initializing Cloudflare R2 client...");
  s3Client = new S3Client({
    endpoint: r2Endpoint,
    region: r2Region,
    credentials: {
      accessKeyId: r2AccessKeyId!,
      secretAccessKey: r2SecretAccessKey!,
    },
    forcePathStyle: false, 
  });
} else {
  console.log(`[S3 Client] Initializing MinIO client at ${minioEndpoint}...`);
  s3Client = new S3Client({
    endpoint: minioEndpoint,
    region: "us-east-1",
    credentials: {
      accessKeyId: minioAccessKeyId,
      secretAccessKey: minioSecretAccessKey,
    },
    forcePathStyle: true, // Crucial for local MinIO
  });
}

// Function to verify and initialize the bucket
export async function initializeBucket() {
  try {
    console.log(`[S3 Client] Checking if bucket "${bucketName}" exists...`);
    await s3Client.send(new HeadBucketCommand({ Bucket: bucketName }));
    console.log(`[S3 Client] Bucket "${bucketName}" already exists.`);
  } catch (error: any) {
    if (error.name === "NotFound" || error.$metadata?.httpStatusCode === 404) {
      console.log(`[S3 Client] Bucket "${bucketName}" not found. Creating it...`);
      try {
        await s3Client.send(new CreateBucketCommand({ Bucket: bucketName }));
        console.log(`[S3 Client] Bucket "${bucketName}" created successfully.`);
      } catch (createError) {
        console.error(`[S3 Client] Failed to create bucket "${bucketName}":`, createError);
        return;
      }
    } else {
      console.error(`[S3 Client] Error checking bucket status:`, error);
      return;
    }
  }

  // Set public read bucket policy (for local MinIO, bypassed on R2 in production)
  try {
    console.log(`[S3 Client] Setting public read policy for bucket "${bucketName}"...`);
    const policy = {
      Version: "2012-10-17",
      Statement: [
        {
          Sid: "PublicRead",
          Effect: "Allow",
          Principal: "*",
          Action: ["s3:GetObject"],
          Resource: [`arn:aws:s3:::${bucketName}/*`],
        },
      ],
    };
    
    await s3Client.send(new PutBucketPolicyCommand({
      Bucket: bucketName,
      Policy: JSON.stringify(policy),
    }));
    console.log(`[S3 Client] Public read policy set successfully.`);
  } catch (policyError) {
    console.warn(`[S3 Client] Could not set public read policy (expected if using Cloudflare R2):`, policyError);
  }
}

// Generate a presigned URL for PUT uploads
export async function getPresignedPutUrl(key: string, contentType: string, expiresInSeconds = 3600): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    ContentType: contentType,
  });
  
  return await getSignedUrl(s3Client, command, { expiresIn: expiresInSeconds });
}

// Generate a presigned URL for GET retrieval
export async function getPresignedGetUrl(key: string, expiresInSeconds = 3600): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: bucketName,
    Key: key,
  });
  
  return await getSignedUrl(s3Client, command, { expiresIn: expiresInSeconds });
}

// Helper to get public URL of a file
export function getPublicUrl(key: string): string {
  if (isProduction) {
    const publicDomain = process.env.R2_PUBLIC_DOMAIN;
    if (publicDomain) {
      return `${publicDomain}/${key}`;
    }
    return `${r2Endpoint}/${bucketName}/${key}`;
  } else {
    return `${minioEndpoint}/${bucketName}/${key}`;
  }
}

export { s3Client };
