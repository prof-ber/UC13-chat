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
import sizeOf from "image-size";
import { fileTypeFromBuffer } from "file-type";
import { fileURLToPath } from "url";
import fs from "fs";
import { exec } from "child_process";
const upload = multer({ storage: multer.memoryStorage() });
dotenv.config();
uuidv4(); // Gera um ID único para o usuário

const SERVER_IP = process.env.SERVER_IP || "localhost";
const baseUrl = process.env.SERVER_URL || "http://localhost:3000";

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

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Define uploadsPath here
const uploadsPath = path.join(__dirname, "uploads");

app.use(cors(corsOptions)); // Enable CORS for all routes
app.use(express.json());
app.use(express.json({ limit: "15MB" }));
app.use(express.urlencoded({ limit: "15MB", extended: true }));
app.use(cors());

app.use(
  "/uploads",
  (req, res, next) => {
    const filePath = path.join(uploadsPath, req.url);
    const filename = path.basename(req.url);
    const imageUrl = `${baseUrl}/uploads/${encodeURIComponent(filename)}`;
    fs.access(filePath, fs.constants.R_OK, (err) => {
      if (err) {
        console.error(`Error accessing file ${filePath}:`, err);
        res.header("Access-Control-Allow-Origin", "*");
        res.header(
          "Access-Control-Allow-Headers",
          "Origin, X-Requested-With, Content-Type, Accept"
        );
        return res.status(404).send("File not found");
      }
      next();
    });
  },
  express.static(uploadsPath)
);

// Add this middleware after your static file serving setup
app.use(
  "/uploads",
  (req, res, next) => {
    const filePath = path.join(uploadsPath, req.url);
    fs.access(filePath, fs.constants.R_OK, (err) => {
      if (err) {
        console.error(`Error accessing file ${filePath}:`, err);
        return res.status(404).send("File not found");
      }
      next();
    });
  },
  express.static(uploadsPath)
);
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

// Função para salvar mensagem no banco de dados
async function saveMessage(senderId, receiverId, content) {
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
      "INSERT INTO messages (id, content) VALUES (?, ?)",
      [messageId, content]
    );

    // Associar a mensagem ao remetente
    await connection.execute(
      "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)",
      [senderId, messageId, true]
    );

    // Associar a mensagem ao destinatário (se não for 'All')
    if (receiverId !== "All") {
      await connection.execute(
        "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?)",
        [receiverId, messageId, false]
      );
    }

    await connection.commit();
    console.log("Message saved to database");
  } catch (error) {
    await connection.rollback();
    console.error("Error saving message to database:", error);
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
    console.error("Error retrieving messages from database:", error);
    return [];
  } finally {
    await connection.end();
  }
}

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

