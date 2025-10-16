{{- define "cluster.plugins" -}}
{{- if and (eq (include "cluster.barman.integrationType" .) "plugin") (eq (include "cluster.backups.objectStorage.enabled" .) "true") }}
{{- $isWALArchiver := eq (include "cluster.backups.objectStorage.walArchiverEnabled" .) "true" }}
plugins:
  - name: barman-cloud.cloudnative-pg.io
    enabled: true
    isWALArchiver: {{ $isWALArchiver }}
    parameters:
      barmanObjectName: {{ include "cluster.objectStore.backup.name" . }}
{{- end }}
{{- end -}}
