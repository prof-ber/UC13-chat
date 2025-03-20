import express from "express";
import http from "http";
import { Server as socketIo } from "socket.io";

const app = express();
const server = http.createServer(app);
const io = new socketIo(server, {
  cors: {
    origin: "*", // Em produção, substitua pelo URL do seu cliente
    methods: ["GET", "POST"],
  },
});
const PORT = process.env.PORT || 3000;

// Rota de exemplo
app.get("/api/example", (req, res) => {
  res.json({ message: "This is an example API route" });
});

io.on("connection", (socket) => {
  console.log("Novo cliente conectado");

  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });

  // Recebe a mensagem do cliente
  socket.on("message", (msg) => {
    console.log("Mensagem recebida:", msg);

    // Adiciona o remetente (nome do cliente) à mensagem
    const messageWithSender = {
      ...msg, // Mantém os campos originais (text e to)
      from: socket.id, // Ou um nome de usuário, se disponível
    };

    // Emite a mensagem para todos os clientes, exceto o remetente
    socket.broadcast.emit("message", messageWithSender);

    // Removemos a linha que emitia a mensagem de volta para o remetente
    // socket.emit("message", messageWithSender);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});