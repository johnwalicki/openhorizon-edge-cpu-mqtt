FROM python:3.7-slim as build
LABEL stage=builder

COPY messaging.pem .
COPY psutil2mqtt.py .

## Deployment container
FROM python:3.7-slim
RUN mkdir -p /app && \
    pip install --trusted-host=pypi.python.org \
    --trusted-host=pypi.org \
    --trusted-host=files.pythonhosted.org \
    paho-mqtt psutil
COPY --from=build / /app
WORKDIR /app
CMD [ "python3", "-u", "psutil2mqtt.py"]
