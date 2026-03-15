#!/bin/bash

echo "Deploying database"
kubectl apply -f postgres-deployment.yaml
kubectl apply -f service-postgres.yaml

echo "Waiting for database to be ready"
kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s

echo "Deploying backend"
kubectl apply -f backend-deployment.yaml
kubectl apply -f service-backend.yaml

echo "Deploying frontend"
kubectl apply -f frontend-deployment.yaml
kubectl apply -f service-frontend.yaml

echo "Applying HPA"
kubectl apply -f hpa.yaml

echo "====="
kubectl get pods
