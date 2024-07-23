#!/bin/bash

echo "Build API..."
cd api 
docker buildx build  -t docker.io/vsramchaik/gojo-api --push . 
cd ..
echo "Pushed to dockerhub"

echo "Build Web..."
cd web
docker buildx build  -t docker.io/vsramchaik/gojo-web --push . 
cd ..
echo "Pushed to dockerhub"