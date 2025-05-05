// server.js
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors()); // Enable CORS
app.use(express.static('../build/contracts')); // Adjust if ABI is somewhere else

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`✅ ABI server running at http://localhost:${PORT}`);
});