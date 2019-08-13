#!/bin/bash
set -e

function waitForMongo {
    port=$1
    n=0
    until [ $n -ge 20 ]
    do
        echo "trying: $port $user $pass"
        mongo admin --quiet --port $port --eval "db" && break
        n=$[$n+1]
        sleep 5
    done
}

[ ! -d "/data/db1" ] && mkdir -p "/data/db1" || :
[ ! -d "/data/db2" ] && mkdir -p "/data/db2" || :
[ ! -d "/data/db3" ] && mkdir -p "/data/db3" || :

echo "STARTING CLUSTER"


mongod --port 27019 --smallfiles --dbpath /data/db3 --bind_ip_all --replSet rs0   &
DB3_PID=$!
mongod --port 27018 --smallfiles --dbpath /data/db2 --bind_ip_all --replSet rs0   &
DB2_PID=$!
mongod --port 27017 --smallfiles --dbpath /data/db1 --bind_ip_all --replSet rs0   &
DB1_PID=$!

waitForMongo 27017 
waitForMongo 27018
waitForMongo 27019

echo "CONFIGURING REPLICA SET: localhost"
CONFIG="{ _id: 'rs0', members: [{_id: 0, host: 'localhost:27017', priority: 2 }, { _id: 1, host: 'localhost:27018' }, { _id: 2, host: 'localhost:27019' } ]}"
mongo admin --port 27017  --eval "db.runCommand({ replSetInitiate: $CONFIG })"

waitForMongo 27018
waitForMongo 27019

mongo admin --port 27017  --eval "db.runCommand({ setParameter: 1, quiet: 1 })"
mongo admin --port 27018  --eval "db.runCommand({ setParameter: 1, quiet: 1 })"
mongo admin --port 27019  --eval "db.runCommand({ setParameter: 1, quiet: 1 })"

echo "REPLICA SET ONLINE"


trap 'echo "KILLING"; kill $DB1_PID $DB2_PID $DB3_PID; wait $DB1_PID; wait $DB2_PID; wait $DB3_PID' SIGINT SIGTERM EXIT

wait $DB1_PID
wait $DB2_PID
wait $DB3_PID
