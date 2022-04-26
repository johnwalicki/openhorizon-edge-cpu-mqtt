import time
import sys
import psutil
import json
import os
import ssl
import paho.mqtt.client as mqtt

# Get the value from an environment variable, or a default value if none was provided
def get_from_env(v, d):
  if v in os.environ and '' != os.environ[v]:
    return os.environ[v]
  else:
    return d

# Seconds to sleep between readings
interval = 5
global mqtt_disconnect

# MQTT broker details - Set by the Horizon Deployment Policy
orgID       = get_from_env('MQTT_ORGID',      '')
deviceType  = get_from_env('MQTT_DEVICETYPE', '')
deviceID    = get_from_env('MQTT_DEVICEID',   '')
deviceToken = get_from_env('MQTT_DEVICETOKEN','')

host = orgID + '.messaging.internetofthings.ibmcloud.com'
# clientID must follow Watson IoT Platform format or will fail to connect:
# If you are connecting as a device use the following clientID
# clientID = 'd:' + orgID + ':' + deviceType + ':' + deviceID
clientID = 'd:' + orgID + ':' + deviceType + ':' + deviceID
print(clientID)
# Server certificate file
#caFile = os.path.dirname(os.path.abspath(__file__)) + "/messaging.pem"
caFile = "./messaging.pem"
# Topics must follow platform format (see docs for details)
# Publish and subscribe as a device
publishTopic = 'iot-2/evt/status/fmt/json'
global connected
connected = False

# MQTT callback functions
def on_connect(mqttclient, userdata, flags, rc):
    global connected
    print("client connected:", rc)
    connected = True


# Create the MQTT client, set the authentication details and register callbacks
mqttclient = mqtt.Client(clientID, protocol=mqtt.MQTTv311)
mqttclient.username_pw_set("use-token-auth", deviceToken)
mqttclient.tls_set(ca_certs=caFile, certfile=None, keyfile=None, cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLSv1_2)
mqttclient.on_connect = on_connect

# Connect the client and start the handler loop
mqttclient.connect(host, port=8883, keepalive=600)
mqttclient.loop_start()

# Take initial CPU readings
psutil.cpu_percent(percpu=False)
before_ts = time.time()
ioBefore = psutil.net_io_counters()
diskBefore = psutil.disk_io_counters()
psutil.disk_io_counters(perdisk=False, nowrap=True)

while True:
    try:
        time.sleep(interval)
        after_ts = time.time()
        ioAfter = psutil.net_io_counters()
        diskAfter = psutil.disk_io_counters()
        # Calculate the time taken between IO checks
        duration = after_ts - before_ts

        data = {
            "node": get_from_env('HZN_NODE_ID',''),
            "cpu": psutil.cpu_percent(percpu=False),
            "mem": psutil.virtual_memory().percent,
            "network": {
                "up": round((ioAfter.bytes_sent - ioBefore.bytes_sent) / (duration * 1024), 2),
                "down": round((ioAfter.bytes_recv - ioBefore.bytes_recv) / (duration * 1024), 2),
            },
            "disk": {
                "read": round((diskAfter.read_bytes - diskBefore.read_bytes) / (duration * 1024), 2),
                "write": round((diskAfter.write_bytes - diskBefore.write_bytes) / (duration * 1024), 2),
            },
        }
        if True:
            print("CPU Data = " + json.dumps(data))

        if connected:
            mqttclient.publish(publishTopic, payload=json.dumps(data), qos=1, retain=False)
            time.sleep(.25) # rate limit the amount of data sent to the MQTT broker

    except KeyboardInterrupt:
        # stop the handler loop
        print("MQTT Connection closed")
        mqttclient.loop_stop()
        sys.exit()

    # Update timestamp and data ready for next loop
    before_ts = after_ts
    ioBefore = ioAfter
    diskBefore = diskAfter
