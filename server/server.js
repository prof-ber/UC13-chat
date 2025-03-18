import express from "express";
import http from "http";
import { Server as socketIo } from "socket.io";

const app = express();
const server = http.createServer(app);
const io = new socketIo(server, {
  cors: {
    origin: "*", // In production, replace with your actual client URL
    methods: ["GET", "POST"],
  },
});
const PORT = process.env.PORT || 3000;

// Example API route
app.get("/api/example", (req, res) => {
  res.json({ message: "This is an example API route" });
});

io.on("connection", (socket) => {
  console.log("Novo cliente conectado");
  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });
  socket.on("message", (msg) => {
    console.log("Mensagem recebida:", msg);
    io.emit("message", msg);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
