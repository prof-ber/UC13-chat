document.addEventListener("DOMContentLoaded", () => {
  const socket = io("http://localhost:3000"); // Connect to the server

  const messageInput = document.getElementById("message-input");
  const sendButton = document.getElementById("send-button");

  sendButton.addEventListener("click", () => {
    const message = messageInput.value;
    if (message) {
      socket.emit("message", message); // Send the "message" event to the server
      messageInput.value = ""; // Clear the input field
    }
  });
});
