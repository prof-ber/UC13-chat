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
import path from "path";
import fs from "fs/promises";

// Ensure upload directory exists
const uploadDir = path.join(process.cwd(), "uploads");
await fs.mkdir(uploadDir, { recursive: true });

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/"); // Make sure this directory exists
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + "-" + file.originalname);
  },
});

const fileFilter = (req, file, cb) => {
  console.log("Received file:", file);
  console.log("File mimetype:", file.mimetype);
  console.log("File original name:", file.originalname);

  // Expanded list of accepted mimetypes
  const acceptedMimeTypes = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "video/mp4",
    "video/quicktime",
    "application/octet-stream", // For unknown binary data
  ];

  if (acceptedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    console.log(`Rejected file: ${file.originalname} (${file.mimetype})`);
    cb(new Error(`Unsupported file type: ${file.mimetype}`), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB file size limit
  },
});

dotenv.config();
uuidv4(); // Gera um ID único para o usuário

const SERVER_IP = process.env.SERVER_IP || "localhost";

async function login(username, password) {
  try {
    const response = await fetch(`http://${SERVER_IP}:3000/api/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        nome: username,
        senha: password,
      }),
    });

    if (response.ok) {
      const data = await response.json();
      console.log("Login efetuado com sucesso!");
      return data;
    } else {
      const errorData = await response.json();
      console.error("Falha ao efetuar login:", errorData.message);
      throw new Error(errorData.message);
    }
  } catch (error) {
    console.error("Erro ao fazer login:", error);
    throw error;
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

app.use(cors(corsOptions)); // Enable CORS for all routes
app.use(express.json());
app.use(express.json({ limit: "15MB" }));
app.use(express.urlencoded({ limit: "15MB", extended: true }));
app.use(cors());
app.use("/uploads", express.static("uploads"));

app.options("*", cors(corsOptions)); // Enable pre-flight requests for all routes

// Log middleware to request sizes
app.use((req, res, next) => {
  const contentLength = req.headers["content-length"];
  console.log(
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

    console.log("Sessions table created or already exists");
    connection.end();
  } catch (error) {
    console.error("Error creating sessions table:", error);
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
    console.log("Generating JWT token...");
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "24h",
    });
    console.log("JWT token generated successfully");

    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    console.log("Creating new session...");
    await connection.execute(
      "INSERT INTO sessions (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)",
      [sessionId, user.id, token, expiresAt]
    );
    console.log("New session created successfully");

    connection.end();

    console.log("Login successful");
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

// Profile picture upload route
app.put("/api/profile-picture", upload.single("image"), async (req, res) => {
  console.log("PUT request received for profile picture");
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    if (!req.file) {
      return res.status(400).json({ error: "Foto de perfil é obrigatória" });
    }

    console.log("Received image data length:", req.file.buffer.length);

    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    await connection.beginTransaction();

    try {
      const [pictureResult] = await connection.execute(
        "INSERT INTO pictures (pictures_data) VALUES (?)",
        [req.file.buffer]
      );
      const pictureId = pictureResult.insertId;

      const [existingPicture] = await connection.execute(
        "SELECT picture_id FROM users_pictures WHERE user_id = ?",
        [userId]
      );

      if (existingPicture.length > 0) {
        await connection.execute(
          "UPDATE users_pictures SET picture_id = ? WHERE user_id = ?",
          [pictureId, userId]
        );
      } else {
        await connection.execute(
          "INSERT INTO users_pictures (user_id, picture_id) VALUES (?, ?)",
          [userId, pictureId]
        );
      }

      await connection.commit();

      res.status(200).json({
        message: "Foto de perfil atualizada com sucesso",
        imageUrl: `/api/profile-picture/${userId}`,
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.end();
    }
  } catch (error) {
    console.error("Erro ao atualizar a foto de perfil:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  }
});

// Get profile picture route
app.get("/api/profile-picture/:userId", async (req, res) => {
  const { userId } = req.params;
  console.log(`Received request for profile picture of user: ${userId}`);
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
      console.log(`No profile picture found for user: ${userId}`);
      return res.status(200).json({ message: "No profile picture found" });
    }

    const imageBuffer = rows[0].pictures_data;

    if (!imageBuffer) {
      console.log(`Invalid profile picture data for user: ${userId}`);
      return res
        .status(200)
        .json({ message: "Profile picture data is invalid" });
    }

    console.log(`Sending profile picture for user: ${userId}`);
    res.writeHead(200, {
      "Content-Type": "image/jpeg",
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
    console.error("Error fetching contacts:", error);
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
    console.error("Error fetching user information:", error);
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

// Envio de fotos e vídeos (acesso a galeria)
app.post("/api/upload", upload.single("file"), async (req, res) => {
  console.log("Upload route hit");
  console.log("Request file:", req.file);
  console.log("Request body:", req.body);
  console.log("Request headers:", req.headers);
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];
  let connection;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    if (!req.file) {
      return res.status(400).json({ error: "Nenhum arquivo enviado" });
    }

    const fileInfo = {
      filename: req.file.filename,
      originalName: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
      userId: userId,
    };

    // Determine file type
    const fileType = fileInfo.mimetype.startsWith("image/") ? "image" : "video";

    // Save fileInfo to your database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [result] = await connection.execute(
      "INSERT INTO files (filename, original_name, mimetype, size, user_id, file_type) VALUES (?, ?, ?, ?, ?, ?)",
      [
        fileInfo.filename,
        fileInfo.originalName,
        fileInfo.mimetype,
        fileInfo.size,
        fileInfo.userId,
        fileType,
      ]
    );

    const fileUrl = `/uploads/${fileInfo.filename}`;

    res.status(200).json({
      message: "Arquivo enviado com sucesso",
      file: {
        ...fileInfo,
        id: result.insertId,
        url: fileUrl,
        type: fileType,
      },
    });
  } catch (error) {
    console.error("Erro ao enviar o arquivo:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    res.status(500).json({
      message: "Internal server error",
      error: error.message,
      stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
    });
  } finally {
    if (connection) {
      await connection.end();
    }
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

// Catch-all route for undefined routes
app.use((req, res, next) => {
  res.status(404).json({
    error: "Not Found",
    message: `The requested resource ${req.url} was not found on this server.`,
  });
  console.log(`404 Not Found: ${req.method} ${req.url}`);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
