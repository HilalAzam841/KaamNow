FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

RUN useradd --create-home kaamnow \
    && mkdir -p /var/lib/kaamnow/media /var/lib/kaamnow/private_media \
    && chown -R kaamnow:kaamnow /var/lib/kaamnow /app
USER kaamnow

RUN DJANGO_SECRET_KEY=build-only python manage.py collectstatic --noinput

EXPOSE 8000
# HTTP + WebSockets via Daphne (ASGI). Celery worker/beat use the same image with a different command.
CMD ["sh", "-c", "python manage.py migrate --noinput && daphne -b 0.0.0.0 -p 8000 config.asgi:application"]
