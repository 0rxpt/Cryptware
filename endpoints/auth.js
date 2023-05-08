const path = require('path');
const crypto = require('crypto')

const accounts = require('../modules/accounts')

const router = require('express').Router()
const Accounts = accounts()

router.get('/login', (_, res) => {
    res.sendFile(path.join(__dirname, '..', 'public', 'login.html'));
});

router.get('/signup', (_, res) => {
    res.sendFile(path.join(__dirname, '..', 'public', 'signup.html'));
});

router.post('/login', async (req, res) => {
    const username = req.body.username
    const password = req.body.password

    Accounts.getUser.fromUsername(username).then(user => {
        if (!user) {
            res.send({ success: false })
            return
        }

        crypto.scrypt(password, user.passwordSalt, 64, (err, derivedKey) => {
            if (err) {
                console.log("Error when hashing password:", err);
                res.send({ success: false });
                return;
            }

            crypto.timingSafeEqual(Buffer.from(derivedKey), Buffer.from(user.passwordHash), (isEqual) => {
                if (isEqual) {
                    const sessionId = Accounts._utils.generateId(32)
                    Accounts._sessions.set(sessionId, user)
                    req.session.user = sessionId
                    res.redirect('/home')
                } else {
                    res.send({ success: false })
                }
            });
        });
    }).catch(error => {
        //console.log("Error when getting user from username:", error);
        res.send({ success: false });
    });
})

router.post('/signup', async (req, res) => {
    const username = req.body.username;
    const password = req.body.password;

    if (await Accounts.getUser.fromUsername(username)) {
        res.send({ success: false, message: "Username already exists." });
        return;
    }

    const newUser = await Accounts.create(username, password);
    const sessionId = Accounts._utils.generateId(32)
    Accounts._sessions.set(sessionId, newUser)

    req.session.user = sessionId
    res.redirect('/home');
});

router.get('/logout', async (req, res) => {
    const sessionId = req.session.user
    Accounts._sessions.delete(sessionId)

    req.session.destroy(() => {
        res.redirect('/auth/login')
    })
})

module.exports = {
    endpoint: "/auth",
    router: router
};