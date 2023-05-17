const path = require('path');
const accounts = require('../modules/accounts')
const router = require('express').Router()

const auth = {
    endpoint: "/auth",
    router: router
};

auth.init = function (server, store) {
    const Accounts = new accounts(store)

    server.get('/auth/login', (_, res) => {
        res.sendFile(path.join(__dirname, '..', 'public', 'login.html'));
    });

    server.get('/auth/signup', (_, res) => {
        res.sendFile(path.join(__dirname, '..', 'public', 'signup.html'));
    });

    server.get('/auth/logout', async (req, res) => {
        try {
            await Accounts.sessions.delete(req.sessionID);

            req.session.destroy(() => {
                res.redirect('/auth/login')
            })
        } catch(err) {
            console.log("Error when logging out:", err)
            res.redirect("/auth/login")
        }
    })

    server.post('/auth/login', async (req, res) => {
        const username = req.body.username
        const password = req.body.password

        try {
            const user = await Accounts.users.authenticate(username, password);

            if (typeof user != "string") {
                await Accounts.sessions.create(user, req.sessionID)

                req.session.user = user;
                await req.session.save();
                res.status(200).send("Login was successful.");
            } else {
                res.status(400).send("User was not found.");
            }
        } catch (err) {
            console.log("Error when logging in:", err)
            res.status(400).send("There was an error when logging in.");
        }
    })

    server.post('/auth/signup', async (req, res) => {
        const username = req.body.username;
        const password = req.body.password;

        try {
            if (await Accounts.users.getUserFromUsername(username)) {
                return res.status(400).send("Username already exists.");
            }

            const user = await Accounts.users.create(username, password);
            await Accounts.sessions.create(user, req.sessionID);

            req.session.user = user
            await req.session.save();
            res.status(200).send("Signup was successful.");
        } catch (err) {
            console.log("Error signing up:", err)
            res.status(400).send("There was an error when signing up.");
        }
    });
}

module.exports = auth