'use strict';

var env = process.env,
    url = require('url'),
    etcdPeers = (env.ETCD_PEERS || "127.0.0.1:2379").split(','),
    serviceDiscoveryPath = env.SERVICE_DISCOVERY_PATH || "/containers/couchdb",
    dbs = env.COUCHDB_DATABASES  && env.COUCHDB_DATABASES.split(',') || [],
    Etcd = require('node-etcd'),
    newNano = require('nano');

var etcd = new Etcd(etcdPeers);

console.log(serviceDiscoveryPath);
etcd.get(serviceDiscoveryPath, { recursive: true }, function(err, data) {
  if (!err) {
    var servers = {};
    data.node.nodes.forEach(function(node) {
      servers[node.key.split('/').pop()] = node.value;
    });
    Object.keys(servers).forEach(function(serverName) {
      var serverAddr = servers[serverName];
      var nano = newNano('http://'+serverAddr+':5984');
      nano.db.list(function(err, body) {
        console.log(dbs,body);
      });
    })

  }
});
