const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function getUserFromDB(userId: string) {
  const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
    method: 'GET',
  })

  if (!response.ok) {
    throw new Error('Failed to fetch user')
  }

  return response.json()
}

export async function getUserRoleForBoard(userId: string, boardId: string) {
  const response = await fetch(
    `${API_BASE_URL}/boards/${boardId}/roles/${userId}`,
    {
      method: 'GET',
    }
  )

  if (!response.ok) {
    throw new Error('Failed to fetch user role for board')
  }

  return response.json()
}
