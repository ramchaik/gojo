const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function checkIsUserOwnerOfBoard({
  userId,
  boardId,
}: {
  userId: string
  boardId: string
}) {
  const response = await fetch(
    `${API_BASE_URL}/boards/${boardId}/owner/${userId}`,
    {
      method: 'GET',
    }
  )

  if (!response.ok) {
    throw new Error('Failed to check if user is owner of board')
  }

  const result = await response.json()
  return result.isOwner
}

export async function deleteBoard(boardId: string) {
  const response = await fetch(`${API_BASE_URL}/boards/${boardId}`, {
    method: 'DELETE',
  })

  if (!response.ok) {
    throw new Error('Failed to delete board')
  }

  return response.json()
}
