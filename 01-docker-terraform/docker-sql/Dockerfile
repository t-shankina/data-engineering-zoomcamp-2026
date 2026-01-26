FROM python:3.13.11-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

WORKDIR /hw1

COPY pyproject.toml .python-version uv.lock ./
RUN uv sync --locked

ENV PATH="/hw1/.venv/bin:$PATH"

COPY pipeline.py .

ENTRYPOINT [ "python", "pipeline.py" ]
