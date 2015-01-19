'use strict';

env = process.env
url = require('url')
etcdjs = require('etcdjs')
liveCollection = require('etcd-live-collection')
newNano = require('nano')
_ = require("underscore")

etcdPeers = (env.ETCDCTL_PEERS || "127.0.0.1:2379").split(',')
serviceDiscoveryPath = "/dit4c/containers/dit4c_highcommand"
domain = env.DIT4C_DOMAIN || 'resbaz.cloud.edu.au'

etcd = etcdjs(etcdPeers)
collection = liveCollection(etcd, serviceDiscoveryPath)

serverName = (key) ->
  key.split('/').pop()

updateHipache = () ->
  servers = _.object([serverName(k), v] for k, v of collection.values())
  console.log("Known servers: ")
  for name, addr of servers
    console.log(name+" → "+addr)
  record = [ domain ].concat("http://"+addr+":9000" for name, addr of servers)
  etcd.set("/dit4c/hipache/frontend:"+domain, JSON.stringify(record))
  etcd.get "/dit4c/hipache/frontend:"+domain, (err, data) ->
    if (!err)
      console.log(data.node.key+" → "+data.node.value)
    else
      console.log(err)

collection.on(event, updateHipache) for event in ['ready', 'action']
