import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  UseInterceptors
} from '@nestjs/common';
import { IncidentsService } from './incidents.service';
import { CreateIncidentDto } from './dto/incident.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { AdminAuditInterceptor } from '../../common/interceptors/admin-audit.interceptor';
import { AdminPermission } from '@secure-messenger/shared-types';

@Controller('admin/incidents')
@UseGuards(AdminAuthGuard)
@UseInterceptors(AdminAuditInterceptor)
export class IncidentsController {
  constructor(private readonly incidentsService: IncidentsService) {}

  @Get()
  @RequirePermissions(AdminPermission.AUDIT_READ)
  list() {
    return this.incidentsService.listIncidents();
  }

  @Post()
  @RequirePermissions(AdminPermission.INCIDENT_CONTAIN_ACCOUNT)
  create(@Body() dto: CreateIncidentDto) {
    return this.incidentsService.createIncident(dto);
  }

  @Post(':id/contain')
  @RequirePermissions(AdminPermission.INCIDENT_CONTAIN_DEVICE)
  contain(
    @Param('id') incidentId: string,
    @Body('wipeApplicationData') wipeAppData?: boolean
  ) {
    return this.incidentsService.containIncident(incidentId, !!wipeAppData);
  }

  @Post(':id/restore')
  @RequirePermissions(AdminPermission.INCIDENT_CONTAIN_DEVICE)
  restore(@Param('id') incidentId: string) {
    return this.incidentsService.restoreIncident(incidentId);
  }
}
