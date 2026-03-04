# Multi-stage: build not required for Python deps, but shows pattern
FROM python:3.12-slim AS runtime

WORKDIR /app

# Non-root user
RUN adduser --disabled-password --gecos "" appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && pip freeze > requirements.lock
COPY main.py .

USER appuser
EXPOSE 8080

ENV FLASK_APP=main.py
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080"]
