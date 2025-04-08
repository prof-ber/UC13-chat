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
import sizeOf from "image-size";
import mime from "mime-types";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "24h",
    });
    console.log("JWT token generated successfully");

    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

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

// Função para salvar as mensagens no banco de dados
async function saveMessage(senderId, receiverId, content) {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  try {
    await connection.beginTransaction();

    const messageId = uuidv4();
    let messageContent;

    console.log("Saving message with content:", content);

    if (typeof content === "object" && content.fileUrl) {
      // This is a file message
      messageContent = JSON.stringify({
        type: "file",
        fileUrl: content.fileUrl,
        fileType: content.fileType || null,
        width: content.width || null,
        height: content.height || null,
      });
    } else {
      // This is a text message
      messageContent = content || "";
    }

    console.log("Prepared message content:", messageContent);

    await connection.execute(
      "INSERT INTO messages (id, content) VALUES (?, ?)",
      [messageId, messageContent]
    );

    console.log("Message inserted into messages table");

    // Associar a mensagem ao remetente
    await connection.execute(
      "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)",
      [senderId, messageId, 1]
    );

    console.log("Message associated with sender");

    // Associar a mensagem ao destinatário (se não for 'All')
    if (receiverId !== "All") {
      await connection.execute(
        "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)",
        [receiverId, messageId, 0]
      );
      console.log("Message associated with receiver");
    }

    await connection.commit();
    console.log("Message saved to database successfully");
    return messageId;
  } catch (error) {
    await connection.rollback();
    console.error("Error saving message to database:", error);
    throw error;
  } finally {
    await connection.end();
  }
}

// Lógica do Socket.io
io.on("connection", (socket) => {
  console.log("Novo cliente conectado");

  socket.on("authenticate", async (token) => {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId;
      socket.userId = userId;

      // Enviar mensagens antigas para o usuário
      const oldMessages = await getMessages(userId);
      socket.emit("old_messages", oldMessages);
    } catch (error) {
      console.error("Authentication error:", error);
      socket.disconnect();
    }
  });

  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });

  socket.on("message", async (msg) => {
    console.log("Mensagem recebida:", msg);

    if (!socket.userId) {
      console.error("Erro: userId não definido");
      return;
    }

    const timestamp = new Date().toISOString();

    let content;
    if (msg.fileUrl) {
      content = {
        fileUrl: msg.fileUrl,
        fileType: msg.fileType || "unknown",
        width: msg.width,
        height: msg.height,
      };
    } else {
      content = msg.text || "";
    }

    try {
      // Salvar a mensagem no banco de dados
      const messageId = await saveMessage(socket.userId, msg.to, content);

      const messageWithSender = {
        id: messageId,
        is_sender: false,
        content: content,
        other_user_id: socket.userId,
        timestamp: timestamp,
      };

      // Enviar a mensagem apenas para os outros clientes
      socket.broadcast.emit("message", messageWithSender);
    } catch (error) {
      console.error("Error processing message:", error);
      socket.emit("message_error", "Erro ao processar a mensagem");
    }
  });
});
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
    console.error("Error retrieving messages from database:", error);
    return [];
  } finally {
    await connection.end();
  }
}

// Envio de fotos e vídeos (acesso a galeria)
app.post("/api/upload", upload.single("file"), async (req, res) => {
  console.log("Upload route hit");
  console.log("Request file:", req.file);
  console.log("Request body:", req.body);
  console.log("Request headers:", req.headers);
  console.log("File received:", req.file);

  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  // Authentication check
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }
  const token = authHeader.split(" ")[1];

  let connection;
  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;

    // File size check
    if (req.file.size > 50 * 1024 * 1024) {
      return res
        .status(400)
        .json({ error: "Arquivo muito grande. Limite de 50MB." });
    }

    // File type check
    const allowedTypes = ["image/jpeg", "image/png", "image/gif", "video/mp4"];
    if (!allowedTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: "Tipo de arquivo não permitido" });
    }

    // Sanitize filename
    const sanitizeFilename = (filename) => {
      // Remove any directory traversal attempts
      const sanitized = path.basename(filename);

      // Remove or replace potentially dangerous characters
      return (
        sanitized
          .replace(/[^a-zA-Z0-9_.-]/g, "_")
          // Ensure the filename doesn't start with a dot (hidden file)
          .replace(/^\.+/, "")
          // Limit the length of the filename
          .slice(0, 255)
      );
    };

    // Prepare file info
    const fileInfo = {
      filename: sanitizeFilename(req.file.filename),
      originalName: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
      userId: userId,
    };

    // Determine file type
    const fileExtension = path.extname(fileInfo.originalName).toLowerCase();
    const fileType = [".jpg", ".jpeg", ".png", ".gif"].includes(fileExtension)
      ? "image"
      : "video";

    // Get image dimensions if it's an image
    let width, height;
    if (fileType === "image") {
      try {
        const dimensions = await getImageDimensions(req.file.path);
        width = dimensions.width;
        height = dimensions.height;
      } catch (error) {
        console.error("Error getting image dimensions:", error);
        width = null;
        height = null;
      }
    }

    // Database operations
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [result] = await connection.execute(
      "INSERT INTO files (filename, original_name, mimetype, size, user_id, file_type, width, height) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [
        fileInfo.filename,
        fileInfo.originalName,
        fileInfo.mimetype,
        fileInfo.size,
        fileInfo.userId,
        fileType,
        width || null,
        height || null,
      ]
    );

    // Prepare response
    const fileUrl = `${process.env.SERVER_URL}/uploads/${fileInfo.filename}`;
    console.log(`File uploaded: ${fileInfo.filename} (${fileInfo.size} bytes)`);

    const response = {
      message: "Arquivo enviado com sucesso",
      file: {
        ...fileInfo,
        id: result.insertId,
        url: fileUrl,
        type: fileType,
        width,
        height,
      },
    };

    console.log("Sending response:", response);
    res.status(200).json(response);
  } catch (error) {
    console.error("Erro ao enviar o arquivo:", error);
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Token inválido" });
    }
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ error: "Arquivo já existe" });
    }
    res.status(500).json({
      message: "Internal server error",
      error:
        process.env.NODE_ENV === "development"
          ? error.message
          : "An unexpected error occurred",
    });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

