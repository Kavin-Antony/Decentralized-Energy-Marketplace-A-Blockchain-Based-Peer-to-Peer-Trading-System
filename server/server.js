// server.js
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors()); 
app.use(express.static('../build/contracts')); 

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`✅ ABI server running at http://localhost:${PORT}`);
});