#!/data/data/com.termux/files/usr/bin/bash
# Station env example (DO NOT commit secrets)
export ENV="termux"
export RUNTIME="station"
export ENGINE="starlette-core"

# Edit mode key for Ops endpoints (header x-edit-key)
export STATION_EDIT_KEY="1234"

# CORS (comma-separated) for Render later:
# export ALLOWED_ORIGINS="https://your-frontend.onrender.com"

# Optional: Render API deploy (can be passed from frontend too)
# export RENDER_API_KEY="..."
# export RENDER_SERVICE_ID="..."