// Envio de fotos e vídeos (acesso a galeria)
app.post("/api/upload", upload.single("file"), async (req, res) => {
  console.log("Upload route hit");
  console.log("Request file:", req.file);
  console.log("Request body:", req.body);
  console.log("Request headers:", req.headers);

  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  console.log("File MIME type:", req.file.mimetype);
  console.log("File size:", req.file.size);

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

    // Detect file type
    const fileTypeResult = await fileTypeFromBuffer(req.file.buffer);
    const detectedMimeType = fileTypeResult
      ? fileTypeResult.mime
      : "application/octet-stream";

    // File type check
    const allowedTypes = [
      "image/jpeg",
      "image/png",
      "image/gif",
      "video/mp4",
      "application/octet-stream",
    ];
    if (!allowedTypes.includes(detectedMimeType)) {
      return res.status(400).json({ error: "Tipo de arquivo não permitido" });
    }

    // Sanitize filename
    const sanitizeFilename = (filename) => {
      const sanitized = path.basename(filename);
      return sanitized
        .replace(/[^a-zA-Z0-9_.-]/g, "_")
        .replace(/^\.+/, "")
        .slice(0, 255);
    };

    // Prepare file info
    const fileInfo = {
      filename: sanitizeFilename(req.file.originalname),
      originalName: req.file.originalname,
      mimetype: detectedMimeType,
      size: req.file.size,
      userId: userId,
    };

    const filePath = path.join(uploadsPath, fileInfo.filename);
    await fs.promises.writeFile(filePath, req.file.buffer);
    console.log("File saved to:", filePath);
    console.log("File exists after save:", fs.existsSync(filePath));

    // Determine file type
    const fileExtension = path.extname(fileInfo.originalName).toLowerCase();
    const fileType = [".jpg", ".jpeg", ".png", ".gif"].includes(fileExtension)
      ? "image"
      : "video";

    // Get image dimensions if it's an image
    let width, height;
    if (fileType === "image") {
      try {
        const dimensions = await getImageDimensions(filePath);
        width = dimensions.width;
        height = dimensions.height;
      } catch (error) {
        console.error("Error getting image dimensions:", error);
        width = null;
        height = null;
      }
    } else if (fileType === "video") {
      try {
        const dimensions = await getVideoDimensions(filePath);
        width = dimensions.width;
        height = dimensions.height;
      } catch (error) {
        console.error("Error getting video dimensions:", error);
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
function getImageDimensions(filePath) {
  console.log("File path:", filePath);
  console.log("File exists:", fs.existsSync(filePath));
  return new Promise((resolve, reject) => {
    fs.readFile(filePath, (err, buffer) => {
      if (err) {
        reject(err);
        return;
      }
      try {
        const dimensions = sizeOf(buffer);
        resolve(dimensions);
      } catch (error) {
        console.error("Error in sizeOf:", error);
        reject(error);
      }
    });
  });
}

// Function for video dimensions
function getVideoDimensions(filePath) {
  return new Promise((resolve, reject) => {
    exec(
      `ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=width,height -of json "${filePath}"`,
      (error, stdout, stderr) => {
        if (error) {
          console.error(`Error executing ffprobe: ${error}`);
          reject(error);
          return;
        }
        try {
          const data = JSON.parse(stdout);
          const dimensions = {
            width: parseInt(data.streams[0].width),
            height: parseInt(data.streams[0].height),
          };
          resolve(dimensions);
        } catch (parseError) {
          console.error(`Error parsing ffprobe output: ${parseError}`);
          reject(parseError);
        }
      }
    );
  });
}

// File messages route
async function uploadFileMessages(token, receiverId, fileId) {
  let connection;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const senderId = decoded.userId;

    if (!receiverId || !fileId) {
      throw new Error("receiverId and fileId are required");
    }

    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
    });

    // Fetch the file information
    const [fileRows] = await connection.execute(
      "SELECT id, filename, original_name, mimetype, size, file_type, width, height FROM files WHERE id = ?",
      [fileId]
    );

    if (fileRows.length === 0) {
      throw new Error("File not found");
    }

    const fileInfo = fileRows[0];

    // Insert the file message
    const messageId = uuidv4();
    const timestamp = new Date().toISOString();
    const messageContent = JSON.stringify({
      type: "file",
      fileId,
      fileInfo: {
        ...fileInfo,
        url: `${process.env.SERVER_URL}/uploads/${fileInfo.filename}`,
      },
    });

    await connection.execute(
      "INSERT INTO messages (id, content, timestamp) VALUES (?, ?, NOW())",
      [messageId, messageContent]
    );

    // Link the message to users
    await connection.execute(
      "INSERT INTO users_messages (user_id, message_id, is_sender) VALUES (?, ?, ?), (?, ?, ?)",
      [senderId, messageId, 1, receiverId, messageId, 0]
    );

    // Insert into file_messages table
    await connection.execute(
      "INSERT INTO file_messages (id, message_id, file_id, original_name, file_type, file_size, width, height) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [
        uuidv4(),
        messageId,
        fileId,
        fileInfo.original_name,
        fileInfo.file_type,
        fileInfo.size,
        fileInfo.width,
        fileInfo.height,
      ]
    );

    // Prepare the message object
    const message = {
      id: messageId,
      senderId,
      receiverId,
      content: messageContent,
      timestamp: timestamp,
    };

    return message;
  } catch (error) {
    console.error("Error sending file message:", error);
    throw error;
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Add the route for file messages
app.post("/api/file-messages", upload.none(), uploadFileMessages);

// Lógica do Socket.io
io.on("connection", (socket) => {
  console.log("Novo cliente conectado");

  socket.on("authenticate", async (token) => {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId;
      socket.userId = userId;
      socket.join(userId); // Join a room with the user's ID

      // Enviar mensagens antigas para o usuário
      const oldMessages = await getMessages(userId);
      socket.emit("old_messages", oldMessages);
    } catch (error) {
      console.error("Authentication error:", error);
      socket.disconnect();
    }
  });

  socket.on("file_message", async (msg) => {
    if (!socket.userId) {
      console.error("Erro: userId não definido");
      return;
    }

    try {
      const message = await uploadFileMessages(
        msg.token,
        msg.receiverId,
        msg.fileId
      );

      // Emit the message to the sender and receiver
      io.to(socket.userId).emit("file_message", {
        ...message,
        is_sender: true,
      });
      io.to(message.receiverId).emit("file_message", {
        ...message,
        is_sender: false,
      });
    } catch (error) {
      console.error("Error sending file message:", error);
      socket.emit("message_error", error.message);
    }
  });

  socket.on("disconnect", () => {
    console.log("Cliente desconectado");
  });

  socket.on("message", async (msg) => {
    if (msg.text && msg.text.length > 50000) {
      socket.emit(
        "message_error",
        "Mensagem excede o limite de 50.000 caracteres"
      );
      console.log(
        `Mensagem bloqueada (tamanho: ${msg.text.length} caracteres)`
      );
      return;
    }

    if (!socket.userId) {
      console.error("Erro: userId não definido");
      return;
    }

    const timestamp = new Date().toISOString();

    // Salvar a mensagem no banco de dados
    await saveMessage(socket.userId, msg.to, msg.content);

    const messageWithSender = {
      is_sender: false,
      content: msg.content,
      other_user_id: socket.userId,
      timestamp: timestamp,
    };

    // Enviar a mensagem apenas para os outros clientes
    socket.broadcast.emit("message", messageWithSender);

    // Removido: Não enviar a mensagem de volta para o remetente
    // socket.emit('message', {
    //   ...messageWithSender,
    //   is_sender: true
    // });
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
