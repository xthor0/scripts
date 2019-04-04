// simple web service
const http = require('http')
//const port = 8000

var os = require("os");
var hostname = os.hostname();

const requestHandler = (request, response) => {
  console.log(request.url)
  response.end(`<HEAD><HTML><H1>Running on hostname ${process.env.HOSTNAME} </H1><p>Served by a node.js process listening on TCP port ${process.env.PORT}</HTML></HEAD>\n`)
}

const server = http.createServer(requestHandler)

server.listen(process.env.PORT, (err) => {
  if (err) {
    return console.log('something bad happened', err)
  }

  console.log(`server is listening on ${process.env.PORT}`)
})
