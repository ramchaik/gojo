const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function checkUserExists(email: string): Promise<boolean> {
  const response = await fetch(
    `${API_BASE_URL}/users/exists?email=${encodeURIComponent(email)}`,
    {
      method: 'GET',
    }
  )

  if (!response.ok) {
    throw new Error('Failed to check if user exists')
  }

  const result = await response.json()
  return result.exists
}