// Add this function to get image dimensions
async function getImageDimensions(filePath) {
  try {
    const dimensions = sizeOf(filePath);
    return { width: dimensions.width, height: dimensions.height };
  } catch (error) {
    console.error("Error getting image dimensions:", error);
    return { width: null, height: null };
  }
}

function getFileType(file) {
  const mimeType = mime.lookup(file.originalname) || file.mimetype;
  if (mimeType.startsWith("image/")) {
    return "image";
  } else if (mimeType.startsWith("video/")) {
    return "video";
  } else {
    return "unknown";
  }
}

// File messages route
async function uploadFileMessages(req, res) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];
  let connection;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const senderId = decoded.userId;
    const { receiverId, fileId } = req.body;

    if (!receiverId || !fileId) {
      return res
        .status(400)
        .json({ error: "receiverId and fileId are required" });
    }

    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    // Fetch the file information
    const [fileRows] = await connection.execute(
      "SELECT filename, original_name, mimetype, size FROM files WHERE id = ?",
      [fileId]
    );

    if (fileRows.length === 0) {
      return res.status(404).json({ error: "File not found" });
    }

    const fileInfo = fileRows[0];

    // Insert the file message
    const messageId = uuidv4();
    await connection.execute(
      "INSERT INTO messages (id, content) VALUES (?, ?)",
      [messageId, JSON.stringify({ type: "file", fileId, fileInfo })]
    );

    // Link the message to users
    await connection.execute(
      "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?), (?, ?, ?)",
      [senderId, messageId, 1, receiverId, messageId, 0]
    );

    // Prepare the message object
    const message = {
      id: messageId,
      senderId,
      receiverId,
      content: "File Message",
      fileInfo: {
        id: fileId,
        filename: fileInfo.filename,
        originalName: fileInfo.original_name,
        mimetype: fileInfo.mimetype,
        size: fileInfo.size,
        url: `/api/files/${fileId}`,
      },
      timestamp: new Date().toISOString(),
    };

    // Near the end of the upload route
    console.log("Sending response:", {
      message: "Arquivo enviado com sucesso",
      file: {
        ...fileInfo,
        id: result.insertId,
        url: fileUrl,
        type: fileType,
        width,
        height,
      },
    });

    res.status(200).json({
      message: "Arquivo enviado com sucesso",
      file: {
        ...fileInfo,
        id: result.insertId,
        url: fileUrl,
        type: fileType,
        width,
        height,
      },
    });

    // Emit the message to the receiver
    io.to(receiverId).emit("file_message", message);

    res
      .status(200)
      .json({ message: "File message sent successfully", data: message });
  } catch (error) {
    console.error("Error sending file message:", error);
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
}

// Add the route for file messages
app.post("/api/file-messages", upload.none(), uploadFileMessages);

// Add a new route to serve files
app.get("/api/files/:fileId", async (req, res) => {
  const { fileId } = req.params;
  let connection;

  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    const [fileRows] = await connection.execute(
      "SELECT filename, original_name, mimetype, file_type, width, height FROM files WHERE id = ?",
      [fileId]
    );

    if (fileRows.length === 0) {
      return res.status(404).json({ error: "File not found" });
    }

    const { filename, original_name, mimetype, file_type, width, height } =
      fileRows[0];
    const filePath = path.join(process.cwd(), "uploads", filename);

    // Check if the file exists
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: "File not found on server" });
    }

    const mimeType = mime.lookup(original_name) || mimetype;
    res.setHeader("Content-Type", mimeType);
    res.setHeader("Content-Disposition", `inline; filename="${original_name}"`);

    // Send additional metadata in the response headers
    res.setHeader("X-File-Type", file_type);
    if (width) res.setHeader("X-Image-Width", width);
    if (height) res.setHeader("X-Image-Height", height);

    res.sendFile(filePath, (err) => {
      if (err) {
        console.error("Error sending file:", err);
        res.status(500).json({ error: "Error sending file" });
      }
    });
  } catch (error) {
    console.error("Error serving file:", error);
    res
      .status(500)
      .json({ message: "Internal server error", error: error.message });
  } finally {
    if (connection) {
      await connection.end();
    }
  }
});

