FROM python:3.12-alpine

WORKDIR /app
COPY gateway.py .

EXPOSE 11435
ENV RIMGATEWAY_CONFIG=/app/rimtalk-gateway.json
CMD ["python", "-u", "gateway.py"]
