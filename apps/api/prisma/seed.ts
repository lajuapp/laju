import { PrismaClient } from '@prisma/client';

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
  for (const role of roles) {
    const createdRole = await prisma.adminRole.upsert({
      where: { name: role.name },
      update: { description: role.description },
      create: { name: role.name, description: role.description }
    });

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
