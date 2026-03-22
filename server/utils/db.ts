import pg from 'pg'

const { Pool } = pg

let pool: pg.Pool | null = null

export function getPool(): pg.Pool {
  if (!pool) {
    const connectionString = process.env.DATABASE_URL

    if (!connectionString) {
      throw new Error('DATABASE_URL environment variable is not set')
    }

    pool = new Pool({
      connectionString,
      // SSL required for most hosted PostgreSQL (Rancher ingress, RDS, etc.)
      ssl: process.env.DATABASE_SSL === 'false'
        ? false
        : { rejectUnauthorized: process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false' },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    })

    pool.on('error', (err) => {
      console.error('Unexpected error on idle PostgreSQL client', err)
    })
  }

  return pool
}

/**
 * Execute a parameterized query against the pool.
 * Usage: query('SELECT * FROM employees WHERE id = $1', [id])
 */
export async function query<T = Record<string, unknown>>(
  text: string,
  params?: unknown[]
): Promise<pg.QueryResult<T>> {
  const client = getPool()
  return client.query<T>(text, params)
}

/**
 * Execute multiple queries in a single transaction.
 * Automatically rolls back on error.
 */
export async function transaction<T>(
  fn: (client: pg.PoolClient) => Promise<T>
): Promise<T> {
  const client = await getPool().connect()
  try {
    await client.query('BEGIN')
    const result = await fn(client)
    await client.query('COMMIT')
    return result
  } catch (err) {
    await client.query('ROLLBACK')
    throw err
  } finally {
    client.release()
  }
}
