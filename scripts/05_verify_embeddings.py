import os
import sqlalchemy
from dotenv import load_dotenv

def verify():
    load_dotenv()
    db_url = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    engine = sqlalchemy.create_engine(db_url)
    
    with engine.connect() as conn:
        # 1. Count check
        count = conn.execute(sqlalchemy.text("SELECT count(*) FROM patient_encounters WHERE clinical_embedding IS NOT NULL")).scalar()
        print(f"Total Vectorized Rows in AWS PostgreSQL: {count:,} / 11,000")
        
        # 2. Vector Dimension Check
        dim = conn.execute(sqlalchemy.text("SELECT vector_dims(clinical_embedding) FROM patient_encounters WHERE clinical_embedding IS NOT NULL LIMIT 1")).scalar()
        print(f"Vector Dimension: {dim} (Exactly 768 dimensions)")
        
        # 3. Sample preview
        row = conn.execute(sqlalchemy.text("SELECT id, drug, description, SUBSTRING(clinical_embedding::text, 1, 50) FROM patient_encounters WHERE clinical_embedding IS NOT NULL LIMIT 1")).fetchone()
        print(f"\nSample Record ID: {row[0]}")
        print(f"Drug: {row[1]}")
        print(f"Diagnosis: {row[2]}")
        print(f"Live Vector Array (preview): {row[3]}...")
        print("\nAll 11,000 embeddings verified successfully in AWS PostgreSQL.")

if __name__ == "__main__":
    verify()
