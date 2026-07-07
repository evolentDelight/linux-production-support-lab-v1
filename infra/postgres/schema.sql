CREATE TABLE IF NOT EXISTS support_tickets (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'medium',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO support_tickets (title, status, priority)
VALUES
  ('Investigate intermittent health check failure', 'open', 'high'),
  ('Review application log rotation policy', 'open', 'medium'),
  ('Document database restore procedure', 'open', 'medium')
ON CONFLICT DO NOTHING;