const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function updateBoardLastOpenedAt(boardId: string) {
  const response = await fetch(
    `${API_BASE_URL}/boards/${boardId}/last-opened`,
    {
      method: 'PATCH',
    }
  )

  if (!response.ok) {
    throw new Error('Failed to update board last opened at')
  }
}

export async function updateBoardName({
  boardId,
  newBoardName,
}: {
  boardId: string
  newBoardName: string
}) {
  const response = await fetch(`${API_BASE_URL}/boards/${boardId}/name`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ newBoardName }),
  })

  if (!response.ok) {
    throw new Error('Failed to update board name')
  }
}

export async function upsertUserBoardRole({
  userId,
  boardId,
}: {
  userId: string
  boardId: string
}) {
  const response = await fetch(`${API_BASE_URL}/board-roles`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId, boardId }),
  })

  if (!response.ok) {
    throw new Error('Failed to upsert user board role')
  }
}
