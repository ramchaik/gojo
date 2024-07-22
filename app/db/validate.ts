const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function checkUserAllowedToEditBoard({
  userId,
  boardId,
}: {
  userId: string
  boardId: string
}) {
  const response = await fetch(
    `${API_BASE_URL}/boards/${boardId}/can-edit?userId=${userId}`,
    {
      method: 'GET',
    }
  )

  if (!response.ok) {
    throw new Error('Failed to check if user is allowed to edit board')
  }

  const result = await response.json()
  return result.canEdit
}
