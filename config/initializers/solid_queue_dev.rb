# In development, run Solid Queue against the single primary database (production
# uses a dedicated queue database — see config/database.yml). This keeps the
# dev jobs worker (Procfile.dev) simple: one DB, one `bin/jobs` process.
if Rails.env.development?
  Rails.application.config.solid_queue.connects_to = { database: { writing: :primary } }
end
