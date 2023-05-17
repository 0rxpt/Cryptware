const express = require('express')
const path = require('path');

const utils = require('../modules/utilities')
const accounts = require('../modules/accounts')

const router = require('express').Router()

const home = {
    endpoint: "/home",
    router: router
}

home.init = function(server, store) {
    const Accounts = new accounts(store)
    
    server.get('/home', async (req, res) => {
        const sessionData = req.session
    
        if (!sessionData) {
            res.redirect('/auth/login');
            return;
        }
    
        res.render('home', { username: sessionData.user.username });
    });
}

module.exports = home