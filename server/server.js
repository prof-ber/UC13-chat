import express, { response } from "express";
import http from "http";
import { Server as socketIo } from "socket.io";
import { v4 as uuidv4 } from "uuid"; // Importando o uuid
import cors from "cors";
import mysql from "mysql2/promise";
import hashPassword from "./lib/auth.js";
import verifyPassword from "./lib/verify.js";
import dotenv from "dotenv";
import jwt from "jsonwebtoken";
import multer from "multer";
const upload = multer({ storage: multer.memoryStorage() });
dotenv.config();
uuidv4(); // Gera um ID único para o usuário

const SERVER_IP = process.env.SERVER_IP || "localhost";

const LOG_LEVELS = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3
};

const CURRENT_LOG_LEVEL = LOG_LEVELS.INFO; // Ajuste conforme necessário

function log(level, message) {
  if (level <= CURRENT_LOG_LEVEL) {
    console.log(`[${new Date().toISOString()}] ${Object.keys(LOG_LEVELS)[level]}: ${message}`);
  }
}

const app = express();
const server = http.createServer(app);
const io = new socketIo(server, {
  cors: {
    origin: "*", // Em produção, substitua pelo URL do seu cliente
    allowedHeaders: ["Content-Type", "Authorization"],
    methods: ["GET", "POST", "PUT", "OPTIONS"],
  },
});
const PORT = process.env.PORT || 3000;
const corsOptions = {
  origin: "*", // This allows all origins
  methods: ["GET", "POST", "PUT"],
  allowedHeaders: ["Content-Type", "Authorization"],
  credentials: true,
};

const onlineUsers = new Map();
const lastActivityTime = new Map();

function updateUserActivity(userId) {
  lastActivityTime.set(userId, Date.now());
  onlineUsers.set(userId, true);
}

function checkUserStatus() {
  const currentTime = Date.now();
  for (const [userId, lastActivity] of lastActivityTime.entries()) {
    if (currentTime - lastActivity > 5 * 60 * 1000) { // 5 minutos de inatividade
      onlineUsers.delete(userId);
      io.emit('userStatusChanged', { userId, isOnline: false });
    }
  }
}

// Executar a verificação a cada minuto
setInterval(checkUserStatus, 60000);

app.use(cors(corsOptions)); // Enable CORS for all routes
app.use(express.json());
app.use(express.json({ limit: "15MB" }));
app.use(express.urlencoded({ limit: "15MB", extended: true }));
app.use(cors());

app.options("*", cors(corsOptions)); // Enable pre-flight requests for all routes

// Log middleware to request sizes
app.use((req, res, next) => {
  const contentLength = req.headers["content-length"];
  log(LOG_LEVELS.INFO,
    `Received ${req.method} request to ${req.url} with content length: ${contentLength} bytes`
  );
  next();
});

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

    connection.end();
  } catch (error) {
    log(LOG_LEVELS.ERROR,"Error creating sessions table:", $);
  }
}

createSessionsTable();

// Rota de cadastro (POST)
app.post("/api/cadastro", cors(corsOptions), async (req, res) => {
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

    const [result] = await connection.execute(
      "INSERT INTO users (id, username, senha) VALUES (?, ?, ?)",
      [userId, nome, hashedPassword]
    );

    connection.end();

    const novoUsuario = {
      id: userId,
      nome: nome,
    };

    res.status(201).json({
      message: "Usuário cadastrado com sucesso",
      usuario: novoUsuario,
    });
  } catch (error) {
    
    
    res.status(500).json({ message: "Internal server error" });
  }
});

