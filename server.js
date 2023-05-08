const express = require('express')
const session = require('express-session')
const crypto = require('crypto');
const path = require('path');

const https = require('https')
const fs = require('fs')
const endpoints = require("./modules/endpoints")

const server = express()

server.use(express.urlencoded({ extended: true }));
server.use(express.json());
server.use('/public', express.static(path.join(__dirname, 'public')));

server.use(session({
    secret: crypto.randomBytes(64).toString('hex'),
    resave: false,
    saveUninitialized: true,
    cookie: {
        secure: true,
        maxAge: 1000 * 60 * 60 * 24 * 30
    }
}))

endpoints.init(server);

const serverOptions = {
    key: fs.readFileSync('server.key'),
    cert: fs.readFileSync('server.crt')
}

const httpsServer = https.createServer(serverOptions, server)
const port = 3000

httpsServer.listen(port, () => {
    console.log('[PORT]: ' + port)
})