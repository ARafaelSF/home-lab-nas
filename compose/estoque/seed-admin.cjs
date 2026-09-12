"use strict";

const { PrismaClient } = require("@prisma/client");
const bcrypt = require("bcryptjs");

async function main() {
  const prisma = new PrismaClient();
  try {
    const count = await prisma.user.count();
    if (count > 0) {
      console.log("[seed] utilizadores já existem — nada a fazer");
      return;
    }
    const email = process.env.ADMIN_EMAIL;
    const password = process.env.ADMIN_PASSWORD;
    const name = process.env.ADMIN_NAME || "Admin";
    if (!email || !password) {
      throw new Error("ADMIN_EMAIL e ADMIN_PASSWORD são obrigatórios no primeiro arranque");
    }
    const passwordHash = await bcrypt.hash(password, 10);
    await prisma.user.create({
      data: { email, passwordHash, name, role: "ADMIN" },
    });
    console.log("[seed] criado ADMIN", email);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error("[seed] falhou:", err);
  process.exit(1);
});