// Rota de login (POST)
app.post("/api/login", cors(corsOptions), async (req, res) => {
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
    if (!isPasswordValid) {
      connection.end();
      return res.status(401).json({ error: "Senha incorreta" });
    }
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "24h",
    });
    log(LOG_LEVELS.INFO,"JWT token generated successfully");

    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await connection.execute(
      "INSERT INTO sessions (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)",
      [sessionId, user.id, token, expiresAt]
    );
    log(LOG_LEVELS.INFO,"New session created successfully");

    connection.end();

    log(LOG_LEVELS.INFO,"Login successful");
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
    log(LOG_LEVELS.ERROR,"Error during login:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});

let savedMessagesCount = 0;
let lastLogTime = Date.now();

// Função para salvar mensagem no banco de dados
async function saveMessage(senderId, receiverId, content) {
  savedMessagesCount++;
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  try {
    await connection.beginTransaction();

    // Inserir a mensagem
    const messageId = uuidv4();
    await connection.execute(
      'INSERT INTO messages (id, content) VALUES (?, ?)',
      [messageId, content]
    );

    // Associar a mensagem ao remetente
    await connection.execute(
      'INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)',
      [senderId, messageId, true]
    );

    // Associar a mensagem ao destinatário (se não for 'All')
    if (receiverId !== 'All') {
      await connection.execute(
        'INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)',
        [receiverId, messageId, false]
      );
    }
    const now = Date.now();
    if (now - lastLogTime > 60000) { // Log a cada minuto
      log(LOG_LEVELS.INFO,`Mensagens salvas nos últimos 60 segundos: ${savedMessagesCount}`);
      savedMessagesCount = 0;
      lastLogTime = now;
    }
  } catch (error) {
    await connection.rollback();
    log(LOG_LEVELS.ERROR,'Error saving message to database:', error);
  } finally {
    await connection.end();
  }
}

// Função para recuperar mensagens do banco de dados
async function getMessages(userId) {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  try {
    const [rows] = await connection.execute(
      `SELECT m.id, m.content, m.timestamp, um.is_sender, 
              CASE WHEN um.is_sender = 1 THEN um.user_id ELSE other_um.user_id END as other_user_id
       FROM messages m
       JOIN users_messages um ON m.id = um.message_id
       JOIN users_messages other_um ON m.id = other_um.message_id AND other_um.user_id != um.user_id
       WHERE um.user_id = ?
       ORDER BY m.timestamp ASC`,
      [userId]
    );
    return rows;
  } catch (error) {
    log(LOG_LEVELS.ERROR,'Error retrieving messages from database:', error);
    return [];
  } finally {
    await connection.end();
  }
}

// Profile picture upload route
app.put("/api/profile-picture", upload.single("image"), async (req, res) => {
  log(LOG_LEVELS.INFO,"Iniciando rota de upload de imagem de perfil");
  
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    log(LOG_LEVELS.INFO,"Token não fornecido");
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];

  try {
    log(LOG_LEVELS.INFO,"Verificando token");
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;
    log(LOG_LEVELS.INFO,"UserId do token:", userId);

    if (!req.file) {
      log(LOG_LEVELS.INFO,"Nenhum arquivo enviado");
      return res.status(400).json({ error: "Foto de perfil é obrigatória" });
    }

    log(LOG_LEVELS.INFO,"Tipo MIME do arquivo:", req.file.mimetype);
    log(LOG_LEVELS.INFO,"Tamanho do arquivo:", req.file.size);
    
    if (!req.file.mimetype.startsWith('image/')) {
      log(LOG_LEVELS.INFO,"Arquivo não é uma imagem válida");
      return res.status(400).json({ error: "O arquivo enviado não é uma imagem válida" });
    }

    log(LOG_LEVELS.INFO,"Received image size:", req.file.size);
    log(LOG_LEVELS.INFO,"Received image data length:", req.file.buffer.length);

    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    await connection.beginTransaction();

    try {
      log(LOG_LEVELS.INFO,"Inserindo imagem no banco de dados");
      const [pictureResult] = await connection.execute(
        "INSERT INTO pictures (pictures_data) VALUES (?)",
        [req.file.buffer]
      );
      const pictureId = pictureResult.insertId;
      log(LOG_LEVELS.INFO,"ID da imagem inserida:", pictureId);

      log(LOG_LEVELS.INFO,"Verificando se o usuário já tem uma imagem de perfil");
      const [existingPicture] = await connection.execute(
        "SELECT picture_id FROM users_pictures WHERE user_id = ?",
        [userId]
      );

      if (existingPicture.length > 0) {
        log(LOG_LEVELS.INFO,"Atualizando imagem de perfil existente");
        await connection.execute(
          "UPDATE users_pictures SET picture_id = ? WHERE user_id = ?",
          [pictureId, userId]
        );
      } else {
        log(LOG_LEVELS.INFO,"Inserindo nova imagem de perfil");
        await connection.execute(
          "INSERT INTO users_pictures (user_id, picture_id) VALUES (?, ?)",
          [userId, pictureId]
        );
      }

      await connection.commit();
      log(LOG_LEVELS.INFO,"Transação concluída com sucesso");

      res.status(200).json({
        message: "Foto de perfil atualizada com sucesso",
        imageUrl: `/api/profile-picture/${userId}`,
      });
    } catch (error) {
      log(LOG_LEVELS.ERROR,"Erro durante a transação:", error);
      await connection.rollback();
      throw error;
    } finally {
      connection.end();
    }
  } catch (error) {
    log(LOG_LEVELS.ERROR,"Erro ao atualizar a foto de perfil:", error);
    console.error("Stack trace:", error.stack);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  }
});

