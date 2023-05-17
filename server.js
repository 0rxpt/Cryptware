const express = require('express')
const session = require('express-session')
const { Sequelize } = require('sequelize');
const crypto = require('crypto');
const https = require('https')
const fs = require('fs')

const { v4: uuidv4 } = require('uuid');
const SequelizeStore = require('connect-session-sequelize')(session.Store);

const endpoints = require("./modules/endpoints")
const server = express()

const sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: './session.db',
    logging: false
});

sequelize.define("Session", {
    sid: {
        type: Sequelize.STRING,
        primaryKey: true,
    },
    userId: {
        type: Sequelize.STRING,
        defaultValue: ""
    },
    expires: {
        type: Sequelize.DATE,
        default: Date.now() + (2 * 60 * 60 * 1000)
    },
    data: {
        type: Sequelize.STRING,
        allowNull: true
    }
});

function extendDefaultFields(defaults, session) {
    const twoHours = 2 * 60 * 60 * 1000;
    const expires = session.cookie && session.cookie.expires ? new Date(session.cookie.expires) : new Date(Date.now() + twoHours);
    return {
        expires: expires,
        userId: session.userId,
        data: session.data || defaults.data
    };
}

const store = new SequelizeStore({
    db: sequelize,
    table: "Session",
    extendDefaultFields: extendDefaultFields,
});

const accounts = require("./modules/accounts")
const Accounts = new accounts(store)

async function _() {
    await Accounts.reset();
}
//_()

server.use(express.urlencoded({ extended: true }));
server.use(express.json());
server.use(express.static(__dirname + '/public'));

server.set('view engine', 'ejs')
server.set('trust proxy', 1)

server.use(session({
    genid: () => {
        return uuidv4();
    },
    secret: crypto.randomBytes(64).toString('hex'),
    resave: false,
    saveUninitialized: false, // true
    store: store,
    cookie: {
        sameSite: 'none',
        secure: true,
        maxAge: 2 * 60 * 60 * 1000
    }
}))

sequelize.sync({ alter: true }).then(async () => {
    await endpoints.init(server, store);

    const serverOptions = {
        key: fs.readFileSync('server.key'),
        cert: fs.readFileSync('server.crt')
    }
    
    const httpsServer = https.createServer(serverOptions, server)
    const port = 3000
    
    httpsServer.listen(port, () => {
        console.log('[PORT]: ' + port)
    })
});