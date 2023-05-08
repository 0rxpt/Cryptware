class Utilities {
    filter(obj, predicate, useOne) {
        const result = {};

        for (const [key, value] of Object.entries(obj)) {
            if (predicate(value)) {
                result[key] = value;
                if (useOne) return value
            }
        }

        return result;
    }

    shuffleString(str) {
        let arr = str.split('')

        for (let i = arr.length - 1; i > 0; i--) {
            let j = Math.floor(Math.random() * (i + 1))
            let temp = arr[i]
            arr[i] = arr[j]
            arr[j] = temp
        }

        return arr.join('')
    }

    generateId(length) {
        length = length || 12

        const types = {
            1: "abcdefghijklmnopqrstuvwxyz",
            2: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            3: "0123456789",
        }

        for (let [k, v] of Object.entries(types)) {
            types[k] = this.shuffleString(v)
        }

        let id = ""
        let chosen, char

        for (i = 1; i <= length; i++) {
            chosen = types[Math.floor(Math.random() * 3) + 1]
            char = chosen[Math.floor(Math.random() * chosen.length)]
            id = id + char
        }

        return id
    }
}

module.exports = Utilities