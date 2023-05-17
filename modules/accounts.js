const { QuickDB } = require('quick.db');
const utils = require('./utilities')

class Accounts {
    constructor(store) {
        this._utils = utils

        this.databases = {
            main: new QuickDB(),
            session: store
        }

        this.users = {
            create: async (username, password) => {
                const passwordSalt = utils.generateId(16)
                const hashedPassword = await utils.hashPassword(password, passwordSalt)

                const newData = {
                    username: username,
                    password: hashedPassword.toString('hex'),
                    passwordSalt: passwordSalt,
                    displayname: "",
                    userid: utils.generateId()
                }

                await this.databases.main.set(username, newData)
                return newData
            },

            authenticate: async (username, password) => {
                const user = await this.users.getUserFromUsername(username)
                if (!user) return "Invalid user."

                const hashedPasswordBuffer = user.password;
                let derivedKeyBuffer = await utils.scryptAsync(password, Buffer.from(user.passwordSalt), 64);
                derivedKeyBuffer = derivedKeyBuffer.toString('hex');

                if (derivedKeyBuffer == hashedPasswordBuffer) {
                    return user;
                }

                return "Invalid Password"
            },

            getUserFromUsername: async (username) => {
                return await this.databases.main.get(username)
            },

            getUserFromId: async (userid) => {
                const usersData = await this.databases.main.all()
                const foundUser = usersData.find(user => user.userid === userid);
                return foundUser
            }
        }

        this.sessions = {
            options: {
                sessionExpiration: 3600000
            },

            get: async (sessionId) => {
                const sessionData = await this.databases.session.get(sessionId)

                if (!sessionData)
                    return

                if (sessionData.sessionExpiration && sessionData.sessionExpiration < Date.now()) {
                    console.log("This session has expired; deleting.")
                    await this.sessions.delete(sessionId);
                    return;
                }

                return sessionData;
            },

            create: async (user, sessionId, useData) => {
                const expires = Date.now() + this.sessions.options.sessionExpiration;
                const sessionData = { expires, user: user, userId: user.userid, sid: sessionId }

                await this.databases.session.set(sessionId, useData || sessionData);
                return sessionData
            },

            delete: async (sessionId) => {
                await this.databases.session.destroy(sessionId)
            }
        }
    }

    async reset() {
        await this.databases.main.deleteAll();
        await this.databases.session.sync({ force: true })
    }
}

module.exports = Accounts