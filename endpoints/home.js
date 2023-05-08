const express = require('express')
const path = require('path');

const utils = require('../modules/utilities')
const accounts = require('../modules/accounts')
const router = express.Router()

const Accounts = accounts()

router.get('/', (req, res) => {
    const sessionId = req.session.user;
    const user = Accounts._sessions.get(sessionId);

    if (!user) {
        res.redirect('/auth/login');
        return;
    }

    res.render('home', { username: user.username });
});

module.exports = {
    endpoint: "/home",
    router: router
};
