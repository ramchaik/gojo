const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function createBoard(
  userId: string,
  boardName: string = 'Untitled'
) {
  const response = await fetch(`${API_BASE_URL}/boards`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId, boardName }),
  })

  if (!response.ok) {
    throw new Error('Failed to create board')
  }

  return response.json()
}

export async function getBoardsForUser(userId: string) {
  const response = await fetch(`${API_BASE_URL}/boards?userId=${userId}`)

  if (!response.ok) {
    throw new Error('Failed to fetch boards')
  }

  return response.json()
}
