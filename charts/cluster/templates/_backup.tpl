{{- define "cluster.backup" -}}
{{- $volumeSnapshotEnabled := eq (include "cluster.backups.volumeSnapshot.enabled" .) "true" -}}
{{- $barmanBuildinEnabled := and (eq (include "cluster.barman.integrationType" .) "buildin") (eq (include "cluster.backups.objectStorage.enabled" .) "true") -}}
{{- if or $volumeSnapshotEnabled $barmanBuildinEnabled }}
backup:
  {{- if $barmanBuildinEnabled }}
  barmanObjectStore:
    {{- $d := dict "chartFullname" (include "cluster.fullname" .) "scope" .Values.backups.objectStorage "secretPrefix" "backup" "existingSecret" .Values.backups.existingSecret }}
    {{- include "cluster.barmanObjectStoreConfig" $d | indent 4 }}
  {{- if not (empty .Values.backups.objectStorage.retentionPolicy) }}
  retentionPolicy: {{ .Values.backups.objectStorage.retentionPolicy }}
  {{- end }}
  {{- end }}
  {{- if $volumeSnapshotEnabled }}
  volumeSnapshot:
    className: {{ .Values.backups.volumeSnapshot.className }}
    {{- if and .Values.cluster.walStorage.enabled (not (empty .Values.backups.volumeSnapshot.walClassName)) }}
    walClassName: {{ .Values.backups.volumeSnapshot.walClassName }}
    {{- end }}
    online: {{ .Values.backups.volumeSnapshot.online }}
    onlineConfiguration:
      immediateCheckpoint: {{ .Values.backups.volumeSnapshot.onlineConfiguration.immediateCheckpoint }}
      waitForArchive: {{ .Values.backups.volumeSnapshot.onlineConfiguration.waitForArchive }}
    snapshotOwnerReference: {{ .Values.backups.volumeSnapshot.snapshotOwnerReference }}
  target: {{ .Values.backups.volumeSnapshot.target }}
  {{- end }}
{{- end }}
{{- end }}
