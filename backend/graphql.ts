import { ApolloServer } from "@apollo/server";
import { auth } from "./auth";
import { db } from "./db";
import { user, session, organization, member, movie, invitation } from "./db/schema";
import { count, eq, and } from "drizzle-orm";
import { getPresignedPutUrl, getPublicUrl } from "./s3";

export interface GraphQLContext {
  user: any;
  session: any;
  headers?: any;
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
    activeOrganizationId: String
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

  type OrganizationMember {
    id: ID!
    organizationId: String!
    userId: String!
    role: String!
    createdAt: String!
    user: User!
  }

  type OrganizationInvitation {
    id: ID!
    organizationId: String!
    email: String!
    role: String!
    status: String!
    expiresAt: String!
    createdAt: String!
    inviterId: String!
    inviter: User!
    organization: Organization
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
    bannerUrl: String
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
    
    # Organization Management
    activeOrganizationMembers(organizationId: ID!): [OrganizationMember!]!
    activeOrganizationInvitations(organizationId: ID!): [OrganizationInvitation!]!
    myPendingInvitations: [OrganizationInvitation!]!
  }

  type Mutation {
    createOrganization(name: String!, slug: String!): Organization!
    createMovie(title: String!, genre: String!, director: String!, releaseYear: Int!, description: String, bannerUrl: String): Movie!
    updateMovie(id: ID!, title: String, genre: String, director: String, releaseYear: Int, description: String, bannerUrl: String): Movie!
    deleteMovie(id: ID!): Boolean!
    updateProfileImage(image: String!): User!
    
    # Organization Management
    setActiveOrganization(organizationId: ID!): Session!
    inviteMember(email: String!, role: String!, organizationId: ID!): OrganizationInvitation!
    cancelInvitation(invitationId: ID!): Boolean!
    acceptInvitation(invitationId: ID!): Boolean!
    rejectInvitation(invitationId: ID!): Boolean!
    removeMember(memberId: ID!, organizationId: ID!): Boolean!
    updateMemberRole(memberId: ID!, role: String!, organizationId: ID!): Boolean!
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
    activeOrganizationMembers: async (parent: any, args: { organizationId: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      const userMembership = await db
        .select()
        .from(member)
        .where(and(eq(member.userId, context.user.id), eq(member.organizationId, args.organizationId)))
        .limit(1);

      if (userMembership.length === 0) {
        throw new Error("Forbidden: You are not a member of this organization");
      }

      const members = await db
        .select()
        .from(member)
        .where(eq(member.organizationId, args.organizationId))
        .leftJoin(user, eq(member.userId, user.id));

      return members.map((m) => {
        if (!m.user) {
          throw new Error("User associated with membership not found");
        }
        return {
          id: m.member.id,
          organizationId: m.member.organizationId,
          userId: m.member.userId,
          role: m.member.role,
          createdAt: m.member.createdAt instanceof Date ? m.member.createdAt.toISOString() : m.member.createdAt,
          user: {
            ...m.user,
            createdAt: m.user.createdAt instanceof Date ? m.user.createdAt.toISOString() : m.user.createdAt,
            updatedAt: m.user.updatedAt instanceof Date ? m.user.updatedAt.toISOString() : m.user.updatedAt,
          },
        };
      });
    },
    activeOrganizationInvitations: async (parent: any, args: { organizationId: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      const userMembership = await db
        .select()
        .from(member)
        .where(and(eq(member.userId, context.user.id), eq(member.organizationId, args.organizationId)))
        .limit(1);

      if (userMembership.length === 0) {
        throw new Error("Forbidden: You are not a member of this organization");
      }

      const invites = await db
        .select()
        .from(invitation)
        .where(
          and(
            eq(invitation.organizationId, args.organizationId),
            eq(invitation.status, "pending")
          )
        )
        .leftJoin(user, eq(invitation.inviterId, user.id));

      return invites.map((i) => {
        if (!i.user) {
          throw new Error("Inviter not found");
        }
        return {
          id: i.invitation.id,
          organizationId: i.invitation.organizationId,
          email: i.invitation.email,
          role: i.invitation.role ?? "member",
          status: i.invitation.status,
          expiresAt: i.invitation.expiresAt instanceof Date ? i.invitation.expiresAt.toISOString() : i.invitation.expiresAt,
          createdAt: i.invitation.createdAt instanceof Date ? i.invitation.createdAt.toISOString() : i.invitation.createdAt,
          inviterId: i.invitation.inviterId,
          inviter: {
            ...i.user,
            createdAt: i.user.createdAt instanceof Date ? i.user.createdAt.toISOString() : i.user.createdAt,
            updatedAt: i.user.updatedAt instanceof Date ? i.user.updatedAt.toISOString() : i.user.updatedAt,
          },
        };
      });
    },
    myPendingInvitations: async (parent: any, args: any, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      const invites = await db
        .select()
        .from(invitation)
        .where(and(eq(invitation.email, context.user.email), eq(invitation.status, "pending")))
        .leftJoin(organization, eq(invitation.organizationId, organization.id))
        .leftJoin(user, eq(invitation.inviterId, user.id));

      return invites.map((i) => {
        if (!i.organization) {
          throw new Error("Organization associated with invitation not found");
        }
        if (!i.user) {
          throw new Error("Inviter not found");
        }
        return {
          id: i.invitation.id,
          organizationId: i.invitation.organizationId,
          email: i.invitation.email,
          role: i.invitation.role ?? "member",
          status: i.invitation.status,
          expiresAt: i.invitation.expiresAt instanceof Date ? i.invitation.expiresAt.toISOString() : i.invitation.expiresAt,
          createdAt: i.invitation.createdAt instanceof Date ? i.invitation.createdAt.toISOString() : i.invitation.createdAt,
          inviterId: i.invitation.inviterId,
          inviter: {
            ...i.user,
            createdAt: i.user.createdAt instanceof Date ? i.user.createdAt.toISOString() : i.user.createdAt,
            updatedAt: i.user.updatedAt instanceof Date ? i.user.updatedAt.toISOString() : i.user.updatedAt,
          },
          organization: {
            ...i.organization,
            createdAt: i.organization.createdAt instanceof Date ? i.organization.createdAt.toISOString() : i.organization.createdAt,
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
    setActiveOrganization: async (parent: any, args: { organizationId: string }, context: GraphQLContext) => {
      if (!context.user || !context.session) {
        throw new Error("Unauthorized");
      }

      const userMembership = await db
        .select()
        .from(member)
        .where(and(eq(member.userId, context.user.id), eq(member.organizationId, args.organizationId)))
        .limit(1);

      if (userMembership.length === 0) {
        throw new Error("Forbidden: You are not a member of this organization");
      }

      const updateResult = await db
        .update(session)
        .set({ activeOrganizationId: args.organizationId })
        .where(eq(session.id, context.session.id))
        .returning();

      const updatedSession = updateResult[0];
      if (!updatedSession) {
        throw new Error("Failed to set active organization");
      }

      return {
        ...updatedSession,
        expiresAt: updatedSession.expiresAt instanceof Date ? updatedSession.expiresAt.toISOString() : updatedSession.expiresAt,
        createdAt: updatedSession.createdAt instanceof Date ? updatedSession.createdAt.toISOString() : updatedSession.createdAt,
        updatedAt: updatedSession.updatedAt instanceof Date ? updatedSession.updatedAt.toISOString() : updatedSession.updatedAt,
      };
    },
    inviteMember: async (
      parent: any,
      args: { email: string; role: string; organizationId: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      const res = await (auth.api as any).createInvitation({
        body: {
          email: args.email,
          role: args.role,
          organizationId: args.organizationId,
        },
        headers: context.headers,
      });

      if (!res) {
        throw new Error("Failed to invite member");
      }

      const inviterUser = await db.select().from(user).where(eq(user.id, context.user.id)).limit(1);
      const inviter = inviterUser[0];
      if (!inviter) {
        throw new Error("Inviter not found");
      }

      return {
        id: res.id,
        organizationId: res.organizationId,
        email: res.email,
        role: res.role,
        status: res.status,
        expiresAt: res.expiresAt instanceof Date ? res.expiresAt.toISOString() : res.expiresAt,
        createdAt: res.createdAt instanceof Date ? res.createdAt.toISOString() : res.createdAt,
        inviterId: context.user.id,
        inviter: {
          ...inviter,
          createdAt: inviter.createdAt instanceof Date ? inviter.createdAt.toISOString() : inviter.createdAt,
          updatedAt: inviter.updatedAt instanceof Date ? inviter.updatedAt.toISOString() : inviter.updatedAt,
        },
      };
    },
    cancelInvitation: async (parent: any, args: { invitationId: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      await (auth.api as any).cancelInvitation({
        body: {
          invitationId: args.invitationId,
        },
        headers: context.headers,
      });

      return true;
    },
    acceptInvitation: async (parent: any, args: { invitationId: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      await (auth.api as any).acceptInvitation({
        body: {
          invitationId: args.invitationId,
        },
        headers: context.headers,
      });

      return true;
    },
    rejectInvitation: async (parent: any, args: { invitationId: string }, context: GraphQLContext) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      await (auth.api as any).rejectInvitation({
        body: {
          invitationId: args.invitationId,
        },
        headers: context.headers,
      });

      return true;
    },
    removeMember: async (
      parent: any,
      args: { memberId: string; organizationId: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      await (auth.api as any).removeMember({
        body: {
          memberIdOrEmail: args.memberId,
          organizationId: args.organizationId,
        },
        headers: context.headers,
      });

      return true;
    },
    updateMemberRole: async (
      parent: any,
      args: { memberId: string; role: string; organizationId: string },
      context: GraphQLContext
    ) => {
      if (!context.user) {
        throw new Error("Unauthorized");
      }

      await (auth.api as any).updateMemberRole({
        body: {
          memberId: args.memberId,
          role: args.role,
          organizationId: args.organizationId,
        },
        headers: context.headers,
      });

      return true;
    },
    createMovie: async (
      parent: any,
      args: { title: string; genre: string; director: string; releaseYear: number; description?: string; bannerUrl?: string },
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
        bannerUrl: args.bannerUrl,
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
      args: { id: string; title?: string; genre?: string; director?: string; releaseYear?: number; description?: string; bannerUrl?: string },
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
      if (args.bannerUrl !== undefined) updateData.bannerUrl = args.bannerUrl;

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