// Profile picture upload route
app.put("/api/profile-picture", upload.single("image"), async (req, res) => {
  console.log("Iniciando rota de upload de imagem de perfil");

  const authHeader = req.headers.authorization;
  if (!authHeader) {
    console.log("Token não fornecido");
    return res.status(401).json({ error: "Token não fornecido" });
  }

  const token = authHeader.split(" ")[1];

  try {
    console.log("Verificando token");
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.userId;
    console.log("UserId do token:", userId);

    if (!req.file) {
      console.log("Nenhum arquivo enviado");
      return res.status(400).json({ error: "Foto de perfil é obrigatória" });
    }

    console.log("Tipo MIME do arquivo:", req.file.mimetype);
    console.log("Tamanho do arquivo:", req.file.size);

    if (!req.file.mimetype.startsWith("image/")) {
      console.log("Arquivo não é uma imagem válida");
      return res
        .status(400)
        .json({ error: "O arquivo enviado não é uma imagem válida" });
    }

    console.log("Received image size:", req.file.size);
    console.log("Received image data length:", req.file.buffer.length);

    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    await connection.beginTransaction();

    try {
      console.log("Inserindo imagem no banco de dados");
      const [pictureResult] = await connection.execute(
        "INSERT INTO pictures (pictures_data) VALUES (?)",
        [req.file.buffer]
      );
      const pictureId = pictureResult.insertId;
      console.log("ID da imagem inserida:", pictureId);

      console.log("Verificando se o usuário já tem uma imagem de perfil");
      const [existingPicture] = await connection.execute(
        "SELECT picture_id FROM users_pictures WHERE user_id = ?",
        [userId]
      );

      if (existingPicture.length > 0) {
        console.log("Atualizando imagem de perfil existente");
        await connection.execute(
          "UPDATE users_pictures SET picture_id = ? WHERE user_id = ?",
          [pictureId, userId]
        );
      } else {
        console.log("Inserindo nova imagem de perfil");
        await connection.execute(
          "INSERT INTO users_pictures (user_id, picture_id) VALUES (?, ?)",
          [userId, pictureId]
        );
      }

      await connection.commit();
      console.log("Transação concluída com sucesso");

      res.status(200).json({
        message: "Foto de perfil atualizada com sucesso",
        imageUrl: `/api/profile-picture/${userId}`,
      });
    } catch (error) {
      console.error("Erro durante a transação:", error);
      await connection.rollback();
      throw error;
    } finally {
      connection.end();
    }
  } catch (error) {
    console.error("Erro ao atualizar a foto de perfil:", error);
    console.error("Stack trace:", error.stack);
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
      return res
        .status(200)
        .json({ message: "Profile picture data is invalid" });
    }

    console.log("Image content type:", imageBuffer.type);

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

// Lógica do Socket.io
io.on("connection", (socket) => {
  console.log("Novo cliente conectado");

  socket.on("authenticate", async (token) => {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId;
      socket.userId = userId;

      // Enviar mensagens antigas para o usuário
      const oldMessages = await getMessages(userId);
      socket.emit("old_messages", oldMessages);
    } catch (error) {
      console.error("Authentication error:", error);
      socket.disconnect();
    }
  });

  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });

  socket.on("message", async (msg) => {
    console.log("Mensagem recebida:", msg);

    if (!socket.userId) {
      console.error("Erro: userId não definido");
      socket.emit("message_error", "Usuário não autenticado");
      return;
    }

    if (!msg.to || (typeof msg.text !== "string" && !msg.fileUrl)) {
      console.error("Erro: Mensagem inválida");
      socket.emit("message_error", "Formato de mensagem inválido");
      return;
    }

    const timestamp = new Date().toISOString();

    let content;
    if (msg.fileUrl) {
      content = {
        type: "file",
        fileUrl: msg.fileUrl,
        fileType: msg.fileType || "unknown",
        width: msg.width,
        height: msg.height,
        fileId: msg.fileId, // Add this line to include the file ID
      };
    } else {
      content = {
        type: "text",
        text: msg.text.trim(),
      };
    }

    try {
      // Salvar a mensagem no banco de dados
      const messageId = await saveMessage(socket.userId, msg.to, content);

      const messageWithSender = {
        id: messageId,
        senderId: socket.userId,
        receiverId: msg.to,
        content: content,
        timestamp: timestamp,
      };

      // Enviar a mensagem apenas para o destinatário
      const recipientSocket = io.sockets.sockets.get(msg.to);
      if (recipientSocket) {
        recipientSocket.emit("message", messageWithSender);
      }

      // Confirmar para o remetente que a mensagem foi enviada
      socket.emit("message_sent", { id: messageId, timestamp: timestamp });
    } catch (error) {
      console.error("Error processing message:", error);
      socket.emit(
        "message_error",
        "Erro ao processar a mensagem: " + error.message
      );
    }
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
