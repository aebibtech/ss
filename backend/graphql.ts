import { ApolloServer } from "@apollo/server";
import { auth } from "./auth";
import { db } from "./db";
import { user, session, organization, member, movie } from "./db/schema";
import { count, eq } from "drizzle-orm";
import { getPresignedPutUrl, getPublicUrl } from "./s3";

export interface GraphQLContext {
  user: any;
  session: any;
}

export const typeDefs = `#graphql
  type User {
    id: ID!
    name: String!
    email: String!
    emailVerified: Boolean!
    image: String
    role: String
    createdAt: String!
    updatedAt: String!
  }

  type Session {
    id: ID!
    userId: String!
    expiresAt: String!
    token: String!
    ipAddress: String
    userAgent: String
    createdAt: String!
    updatedAt: String!
  }

  type MePayload {
    user: User!
    session: Session!
  }

  type Organization {
    id: ID!
    name: String!
    slug: String!
    logo: String
    createdAt: String!
  }

  type UserOrganization {
    id: ID!
    organizationId: String!
    userId: String!
    role: String!
    createdAt: String!
    organization: Organization!
  }

  type AdminStats {
    totalUsers: Int!
    activeSessions: Int!
    totalOrganizations: Int!
  }

  type Movie {
    id: ID!
    title: String!
    genre: String!
    director: String!
    releaseYear: Int!
    description: String
    userId: String!
    createdAt: String!
    updatedAt: String!
  }

  type PresignedUrlPayload {
    uploadUrl: String!
    publicUrl: String!
    key: String!
  }

  type Query {
    me: MePayload
    organizations: [UserOrganization!]!
    adminStats: AdminStats!
    movies: [Movie!]!
    movie(id: ID!): Movie
    presignedUploadUrl(fileName: String!, contentType: String!): PresignedUrlPayload!
  }

  type Mutation {
    createOrganization(name: String!, slug: String!): Organization!
    createMovie(title: String!, genre: String!, director: String!, releaseYear: Int!, description: String): Movie!
    updateMovie(id: ID!, title: String, genre: String, director: String, releaseYear: Int, description: String): Movie!
    deleteMovie(id: ID!): Boolean!
    updateProfileImage(image: String!): User!
  }
`;

const mapMovie = (m: any) => {
  return {
    ...m,
    createdAt: m.createdAt instanceof Date ? m.createdAt.toISOString() : m.createdAt,
    updatedAt: m.updatedAt instanceof Date ? m.updatedAt.toISOString() : m.updatedAt,
  };
};

