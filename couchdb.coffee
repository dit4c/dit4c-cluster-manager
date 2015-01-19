'use strict';

env = process.env
url = require('url')
etcdjs = require('etcdjs')
liveCollection = require('etcd-live-collection')
newNano = require('nano')
_ = require("underscore")

etcdPeers = (env.ETCDCTL_PEERS || "127.0.0.1:2379").split(',')
serviceDiscoveryPath = "/dit4c/containers/dit4c_couchdb"
managedDBs = ['dit4c-highcommand']

etcd = etcdjs(etcdPeers)
collection = liveCollection(etcd, serviceDiscoveryPath)

loggerFor = (name) ->
  (msg) -> console.log("["+name+"] "+msg)

serverName = (key) ->
  key.split('/').pop()

replicationId = (db, otherServerName) ->
  [db, otherServerName].join('---')

replicationDoc = (db, otherServerAddr) ->
  "source":  "http://"+otherServerAddr+":5984/"+db
  "target":  db
  "continuous": true
  "create_target":  true
  "user_ctx": { "roles": ["_admin"] }

ensureDocExists = (replicator, log, id, doc) ->
  (callback) ->
    insertDoc = (newDoc) ->
      replicator.insert newDoc, id, (err, body) ->
        if (!err)
          log("Created replication record: "+id)
          callback()
        else
          callback(err)
    updateDoc = (oldDoc, newDoc, callback) ->
      if (oldDoc.source == newDoc.source)
        log("Replication record "+id+" is up-to-date.")
        callback()
      else
        replicator.destroy id, oldDoc._rev, (err, body) ->
          if (!err)
            log("Deleted old replication record: "+id)
            insertDoc(newDoc, callback)
          else
            callback(err)
    replicator.get id, (err, currentDoc) ->
      if (err)
        insertDoc(doc, callback)
      else
        updateDoc(currentDoc, doc, callback)

ensureDbExists = (nano, log, db) ->
  (callback) ->
    nano.db.get db, (err) ->
      if (!err)
        callback(db)
      else
        nano.db.create db, () ->
          log("Created DB: "+db)
          callback(db)

setupReplication = () ->
  servers = _.object([serverName(k), v] for k, v of collection.values())
  console.log("Known servers: ")
  for name, addr of servers
    console.log(name+" → "+addr)
    nano = newNano('http://'+addr+':5984')
    log = loggerFor(name)
    for otherName, otherAddr of servers when otherName != name
      managedDBs.forEach (db) ->
        dbOp = ensureDbExists nano, log, db
        docOp = ensureDocExists nano.use('_replicator'), log,
            replicationId(db, otherName),
            replicationDoc(db, otherAddr)
        dbOp(() -> docOp((err) -> log(err) if err))

collection.on(event, setupReplication) for event in ['ready', 'action']
