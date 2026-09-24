/**
 * Whether the database setup that runs at startup (server/plugins/bootstrap.ts)
 * has finished.
 *
 * Nitro starts answering requests without waiting for that plugin. Before this
 * existed, a request that arrived while the tables were still being created — or
 * after setup had failed because the database was not up yet — ran against a
 * database with no tables: `relation "pto_days" does not exist`, seen at work in
 * Sep 2026 from the kiosk's 2-minute refresh.
 */
export const startup = {
  ready: false,
  /** Why setup failed, when it did. Only under `npm run dev`: a built app exits instead. */
  failure: null as string | null,
}
