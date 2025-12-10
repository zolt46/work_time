# Dasan Shift Manager

A lightweight shift scheduling and request workflow for the Dasan Information Center library student workers. Frontend is static (for GitHub Pages), backend is FastAPI (Render), database is PostgreSQL (Neon).

## Repository structure
- `/ui`: static frontend (HTML/CSS/JS). Update `ui/js/api.js` to point to your deployed backend URL.
- `/backend`: FastAPI app.
- `/db`: PostgreSQL schema and seeds (Neon-ready).

## Database setup (Neon)
1. Create a new PostgreSQL database instance.
2. Run the schema:
   ```sql
   \i db/schema.sql
   ```
3. Load sample data (optional):
   ```sql
   \i db/seed.sql
   ```

## Backend configuration
Set environment variables on Render or locally:
- `DATABASE_URL` (e.g., `postgresql://user:pass@host:5432/dbname`)
- `JWT_SECRET` (random string)
- `ACCESS_TOKEN_EXPIRE_MINUTES` (optional, default 60)

## Run backend locally
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\\Scripts\\activate
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload
```

## Deploy backend to Render
1. Connect repo to Render, create a Web Service.
2. Build command: `pip install -r backend/requirements.txt`
3. Start command: `uvicorn backend.main:app --host 0.0.0.0 --port $PORT`
4. Set environment variables (`DATABASE_URL`, `JWT_SECRET`).

## Deploy frontend to GitHub Pages
1. Ensure `ui/js/api.js` `API_BASE_URL` matches your Render backend.
2. Publish the `/ui` directory via GitHub Pages (e.g., use `gh-pages` branch or GitHub Actions to copy `/ui`).

## Key API endpoints
- `POST /auth/login` — OAuth2 password flow; returns JWT.
- `GET /auth/me` — current user profile.
- `PATCH /auth/password` — change own password.
- `GET/POST/PATCH/DELETE /users` — user management (role-aware).
- `GET /schedule/global`, `POST /schedule/shifts`, `POST /schedule/assign` — schedule management.
- `POST /requests`, `/requests/pending`, `/requests/{id}/approve|reject` — request workflow.
- `GET /admin/audit-logs` — master-level audit visibility.

## Notes
- Roles: MASTER > OPERATOR > MEMBER. Higher roles can see/do everything below.
- Timezone assumption: Asia/Seoul.
- Seed users: `master/Master123!`, `operator/Operator123!`, members `kim|lee|park/Member123!`.
