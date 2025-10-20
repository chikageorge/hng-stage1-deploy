// app.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('🚀 HNG DevOps Stage 1 Deployment Successful!');
});

app.listen(PORT, () => {
  console.log(`App running on port ${PORT}`);
});