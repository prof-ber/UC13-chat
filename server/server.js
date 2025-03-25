import express from "express";
import http from "http";
import { Server as socketIo } from "socket.io";
import { v4 as uuidv4 } from "uuid"; // Importando o uuid
import cors from "cors";
import mysql from "mysql2/promise";
import hashPassword from "./lib/auth.js";
import verifyPassword from "./lib/verify.js";
import dotenv from "dotenv";
import jwt from "jsonwebtoken";
dotenv.config();
uuidv4(); // Gera um ID único para o usuário

const app = express();
const server = http.createServer(app);
const io = new socketIo(server, {
  cors: {
    origin: "*", // Em produção, substitua pelo URL do seu cliente
    methods: ["GET", "POST"],
  },
});
const PORT = process.env.PORT || 3000;
app.use(express.json());
app.use(cors());

// Function to create sessions table
async function createSessionsTable() {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS sessions (
        id VARCHAR(128) PRIMARY KEY,
        user_id VARCHAR(128) NOT NULL,
        token VARCHAR(255) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    console.log("Sessions table created or already exists");
    connection.end();
  } catch (error) {
    console.error("Error creating sessions table:", error);
  }
}

createSessionsTable();

// Rota de cadastro (POST)
app.post("/api/cadastro", async (req, res) => {
  const { nome, senha } = req.body;

  // Validação dos campos
  if (!nome || !senha) {
    return res.status(400).json({ error: "Nome e senha são obrigatórios" });
  }

  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const hashedPassword = await hashPassword(senha);
    const userId = uuidv4();
    console.log(userId);

    const [result] = await connection.execute(
      "INSERT INTO users (id, username, senha) VALUES (?, ?, ?)",
      [userId, nome, hashedPassword]
    );

    connection.end();

    const novoUsuario = {
      id: userId,
      nome: nome,
    };

    console.log("Novo usuário cadastrado:", novoUsuario);

    res.status(201).json({
      message: "Usuário cadastrado com sucesso",
      usuario: novoUsuario,
    });
  } catch (error) {
    console.error("Error during registration:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});

// Rota de login (POST)
app.post("/api/login", async (req, res) => {
  console.log("Login attempt:", req.body);
  const { nome, senha } = req.body;

  // Validação dos campos
  if (!nome || !senha) {
    return res.status(400).json({ error: "Nome e senha são obrigatórios" });
  }

  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    // Busca o usuário pelo nome
    const [rows] = await connection.execute(
      "SELECT * FROM users WHERE username = ?",
      [nome]
    );

    // Verifica se o usuário existe
    if (rows.length === 0) {
      connection.end();
      return res.status(401).json({ error: "Usuário não cadastrado" });
    }

    const user = rows[0];

    // Verifica se a senha está correta
    const isPasswordValid = await verifyPassword(senha, user.senha);
    console.log("Password valid:", isPasswordValid);

    if (!isPasswordValid) {
      connection.end();
      return res.status(401).json({ error: "Senha incorreta" });
    }

    // Gera um token JWT
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "24h",
    });

    // Cria uma nova sessão
    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours from now

    await connection.execute(
      "INSERT INTO sessions (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)",
      [sessionId, user.id, token, expiresAt]
    );

    connection.end();

    // Login bem-sucedido
    res.status(200).json({
      message: "Login realizado com sucesso",
      usuario: {
        id: user.id,
        nome: user.username,
      },
      token: token,
      sessionId: sessionId,
    });
  } catch (error) {
    console.error("Error during login:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});
// Lógica do Socket.io
io.on("connection", (socket) => {
  console.log("Novo cliente conectado");

  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });

  socket.on("message", (msg) => {
    console.log("Mensagem recebida:", msg);
    socket.broadcast.emit("message", msg);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
