aws eks --region us-east-2 update-kubeconfig --name $1
kubectl apply -f $2