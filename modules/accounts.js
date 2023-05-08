const { QuickDB } = require('quick.db');
const utils = require('./utilities')

class Accounts {
    constructor() {
        this._database = new QuickDB();
        this._sessions = new QuickDB();
        this._utils = utils

        this.getUser = {
            fromUsername: async (username) => {
                return await this._database.get(username)
            },

            fromId: async (userid) => {
                const usersData = await this._database.all()
                const foundUser = utils.filter(usersData, user => user.userid == userid, true)
                return foundUser
            },
        };
    }

    async authenticate(username, password) {
        const user = this.getUser.fromUsername(username)

        if (user && user.password === password) {
            const sessionId = utils.generateId(32)
            this._sessions.set(sessionId, user)
            return sessionId
        }

        return null
    }

    async create(username, password) {
        const newData = {
            username: username,
            password: password,
            displayname: "",
            userid: utils.generateId()
        }

        await this._database.set(username, newData)
        return newData
    }
}

module.exports = function () {
    if (!process.env.ACCOUNTS_MODULE) process.env.ACCOUNTS_MODULE = new Accounts()
    return process.env.ACCOUNTS_MODULE
}