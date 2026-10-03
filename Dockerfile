# Return Pulse: one container serves the API and Neha's dashboard.
# Hugging Face Spaces (Docker SDK) expects the app on port 7860 and a user with uid 1000.
FROM python:3.11-slim

RUN useradd -m -u 1000 user
USER user
ENV PATH="/home/user/.local/bin:$PATH" PYTHONUNBUFFERED=1 DATA_DIR=/home/user/data
WORKDIR /home/user/app

# Requirements first, so code changes don't reinstall packages.
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

COPY --chown=user . .
ARG BUILD_SHA=local
ENV BUILD_SHA=${BUILD_SHA}

EXPOSE 7860
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:7860/health').status==200 else 1)"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
