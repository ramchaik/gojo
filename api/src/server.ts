import crypto from "crypto";

import { PrismaClient } from "@prisma/client";
import Fastify from "fastify";

const prisma = new PrismaClient();
const fastify = Fastify({ logger: true });

// User route
fastify.get("/api/v1/users/:userId", async (request, reply) => {
  const { userId } = request.params as { userId: string };

  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    return reply.status(404).send({ error: "User not found" });
  }

  return user;
});

// Board role route
fastify.get("/apii/v1/board-roles", async (request, reply) => {
  const { userId, boardId } = request.query as {
    userId: string;
    boardId: string;
  };

  const boardRole = await prisma.boardRole.findUnique({
    where: {
      boardId_userId: {
        boardId,
        userId,
      },
    },
  });

  if (!boardRole) {
    return reply.status(404).send({ error: "Board role not found" });
  }

  return boardRole;
});

// Liveblocks session preparation route
fastify.post("/api/v1/liveblocks-session", async (request, reply) => {
  const { userId, room } = request.body as { userId: string; room: string };

  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    return reply.status(404).send({ error: "User not found" });
  }

  const boardRole = await prisma.boardRole.findUnique({
    where: {
      boardId_userId: {
        boardId: room,
        userId,
      },
    },
  });

  if (!boardRole) {
    return reply.status(404).send({ error: "Board role not found" });
  }

  // Return user and board role information
  return {
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
    },
    boardRole: {
      role: boardRole.role,
    },
  };
});

fastify.post("/api/v1/boards", async (request, reply) => {
  const { userId, boardName = "Untitled" } = request.body as {
    userId: string;
    boardName?: string;
  };

  const board = await prisma.board.create({
    data: { name: boardName },
  });

  if (!board) {
    return reply.status(500).send({ error: "Failed to create board" });
  }

  await prisma.boardRole.create({
    data: {
      role: "Owner",
      boardId: board.id,
      userId: userId,
    },
  });

  return board;
});

// Get boards for user route
fastify.get("/api/v1/boards", async (request, reply) => {
  const { userId } = request.query as { userId: string };

  const result = await prisma.boardRole.findMany({
    where: { userId },
    include: { board: true },
  });

  return result.map(({ board }: { board: any }) => ({
    ...board,
    lastOpenedAt: board.lastOpenedAt?.toLocaleDateString() ?? null,
  }));
});

// Update board last opened at
fastify.patch("/api/v1/boards/:boardId/last-opened", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };

  await prisma.board.update({
    where: { id: boardId },
    data: { lastOpenedAt: new Date() },
  });

  return { success: true };
});

// Update board name
fastify.patch("/api/v1/boards/:boardId/name", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };
  const { newBoardName } = request.body as { newBoardName: string };

  await prisma.board.update({
    where: { id: boardId },
    data: { name: newBoardName },
  });

  return { success: true };
});

// Upsert user board role
fastify.post("/api/v1/board-roles", async (request, reply) => {
  const { userId, boardId } = request.body as {
    userId: string;
    boardId: string;
  };

  await prisma.boardRole.upsert({
    where: {
      boardId_userId: { boardId, userId },
    },
    update: {},
    create: {
      boardId,
      userId,
      role: "Editor",
    },
  });

  return { success: true };
});

// Check if user is allowed to enter board with secret ID
fastify.post("/api/v1/boards/check-secret", async (request, reply) => {
  const { boardId, secretId } = request.body as {
    boardId: string;
    secretId: string;
  };

  const board = await prisma.board.findUnique({
    where: { id: boardId },
  });

  if (!board) {
    return reply.status(404).send({ error: "Board not found" });
  }

  return { isAllowed: board.secretId === secretId };
});

// Check if user is owner of board
fastify.get("/api/v1/boards/:boardId/owner/:userId", async (request, reply) => {
  const { userId, boardId } = request.params as {
    userId: string;
    boardId: string;
  };

  const boardRole = await prisma.boardRole.findUnique({
    where: {
      boardId_userId: {
        boardId,
        userId,
      },
    },
  });

  return { isOwner: boardRole?.role === "Owner" };
});

