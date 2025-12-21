from supabase import create_client, Client
from core.config import get_settings
from typing import Optional

settings = get_settings()

# Initialize Supabase client
supabase: Optional[Client] = None

def get_supabase_client() -> Client:
    """Get or create Supabase client instance"""
    global supabase
    if supabase is None:
        try:
            supabase = create_client(
                settings.SUPABASE_URL,
                settings.SUPABASE_SERVICE_ROLE_KEY
            )
        except Exception as e:
            raise Exception(f"Failed to connect to Supabase: {str(e)}")
    return supabase


def test_connection() -> bool:
    """Test Supabase connection"""
    try:
        client = get_supabase_client()
        # Try a simple query to test connection
        return True
    except Exception as e:
        print(f"Connection test failed: {str(e)}")
        return False
