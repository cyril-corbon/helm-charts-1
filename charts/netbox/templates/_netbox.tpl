{{- define "netbox.common" -}}
{{- $netboxEnv := include (print $.Template.BasePath "/env-configmap.yaml") . }}
{{- $netboxSecretEnv := include (print $.Template.BasePath "/env-secret.yaml") . }}
selector:
  matchLabels:
    {{- include "netbox.selectorLabels" . | nindent 4 }}
{{- with .Values.statefulSet.updateStrategy }}
updateStrategy:
  {{- toYaml . | nindent 2 }}
{{- end }}
template:
  metadata:
    labels:
      {{- include "netbox.selectorLabels" . | nindent 8 }}
    annotations:
      checksum/config: {{ print "%s%s%s" $netboxEnv $netboxSecretEnv | sha256sum }}
  spec:
  {{- with .Values.imagePullSecrets }}
    imagePullSecrets:
      {{- toYaml . | nindent 6 }}
  {{- end }}
    serviceAccountName: {{ include "netbox.serviceAccountName" . }}
    securityContext:
      {{- toYaml .Values.podSecurityContext | nindent 6 }}
    containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ include "netbox.imageTag" . }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        envFrom:
        - configMapRef:
            name: {{ include "netbox.env.configMapName" . | quote }}
        - secretRef:
          {{- if .Values.existingEnvSecret }}
            name: {{ .Values.existingEnvSecret | quote }}
          {{- else }}
            name: {{ include "netbox.env.secretName" . | quote }}
          {{- end }}
        {{- if not .Values.superuserSkip }}
        - secretRef:
          {{- if .Values.superuserExistingSecret }}
            name: {{ .Values.superuserExistingSecret |quote }}
          {{- else }}
            name: {{ include "netbox.superuser.secretName" . | quote }}
          {{- end }}
            optional: true
        {{- end }}
{{- if or (or .Values.postgresql.enabled .Values.redis.enabled) .Values.redis.existingSecret }}
        env:
{{- if or .Values.postgresql.enabled .Values.postgresql.existingSecret}}
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
{{- if .Values.postgresql.existingSecret }}
              name: {{ .Values.postgresql.existingSecret | quote }}
{{- else }}
              name: {{ include "call-nested" (list . "postgresql" "postgresql.fullname") | quote }}
{{- end }}
              key: "postgresql-password"
{{- end }}
{{- if or .Values.redis.enabled .Values.redis.existingSecret }}
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
{{- if .Values.redis.existingSecret }}
              name: {{ .Values.redis.existingSecret | quote}}
{{- else }}
              name: {{ include "call-nested" (list . "redis" "redis.fullname") | quote }}
{{- end }}
              key: 'redis-password'
{{- end }}
{{- end }}
        volumeMounts:
        - name: netbox-media-files
          mountPath: /etc/netbox/media
        {{- if .Values.initializers }}
        - name: netbox-initializers
          mountPath: /opt/netbox/initializers/
        {{- end }}
        {{- range $mount := .Values.extraVolumeMounts }}
        - {{ $mount | toYaml | indent 10 | trim }}
        {{- end }}
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        {{- with .Values.livenessProbe }}
        livenessProbe:
          {{ . | toYaml | indent 10 | trim }}
        {{- end }}
        {{- with .Values.readinessProbe }}
        readinessProbe:
          {{ . | toYaml | indent 10 | trim }}
        {{- end }}
      {{- range $container := .Values.extraContainers }}
      - {{ $container | toYaml | indent 8 | trim }}
      {{- end }}
    {{- if .Values.extraInitContainers }}
    initContainers:
    {{ toYaml .Values.extraInitContainers | nindent 4}}
    {{- end }}
    restartPolicy: {{ .Values.restartPolicy }}
    {{- with .Values.nodeSelector }}
    nodeSelector:
    {{- toYaml . | nindent 6  }}
    {{- end }}
    {{- with .Values.affinity }}
    affinity:
    {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.tolerations }}
    tolerations:
    {{- toYaml . | nindent 6 }}
    {{- end }}
    volumes:
    {{- range $volume := .Values.extraVolumes }}
    - {{ $volume | toYaml | indent 6 | trim }}
    {{- end }}
    {{- if .Values.initializers }}
    - name: netbox-initializers
      configMap:
        name: {{ include "netbox.initializersConfigName" . | quote }}
    {{- end }}
{{- if not .Values.persistence.enabled }}
    - name: netbox-media-files
      emptyDir: {}
{{- end }}
{{- end -}}
