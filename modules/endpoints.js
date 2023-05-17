const endpoints = {}

const fs = require('fs');
const path = require('path');
const accounts = require("../modules/accounts")

const endpointsDir = path.join(__dirname, '..', 'endpoints');

endpoints.init = async function (server, store) {
    const Accounts = new accounts(store) 

    fs.readdir(endpointsDir, (err, files) => {
        if (err) throw err;

        const jsFiles = files.filter(file => path.extname(file) === '.js');

        jsFiles.forEach(file => {
            const endpointModule = require(path.join(endpointsDir, file));
            server.use(endpointModule.endpoint, endpointModule.router);
            endpointModule.init(server, store)
        });
    })

    server.use(async (req, res, next) => {
        console.log("USER? TRIED:", req.session.user);
        console.log("SESSION ID:", req.sessionID)
        console.log("SESSION DATA:", req.session)

        const sessionData = await Accounts.sessions.get(req.sessionID);
        console.log("SAVED SESSION? TRIED:", sessionData)
        const userId = sessionData?.user?.userid
        const user = userId ? sessionData.user : undefined

        const _path = req.path

        if (sessionData && user) {
            await req.session.reload(() => {});
            req.session.user = user;
            console.log("FOUND SESSION:", req.session.user)
            await req.session.save();
        }

        if (!user && !_path.includes("auth") || !user && _path.includes("logout")) {
            return res.redirect('/auth/login');
        }

        if (user && _path.includes("auth/login") || user && _path == "/") {
            return res.redirect('/home');
        }

        return next();
    })    
};

module.exports = endpoints