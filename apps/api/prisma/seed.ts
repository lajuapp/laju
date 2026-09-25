import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const permissions = [
  { slug: 'conversation.metadata.read', description: 'Read conversation metadata' },
  { slug: 'conversation.content.request', description: 'Request access to conversation plaintext' },
  { slug: 'conversation.content.approve', description: 'Approve access request to conversation plaintext' },
  { slug: 'location.read.coarse', description: 'Read coarse location' },
  { slug: 'location.read.precise', description: 'Read precise location' },
  { slug: 'location.export', description: 'Export location trails' },
  { slug: 'device.revoke', description: 'Revoke device access' },
  { slug: 'user.suspend', description: 'Suspend user account' },
  { slug: 'incident.contain.account', description: 'Contain account in incident' },
  { slug: 'incident.contain.device', description: 'Contain device in incident' },
  { slug: 'incident.wipe.application_data', description: 'Order wipe of application encrypted data' },
  { slug: 'call.metadata.read', description: 'Read call metadata' },
  { slug: 'audit.read', description: 'Read audit logs' },
  { slug: 'retention.manage', description: 'Manage retention policies' },
  { slug: 'admin_role.manage', description: 'Manage admin roles and permissions' }
];

const roles = [
  {
    name: 'Super Admin',
    description: 'Universal administrative control',
    permissions: permissions.map((p) => p.slug)
  },
  {
    name: 'Security Admin',
    description: 'Security and incident containment specialist',
    permissions: [
      'incident.contain.account',
      'incident.contain.device',
      'incident.wipe.application_data',
      'device.revoke',
      'user.suspend',
      'audit.read'
    ]
  },
  {
    name: 'Conversation Investigator',
    description: 'Authorized investigator for sensitive conversations',
    permissions: [
      'conversation.metadata.read',
      'conversation.content.request',
      'audit.read'
    ]
  },
  {
    name: 'Auditor',
    description: 'Compliance and security audit',
    permissions: ['audit.read', 'conversation.metadata.read', 'call.metadata.read']
  }
];

async function main() {
  console.log('Seeding permissions...');
  for (const perm of permissions) {
    await prisma.adminPermission.upsert({
      where: { slug: perm.slug },
      update: { description: perm.description },
      create: perm
    });
  }

  console.log('Seeding roles...');
  let superAdminRoleId = '';
  for (const role of roles) {
    const createdRole = await prisma.adminRole.upsert({
      where: { name: role.name },
      update: { description: role.description },
      create: { name: role.name, description: role.description }
    });

    if (role.name === 'Super Admin') {
      superAdminRoleId = createdRole.id;
    }

    for (const permSlug of role.permissions) {
      const perm = await prisma.adminPermission.findUnique({ where: { slug: permSlug } });
      if (perm) {
        await prisma.adminRolePermission.upsert({
          where: {
            roleId_permissionId: {
              roleId: createdRole.id,
              permissionId: perm.id
            }
          },
          update: {},
          create: {
            roleId: createdRole.id,
            permissionId: perm.id
          }
        });
      }
    }
  }

  console.log('Seeding initial Super Admin user...');
  if (superAdminRoleId) {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash('admin12345', salt);

    await prisma.adminUser.upsert({
      where: { username: 'admin' },
      update: { roleId: superAdminRoleId, isActive: true },
      create: {
        username: 'admin',
        email: 'admin@laju.chat',
        name: 'System Administrator',
        passwordHash,
        roleId: superAdminRoleId,
        isActive: true
      }
    });
  }

  console.log('Seeding default wallpapers...');
  const defaultWallpapers = [
    { name: 'Default Minimalist', category: 'SOLID', colorHex: '#0F172A', isDefault: true, sortOrder: 1 },
    { name: 'Warm Amber Sand', category: 'SOLID', colorHex: '#78350F', isDefault: false, sortOrder: 2 },
    { name: 'Emerald Forest', category: 'SOLID', colorHex: '#064E3B', isDefault: false, sortOrder: 3 },
    { name: 'Deep Midnight Slate', category: 'GRADIENT', colorHex: '#1E1B4B', isDefault: false, sortOrder: 4 }
  ];
  for (const wp of defaultWallpapers) {
    const existing = await prisma.chatWallpaper.findFirst({ where: { name: wp.name } });
    if (!existing) {
      await prisma.chatWallpaper.create({ data: wp });
    }
  }

  console.log('Seeding default sticker pack...');
  const catPack = await prisma.stickerPack.upsert({
    where: { id: 'pack-cat-vibes' },
    update: {},
    create: {
      id: 'pack-cat-vibes',
      name: 'Cat Vibes Official',
      description: 'Stiker kucing ekspresif dan lucu untuk obrolan harian',
      publisher: 'LAJU Creative Team',
      coverUrl: '/assets/stickers/cat_cheer.png',
      sortOrder: 1,
      isActive: true,
      stickers: {
        create: [
          { name: 'Cat Thumbs Up', imageUrl: '/assets/stickers/cat_thumbs_up.png', emoji: '👍' },
          { name: 'Cat Cool', imageUrl: '/assets/stickers/cat_cool.png', emoji: '😎' },
          { name: 'Cat Cheer', imageUrl: '/assets/stickers/cat_cheer.png', emoji: '🎉' }
        ]
      }
    }
  });

  console.log('Database seeded successfully.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
