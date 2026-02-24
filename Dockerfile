FROM python:3.12-slim
COPY cr.yaml .
EXPOSE 8000
CMD ["python3", "-m" , "http.server"]