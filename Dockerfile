FROM python:3.12-alpine

WORKDIR /app
COPY rimtalk-gateway.py rimtalk-gateway.json ./

EXPOSE 11435
CMD ["python", "-u", "rimtalk-gateway.py"]
