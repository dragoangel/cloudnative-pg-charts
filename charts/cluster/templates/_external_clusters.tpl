{{- define "cluster.externalClusters" -}}
{{- if or (eq (include "cluster.recovery.enabled" .) "true") (gt (len .Values.externalClusters) 0) }}
{{- include "cluster.externalClusters.validate" . }}
externalClusters:
{{- with .Values.externalClusters }}
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if and (eq (include "cluster.recovery.enabled" .) "true") (eq .Values.recovery.method "objectStorage") }}
  {{- if eq .Values.replica.topology "distributed" }}
  - name: {{ include "cluster.fullname" . }}
    {{- if (eq (include "cluster.barman.integrationType" .) "plugin") }}
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: {{ include "cluster.objectStore.backup.name" . }}
        serverName: {{ include "cluster.fullname" . }}
    {{- else if (eq (include "cluster.barman.integrationType" .) "buildin") }}
    barmanObjectStore:
      serverName: {{ include "cluster.fullname" . }}
      {{- $d := dict "chartFullname" (include "cluster.fullname" .) "scope" .Values.backups.objectStorage "secretPrefix" "backup" "existingSecret" .Values.backups.existingSecret }}
      {{- include "cluster.barmanObjectStoreConfig" $d | indent 6 }}
    {{- end }}
  {{- end }}
  - name: {{ include "cluster.replica.source" . }}
    {{- if (eq (include "cluster.barman.integrationType" .) "plugin") }}
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: {{ include "cluster.objectStore.recovery.name" . }}
        serverName: {{ default (include "cluster.fullname" .) .Values.recovery.methodSettings.objectStorage.clusterName }}
    {{- else if (eq (include "cluster.barman.integrationType" .) "buildin") }}
    barmanObjectStore:
      serverName: {{ default (include "cluster.fullname" .) .Values.recovery.methodSettings.objectStorage.clusterName }}
      {{- $d := dict "chartFullname" (include "cluster.fullname" .) "scope" .Values.recovery.methodSettings.objectStorage "secretPrefix" "recovery" "existingSecret" .Values.recovery.existingSecret }}
      {{- include "cluster.barmanObjectStoreConfig" $d | indent 6 }}
    {{- end }}
{{- else if and (eq (include "cluster.recovery.enabled" .) "true") (eq .Values.recovery.method "pgBasebackup") }}
  - name: {{ include "cluster.replica.source" . }}
    connectionParameters:
      host: {{ required ".Values.recovery.methodSettings.pgBasebackup.connectionParameters.host is required, but not specified." .Values.recovery.methodSettings.pgBasebackup.connectionParameters.host }}
      port: {{ required ".Values.recovery.methodSettings.pgBasebackup.connectionParameters.port is required, but not specified." (.Values.recovery.methodSettings.pgBasebackup.connectionParameters.port | quote) }}
      user: {{ required ".Values.recovery.methodSettings.pgBasebackup.connectionParameters.user is required, but not specified." .Values.recovery.methodSettings.pgBasebackup.connectionParameters.user }}
      {{- with .Values.recovery.methodSettings.pgBasebackup.connectionParameters.sslMode }}
      sslmode: {{ . }}
      {{- end }}
      {{- if and (or (eq .Values.mode "recovery") (eq .Values.mode "import")) (not (empty .Values.recovery.methodSettings.pgBasebackup.connectionParameters.database)) }}
      dbname: {{ default .Values.recovery.methodSettings.pgBasebackup.database .Values.recovery.methodSettings.pgBasebackup.connectionParameters.database }}
      {{- else if or (eq .Values.mode "replica") (eq .Values.mode "import") }}
      dbname: postgres
      {{- end }}
  {{- $secretName := coalesce .Values.recovery.existingSecret.name (printf "%s-recovery-creds-pgbb" (include "cluster.fullname" .)) }}
  {{- if eq .Values.recovery.methodSettings.auth "password" }}
    password:
      name: {{ printf $secretName }}
      key: password
  {{- else if eq .Values.recovery.methodSettings.auth "tls" }}
    sslKey:
      name: {{ printf $secretName }}
      key: tls.key
    sslCert:
      name: {{ printf $secretName }}
      key: tls.crt
    sslRootCert:
      name: {{ printf $secretName }}
      key: ca.crt
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
