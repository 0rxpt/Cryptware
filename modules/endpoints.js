const endpoints = {}

const fs = require('fs');
const path = require('path');

const endpointsDir = path.join(__dirname, '..', 'endpoints');

endpoints.init = async function (server) {
    server.use((req, res, next) => {
        console.log('Session ID:', req.sessionID);
        console.log('Session:', req.session);

        if (req.session && req.session.user) {
            console.log("User has session; continuing.")
            res.set('Cache-Control', 'no-cache');
            next();
        } else if (req.path !== '/auth/login' && req.path !== '/auth/signup') {
            console.log('Redirecting to login');
            res.redirect('/auth/login');
        }

        return
    })

    fs.readdir(endpointsDir, (err, files) => {
        if (err) throw err;

        const jsFiles = files.filter(file => path.extname(file) === '.js');

        jsFiles.forEach(async file => {
            const endpointModule = require(path.join(endpointsDir, file));
            server.use(endpointModule.endpoint, endpointModule.router);
        });
    })
};

module.exports = endpoints