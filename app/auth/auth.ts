import type { LoaderFunctionArgs } from '@vercel/remix'
import { createCookie, redirect } from '@vercel/remix'
import { env } from '~/helpers/env'

let secret = env.COOKIE_SECRET || 'default'
if (secret === 'default') {
  console.warn(
    '🚨 No COOKIE_SECRET environment variable set, using default. The app is insecure in production.'
  )
  secret = 'default-secret'
}

const authCookie = createCookie('auth', {
  secrets: [secret],
  // 30 days
  maxAge: 30 * 24 * 60 * 60,
  httpOnly: true,
  secure: env.NODE_ENV === 'production',
  sameSite: 'lax',
})

export async function setAuthOnResponse(
  response: Response,
  userId: string
): Promise<Response> {
  let header = await authCookie.serialize(userId)
  response.headers.append('Set-Cookie', header)
  return response
}

export async function getAuthFromRequest(
  request: Request
): Promise<string | null> {
  let userId = await authCookie.parse(request.headers.get('Cookie'))
  return userId ?? null
}

export async function requireAuthCookie(request: Request) {
  let userId = await getAuthFromRequest(request)
  if (!userId) {
    throw redirect('/login', {
      headers: {
        'Set-Cookie': await authCookie.serialize('', {
          maxAge: 0,
        }),
      },
    })
  }
  return userId
}

export async function redirectWithClearedCookie(): Promise<Response> {
  return redirect('/', {
    headers: {
      'Set-Cookie': await authCookie.serialize(null, {
        expires: new Date(0),
      }),
    },
  })
}

export async function redirectIfLoggedInLoader({
  request,
}: LoaderFunctionArgs) {
  let userId = await getAuthFromRequest(request)

  if (userId) {
    throw redirect('/boards')
  }

  return null
}

export async function redirectFromRoot({ request }: LoaderFunctionArgs) {
  let userId = await getAuthFromRequest(request)

  if (userId) {
    throw redirect('/boards')
  } else {
    throw redirect('/login')
  }
}
