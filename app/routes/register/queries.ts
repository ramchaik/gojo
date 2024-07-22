const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export async function createUser({
  email,
  password,
  name,
}: {
  email: string
  name: string
  password: string
}) {
  const response = await fetch(`${API_BASE_URL}/users`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, name }),
  })

  if (!response.ok) {
    throw new Error('Failed to create user')
  }

  const result = await response.json()
  if (!result.success) {
    throw new Error(result.message || 'Failed to create user')
  }

  return result.userId
}
