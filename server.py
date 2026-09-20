import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests

app = FastAPI()

# Recupera a chave API definida no ambiente Linux
API_KEY = os.getenv("API_KEY")

class PromptRequest(BaseModel):
    prompt: str

@app.post("/generate")
def generate_text(data: PromptRequest):
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Chave API não configurada no servidor.")
    
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={API_KEY}"
    payload = {"contents": [{"parts": [{"text": data.prompt}]}]}
    
    response = requests.post(url, json=payload)
    return response.json()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
