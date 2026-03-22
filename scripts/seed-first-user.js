/**
 * Seed the first super admin user (for fresh database).
 * Run: node scripts/seed-first-user.js
 *
 * Uses DATABASE_URL from env, or defaults to localhost for Docker.
 */

import pg from 'pg'
import bcrypt from 'bcryptjs'

const DATABASE_URL =
  process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/scheduling'

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com'
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123'
const ADMIN_NAME = process.env.ADMIN_NAME || 'Admin User'

async function main() {
  const client = new pg.Client({
    connectionString: DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'false' || DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false },
  })

  await client.connect()

  try {
    // 1. Create a team
    const teamResult = await client.query(
      `INSERT INTO teams (name) VALUES ('Default Team') RETURNING id, name`
    )
    const team = teamResult.rows[0]
    console.log('Created team:', team.name, '(' + team.id + ')')

    // 2. Create super admin user
    const username = ADMIN_EMAIL.split('@')[0]
    const passwordHash = bcrypt.hashSync(ADMIN_PASSWORD, 10)

    await client.query(
      `INSERT INTO user_profiles (username, email, password_hash, full_name, team_id, is_super_admin)
       VALUES ($1, $2, $3, $4, $5, true)`,
      [username, ADMIN_EMAIL, passwordHash, ADMIN_NAME, team.id]
    )

    console.log('\n✅ First user created successfully!\n')
    console.log('  Email:    ', ADMIN_EMAIL)
    console.log('  Password: ', ADMIN_PASSWORD)
    console.log('\n  Open http://localhost:3000 and log in.\n')
  } catch (err) {
    if (err.code === '23505') {
      console.log('A user with that email already exists. Skipping seed.')
    } else {
      throw err
    }
  } finally {
    await client.end()
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
