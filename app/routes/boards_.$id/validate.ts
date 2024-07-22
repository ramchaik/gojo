const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function checkUserAllowedToEnterBoardWithSecretId({
  boardId,
  secretId,
}: {
  boardId: string
  secretId: string
}) {
  const response = await fetch(`${API_BASE_URL}/boards/check-secret`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ boardId, secretId }),
  })

  if (!response.ok) {
    throw new Error('Failed to check if user is allowed to enter board')
  }

  const result = await response.json()
  return result.isAllowed
}
