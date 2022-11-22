FROM python:3.11 as build
LABEL stage=builder

RUN apt update && apt install -y --no-install-recommends gcc build-essential python3-dev

RUN mkdir -p /app

RUN python -m venv /app
# Make sure we use the virtualenv:
ENV PATH="/app/bin:$PATH"
RUN pip install --trusted-host=pypi.python.org \
    --trusted-host=pypi.org \
    --trusted-host=files.pythonhosted.org \
    psutil paho-mqtt

COPY messaging.pem /app/
COPY psutil2mqtt.py /app/

## Deployment container
FROM python:3.11-slim

RUN mkdir -p /app
ENV PATH="/app/bin:$PATH"
COPY --from=build /app /app
WORKDIR /app
CMD [ "python3", "-u", "psutil2mqtt.py"]
