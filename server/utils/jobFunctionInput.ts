import { query } from './db'

/**
 * Shared rules for creating and editing a job function (server/api/job-functions/*):
 * database errors said in words, and the one deactivation that is refused.
 */

const CHECK_MESSAGES: Record<string, string> = {
  check_job_function_name_length: 'The name can be at most 100 characters.',
  check_job_function_name_not_empty: 'The job function needs a name.',
  check_job_function_max_headcount: '"Max people at once" must be 0 or more (or blank for no limit).',
  check_job_function_staffing_priority: 'Staffing priority must be between 1 and 5.',
  check_job_function_color_format: 'Pick a colour.',
  check_job_function_training_target: 'Training target must be a whole number, 0 or more.',
}

/**
 * Turn a constraint violation into a 4xx the form can show; rethrow anything else.
 * A duplicate name is usually someone re-creating a job they deactivated, so say so.
 */
export async function rethrowJobFunctionError(e: any, name: string, teamId: string): Promise<never> {
  if (e?.code === '23505') {
    const existing = (await query<{ is_active: boolean }>(
      'SELECT is_active FROM job_functions WHERE name = $1 AND team_id = $2',
      [name, teamId]
    )).rows[0]
    throw createError({
      statusCode: 409,
      message: existing && !existing.is_active
        ? `An inactive job function named "${name}" already exists. Reactivate it instead of adding a new one.`
        : `A job function named "${name}" already exists.`,
    })
  }
  if (e?.code === '23514' && CHECK_MESSAGES[e.constraint]) {
    throw createError({ statusCode: 400, message: CHECK_MESSAGES[e.constraint] })
  }
  // A number too big for its column ("Max people at once" = 99999999999).
  if (e?.code === '22003') throw createError({ statusCode: 400, message: 'One of the numbers is too large.' })
  // Text where a number belongs (a caller other than the form).
  if (e?.code === '22P02') throw createError({ statusCode: 400, message: "One of the numbers isn't a number." })
  throw e
}

/**
 * Refuse to deactivate a parent job ("Meter") while its numbered children
 * ("Meter 1", "Meter 2", …) are active: the children take their staffing targets and
 * training from the parent, so the builder would silently lose all of that demand.
 */
export async function assertCanDeactivate(name: string, teamId: string): Promise<void> {
  const childName = new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} \\d+$`)
  const children = (await query<{ name: string }>(
    'SELECT name FROM job_functions WHERE team_id = $1 AND is_active',
    [teamId]
  )).rows
    .map((r) => r.name)
    .filter((n) => childName.test(n))
    .sort((a, b) => a.length - b.length || a.localeCompare(b))
  if (children.length) {
    const shown = children.length > 3 ? `${children.slice(0, 3).join(', ')} and ${children.length - 3} more` : children.join(', ')
    throw createError({
      statusCode: 409,
      message: `${shown} ${children.length === 1 ? 'is' : 'are'} still active and ${children.length === 1 ? 'gets its' : 'get their'} targets and training from ${name}. Deactivate ${children.length === 1 ? 'it' : 'them'} first.`,
    })
  }
}
