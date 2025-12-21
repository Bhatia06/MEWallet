# Backend Setup Guide

## Step 1: Install Python Dependencies

```powershell
# Navigate to backend directory
cd backend

# Create virtual environment (if not already created)
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate

# Install all dependencies
pip install -r requirements.txt
```

## Step 2: Configure Environment Variables

1. Copy the example environment file:
```powershell
Copy-Item .env.example .env
```

2. Open `.env` file and fill in your credentials:

```env
# Get these from your Supabase project dashboard
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# Generate a secret key (run this in PowerShell):
# python -c "import secrets; print(secrets.token_hex(32))"
SECRET_KEY=your-generated-secret-key-here

ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

## Step 3: Set Up Supabase Database

1. Go to your Supabase project: https://supabase.com/dashboard
2. Navigate to SQL Editor
3. Copy the contents of `schema.sql`
4. Paste and run the SQL commands
5. Verify tables are created in Table Editor

### Disable Row Level Security (RLS) for Development

In Supabase SQL Editor, run:
```sql
ALTER TABLE merchants DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_user_links DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
```

**Note:** For production, implement proper RLS policies.

## Step 4: Test the Backend

```powershell
# Start the server
python main.py
```

You should see:
```
🚀 MEWallet API is starting...
✅ Database connection successful
INFO:     Uvicorn running on http://0.0.0.0:8000
```

## Step 5: Test API

Open your browser and go to:
- http://localhost:8000 - Basic info
- http://localhost:8000/docs - Swagger API documentation
- http://localhost:8000/health - Health check

## Common Issues

### Issue: ModuleNotFoundError
**Solution:** Make sure virtual environment is activated and dependencies are installed

### Issue: Database connection failed
**Solution:** 
- Check SUPABASE_URL and SUPABASE_ANON_KEY in .env
- Ensure your Supabase project is active
- Verify you're using the correct URL (not the project dashboard URL)

### Issue: Tables not found
**Solution:** Run the schema.sql in Supabase SQL Editor

## Getting Supabase Credentials

1. Go to https://supabase.com/dashboard
2. Select your project (or create a new one)
3. Go to Project Settings (gear icon) > API
4. Copy:
   - Project URL → SUPABASE_URL
   - anon public → SUPABASE_ANON_KEY

## API Testing with Swagger

1. Go to http://localhost:8000/docs
2. Test `/merchant/register`:
   ```json
   {
     "store_name": "Test Store",
     "phone": "1234567890",
     "password": "password123"
   }
   ```
3. You should receive a merchant_id and access_token

## Running in Production

For production deployment:
```powershell
# Install gunicorn (for production)
pip install gunicorn

# Run with gunicorn
gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## Environment Variables Explanation

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Public anonymous key for Supabase
- `SECRET_KEY`: Used for JWT token encryption (keep this secret!)
- `ALGORITHM`: JWT algorithm (default: HS256)
- `ACCESS_TOKEN_EXPIRE_MINUTES`: Token expiration time (default: 30 minutes)
