#!/bin/bash

TIMEOUTMAX=120

# Get host's IP (127.0.0.1 is assumed if $DOCKET_HOST is empty)
IP=$(echo $DOCKER_HOST | cut -d'/' -f3 | cut -d':' -f1)
if [ "$IP" = "" ]; then
  IP="127.0.0.1"
fi
export IP

curl --version > /dev/null
if [ $? -ne 0 ];then
	echo "Curl not found"
	exit 1
fi

# disable cache
sed -i "s,^CACHE_TYPE.*,CACHE_TYPE = 'null'," frontend/flask_settings

## build the images first
docker-compose build --build-arg HTTP_PROXY="${http_proxy}" || exit $?

## Deploy the application

echo "-> deploying the application..."
docker-compose up -d || exit $?

## Wait for the application to be available

echo "-> waiting for backend..."
TIMEOUT=0
while [ $(curl -s -m 3 -o /dev/null -w "%{http_code}" $IP:8081) -ne 200 ]; do
   sleep 1
   TIMEOUT=$(($TIMEOUT+1))
   if [ $TIMEOUT -ge $TIMEOUTMAX ];then
       echo "TIMEOUT!"
       exit 1
   fi
done
echo "-> waiting for frontend..."
TIMEOUT=0
while [ $(curl -s -m 3 -o /dev/null -w "%{http_code}" $IP:8080) -ne 200 ]; do
  sleep 1
   TIMEOUT=$(($TIMEOUT+1))
   if [ $TIMEOUT -ge $TIMEOUTMAX ];then
       echo "TIMEOUT!"
       exit 1
   fi
done

## Configure the application

echo "-> configuring the application..."

### Get token from backend

echo "-> requesting token from backend..."
TOKEN=""
TIMEOUT=0
while [ "$TOKEN" = "" ];do
  TOKEN=$(curl -m 3 -s -X POST -H "Content-Type: application/json" -H "Authorization: MASTER_KEY" -d '{"email": "adm@kernelci.org", "admin": 1}' $IP:8081/token | docker container run --rm -i lucj/jq -r .result[0].token 2>/dev/null)
  sleep 1
   TIMEOUT=$(($TIMEOUT+1))
   if [ $TIMEOUT -ge 60 ];then
       echo "TIMEOUT!"
       exit 1
   fi
done
echo $TOKEN > .kernelci_token
echo "-> token returned: $TOKEN"

### Update frontend with token created

sed -i "s/^BACKEND_TOKEN.*$/BACKEND_TOKEN = \"$TOKEN\"/" frontend/flask_settings

echo "-> wait while frontend is restarted"
docker-compose stop frontend || exit $?
docker-compose start frontend || exit $?

echo "-> application configured"
echo "--> frontend available on port 8080"
echo "--> backend  available on port 8081"
echo "--> storage  available on port 8082"