export const resolvers = {
  Query: {
    presignedUploadUrl: async (
      parent: any,
      args: { fileName: string; contentType: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      
      const fileExtension = args.fileName.split(".").pop();
      const uuid = crypto.randomUUID();
      const key = `${context.user.id}/${uuid}.${fileExtension}`;
      
      try {
        const uploadUrl = await getPresignedPutUrl(key, args.contentType);
        const publicUrl = getPublicUrl(key);
        return {
          uploadUrl,
          publicUrl,
          key,
        };
      } catch (error) {
        console.error("Error generating presigned upload URL:", error);
        throw new Error("Failed to generate presigned upload URL");
      }
    },
    me: async (parent: any, args: any, context: GraphQLContext) => {
      if (!context.user || !context.session) {
        return null;
      }
      return {
        user: {
          ...context.user,
          createdAt: context.user.createdAt instanceof Date ? context.user.createdAt.toISOString() : context.user.createdAt,
          updatedAt: context.user.updatedAt instanceof Date ? context.user.updatedAt.toISOString() : context.user.updatedAt,
        },
        session: {
          ...context.session,
          expiresAt: context.session.expiresAt instanceof Date ? context.session.expiresAt.toISOString() : context.session.expiresAt,
          createdAt: context.session.createdAt instanceof Date ? context.session.createdAt.toISOString() : context.session.createdAt,
          updatedAt: context.session.updatedAt instanceof Date ? context.session.updatedAt.toISOString() : context.session.updatedAt,
        },
      };
    },
    organizations: async (parent: any, args: any, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      
      const userMemberships = await db
        .select()
        .from(member)
        .where(eq(member.userId, context.user.id))
        .leftJoin(organization, eq(member.organizationId, organization.id));

      return userMemberships.map((m) => {
        if (!m.organization) {
          throw new Error("Associated organization not found");
        }
        return {
          id: m.member.id,
          organizationId: m.member.organizationId,
          userId: m.member.userId,
          role: m.member.role,
          createdAt: m.member.createdAt instanceof Date ? m.member.createdAt.toISOString() : m.member.createdAt,
          organization: {
            ...m.organization,
            createdAt: m.organization.createdAt instanceof Date ? m.organization.createdAt.toISOString() : m.organization.createdAt,
          },
        };
      });
    },
    adminStats: async (parent: any, args: any, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      
      if (context.user.role !== "admin") {
        throw new Error("Forbidden: Admin access required");
      }

      const usersCount = await db.select({ count: count() }).from(user);
      const sessionsCount = await db.select({ count: count() }).from(session);
      const orgsCount = await db.select({ count: count() }).from(organization);

      return {
        totalUsers: usersCount[0]?.count ?? 0,
        activeSessions: sessionsCount[0]?.count ?? 0,
        totalOrganizations: orgsCount[0]?.count ?? 0,
      };
    },
    movies: async (parent: any, args: any, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      const results = await db
        .select()
        .from(movie)
        .where(eq(movie.userId, context.user.id));
      return results.map(mapMovie);
    },
    movie: async (parent: any, args: { id: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      const results = await db
        .select()
        .from(movie)
        .where(eq(movie.id, args.id));
      const m = results[0];
      if (!m) return null;
      if (m.userId !== context.user.id) {
        throw new Error("Forbidden");
      }
      return mapMovie(m);
    },
  },
  Mutation: {
    createOrganization: async (parent: any, args: { name: string; slug: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      const org = await auth.api.createOrganization({
        body: {
          name: args.name,
          slug: args.slug,
          userId: context.user.id,
        },
      });

      if (!org) {
        throw new Error("Failed to create organization");
      }

      return {
        ...org,
        createdAt: org.createdAt instanceof Date ? org.createdAt.toISOString() : org.createdAt,
      };
    },
    createMovie: async (
      parent: any,
      args: { title: string; genre: string; director: string; releaseYear: number; description?: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      const id = crypto.randomUUID();
      const insertResult = await db.insert(movie).values({
        id,
        title: args.title,
        genre: args.genre,
        director: args.director,
        releaseYear: args.releaseYear,
        description: args.description,
        userId: context.user.id,
      }).returning();
      const created = insertResult[0];
      if (!created) {
        throw new Error("Failed to create movie");
      }
      return mapMovie(created);
    },
    updateMovie: async (
      parent: any,
      args: { id: string; title?: string; genre?: string; director?: string; releaseYear?: number; description?: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      // Check ownership
      const existing = await db.select().from(movie).where(eq(movie.id, args.id));
      if (!existing[0]) {
        throw new Error("Movie not found");
      }
      if (existing[0].userId !== context.user.id) {
        throw new Error("Forbidden");
      }

      const updateData: any = {};
      if (args.title !== undefined) updateData.title = args.title;
      if (args.genre !== undefined) updateData.genre = args.genre;
      if (args.director !== undefined) updateData.director = args.director;
      if (args.releaseYear !== undefined) updateData.releaseYear = args.releaseYear;
      if (args.description !== undefined) updateData.description = args.description;

      const updateResult = await db
        .update(movie)
        .set(updateData)
        .where(eq(movie.id, args.id))
        .returning();
      
      const updated = updateResult[0];
      if (!updated) {
        throw new Error("Failed to update movie");
      }
      return mapMovie(updated);
    },
    deleteMovie: async (parent: any, args: { id: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      // Check ownership
      const existing = await db.select().from(movie).where(eq(movie.id, args.id));
      if (!existing[0]) {
        throw new Error("Movie not found");
      }
      if (existing[0].userId !== context.user.id) {
        throw new Error("Forbidden");
      }

      const deleteResult = await db.delete(movie).where(eq(movie.id, args.id)).returning();
      return deleteResult.length > 0;
    },
    updateProfileImage: async (parent: any, args: { image: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }
      
      const updateResult = await db
        .update(user)
        .set({ image: args.image })
        .where(eq(user.id, context.user.id))
        .returning();
        
      const updatedUser = updateResult[0];
      if (!updatedUser) {
        throw new Error("Failed to update user image");
      }
      
      return {
        ...updatedUser,
        createdAt: updatedUser.createdAt instanceof Date ? updatedUser.createdAt.toISOString() : updatedUser.createdAt,
        updatedAt: updatedUser.updatedAt instanceof Date ? updatedUser.updatedAt.toISOString() : updatedUser.updatedAt,
      };
    },
  },
};

export const createGraphQLServer = () => {
  return new ApolloServer<GraphQLContext>({
    typeDefs,
    resolvers,
  });
};
