const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function addNewBoardMember({
  email,
  boardId,
}: {
  email: string
  boardId: string
}) {
  const response = await fetch(`${API_BASE_URL}/boards/${boardId}/members`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  })

  if (!response.ok) {
    throw new Error('Failed to add new board member')
  }

  return response.json()
}

export async function getAllBoardRoles(boardId: string) {
  const response = await fetch(`${API_BASE_URL}/boards/${boardId}/roles`, {
    method: 'GET',
  })

  if (!response.ok) {
    throw new Error('Failed to get board roles')
  }

  return response.json()
}

export async function getBoardById(boardId: string) {
  const response = await fetch(`${API_BASE_URL}/boards/${boardId}`, {
    method: 'GET',
  })

  if (!response.ok) {
    throw new Error('Failed to get board')
  }

  return response.json()
}
