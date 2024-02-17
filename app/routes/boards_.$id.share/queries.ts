import { prisma } from "~/db";

export async function addNewBoardMember({
  email,
  boardId,
}: {
  email: string;
  boardId: string;
}) {
  const user = await prisma.user.findUnique({
    where: {
      email,
    },
  });

  if (!user) {
    return { success: false, message: "User not found." };
  }

  await prisma.boardRole.create({
    data: {
      role: "editor",
      userId: user.id,
      boardId,
    },
  });

  return { success: true, message: `User "${email}" added to board.` };
}

export async function getAllBoardRoles(boardId: string) {
  const result = await prisma.boardRole.findMany({
    where: {
      boardId,
    },
    include: {
      user: true,
    },
  });

  // we need email, name, role and boardrole id

  const boardRoles = result.map((boardRole) => {
    return {
      email: boardRole.user.email,
      name: boardRole.user.name,
      role: boardRole.role,
      boardRoleId: boardRole.id,
    };
  });

  return boardRoles;
}