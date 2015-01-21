'use strict';

env = process.env
url = require('url')
etcdjs = require('etcdjs')
liveCollection = require('etcd-live-collection')
newNano = require('nano')
_ = require("underscore")
monitor = require('http-monitor')

etcdPeers = (env.ETCDCTL_PEERS || "127.0.0.1:2379").split(',')
serviceDiscoveryPath = "/dit4c/containers/dit4c_highcommand"
domain = env.DIT4C_DOMAIN || 'resbaz.cloud.edu.au'

etcd = etcdjs(etcdPeers)
collection = liveCollection(etcd, serviceDiscoveryPath)

loggerFor = (name) ->
  (msg) -> console.log("["+name+"] "+msg)

serverName = (key) ->
  key.split('/').pop()

restartMonitoring = do () ->
  data =
    monitors: []
    alive: {}
  writeHipacheRecord = () ->
    key = "/dit4c/hipache/frontend:"+domain
    servers = (ip for ip, isUp of data.alive when isUp)
    record = [ domain ].concat("http://"+ip+":9000" for ip in servers)
    etcd.set key, JSON.stringify(record), (err) ->
      if (!err)
        # Log success
        console.log "Servers now: "+servers.join(', ')
      else
        # Retry write
        setTimeout(writeHipacheRecord, 5000)
  markAsAlive = (serverIP) ->
    data.alive[serverIP] = true
    loggerFor(serverIP)("UP")
    writeHipacheRecord()
  markAsDead = (serverIP) ->
    data.alive[serverIP] = false
    loggerFor(serverIP)("DOWN")
    writeHipacheRecord()
  startMonitor = (serverIP) ->
    m = monitor 'http://'+serverIP+':9000/health',
      retries: 1
      interval: 5000
      timeout: 15000
    m.on 'error', (err) ->
      markAsDead(serverIP)
    m.on 'recovery', () ->
      markAsAlive(serverIP)
    markAsAlive(serverIP)
  stopMonitors = () ->
    # Destroy all monitors
    for monitor in data.monitors
      monitor.destroy()
    data.monitors = []
    # Clear health status lookup
    data.alive = {}
  (serverIPs) ->
    stopMonitors()
    startMonitor(ip) for ip in serverIPs

updateMonitoring = () ->
  servers = _.object([serverName(k), v] for k, v of collection.values())
  console.log("Known servers: ")
  for name, addr of servers
    console.log(name+" → "+addr)
  restartMonitoring(addr for name, addr of servers)

collection.on(event, updateMonitoring) for event in ['ready', 'action']
