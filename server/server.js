import express from "express";
const http = require("http");
const socketIo = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // In production, replace with your GitHub Pages URL
    methods: ["GET", "POST"],
  },
});
const PORT = process.env.PORT || 3000;
app.use(cors());

//Posso fazer rotas de API express aqui
app.get("/api/example", (req, res) => {
  res.json({ message: "This is an example API route" });
});

io.on("connection", (socket) => {
  console.log("Novo cliente conectado");
  //Evento desconexão
  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });
  //Evento de envio de mensagem para o servidor
  socket.on("message", (msg) => {
    console.log("Mensagem recebida:", msg);
    io.emit("message", msg);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
