# dit4c-cluster-manager

To run:

```
docker run -d --name dit4c_cluster_manager \
  --link dit4c_etcd:etcd \
  -e ETCDCTL_PEERS="etcd:2379" \
  dit4c/dit4c-cluster-manager
```
