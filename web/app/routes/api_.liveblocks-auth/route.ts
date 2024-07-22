import { invariant } from '@epic-web/invariant'
import { redirect, type ActionFunctionArgs } from '@vercel/remix'

import { requireAuthCookie } from '~/auth'
import { liveblocks } from '~/helpers/liveblocks'

const API_BASE_URL =
  process.env.BACKEND_API_BASE_URL || 'http://localhost:9000/api/v1'

export const action = async ({ request }: ActionFunctionArgs) => {
  const userId = await requireAuthCookie(request)

  const { room } = await request.json()

  invariant(typeof room === 'string', 'Invalid room')

  // Get Liveblocks session information from the Fastify server
  const sessionResponse = await fetch(`${API_BASE_URL}/liveblocks-session`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ userId, room }),
  })

  if (!sessionResponse.ok) {
    if (sessionResponse.status === 404) {
      // TODO: Toast message
      return redirect('/', { status: 403 })
    }
    throw new Error('Failed to prepare Liveblocks session')
  }

  const sessionData = await sessionResponse.json()

  // Prepare Liveblocks session
  const session = liveblocks.prepareSession(sessionData.user.id, {
    userInfo: {
      email: sessionData.user.email,
      name: sessionData.user.name,
    },
  })

  // Allow access to the room
  session.allow(room, session.FULL_ACCESS)

  // Authorize the user and return the result
  const result = await session.authorize()

  if (result.error) {
    console.error('Liveblocks authentication failed:', result.error)
    return new Response(undefined, { status: 403 })
  }

  return new Response(result.body, { status: result.status })
}
