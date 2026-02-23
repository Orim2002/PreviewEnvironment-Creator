FROM python:3.12-slim
COPY test.py .
CMD ["python3", "test.py"]