// Delete board
fastify.delete("/api/v1/boards/:boardId", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };

  const deletedBoard = await prisma.board.delete({
    where: { id: boardId },
  });

  return deletedBoard;
});

// Add new board member
fastify.post("/api/v1/boards/:boardId/members", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };
  const { email } = request.body as { email: string };

  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user) {
    return reply
      .status(404)
      .send({ success: false, message: "User not found." });
  }

  await prisma.boardRole.create({
    data: {
      role: "Editor",
      userId: user.id,
      boardId,
    },
  });

  return { success: true, message: `User "${email}" added to board.` };
});

// Get all board roles
fastify.get("/api/v1/boards/:boardId/roles", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };

  const result = await prisma.boardRole.findMany({
    where: { boardId },
    include: { user: true },
    orderBy: { addedAt: "asc" },
  });

  const boardRoles = result.map((boardRole: any) => ({
    email: boardRole.user.email,
    name: boardRole.user.name,
    role: boardRole.role,
    boardRoleId: boardRole.id,
    addedAt: boardRole.addedAt,
  }));

  return boardRoles;
});

// Get board by ID
fastify.get("/api/v1/boards/:boardId", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };

  const board = await prisma.board.findUnique({
    where: { id: boardId },
  });

  if (!board) {
    return reply.status(404).send({ error: "Board not found" });
  }

  return board;
});

// User login
fastify.post("/api/v1/login", async (request, reply) => {
  const { email, password } = request.body as {
    email: string;
    password: string;
  };

  const user = await prisma.user.findUnique({
    where: { email: email },
    include: { Password: true },
  });

  if (!user || !user.Password) {
    return reply
      .status(401)
      .send({ success: false, message: "Invalid credentials" });
  }

  const hash = crypto
    .pbkdf2Sync(password, user.Password.salt, 1000, 64, "sha256")
    .toString("hex");

  if (hash !== user.Password.hash) {
    return reply
      .status(401)
      .send({ success: false, message: "Invalid credentials" });
  }

  return { success: true, userId: user.id };
});

// Create user
fastify.post("/api/v1/users", async (request, reply) => {
  const { email, password, name } = request.body as {
    email: string;
    password: string;
    name: string;
  };

  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto
    .pbkdf2Sync(password, salt, 1000, 64, "sha256")
    .toString("hex");

  try {
    const user = await prisma.user.create({
      data: {
        email,
        name,
        Password: {
          create: {
            hash,
            salt,
          },
        },
      },
    });

    return { success: true, userId: user.id };
  } catch (error) {
    console.error("Error creating user:", error);
    return reply
      .status(500)
      .send({ success: false, message: "Failed to create user" });
  }
});

fastify.get("/api/v1/users/exists", async (request, reply) => {
  const { email } = request.query as { email: string };

  const user = await prisma.user.findUnique({
    where: { email },
  });

  return { exists: user !== null };
});

// Check if user is allowed to edit board
fastify.get("/api/v1/boards/:boardId/can-edit", async (request, reply) => {
  const { boardId } = request.params as { boardId: string };
  const { userId } = request.query as { userId: string };

  const result = await prisma.boardRole.findUnique({
    where: {
      boardId_userId: {
        userId,
        boardId,
      },
    },
    select: {
      role: true,
    },
  });

  // We currently only support two roles: "owner" and "editor"
  // Editors also have full access, so no need for further checking
  const canEdit = result !== null && result.role !== null;

  return { canEdit };
});

// Get user role for board
fastify.get("/api/v1/boards/:boardId/roles/:userId", async (request, reply) => {
  const { boardId, userId } = request.params as {
    boardId: string;
    userId: string;
  };

  const boardRole = await prisma.boardRole.findUnique({
    where: {
      boardId_userId: {
        boardId,
        userId,
      },
    },
  });

  if (!boardRole) {
    return reply.status(404).send({ error: "Board role not found" });
  }

  return boardRole;
});

const start = async () => {
  try {
    const PORT = process.env.PORT || "9000";
    await fastify.listen({
      port: parseInt(PORT, 10),
      host: "0.0.0.0",
    });
    console.log(`Server is running at http://0.0.0.0:${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