let profilePictureRequests = {};
// Get profile picture route
app.get("/api/profile-picture/:userId", async (req, res) => {
  const { userId } = req.params;

  const now = Date.now();
  if (!profilePictureRequests[userId] || now - profilePictureRequests[userId] > 300000) {
    log(LOG_LEVELS.INFO,`Received request for profile picture of user: ${userId}`);
    profilePictureRequests[userId] = now;
  }

  log(LOG_LEVELS.INFO,`Received request for profile picture of user: ${userId}`);
  let connection;
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [rows] = await connection.execute(
      `SELECT p.pictures_data 
       FROM pictures p 
       JOIN users_pictures up ON p.id = up.picture_id 
       WHERE up.user_id = ?`,
      [userId]
    );

    if (rows.length === 0) {
      log(LOG_LEVELS.INFO,`No profile picture found for user: ${userId}`);
      return res.status(200).json({ message: "No profile picture found" });
    }

    const imageBuffer = rows[0].pictures_data;

    if (!imageBuffer) {
      return res
        .status(200)
        .json({ message: "Profile picture data is invalid" });
    }
  
    log(LOG_LEVELS.INFO,"Image content type:", imageBuffer.type);
  
    res.writeHead(200, {
      "Content-Type": "image/jpeg", // Ajuste isso se necessário com base no tipo real da imagem
      "Content-Length": imageBuffer.length,
    });
    res.end(imageBuffer);
  } catch (error) {
    console.error(`Error in profile picture route for user ${userId}:`, error);
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

// Fetch contacts route
app.get("/api/contacts", async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];

  let connection;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [rows] = await connection.execute(
      `
      SELECT u.id, u.username, up.picture_id
      FROM contacts c
      JOIN users u ON c.contact_id = u.id
      LEFT JOIN users_pictures up ON u.id = up.user_id
      WHERE c.user_id = ?
    `,
      [userId]
    );

    const contacts = rows.map((row) => ({
      id: row.id,
      username: row.username,
      avatarUrl: row.picture_id ? `/api/profile-picture/${row.id}` : null,
    }));

    res.status(200).json(contacts);
  } catch (error) {
    log(LOG_LEVELS.ERROR,"Error fetching contacts:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

// Add contact route
app.post("/api/contacts", async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];
  const { contactId } = req.body;

  if (!contactId) {
    return res.status(400).json({ error: "Contact ID is required" });
  }

  let connection;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    // Check if the contact exists
    const [userRows] = await connection.execute(
      "SELECT id FROM users WHERE id = ?",
      [contactId]
    );
    if (userRows.length === 0) {
      return res.status(404).json({ error: "Contact not found" });
    }

    // Check if the contact is already added
    const [existingRows] = await connection.execute(
      "SELECT * FROM contacts WHERE user_id = ? AND contact_id = ?",
      [userId, contactId]
    );
    if (existingRows.length > 0) {
      return res.status(400).json({ error: "Contact already added" });
    }

    // Add the contact
    await connection.execute(
      "INSERT INTO contacts (user_id, contact_id) VALUES (?, ?)",
      [userId, contactId]
    );

    res.status(201).json({ message: "Contact added successfully" });
  } catch (error) {
    console.error("Error adding contact:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});



// Fetch user information route
app.get("/api/users/:userId", async (req, res) => {
  const { userId } = req.params;
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];

  let connection;
  try {
    jwt.verify(token, process.env.JWT_SECRET);

    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [rows] = await connection.execute(
      `
      SELECT u.id, u.username, up.picture_id
      FROM users u
      LEFT JOIN users_pictures up ON u.id = up.user_id
      WHERE u.id = ?
    `,
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = {
      id: rows[0].id,
      username: rows[0].username,
      avatarUrl: rows[0].picture_id
        ? `/api/profile-picture/${rows[0].id}`
        : null,
    };

    res.status(200).json(user);
  } catch (error) {
    log(LOG_LEVELS.ERROR,"Error fetching user information:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

function broadcastOnlineStatus() {
  const onlineUsersList = Array.from(onlineUsers.keys());
  io.emit('online_users', onlineUsersList);
  
  // Adicionando o console.log para informar os usuários online
  console.log(`Usuários online: ${onlineUsersList.join(', ')}`);
}

// Enviar atualizações a cada 30 segundos
setInterval(broadcastOnlineStatus, 30000);

let connectedClients = 0;
// Lógica do Socket.io
io.on("connection", (socket) => {
  let userId;
  connectedClients++;
  log(LOG_LEVELS.INFO,`Novo cliente conectado. Total de clientes: ${connectedClients}`);

  socket.on('login', (data) => {
    userId = data.userId;
    updateUserActivity(userId);
    io.emit('userStatusChanged', { userId, isOnline: true });
  });

  socket.on("authenticate", async (token) => {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      userId = decoded.userId;
      socket.userId = userId;

      onlineUsers.set(userId, socket.id);
      updateUserActivity(userId);
      
      socket.broadcast.emit('userStatusChanged', { userId, isOnline: true });

      const oldMessages = await getMessages(userId);
      socket.emit("old_messages", oldMessages);

      const onlineUsersList = Array.from(onlineUsers.keys());
      socket.emit('online_users', onlineUsersList);

    } catch (error) {
      log(LOG_LEVELS.ERROR, "Authentication error:", error);
      socket.disconnect();
    }
  });

  socket.on('disconnect', () => {
    if (userId) {
      onlineUsers.delete(userId);
      io.emit('userStatusChanged', { userId, isOnline: false });
    }
  });

  socket.on('updateActivity', () => {
    if (userId) {
      updateUserActivity(userId);
    }
  });

  socket.on('message', async (msg) => {
  
    if (msg.text && msg.text.length > 50000) {
      socket.emit("message_error", "Mensagem excede o limite de 50.000 caracteres");
      log(LOG_LEVELS.INFO,`Mensagem bloqueada (tamanho: ${msg.text.length} caracteres)`);
      return;
    }
  
    if (!socket.userId) {
      log(LOG_LEVELS.ERROR,"Erro: userId não definido");
      return;
    }
  
    const timestamp = new Date().toISOString();
  
    // Salvar a mensagem no banco de dados
    await saveMessage(socket.userId, msg.to, msg.content);
  
    const messageWithSender = {
      is_sender: false,
      content: msg.content,
      other_user_id: socket.userId,
      timestamp: timestamp
    };
  
    // Enviar a mensagem apenas para os outros clientes
    socket.broadcast.emit('message', messageWithSender);
  });
});

app.get("/api/user-status/:userId", (req, res) => {
  const { userId } = req.params;
  const isOnline = onlineUsers.has(userId) && (Date.now() - lastActivityTime.get(userId) <= 60000);
  res.json({ userId, isOnline });
});

app.post("/api/bulk-user-status", async (req, res) => {
  const { userIds } = req.body;
  const statuses = {};
  userIds.forEach(userId => {
    statuses[userId] = onlineUsers.has(userId);
  });
  res.json(statuses);
});

// Catch-all route for undefined routes
app.use((req, res, next) => {
  res.status(404).json({
    error: "Not Found",
    message: `The requested resource ${req.url} was not found on this server.`,
  });
  log(LOG_LEVELS.INFO,`404 Not Found: ${req.method} ${req.url}`);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
