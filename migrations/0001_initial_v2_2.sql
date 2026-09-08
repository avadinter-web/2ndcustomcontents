
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  email_normalized TEXT NOT NULL UNIQUE,
  display_name TEXT,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','DISABLED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);

CREATE TABLE workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  settings_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(settings_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);

CREATE TABLE workspace_memberships (
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role TEXT NOT NULL CHECK(role IN ('ADMIN','EDITOR','REVIEWER','VIEWER')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(workspace_id,user_id)
);
CREATE INDEX idx_memberships_user ON workspace_memberships(user_id);

CREATE TABLE service_accounts (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','DISABLED')),
  permissions_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(permissions_json)),
  credential_secret_ref TEXT,
  credential_rotated_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(workspace_id,name)
);

CREATE TABLE auth_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  session_token_hash TEXT NOT NULL UNIQUE,
  session_family_id TEXT NOT NULL,
  rotated_from_session_id TEXT REFERENCES auth_sessions(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  revocation_reason TEXT,
  client_fingerprint_hash TEXT,
  user_agent_hash TEXT,
  CHECK(expires_at > created_at),
  CHECK(last_seen_at >= created_at),
  CHECK(revoked_at IS NULL OR revoked_at >= created_at)
);
CREATE INDEX idx_auth_sessions_user_expiry ON auth_sessions(user_id,expires_at);
CREATE INDEX idx_auth_sessions_family ON auth_sessions(session_family_id,created_at);


CREATE TABLE oauth_transactions (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  provider TEXT NOT NULL CHECK(provider IN ('YOUTUBE','INSTAGRAM','FACEBOOK','CANVA','GOOGLE_DRIVE','OTHER')),
  state_hash TEXT NOT NULL UNIQUE,
  pkce_verifier_secret_ref TEXT,
  redirect_uri TEXT NOT NULL,
  return_path TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  CHECK(consumed_at IS NULL OR consumed_at >= created_at)
);
CREATE INDEX idx_oauth_transactions_expiry ON oauth_transactions(expires_at,consumed_at);

CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  description TEXT,
  content_type TEXT,
  default_language TEXT NOT NULL DEFAULT 'ko',
  default_platforms_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(default_platforms_json)),
  brand_profile_ref TEXT,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','PAUSED','ARCHIVED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);
CREATE INDEX idx_projects_workspace_status ON projects(workspace_id,status);

CREATE TABLE assets (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
  asset_type TEXT NOT NULL CHECK(asset_type IN (
    'SOURCE_VIDEO','SOURCE_AUDIO','IMAGE','LOGO','FONT_REFERENCE','THUMBNAIL',
    'PREVIEW_VIDEO','FINAL_VIDEO','CAPTION_FILE','METADATA','BENCHMARK_REFERENCE','OTHER'
  )),
  storage_provider TEXT NOT NULL CHECK(storage_provider IN ('LOCAL','GOOGLE_DRIVE','CLOUDFLARE_R2','S3_REFERENCE')),
  storage_key TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER CHECK(size_bytes IS NULL OR size_bytes >= 0),
  checksum_sha256 TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(metadata_json)),
  status TEXT NOT NULL CHECK(status IN ('AVAILABLE','MISSING','PROCESSING','FAILED','ARCHIVED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(workspace_id,storage_provider,storage_key),
  UNIQUE(id,workspace_id)
);
CREATE INDEX idx_assets_project_type ON assets(project_id,asset_type);
CREATE INDEX idx_assets_checksum ON assets(workspace_id,checksum_sha256);

CREATE TABLE media_probes (
  id TEXT PRIMARY KEY,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  source_checksum_sha256 TEXT NOT NULL,
  ffprobe_version TEXT NOT NULL,
  probe_schema_version TEXT NOT NULL,
  probe_json TEXT NOT NULL CHECK(COALESCE(
    json_valid(probe_json) AND json_type(probe_json)='object'
    AND json_extract(probe_json,'$._schema')='ccs.media-probe'
    AND CAST(json_extract(probe_json,'$._version') AS TEXT)=probe_schema_version,
    0
  )),
  probe_hash TEXT NOT NULL,
  duration_us INTEGER NOT NULL CHECK(duration_us > 0),
  start_time_us INTEGER NOT NULL DEFAULT 0,
  container_format TEXT,
  video_stream_count INTEGER NOT NULL DEFAULT 0 CHECK(video_stream_count >= 0),
  audio_stream_count INTEGER NOT NULL DEFAULT 0 CHECK(audio_stream_count >= 0),
  variable_frame_rate INTEGER NOT NULL DEFAULT 0 CHECK(variable_frame_rate IN (0,1)),
  rotation_deg INTEGER,
  created_at TEXT NOT NULL,
  UNIQUE(source_asset_id,source_checksum_sha256,ffprobe_version,probe_hash),
  UNIQUE(id,source_asset_id)
);
CREATE INDEX idx_media_probes_asset_created ON media_probes(source_asset_id,created_at);

CREATE TABLE contents (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  content_type TEXT NOT NULL CHECK(content_type IN ('LONG_FORM','SHORT','REEL','IMAGE','THUMBNAIL','OTHER')),
  primary_platform TEXT,
  goal TEXT,
  status TEXT NOT NULL CHECK(status IN ('IDEA','ACTIVE','ARCHIVED')),
  current_version_id TEXT REFERENCES content_versions(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);
CREATE INDEX idx_contents_project_status ON contents(project_id,status);
CREATE INDEX idx_contents_workspace_updated ON contents(workspace_id,updated_at);

CREATE TABLE content_versions (
  id TEXT PRIMARY KEY,
  content_id TEXT NOT NULL REFERENCES contents(id) ON DELETE RESTRICT,
  version_number INTEGER NOT NULL CHECK(version_number >= 1),
  parent_version_id TEXT,
  status TEXT NOT NULL CHECK(status IN ('DRAFT','REVIEW_REQUIRED','REVISION_REQUIRED','APPROVED','SUPERSEDED')),
  title_snapshot TEXT,
  script_snapshot_json TEXT CHECK(script_snapshot_json IS NULL OR json_valid(script_snapshot_json)),
  content_snapshot_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(content_snapshot_json)),
  snapshot_hash TEXT NOT NULL,
  created_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  approved_at TEXT,
  approved_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(content_id,version_number),
  UNIQUE(id,content_id),
  FOREIGN KEY(parent_version_id,content_id) REFERENCES content_versions(id,content_id) ON DELETE RESTRICT,
  CHECK(
    (status IN ('APPROVED','SUPERSEDED') AND approved_at IS NOT NULL AND approved_by IS NOT NULL)
    OR
    (status NOT IN ('APPROVED','SUPERSEDED') AND approved_at IS NULL AND approved_by IS NULL)
  )
);
CREATE INDEX idx_content_versions_content_status ON content_versions(content_id,status);
CREATE UNIQUE INDEX uq_content_versions_one_approved
  ON content_versions(content_id) WHERE status='APPROVED';

CREATE TRIGGER trg_contents_current_version_insert
BEFORE INSERT ON contents
WHEN NEW.current_version_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT,'current_version_id cannot be set before content exists');
END;

CREATE TRIGGER trg_contents_current_version_update
BEFORE UPDATE OF current_version_id ON contents
WHEN NEW.current_version_id IS NOT NULL
BEGIN
  SELECT CASE WHEN NOT EXISTS(
    SELECT 1 FROM content_versions
    WHERE id=NEW.current_version_id AND content_id=NEW.id
  ) THEN RAISE(ABORT,'current_version_id must belong to content') END;
END;

CREATE TABLE benchmarks (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
  platform TEXT NOT NULL,
  source_type TEXT NOT NULL CHECK(source_type IN ('URL','UPLOADED_ASSET','MANUAL_REFERENCE')),
  source_url TEXT,
  source_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  title TEXT,
  creator TEXT,
  duration_ms INTEGER CHECK(duration_ms IS NULL OR duration_ms >= 0),
  range_start_ms INTEGER CHECK(range_start_ms IS NULL OR range_start_ms >= 0),
  range_end_ms INTEGER CHECK(range_end_ms IS NULL OR range_end_ms >= 0),
  notes TEXT,
  status TEXT NOT NULL CHECK(status IN ('REGISTERED','ANALYZING','READY','FAILED','ARCHIVED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(range_end_ms IS NULL OR range_start_ms IS NULL OR range_end_ms >= range_start_ms)
);
CREATE INDEX idx_benchmarks_project_status ON benchmarks(project_id,status);

CREATE TABLE benchmark_analyses (
  id TEXT PRIMARY KEY,
  benchmark_id TEXT NOT NULL REFERENCES benchmarks(id) ON DELETE RESTRICT,
  analysis_version INTEGER NOT NULL CHECK(analysis_version >= 1),
  model_evidence_json TEXT NOT NULL CHECK(json_valid(model_evidence_json)),
  result_json TEXT CHECK(result_json IS NULL OR json_valid(result_json)),
  result_hash TEXT,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','RUNNING','COMPLETED','FAILED','CANCELLED')),
  created_at TEXT NOT NULL,
  started_at TEXT,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK((result_json IS NULL AND result_hash IS NULL) OR (result_json IS NOT NULL AND result_hash IS NOT NULL)),
  CHECK(
    (status='QUEUED' AND started_at IS NULL AND completed_at IS NULL
      AND result_json IS NULL AND result_hash IS NULL)
    OR (status='RUNNING' AND started_at IS NOT NULL AND completed_at IS NULL
      AND result_json IS NULL AND result_hash IS NULL)
    OR (status='COMPLETED' AND started_at IS NOT NULL AND completed_at IS NOT NULL
      AND result_json IS NOT NULL AND result_hash IS NOT NULL)
    OR (status='FAILED' AND started_at IS NOT NULL AND completed_at IS NOT NULL
      AND result_json IS NULL AND result_hash IS NULL)
    OR (status='CANCELLED' AND completed_at IS NOT NULL
      AND result_json IS NULL AND result_hash IS NULL)
  ),
  UNIQUE(benchmark_id,analysis_version)
);

CREATE TABLE benchmark_patterns (
  id TEXT PRIMARY KEY,
  benchmark_analysis_id TEXT NOT NULL REFERENCES benchmark_analyses(id) ON DELETE RESTRICT,
  pattern_type TEXT NOT NULL,
  pattern_json TEXT NOT NULL CHECK(json_valid(pattern_json)),
  evidence_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(evidence_json)),
  confidence REAL CHECK(confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  created_at TEXT NOT NULL
);
CREATE INDEX idx_benchmark_patterns_analysis_type ON benchmark_patterns(benchmark_analysis_id,pattern_type);

CREATE TABLE generation_evidence (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL UNIQUE REFERENCES content_versions(id) ON DELETE RESTRICT,
  provider TEXT NOT NULL,
  model_id TEXT NOT NULL,
  model_revision TEXT,
  prompt_template_id TEXT NOT NULL,
  prompt_template_version TEXT NOT NULL,
  prompt_template_hash TEXT NOT NULL,
  normalized_input_hash TEXT NOT NULL,
  model_parameters_json TEXT NOT NULL CHECK(json_valid(model_parameters_json)),
  source_asset_hashes_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(source_asset_hashes_json)),
  tool_versions_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(tool_versions_json)),
  seed TEXT,
  generated_at TEXT NOT NULL
);

CREATE TABLE hooks (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  variant_key TEXT NOT NULL,
  hook_type TEXT,
  text TEXT NOT NULL,
  visual_hook_json TEXT CHECK(visual_hook_json IS NULL OR json_valid(visual_hook_json)),
  audio_hook_json TEXT CHECK(audio_hook_json IS NULL OR json_valid(audio_hook_json)),
  duration_ms INTEGER CHECK(duration_ms IS NULL OR duration_ms >= 0),
  benchmark_pattern_id TEXT REFERENCES benchmark_patterns(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  UNIQUE(content_version_id,variant_key)
);

CREATE TABLE scenes (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK(sequence_no >= 1),
  scene_json TEXT NOT NULL CHECK(json_valid(scene_json)),
  created_at TEXT NOT NULL,
  UNIQUE(content_version_id,sequence_no)
);

CREATE TABLE design_presets (
  id TEXT PRIMARY KEY,
  workspace_id TEXT REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  scope TEXT NOT NULL CHECK(scope IN ('SYSTEM','WORKSPACE','PROJECT')),
  preset_json TEXT NOT NULL CHECK(json_valid(preset_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (scope='SYSTEM' AND workspace_id IS NULL AND project_id IS NULL)
    OR (scope='WORKSPACE' AND workspace_id IS NOT NULL AND project_id IS NULL)
    OR (scope='PROJECT' AND workspace_id IS NOT NULL AND project_id IS NOT NULL)
  )
);
CREATE UNIQUE INDEX uq_design_presets_system_name
  ON design_presets(name) WHERE scope='SYSTEM';
CREATE UNIQUE INDEX uq_design_presets_workspace_name
  ON design_presets(workspace_id,name) WHERE scope='WORKSPACE';
CREATE UNIQUE INDEX uq_design_presets_project_name
  ON design_presets(project_id,name) WHERE scope='PROJECT';

CREATE TABLE design_overrides (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  element_key TEXT NOT NULL,
  property_key TEXT NOT NULL,
  auto_value_json TEXT CHECK(auto_value_json IS NULL OR json_valid(auto_value_json)),
  override_value_json TEXT CHECK(override_value_json IS NULL OR json_valid(override_value_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(content_version_id,element_key,property_key)
);

CREATE TABLE thumbnails (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  variant_key TEXT NOT NULL,
  asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  design_json TEXT NOT NULL CHECK(json_valid(design_json)),
  design_hash TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('DRAFT','READY','APPROVED','ARCHIVED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(content_version_id,variant_key)
);

CREATE TABLE timelines (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  revision_no INTEGER NOT NULL CHECK(revision_no >= 1),
  status TEXT NOT NULL CHECK(status IN ('DRAFT','REVIEW_REQUIRED','APPROVED','SUPERSEDED')),
  graph_revision INTEGER NOT NULL DEFAULT 1 CHECK(graph_revision >= 1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(content_version_id,revision_no),
  UNIQUE(id,content_version_id)
);
CREATE INDEX idx_timelines_content_status ON timelines(content_version_id,status);
CREATE UNIQUE INDEX uq_timelines_one_approved
  ON timelines(content_version_id) WHERE status='APPROVED';

CREATE TABLE timeline_tracks (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  track_type TEXT NOT NULL CHECK(track_type IN (
    'VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY',
    'AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX',
    'CAPTION','TEXT','GRAPHIC'
  )),
  track_index INTEGER NOT NULL CHECK(track_index >= 0),
  name TEXT,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
  locked INTEGER NOT NULL DEFAULT 0 CHECK(locked IN (0,1)),
  muted INTEGER NOT NULL DEFAULT 0 CHECK(muted IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(timeline_id,track_index),
  UNIQUE(id,timeline_id)
);
CREATE INDEX idx_timeline_tracks_timeline_type ON timeline_tracks(timeline_id,track_type);

CREATE TABLE timeline_clips (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  track_id TEXT NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no >= 1),
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  source_probe_id TEXT,
  video_stream_index INTEGER CHECK(video_stream_index IS NULL OR video_stream_index >= 0),
  audio_stream_index INTEGER CHECK(audio_stream_index IS NULL OR audio_stream_index >= 0),
  clip_kind TEXT NOT NULL DEFAULT 'NORMAL' CHECK(clip_kind IN ('NORMAL','FREEZE_FRAME','STILL_IMAGE')),
  source_start_ms INTEGER NOT NULL CHECK(source_start_ms >= 0),
  source_end_ms INTEGER NOT NULL CHECK(source_end_ms >= source_start_ms),
  freeze_duration_ms INTEGER,
  still_duration_ms INTEGER,
  timeline_start_ms INTEGER NOT NULL CHECK(timeline_start_ms >= 0),
  speed REAL NOT NULL DEFAULT 1.0 CHECK(speed > 0),
  duration_ms INTEGER GENERATED ALWAYS AS (
    CASE WHEN clip_kind='FREEZE_FRAME' THEN freeze_duration_ms
         WHEN clip_kind='STILL_IMAGE' THEN still_duration_ms
         ELSE CAST(ROUND((source_end_ms-source_start_ms)/speed) AS INTEGER)
    END
  ) STORED,
  transform_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(transform_json)),
  volume REAL NOT NULL DEFAULT 1.0 CHECK(volume >= 0),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
  clip_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(duration_ms > 0),
  CHECK(
    (clip_kind='NORMAL' AND source_end_ms > source_start_ms AND freeze_duration_ms IS NULL AND still_duration_ms IS NULL)
    OR
    (clip_kind='FREEZE_FRAME' AND source_end_ms = source_start_ms AND freeze_duration_ms IS NOT NULL AND freeze_duration_ms > 0 AND still_duration_ms IS NULL)
    OR
    (clip_kind='STILL_IMAGE' AND source_start_ms=0 AND source_end_ms=0 AND freeze_duration_ms IS NULL AND still_duration_ms IS NOT NULL AND still_duration_ms > 0)
  ),
  UNIQUE(track_id,sequence_no),
  UNIQUE(id,timeline_id),
  UNIQUE(id,track_id,timeline_id),
  FOREIGN KEY(track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(source_probe_id,source_asset_id) REFERENCES media_probes(id,source_asset_id) ON DELETE RESTRICT
);
CREATE INDEX idx_timeline_clips_timeline_start ON timeline_clips(timeline_id,timeline_start_ms);

CREATE TABLE timeline_transitions (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  track_id TEXT NOT NULL,
  from_clip_id TEXT NOT NULL,
  to_clip_id TEXT NOT NULL,
  transition_type TEXT NOT NULL CHECK(transition_type IN (
    'CUT','CROSSFADE'
  )),
  media_scope TEXT NOT NULL DEFAULT 'BOTH' CHECK(media_scope IN ('VIDEO','AUDIO','BOTH')),
  duration_ms INTEGER NOT NULL DEFAULT 0 CHECK(duration_ms >= 0),
  parameters_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(parameters_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(from_clip_id <> to_clip_id),
  CHECK(
    (transition_type='CUT' AND duration_ms=0)
    OR (transition_type<>'CUT' AND duration_ms>0)
  ),
  UNIQUE(timeline_id,track_id,from_clip_id,to_clip_id),
  FOREIGN KEY(track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(from_clip_id,track_id,timeline_id) REFERENCES timeline_clips(id,track_id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(to_clip_id,track_id,timeline_id) REFERENCES timeline_clips(id,track_id,timeline_id) ON DELETE RESTRICT
);

CREATE TABLE clip_fades (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  clip_id TEXT NOT NULL,
  fade_type TEXT NOT NULL CHECK(fade_type IN ('FADE_IN','FADE_OUT')),
  media_scope TEXT NOT NULL DEFAULT 'BOTH' CHECK(media_scope IN ('VIDEO','AUDIO','BOTH')),
  duration_ms INTEGER NOT NULL CHECK(duration_ms > 0),
  parameters_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(parameters_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(clip_id,fade_type,media_scope),
  FOREIGN KEY(clip_id,timeline_id) REFERENCES timeline_clips(id,timeline_id) ON DELETE RESTRICT
);

CREATE TABLE timeline_overlays (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  track_id TEXT NOT NULL,
  overlay_type TEXT NOT NULL CHECK(overlay_type IN (
    'TEXT','IMAGE','LOGO','BANNER','SHAPE','PROGRESS',
    'MASK','BLUR_REGION','PIXELATE_REGION'
  )),
  asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  text_value TEXT,
  start_ms INTEGER NOT NULL CHECK(start_ms >= 0),
  end_ms INTEGER NOT NULL CHECK(end_ms > start_ms),
  geometry_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(geometry_json)),
  style_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(style_json)),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
  overlay_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (overlay_type IN ('IMAGE','LOGO') AND asset_id IS NOT NULL)
    OR (overlay_type='TEXT' AND text_value IS NOT NULL)
    OR (overlay_type NOT IN ('IMAGE','LOGO','TEXT'))
  ),
  UNIQUE(id,timeline_id),
  FOREIGN KEY(track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT
);
CREATE INDEX idx_overlays_timeline_time ON timeline_overlays(timeline_id,start_ms,end_ms);

CREATE TABLE timeline_keyframes (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  target_type TEXT NOT NULL CHECK(target_type IN ('CLIP','OVERLAY','AUDIO_TRACK')),
  clip_id TEXT,
  overlay_id TEXT,
  track_id TEXT,
  property_name TEXT NOT NULL CHECK(property_name IN (
    'POSITION_X','POSITION_Y','SCALE_X','SCALE_Y','ROTATION_DEG','OPACITY',
    'CROP_X','CROP_Y','CROP_WIDTH','CROP_HEIGHT','VOLUME','BLUR_RADIUS','SATURATION'
  )),
  time_ms INTEGER NOT NULL CHECK(time_ms >= 0),
  auto_value_json TEXT NOT NULL CHECK(json_valid(auto_value_json) AND json_type(auto_value_json) IN ('integer','real')),
  override_value_json TEXT CHECK(override_value_json IS NULL OR (json_valid(override_value_json) AND json_type(override_value_json) IN ('integer','real'))),
  interpolation TEXT NOT NULL CHECK(interpolation IN (
    'HOLD','LINEAR','EASE_IN','EASE_OUT','EASE_IN_OUT','BEZIER_REFERENCE'
  )),
  bezier_json TEXT CHECK(bezier_json IS NULL OR json_valid(bezier_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (target_type='CLIP' AND clip_id IS NOT NULL AND overlay_id IS NULL AND track_id IS NULL)
    OR (target_type='OVERLAY' AND clip_id IS NULL AND overlay_id IS NOT NULL AND track_id IS NULL)
    OR (target_type='AUDIO_TRACK' AND clip_id IS NULL AND overlay_id IS NULL AND track_id IS NOT NULL)
  ),
  CHECK((interpolation='BEZIER_REFERENCE' AND bezier_json IS NOT NULL) OR interpolation<>'BEZIER_REFERENCE'),
  FOREIGN KEY(clip_id,timeline_id) REFERENCES timeline_clips(id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(overlay_id,timeline_id) REFERENCES timeline_overlays(id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX uq_keyframes_clip
  ON timeline_keyframes(clip_id,property_name,time_ms) WHERE target_type='CLIP';
CREATE UNIQUE INDEX uq_keyframes_overlay
  ON timeline_keyframes(overlay_id,property_name,time_ms) WHERE target_type='OVERLAY';
CREATE UNIQUE INDEX uq_keyframes_track
  ON timeline_keyframes(track_id,property_name,time_ms) WHERE target_type='AUDIO_TRACK';
CREATE INDEX idx_keyframes_timeline_time ON timeline_keyframes(timeline_id,time_ms);

CREATE TABLE clip_effects (
  id TEXT PRIMARY KEY,
  clip_id TEXT NOT NULL REFERENCES timeline_clips(id) ON DELETE RESTRICT,
  effect_type TEXT NOT NULL CHECK(effect_type IN (
    'BRIGHTNESS','CONTRAST','SATURATION','GAMMA','BLUR',
    'PIXELATE_REGION','REGION_BLUR',
    'SHARPEN','VIGNETTE','TEMPERATURE_REFERENCE','CUSTOM_REFERENCE'
  )),
  order_index INTEGER NOT NULL CHECK(order_index >= 0),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
  auto_parameters_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(auto_parameters_json)),
  override_parameters_json TEXT CHECK(override_parameters_json IS NULL OR json_valid(override_parameters_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(clip_id,order_index)
);

CREATE TABLE captions (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  track_id TEXT NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no >= 1),
  start_ms INTEGER NOT NULL CHECK(start_ms >= 0),
  end_ms INTEGER NOT NULL CHECK(end_ms > start_ms),
  text TEXT NOT NULL,
  speaker TEXT,
  style_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(style_json)),
  source_type TEXT NOT NULL CHECK(source_type IN ('AI','HUMAN','IMPORT')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(track_id,sequence_no),
  UNIQUE(id,timeline_id),
  FOREIGN KEY(track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT
);

CREATE VIEW timeline_duration_view AS
SELECT t.id AS timeline_id, COALESCE(MAX(e.end_ms),0) AS duration_ms
FROM timelines t
LEFT JOIN (
  SELECT timeline_id, timeline_start_ms + duration_ms AS end_ms
  FROM timeline_clips WHERE enabled=1
  UNION ALL
  SELECT timeline_id, end_ms FROM timeline_overlays WHERE enabled=1
  UNION ALL
  SELECT timeline_id, end_ms FROM captions
) e ON e.timeline_id=t.id
GROUP BY t.id;

CREATE TABLE timeline_validations (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  graph_revision INTEGER NOT NULL CHECK(graph_revision >= 1),
  validator_version TEXT NOT NULL,
  validation_schema_version TEXT NOT NULL,
  validation_json TEXT NOT NULL CHECK(COALESCE(
    json_valid(validation_json) AND json_type(validation_json)='object'
    AND json_extract(validation_json,'$._schema')='ccs.timeline-validation'
    AND CAST(json_extract(validation_json,'$._version') AS INTEGER) >= 1,
    0
  )),
  validation_hash TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('VALID','BLOCKED')),
  validated_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  UNIQUE(timeline_id,graph_revision,validation_hash),
  UNIQUE(id,timeline_id),
  CHECK(COALESCE(
    (status='VALID' AND json_extract(validation_json,'$.data.valid')=1)
    OR (status='BLOCKED' AND json_extract(validation_json,'$.data.valid')=0),
    0
  ))
);
CREATE INDEX idx_timeline_validations_status ON timeline_validations(timeline_id,status,graph_revision);

CREATE TABLE timeline_materializations (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  timeline_validation_id TEXT NOT NULL,
  graph_revision INTEGER NOT NULL CHECK(graph_revision >= 1),
  canonical_schema_version TEXT NOT NULL,
  canonical_json TEXT NOT NULL CHECK(COALESCE(
    json_valid(canonical_json) AND json_type(canonical_json)='object'
    AND json_extract(canonical_json,'$._schema')='ccs.timeline'
    AND CAST(json_extract(canonical_json,'$._version') AS TEXT)=canonical_schema_version,
    0
  )),
  canonical_hash TEXT NOT NULL,
  duration_ms INTEGER NOT NULL CHECK(duration_ms > 0),
  generator_version TEXT NOT NULL,
  generated_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  UNIQUE(timeline_id,graph_revision),
  UNIQUE(id,timeline_id),
  FOREIGN KEY(timeline_validation_id,timeline_id) REFERENCES timeline_validations(id,timeline_id) ON DELETE RESTRICT
);
CREATE INDEX idx_timeline_materializations_hash ON timeline_materializations(canonical_hash);

CREATE TABLE timeline_approvals (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  materialization_id TEXT NOT NULL,
  approved_by TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  approved_at TEXT NOT NULL,
  approval_hash TEXT NOT NULL,
  UNIQUE(timeline_id),
  UNIQUE(materialization_id),
  FOREIGN KEY(materialization_id,timeline_id) REFERENCES timeline_materializations(id,timeline_id) ON DELETE RESTRICT
);


CREATE TABLE media_analysis_runs (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  analysis_type TEXT NOT NULL CHECK(analysis_type IN (
    'SCENE_DETECTION','SILENCE_DETECTION','SPEECH_TRANSCRIPT',
    'HIGHLIGHT_SCORING','SUBJECT_TRACKING','REFRAME_ANALYSIS'
  )),
  provider TEXT NOT NULL,
  tool_or_model_id TEXT NOT NULL,
  version TEXT,
  parameters_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(parameters_json)),
  source_checksum_sha256 TEXT NOT NULL,
  result_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(result_json)),
  result_hash TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','RUNNING','COMPLETED','FAILED')),
  created_at TEXT NOT NULL,
  completed_at TEXT,
  UNIQUE(id,source_asset_id),
  CHECK(status<>'COMPLETED' OR completed_at IS NOT NULL)
);
CREATE INDEX idx_media_analysis_asset_type ON media_analysis_runs(source_asset_id,analysis_type,status);

CREATE TABLE asset_proxies (
  id TEXT PRIMARY KEY,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  proxy_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  profile_id TEXT NOT NULL,
  profile_hash TEXT NOT NULL,
  source_checksum_sha256 TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','GENERATING','READY','FAILED','STALE')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(source_asset_id,profile_hash),
  CHECK(status<>'READY' OR proxy_asset_id IS NOT NULL)
);

CREATE TABLE audio_waveforms (
  id TEXT PRIMARY KEY,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  waveform_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  sample_window_ms INTEGER NOT NULL CHECK(sample_window_ms > 0),
  peaks_json TEXT CHECK(peaks_json IS NULL OR json_valid(peaks_json)),
  source_checksum_sha256 TEXT NOT NULL,
  generator_version TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','GENERATING','READY','FAILED','STALE')),
  created_at TEXT NOT NULL,
  UNIQUE(source_asset_id,source_checksum_sha256,sample_window_ms,generator_version),
  CHECK(status<>'READY' OR waveform_asset_id IS NOT NULL OR peaks_json IS NOT NULL)
);

CREATE TABLE silence_regions (
  id TEXT PRIMARY KEY,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  analysis_run_id TEXT NOT NULL REFERENCES media_analysis_runs(id) ON DELETE RESTRICT,
  start_ms INTEGER NOT NULL CHECK(start_ms >= 0),
  end_ms INTEGER NOT NULL CHECK(end_ms > start_ms),
  detector_parameters_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(detector_parameters_json)),
  measured_level_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(measured_level_json)),
  recommendation TEXT NOT NULL CHECK(recommendation IN ('KEEP','REMOVE','SHORTEN')),
  decision TEXT NOT NULL DEFAULT 'UNREVIEWED' CHECK(decision IN (
    'UNREVIEWED','KEEP','REMOVE','SHORTEN','REJECT_RECOMMENDATION'
  )),
  target_duration_ms INTEGER CHECK(target_duration_ms IS NULL OR target_duration_ms >= 0),
  decided_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(analysis_run_id,source_asset_id) REFERENCES media_analysis_runs(id,source_asset_id) ON DELETE RESTRICT,
  CHECK(
    (decision='UNREVIEWED' AND decided_by IS NULL AND target_duration_ms IS NULL)
    OR (decision='SHORTEN' AND decided_by IS NOT NULL AND target_duration_ms IS NOT NULL
        AND target_duration_ms>0 AND target_duration_ms<(end_ms-start_ms))
    OR (decision IN ('KEEP','REMOVE','REJECT_RECOMMENDATION') AND decided_by IS NOT NULL AND target_duration_ms IS NULL)
  )
);
CREATE INDEX idx_silence_regions_asset_time ON silence_regions(source_asset_id,start_ms,end_ms);

CREATE TABLE audio_ducking_rules (
  id TEXT PRIMARY KEY,
  timeline_id TEXT NOT NULL REFERENCES timelines(id) ON DELETE RESTRICT,
  trigger_track_id TEXT NOT NULL,
  target_track_id TEXT NOT NULL,
  threshold_db REAL NOT NULL,
  duck_db REAL NOT NULL CHECK(duck_db <= 0),
  attack_ms INTEGER NOT NULL CHECK(attack_ms >= 0),
  release_ms INTEGER NOT NULL CHECK(release_ms >= 0),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(trigger_track_id <> target_track_id),
  UNIQUE(timeline_id,trigger_track_id,target_track_id),
  FOREIGN KEY(trigger_track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT,
  FOREIGN KEY(target_track_id,timeline_id) REFERENCES timeline_tracks(id,timeline_id) ON DELETE RESTRICT
);

CREATE TABLE reframe_plans (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  target_aspect_ratio TEXT NOT NULL,
  plan_version INTEGER NOT NULL CHECK(plan_version >= 1),
  analysis_evidence_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(analysis_evidence_json)),
  status TEXT NOT NULL CHECK(status IN ('DRAFT','REVIEW_REQUIRED','APPROVED','SUPERSEDED')),
  created_at TEXT NOT NULL,
  approved_at TEXT,
  approved_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  UNIQUE(content_version_id,source_asset_id,target_aspect_ratio,plan_version),
  CHECK(
    (status IN ('APPROVED','SUPERSEDED') AND approved_at IS NOT NULL AND approved_by IS NOT NULL)
    OR (status NOT IN ('APPROVED','SUPERSEDED') AND approved_at IS NULL AND approved_by IS NULL)
  )
);
CREATE UNIQUE INDEX uq_reframe_one_approved
  ON reframe_plans(content_version_id,source_asset_id,target_aspect_ratio) WHERE status='APPROVED';

CREATE TABLE reframe_keyframes (
  id TEXT PRIMARY KEY,
  reframe_plan_id TEXT NOT NULL REFERENCES reframe_plans(id) ON DELETE RESTRICT,
  time_ms INTEGER NOT NULL CHECK(time_ms >= 0),
  auto_center_x REAL NOT NULL CHECK(auto_center_x BETWEEN 0 AND 1),
  auto_center_y REAL NOT NULL CHECK(auto_center_y BETWEEN 0 AND 1),
  auto_scale REAL NOT NULL CHECK(auto_scale > 0),
  override_center_x REAL CHECK(override_center_x IS NULL OR override_center_x BETWEEN 0 AND 1),
  override_center_y REAL CHECK(override_center_y IS NULL OR override_center_y BETWEEN 0 AND 1),
  override_scale REAL CHECK(override_scale IS NULL OR override_scale > 0),
  confidence REAL CHECK(confidence IS NULL OR confidence BETWEEN 0 AND 1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(reframe_plan_id,time_ms)
);

CREATE TABLE short_candidates (
  id TEXT PRIMARY KEY,
  source_content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  source_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  candidate_type TEXT NOT NULL CHECK(candidate_type IN (
    'HOOK_CLIP','BEST_MOMENT','QUESTION','REACTION','TIP','MISTAKE',
    'CHALLENGE','QUIZ','BEFORE_AFTER','LONG_FORM_TEASER','STORY','CUSTOM'
  )),
  start_ms INTEGER NOT NULL CHECK(start_ms >= 0),
  end_ms INTEGER NOT NULL CHECK(end_ms > start_ms),
  scoring_model_evidence_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(scoring_model_evidence_json)),
  total_score REAL NOT NULL CHECK(total_score BETWEEN 0 AND 1),
  hook_score REAL NOT NULL CHECK(hook_score BETWEEN 0 AND 1),
  retention_potential_score REAL NOT NULL CHECK(retention_potential_score BETWEEN 0 AND 1),
  standalone_score REAL NOT NULL CHECK(standalone_score BETWEEN 0 AND 1),
  curiosity_emotion_score REAL NOT NULL CHECK(curiosity_emotion_score BETWEEN 0 AND 1),
  longform_conversion_score REAL NOT NULL CHECK(longform_conversion_score BETWEEN 0 AND 1),
  recommended_duration_ms INTEGER CHECK(recommended_duration_ms IS NULL OR recommended_duration_ms > 0),
  rationale_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(rationale_json)),
  status TEXT NOT NULL CHECK(status IN ('CANDIDATE','SHORTLISTED','REJECTED','CONVERTED')),
  converted_content_id TEXT REFERENCES contents(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK(
    (status='CONVERTED' AND converted_content_id IS NOT NULL)
    OR (status<>'CONVERTED' AND converted_content_id IS NULL)
  )
);
CREATE INDEX idx_short_candidates_source_score ON short_candidates(source_content_version_id,status,total_score);

CREATE TABLE review_sessions (
  id TEXT PRIMARY KEY,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  timeline_materialization_id TEXT REFERENCES timeline_materializations(id) ON DELETE RESTRICT,
  reviewer_user_id TEXT REFERENCES users(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK(status IN ('OPEN','APPROVED','REVISION_REQUESTED','REJECTED')),
  review_note TEXT,
  review_target_json TEXT NOT NULL CHECK(
    json_valid(review_target_json)
    AND json_type(review_target_json)='object'
    AND json_extract(review_target_json,'$._schema')='ccs.review-target'
    AND json_type(review_target_json,'$._version')='integer'
    AND json_extract(review_target_json,'$._version')=1
    AND json_type(review_target_json,'$.data')='object'
    AND json_type(review_target_json,'$.data.content_version_id')='text'
    AND json_type(review_target_json,'$.data.content_hash')='text'
    AND COALESCE(
      json_type(review_target_json,'$.data.content_row_version')='integer'
      AND json_extract(review_target_json,'$.data.content_row_version') >= 1,
      0
    )
    AND COALESCE(json_extract(review_target_json,'$.data.content_version_id'),'')=content_version_id
    AND COALESCE(json_extract(review_target_json,'$.data.content_hash'),'')=content_hash
    AND (
      (timeline_materialization_id IS NULL AND timeline_materialization_hash IS NULL
        AND json_type(review_target_json,'$.data.timeline') IS NULL)
      OR COALESCE(
        timeline_materialization_id IS NOT NULL AND timeline_materialization_hash IS NOT NULL
        AND json_type(review_target_json,'$.data.timeline')='object'
        AND json_type(review_target_json,'$.data.timeline.timeline_id')='text'
        AND json_type(review_target_json,'$.data.timeline.timeline_row_version')='integer'
        AND json_extract(review_target_json,'$.data.timeline.timeline_row_version') >= 1
        AND json_type(review_target_json,'$.data.timeline.graph_revision')='integer'
        AND json_extract(review_target_json,'$.data.timeline.graph_revision') >= 1
        AND json_type(review_target_json,'$.data.timeline.timeline_materialization_id')='text'
        AND json_type(review_target_json,'$.data.timeline.timeline_materialization_hash')='text'
        AND json_extract(review_target_json,'$.data.timeline.timeline_materialization_id')=timeline_materialization_id
        AND json_extract(review_target_json,'$.data.timeline.timeline_materialization_hash')=timeline_materialization_hash,
        0
      )
    )
    AND (
      (design_hash IS NULL AND json_type(review_target_json,'$.data.design') IS NULL)
      OR COALESCE(
        design_hash IS NOT NULL AND json_type(review_target_json,'$.data.design')='object'
        AND json_type(review_target_json,'$.data.design.resource_hash')='text'
        AND json_extract(review_target_json,'$.data.design.resource_hash')=design_hash,
        0
      )
    )
    AND (
      (caption_hash IS NULL AND json_type(review_target_json,'$.data.caption') IS NULL)
      OR COALESCE(
        caption_hash IS NOT NULL AND json_type(review_target_json,'$.data.caption')='object'
        AND json_type(review_target_json,'$.data.caption.resource_hash')='text'
        AND json_extract(review_target_json,'$.data.caption.resource_hash')=caption_hash,
        0
      )
    )
    AND (
      json_type(review_target_json,'$.data.preview') IS NULL
      OR COALESCE(
        json_type(review_target_json,'$.data.preview')='object'
        AND json_type(review_target_json,'$.data.preview.render_job_id')='text'
        AND json_type(review_target_json,'$.data.preview.render_job_row_version')='integer'
        AND json_extract(review_target_json,'$.data.preview.render_job_row_version') >= 1
        AND json_type(review_target_json,'$.data.preview.render_snapshot_id')='text'
        AND json_type(review_target_json,'$.data.preview.render_snapshot_hash')='text'
        AND json_type(review_target_json,'$.data.preview.output_asset_id')='text'
        AND json_type(review_target_json,'$.data.preview.output_checksum_sha256')='text',
        0
      )
    )
  ),
  review_target_hash TEXT NOT NULL CHECK(
    length(review_target_hash)=64 AND review_target_hash NOT GLOB '*[^0-9a-f]*'
  ),
  content_hash TEXT NOT NULL,
  timeline_materialization_hash TEXT,
  design_hash TEXT,
  caption_hash TEXT,
  opened_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  decided_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (timeline_materialization_id IS NULL AND timeline_materialization_hash IS NULL)
    OR (timeline_materialization_id IS NOT NULL AND timeline_materialization_hash IS NOT NULL)
  ),
  CHECK(
    (status='OPEN' AND decided_at IS NULL)
    OR (status<>'OPEN' AND decided_at IS NOT NULL)
  )
);
CREATE INDEX idx_review_sessions_content_status ON review_sessions(content_version_id,status);

-- Review findings are durable evidence against the exact review materialization.
-- Editing the reviewed payload creates a new revision; findings on this session
-- may only move once from OPEN to a terminal resolution state.
CREATE TABLE review_items (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  review_session_id TEXT NOT NULL REFERENCES review_sessions(id) ON DELETE RESTRICT,
  source_review_item_id TEXT REFERENCES review_items(id) ON DELETE RESTRICT,
  target_kind TEXT NOT NULL CHECK(target_kind IN (
    'CONTENT','TIMELINE','SCENE','SCRIPT','CLIP','CAPTION','DESIGN',
    'THUMBNAIL','METADATA','RENDER_OUTPUT','PUBLICATION'
  )),
  anchor_json TEXT NOT NULL CHECK(
    json_valid(anchor_json)
    AND json_type(anchor_json)='object'
    AND json_extract(anchor_json,'$._schema')='ccs.review.anchor'
    AND json_type(anchor_json,'$._version')='integer'
    AND json_extract(anchor_json,'$._version')=1
    AND json_type(anchor_json,'$.data')='object'
    AND (
      COALESCE(
        json_type(anchor_json,'$.data.field_path')='text'
        AND length(trim(json_extract(anchor_json,'$.data.field_path'))) > 0,
        0
      )
      OR
      COALESCE(
        json_type(anchor_json,'$.data.start_ms')='integer'
        AND json_type(anchor_json,'$.data.end_ms')='integer'
        AND json_extract(anchor_json,'$.data.start_ms') >= 0
        AND json_extract(anchor_json,'$.data.end_ms') > json_extract(anchor_json,'$.data.start_ms'),
        0
      )
      OR
      COALESCE(
        json_type(anchor_json,'$.data.artifact_id')='text'
        AND length(trim(json_extract(anchor_json,'$.data.artifact_id'))) > 0,
        0
      )
    )
  ),
  severity TEXT NOT NULL CHECK(severity IN ('BLOCKING','MAJOR','MINOR','NOTE')),
  body TEXT NOT NULL CHECK(length(trim(body)) > 0),
  status TEXT NOT NULL CHECK(status IN ('OPEN','RESOLVED','WONT_FIX')),
  resolution_note TEXT,
  created_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  resolved_by_user_id TEXT REFERENCES users(id) ON DELETE RESTRICT,
  resolved_at TEXT,
  resolution_evidence_json TEXT CHECK(
    resolution_evidence_json IS NULL OR
    (json_valid(resolution_evidence_json) AND json_type(resolution_evidence_json)='object')
  ),
  resolution_evidence_hash TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(source_review_item_id IS NULL OR source_review_item_id<>id),
  CHECK(
    (status='OPEN' AND resolved_by_user_id IS NULL AND resolved_at IS NULL
      AND resolution_note IS NULL AND resolution_evidence_json IS NULL
      AND resolution_evidence_hash IS NULL)
    OR
    (status IN ('RESOLVED','WONT_FIX') AND resolved_by_user_id IS NOT NULL AND resolved_at IS NOT NULL
      AND resolution_evidence_json IS NOT NULL AND resolution_evidence_hash IS NOT NULL)
  ),
  CHECK(status<>'WONT_FIX' OR (resolution_note IS NOT NULL AND length(trim(resolution_note)) > 0)),
  UNIQUE(id,workspace_id)
);
CREATE INDEX idx_review_items_session_status
  ON review_items(review_session_id,status,severity,created_at);
CREATE INDEX idx_review_items_source ON review_items(source_review_item_id);

CREATE TABLE render_snapshots (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  timeline_id TEXT NOT NULL,
  timeline_materialization_id TEXT NOT NULL,
  snapshot_type TEXT NOT NULL CHECK(snapshot_type IN ('PREVIEW','DRAFT','FINAL')),
  snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json) AND json_type(snapshot_json)='object'),
  snapshot_hash TEXT NOT NULL,
  source_asset_checksums_json TEXT NOT NULL CHECK(json_valid(source_asset_checksums_json) AND json_type(source_asset_checksums_json)='array' AND json_array_length(source_asset_checksums_json)>0),
  font_asset_checksums_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(font_asset_checksums_json) AND json_type(font_asset_checksums_json)='array'),
  effect_asset_checksums_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(effect_asset_checksums_json) AND json_type(effect_asset_checksums_json)='array'),
  ffmpeg_version TEXT NOT NULL,
  ffmpeg_build_hash TEXT,
  ffprobe_version TEXT NOT NULL,
  renderer_version TEXT NOT NULL,
  render_profile_json TEXT NOT NULL CHECK(json_valid(render_profile_json) AND json_type(render_profile_json)='object'),
  render_plan_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(workspace_id,snapshot_hash),
  UNIQUE(id,workspace_id,snapshot_type),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(timeline_id,content_version_id) REFERENCES timelines(id,content_version_id) ON DELETE RESTRICT,
  FOREIGN KEY(timeline_materialization_id,timeline_id) REFERENCES timeline_materializations(id,timeline_id) ON DELETE RESTRICT
);

CREATE TABLE render_jobs (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  render_snapshot_id TEXT NOT NULL,
  render_type TEXT NOT NULL CHECK(render_type IN ('PREVIEW','DRAFT','FINAL')),
  status TEXT NOT NULL CHECK(status IN ('QUEUED','RUNNING','RETRY','COMPLETED','FAILED','CANCELLED')),
  idempotency_key TEXT NOT NULL,
  execution_fingerprint TEXT NOT NULL,
  correlation_id TEXT NOT NULL,
  output_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  output_checksum_sha256 TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 3 CHECK(max_attempts >= 1),
  last_error_code TEXT,
  last_error_message TEXT,
  queued_at TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(workspace_id,idempotency_key),
  UNIQUE(workspace_id,execution_fingerprint),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(render_snapshot_id,workspace_id,render_type) REFERENCES render_snapshots(id,workspace_id,snapshot_type) ON DELETE RESTRICT,
  FOREIGN KEY(output_asset_id,workspace_id) REFERENCES assets(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_render_jobs_status_queue ON render_jobs(status,queued_at);

CREATE TABLE platform_accounts (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  platform TEXT NOT NULL CHECK(platform IN ('YOUTUBE','INSTAGRAM','FACEBOOK')),
  external_account_id TEXT NOT NULL,
  display_name TEXT,
  secret_ref TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','REAUTH_REQUIRED','DISABLED')),
  token_expires_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(workspace_id,platform,external_account_id),
  UNIQUE(id,workspace_id)
);

-- Platform constraints are versioned data, never mutable configuration in code.
-- A new constraint set is a new version row; only lifecycle deprecation may
-- change on an existing row.
CREATE TABLE platform_media_profiles (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  platform TEXT NOT NULL CHECK(platform IN ('YOUTUBE','INSTAGRAM','FACEBOOK')),
  publication_type TEXT NOT NULL CHECK(publication_type IN ('LONG_FORM','SHORT','REEL','IMAGE')),
  profile_key TEXT NOT NULL CHECK(length(trim(profile_key)) > 0),
  profile_version INTEGER NOT NULL CHECK(profile_version >= 1),
  profile_json TEXT NOT NULL CHECK(json_valid(profile_json) AND json_type(profile_json)='object'),
  profile_hash TEXT NOT NULL CHECK(length(trim(profile_hash)) > 0),
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','DEPRECATED')),
  created_by TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TEXT NOT NULL,
  deprecated_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (status='ACTIVE' AND deprecated_at IS NULL)
    OR (status='DEPRECATED' AND deprecated_at IS NOT NULL)
  ),
  UNIQUE(workspace_id,platform,publication_type,profile_key,profile_version),
  UNIQUE(id,workspace_id)
);
CREATE UNIQUE INDEX uq_platform_media_profile_active
  ON platform_media_profiles(workspace_id,platform,publication_type,profile_key)
  WHERE status='ACTIVE';

CREATE TABLE publications (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  content_version_id TEXT NOT NULL REFERENCES content_versions(id) ON DELETE RESTRICT,
  platform_account_id TEXT NOT NULL REFERENCES platform_accounts(id) ON DELETE RESTRICT,
  publication_type TEXT NOT NULL CHECK(publication_type IN ('LONG_FORM','SHORT','REEL','IMAGE')),
  status TEXT NOT NULL CHECK(status IN (
    'NOT_READY','READY','SCHEDULED','UPLOADING','PROCESSING','PUBLISHED','FAILED','RETRY_REQUIRED','CANCELLED'
  )),
  metadata_json TEXT NOT NULL CHECK(json_valid(metadata_json) AND json_type(metadata_json)='object'),
  metadata_hash TEXT NOT NULL,
  final_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  final_render_job_id TEXT REFERENCES render_jobs(id) ON DELETE RESTRICT,
  remote_operation_id TEXT,
  remote_container_id TEXT,
  remote_media_id TEXT,
  remote_status TEXT,
  remote_url TEXT,
  last_remote_checked_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  published_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (publication_type IN ('LONG_FORM','SHORT','REEL') AND (
      (final_asset_id IS NULL AND final_render_job_id IS NULL)
      OR (final_asset_id IS NOT NULL AND final_render_job_id IS NOT NULL)
    ))
    OR (publication_type='IMAGE' AND final_render_job_id IS NULL)
  ),
  CHECK(status IN ('NOT_READY','CANCELLED') OR final_asset_id IS NOT NULL),
  CHECK(status IN ('NOT_READY','CANCELLED') OR publication_type='IMAGE' OR final_render_job_id IS NOT NULL),
  UNIQUE(content_version_id,platform_account_id,publication_type),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(platform_account_id,workspace_id) REFERENCES platform_accounts(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(final_asset_id,workspace_id) REFERENCES assets(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_publications_workspace_status ON publications(workspace_id,status);
CREATE INDEX idx_publications_remote_media ON publications(platform_account_id,remote_media_id);
CREATE UNIQUE INDEX uq_publications_remote_media
  ON publications(platform_account_id,remote_media_id) WHERE remote_media_id IS NOT NULL;

CREATE TABLE publication_assets (
  id TEXT PRIMARY KEY,
  publication_id TEXT NOT NULL REFERENCES publications(id) ON DELETE RESTRICT,
  asset_role TEXT NOT NULL CHECK(asset_role IN ('THUMBNAIL','COVER')),
  asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  asset_checksum_sha256 TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(publication_id,asset_role)
);
CREATE INDEX idx_publication_assets_asset ON publication_assets(asset_id);

-- A Publication may accumulate multiple immutable preflight/profile bindings.
-- Each PublicationJob freezes exactly one historical binding.
CREATE TABLE publication_profile_bindings (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  publication_id TEXT NOT NULL,
  binding_hash TEXT NOT NULL CHECK(
    length(binding_hash)=64 AND binding_hash NOT GLOB '*[^0-9a-f]*'
  ),
  publication_row_version INTEGER NOT NULL CHECK(publication_row_version >= 1),
  platform_media_profile_id TEXT NOT NULL,
  profile_row_version INTEGER NOT NULL CHECK(profile_row_version >= 1),
  profile_version INTEGER NOT NULL CHECK(profile_version >= 1),
  profile_hash TEXT NOT NULL,
  metadata_hash TEXT NOT NULL,
  final_asset_checksum_sha256 TEXT,
  attachment_fingerprint TEXT NOT NULL CHECK(
    length(attachment_fingerprint)=64 AND attachment_fingerprint NOT GLOB '*[^0-9a-f]*'
  ),
  preflight_outcome TEXT NOT NULL CHECK(preflight_outcome IN ('PASS','WARN','BLOCKED')),
  preflight_result_json TEXT NOT NULL CHECK(
    json_valid(preflight_result_json) AND json_type(preflight_result_json)='object'
  ),
  preflight_result_hash TEXT NOT NULL,
  preflight_engine_version TEXT NOT NULL,
  bound_by TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  bound_at TEXT NOT NULL,
  CHECK(preflight_outcome<>'PASS' OR final_asset_checksum_sha256 IS NOT NULL),
  UNIQUE(workspace_id,publication_id,binding_hash),
  UNIQUE(id,workspace_id),
  UNIQUE(id,workspace_id,publication_id),
  FOREIGN KEY(publication_id,workspace_id) REFERENCES publications(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(platform_media_profile_id,workspace_id)
    REFERENCES platform_media_profiles(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_publication_profile_binding_profile
  ON publication_profile_bindings(platform_media_profile_id,profile_version);
CREATE INDEX idx_publication_profile_binding_history
  ON publication_profile_bindings(publication_id,bound_at,id);

CREATE TABLE publication_jobs (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  publication_id TEXT NOT NULL,
  profile_binding_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  execution_fingerprint TEXT NOT NULL,
  correlation_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','RUNNING','REMOTE_UNKNOWN','RETRY','COMPLETED','FAILED','CANCELLED')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 5 CHECK(max_attempts >= 1),
  remote_operation_id TEXT,
  last_remote_checked_at TEXT,
  last_error_code TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(publication_id,idempotency_key),
  UNIQUE(publication_id,execution_fingerprint),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(publication_id,workspace_id) REFERENCES publications(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(profile_binding_id,workspace_id,publication_id)
    REFERENCES publication_profile_bindings(id,workspace_id,publication_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX uq_publication_jobs_one_active
  ON publication_jobs(publication_id)
  WHERE status IN ('QUEUED','RUNNING','REMOTE_UNKNOWN','RETRY');

CREATE TABLE idempotency_records (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  scope TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('IN_PROGRESS','COMPLETED','FAILED_RETRYABLE','FAILED_FINAL')),
  resource_type TEXT,
  resource_id TEXT,
  response_code INTEGER,
  response_json TEXT CHECK(response_json IS NULL OR json_valid(response_json)),
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  UNIQUE(workspace_id,scope,idempotency_key)
);
CREATE INDEX idx_idempotency_expiry ON idempotency_records(expires_at);

CREATE TABLE schedules (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  schedule_type TEXT NOT NULL CHECK(schedule_type IN ('ONE_TIME','RECURRING')),
  job_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('DRAFT','ACTIVE','PAUSED','CANCELLED','COMPLETED')),
  timezone TEXT NOT NULL,
  dst_policy TEXT NOT NULL CHECK(dst_policy IN ('EARLIEST','LATEST','SKIP','SHIFT_FORWARD','REQUIRE_REVIEW')),
  past_due_policy TEXT NOT NULL CHECK(past_due_policy IN ('RUN_IMMEDIATELY','SKIP','REQUIRE_REVIEW')),
  one_time_local_datetime TEXT,
  recurrence_json TEXT CHECK(recurrence_json IS NULL OR json_valid(recurrence_json)),
  next_run_at_utc TEXT,
  schedule_version INTEGER NOT NULL DEFAULT 1 CHECK(schedule_version >= 1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  cancelled_at TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (schedule_type='ONE_TIME' AND one_time_local_datetime IS NOT NULL AND recurrence_json IS NULL)
    OR (schedule_type='RECURRING' AND one_time_local_datetime IS NULL AND recurrence_json IS NOT NULL)
  ),
  CHECK((status='CANCELLED' AND cancelled_at IS NOT NULL) OR status<>'CANCELLED'),
  UNIQUE(id,workspace_id)
);
CREATE INDEX idx_schedules_next_run ON schedules(status,next_run_at_utc);

CREATE TABLE schedule_occurrences (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  schedule_id TEXT NOT NULL,
  schedule_version INTEGER NOT NULL CHECK(schedule_version >= 1),
  occurrence_key TEXT NOT NULL,
  scheduled_at_utc TEXT NOT NULL,
  intended_local_datetime TEXT NOT NULL,
  utc_offset_minutes INTEGER NOT NULL CHECK(utc_offset_minutes BETWEEN -840 AND 840),
  fold INTEGER NOT NULL DEFAULT 0 CHECK(fold IN (0,1)),
  status TEXT NOT NULL CHECK(status IN (
    'PLANNED','DUE','REVIEW_REQUIRED','ENQUEUED','SKIPPED','MISSED','CANCELLED','COMPLETED','FAILED'
  )),
  past_due_decision TEXT CHECK(past_due_decision IS NULL OR past_due_decision IN ('RUN_IMMEDIATELY','SKIP','REQUIRE_REVIEW')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  UNIQUE(schedule_id,occurrence_key),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(schedule_id,workspace_id) REFERENCES schedules(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_schedule_occurrences_due ON schedule_occurrences(status,scheduled_at_utc);


CREATE TABLE worker_jobs (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  schedule_occurrence_id TEXT,
  job_type TEXT NOT NULL,
  payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
  execution_fingerprint TEXT NOT NULL CHECK(length(trim(execution_fingerprint)) > 0),
  correlation_id TEXT NOT NULL,
  causation_id TEXT,
  status TEXT NOT NULL CHECK(status IN ('QUEUED','RUNNING','WAITING','RETRY','COMPLETED','FAILED','CANCELLED')),
  priority INTEGER NOT NULL DEFAULT 100,
  available_at TEXT NOT NULL,
  lease_owner TEXT,
  lease_acquired_at TEXT,
  lease_expires_at TEXT,
  heartbeat_at TEXT,
  lease_generation INTEGER NOT NULL DEFAULT 0 CHECK(lease_generation >= 0),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 5 CHECK(max_attempts >= 1),
  idempotency_key TEXT,
  last_error_code TEXT,
  last_error_message TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(
    (status='RUNNING' AND lease_owner IS NOT NULL AND lease_acquired_at IS NOT NULL
      AND lease_expires_at IS NOT NULL AND heartbeat_at IS NOT NULL AND lease_generation >= 1)
    OR
    (status<>'RUNNING' AND lease_owner IS NULL AND lease_acquired_at IS NULL
      AND lease_expires_at IS NULL AND heartbeat_at IS NULL)
  ),
  UNIQUE(workspace_id,job_type,execution_fingerprint),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(schedule_occurrence_id,workspace_id) REFERENCES schedule_occurrences(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_worker_jobs_claim ON worker_jobs(status,available_at,priority);
CREATE UNIQUE INDEX idx_worker_jobs_idempotency
  ON worker_jobs(workspace_id,job_type,idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX uq_worker_job_schedule_occurrence
  ON worker_jobs(schedule_occurrence_id) WHERE schedule_occurrence_id IS NOT NULL;

-- Domain operations and generic workers have a typed, immutable one-to-one dispatch link.
CREATE TABLE render_job_dispatches (
  render_job_id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  worker_job_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  FOREIGN KEY(render_job_id,workspace_id) REFERENCES render_jobs(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(worker_job_id,workspace_id) REFERENCES worker_jobs(id,workspace_id) ON DELETE RESTRICT
);

CREATE TABLE publication_job_dispatches (
  publication_job_id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  worker_job_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  FOREIGN KEY(publication_job_id,workspace_id) REFERENCES publication_jobs(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(worker_job_id,workspace_id) REFERENCES worker_jobs(id,workspace_id) ON DELETE RESTRICT
);

-- Attempts are append-only evidence. Mutable job rows remain current projections.
CREATE TABLE worker_job_attempts (
  id TEXT PRIMARY KEY,
  worker_job_id TEXT NOT NULL REFERENCES worker_jobs(id) ON DELETE RESTRICT,
  attempt_no INTEGER NOT NULL CHECK(attempt_no >= 1),
  lease_generation INTEGER NOT NULL CHECK(lease_generation >= 1),
  lease_owner TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK(outcome IN (
    'RUNNING','SUCCEEDED','RETRYABLE_FAILURE','FINAL_FAILURE',
    'CANCELLED','LEASE_LOST','REMOTE_UNKNOWN'
  )),
  started_at TEXT NOT NULL,
  ended_at TEXT,
  error_code TEXT,
  retry_decision TEXT,
  evidence_json TEXT NOT NULL CHECK(json_valid(evidence_json) AND json_type(evidence_json)='object'),
  evidence_hash TEXT NOT NULL,
  correlation_id TEXT NOT NULL,
  causation_id TEXT,
  UNIQUE(worker_job_id,attempt_no),
  UNIQUE(worker_job_id,lease_generation),
  CHECK(
    (outcome='RUNNING' AND ended_at IS NULL)
    OR (outcome<>'RUNNING' AND ended_at IS NOT NULL)
  )
);

CREATE TABLE render_attempts (
  id TEXT PRIMARY KEY,
  render_job_id TEXT NOT NULL REFERENCES render_jobs(id) ON DELETE RESTRICT,
  worker_attempt_id TEXT NOT NULL UNIQUE REFERENCES worker_job_attempts(id) ON DELETE RESTRICT,
  attempt_no INTEGER NOT NULL CHECK(attempt_no >= 1),
  outcome TEXT NOT NULL CHECK(outcome IN (
    'RUNNING','SUCCEEDED','RETRYABLE_FAILURE','FINAL_FAILURE','CANCELLED','LEASE_LOST'
  )),
  render_plan_hash TEXT NOT NULL,
  executable_hash TEXT,
  argument_plan_hash TEXT NOT NULL,
  encoder_actual TEXT,
  fallback_used INTEGER NOT NULL DEFAULT 0 CHECK(fallback_used IN (0,1)),
  preflight_json TEXT NOT NULL CHECK(json_valid(preflight_json) AND json_type(preflight_json)='object'),
  probe_result_json TEXT CHECK(probe_result_json IS NULL OR (json_valid(probe_result_json) AND json_type(probe_result_json)='object')),
  output_checksum_sha256 TEXT,
  log_asset_id TEXT REFERENCES assets(id) ON DELETE RESTRICT,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  UNIQUE(render_job_id,attempt_no),
  CHECK(
    (outcome='RUNNING' AND ended_at IS NULL)
    OR (outcome<>'RUNNING' AND ended_at IS NOT NULL)
  )
);

CREATE TABLE publication_attempts (
  id TEXT PRIMARY KEY,
  publication_job_id TEXT NOT NULL REFERENCES publication_jobs(id) ON DELETE RESTRICT,
  worker_attempt_id TEXT NOT NULL UNIQUE REFERENCES worker_job_attempts(id) ON DELETE RESTRICT,
  attempt_no INTEGER NOT NULL CHECK(attempt_no >= 1),
  outcome TEXT NOT NULL CHECK(outcome IN (
    'RUNNING','SUCCEEDED','RETRYABLE_FAILURE','FINAL_FAILURE',
    'CANCELLED','LEASE_LOST','REMOTE_UNKNOWN'
  )),
  provider_outcome TEXT CHECK(provider_outcome IS NULL OR provider_outcome IN (
    'ACCEPTED','PROCESSING','PUBLISHED','DEFINITELY_NOT_FOUND','REMOTE_UNKNOWN',
    'AUTH_REQUIRED','RATE_LIMITED','TRANSIENT_FAILURE','PERMANENT_REJECTED','CANCELLED_REMOTE'
  )),
  provider_request_hash TEXT NOT NULL,
  adapter_version TEXT NOT NULL,
  remote_operation_id TEXT,
  remote_container_id TEXT,
  remote_media_id TEXT,
  evidence_json TEXT NOT NULL CHECK(json_valid(evidence_json) AND json_type(evidence_json)='object'),
  evidence_hash TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  UNIQUE(publication_job_id,attempt_no),
  CHECK(
    (outcome='RUNNING' AND ended_at IS NULL)
    OR (outcome<>'RUNNING' AND ended_at IS NOT NULL)
  ),
  CHECK(COALESCE((
    (outcome='RUNNING' AND provider_outcome IS NULL)
    OR outcome='LEASE_LOST'
    OR (outcome='CANCELLED' AND provider_outcome IS NULL)
    OR (outcome='SUCCEEDED' AND provider_outcome IN (
      'ACCEPTED','PROCESSING','PUBLISHED','DEFINITELY_NOT_FOUND','CANCELLED_REMOTE'
    ))
    OR (outcome='REMOTE_UNKNOWN' AND provider_outcome='REMOTE_UNKNOWN')
    OR (outcome='RETRYABLE_FAILURE' AND (
      provider_outcome IS NULL OR provider_outcome IN ('RATE_LIMITED','TRANSIENT_FAILURE')
    ))
    OR (outcome='FINAL_FAILURE' AND (
      provider_outcome IS NULL OR provider_outcome IN ('AUTH_REQUIRED','PERMANENT_REJECTED')
    ))
  ),0))
);

-- Remote staging is operational state with durable checksum and cleanup
-- evidence. Credentials and signed URLs are deliberately excluded.
CREATE TABLE publication_staging_objects (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  publication_id TEXT NOT NULL,
  publication_job_id TEXT,
  publication_attempt_id TEXT REFERENCES publication_attempts(id) ON DELETE RESTRICT,
  object_role TEXT NOT NULL CHECK(object_role IN (
    'UPLOAD_SOURCE','THUMBNAIL','COVER','TRANSCODE_INPUT','PROVIDER_CONTAINER'
  )),
  storage_provider TEXT NOT NULL CHECK(storage_provider IN (
    'R2','S3','GCS','AZURE_BLOB','LOCAL','PROVIDER'
  )),
  bucket_or_container TEXT NOT NULL CHECK(length(trim(bucket_or_container)) > 0),
  object_key TEXT NOT NULL CHECK(length(trim(object_key)) > 0),
  object_etag TEXT,
  checksum_sha256 TEXT,
  size_bytes INTEGER CHECK(size_bytes IS NULL OR size_bytes >= 0),
  status TEXT NOT NULL CHECK(status IN (
    'ALLOCATED','UPLOADING','READY','CONSUMED','EXPIRED',
    'CLEANUP_PENDING','CLEANUP_FAILED','CLEANED'
  )),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  ready_at TEXT,
  consumed_at TEXT,
  expires_at TEXT NOT NULL,
  cleanup_requested_at TEXT,
  cleaned_at TEXT,
  cleanup_evidence_json TEXT CHECK(
    cleanup_evidence_json IS NULL OR
    (json_valid(cleanup_evidence_json) AND json_type(cleanup_evidence_json)='object')
  ),
  cleanup_evidence_hash TEXT,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1),
  CHECK(status NOT IN ('READY','CONSUMED') OR
    (ready_at IS NOT NULL AND checksum_sha256 IS NOT NULL AND size_bytes IS NOT NULL)),
  CHECK(status<>'CONSUMED' OR consumed_at IS NOT NULL),
  CHECK(status NOT IN ('CLEANUP_PENDING','CLEANUP_FAILED','CLEANED') OR cleanup_requested_at IS NOT NULL),
  CHECK(status NOT IN ('CLEANUP_FAILED','CLEANED') OR
    (cleanup_evidence_json IS NOT NULL AND cleanup_evidence_hash IS NOT NULL)),
  CHECK((status='CLEANED' AND cleaned_at IS NOT NULL) OR (status<>'CLEANED' AND cleaned_at IS NULL)),
  UNIQUE(workspace_id,storage_provider,bucket_or_container,object_key),
  UNIQUE(id,workspace_id),
  FOREIGN KEY(publication_id,workspace_id) REFERENCES publications(id,workspace_id) ON DELETE RESTRICT,
  FOREIGN KEY(publication_job_id,workspace_id)
    REFERENCES publication_jobs(id,workspace_id) ON DELETE RESTRICT
);
CREATE INDEX idx_publication_staging_cleanup
  ON publication_staging_objects(workspace_id,status,expires_at);

CREATE TABLE operation_events (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  event_type TEXT NOT NULL,
  request_id TEXT NOT NULL CHECK(length(trim(request_id)) > 0),
  correlation_id TEXT NOT NULL,
  causation_id TEXT,
  actor_type TEXT CHECK(actor_type IS NULL OR actor_type IN ('USER','SERVICE','SYSTEM')),
  actor_id TEXT,
  actor_role TEXT,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  aggregate_version INTEGER NOT NULL CHECK(aggregate_version >= 1),
  payload_schema TEXT NOT NULL CHECK(
    length(trim(payload_schema)) > 4 AND payload_schema GLOB 'ccs.*'
  ),
  payload_version INTEGER NOT NULL CHECK(payload_version >= 1),
  payload_json TEXT NOT NULL CHECK(json_valid(payload_json) AND json_type(payload_json)='object'),
  payload_hash TEXT NOT NULL CHECK(
    length(payload_hash)=64 AND payload_hash NOT GLOB '*[^0-9a-f]*'
  ),
  metadata_json TEXT CHECK(
    metadata_json IS NULL OR (json_valid(metadata_json) AND json_type(metadata_json)='object')
  ),
  occurred_at TEXT NOT NULL,
  CHECK(
    (actor_type IS NULL AND actor_id IS NULL AND actor_role IS NULL)
    OR (actor_type IS NOT NULL AND actor_id IS NOT NULL AND length(trim(actor_id)) > 0)
  ),
  UNIQUE(aggregate_type,aggregate_id,aggregate_version,event_type)
);
CREATE INDEX idx_operation_events_workspace_time
  ON operation_events(workspace_id,occurred_at,id);

CREATE TABLE analytics_metrics (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  publication_id TEXT NOT NULL REFERENCES publications(id) ON DELETE RESTRICT,
  metric_name TEXT NOT NULL,
  metric_date TEXT NOT NULL,
  value_numeric REAL,
  value_json TEXT CHECK(value_json IS NULL OR json_valid(value_json)),
  dimensions_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(dimensions_json)),
  dimensions_hash TEXT NOT NULL,
  provider_observed_at TEXT,
  collected_at TEXT NOT NULL,
  UNIQUE(publication_id,metric_name,metric_date,dimensions_hash)
);
CREATE INDEX idx_analytics_publication_date ON analytics_metrics(publication_id,metric_date);

CREATE TABLE experiments (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
  experiment_type TEXT NOT NULL,
  target_metric TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('DRAFT','RUNNING','COLLECTING','COMPLETED','INCONCLUSIVE','CANCELLED')),
  evaluation_rule_json TEXT NOT NULL CHECK(json_valid(evaluation_rule_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);

CREATE TABLE experiment_variants (
  id TEXT PRIMARY KEY,
  experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE RESTRICT,
  variant_key TEXT NOT NULL,
  content_version_id TEXT REFERENCES content_versions(id) ON DELETE RESTRICT,
  hook_id TEXT REFERENCES hooks(id) ON DELETE RESTRICT,
  thumbnail_id TEXT REFERENCES thumbnails(id) ON DELETE RESTRICT,
  variant_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(variant_json)),
  created_at TEXT NOT NULL,
  UNIQUE(experiment_id,variant_key)
);

CREATE TABLE project_learning (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
  learning_type TEXT NOT NULL,
  pattern_json TEXT NOT NULL CHECK(json_valid(pattern_json)),
  evidence_json TEXT NOT NULL CHECK(json_valid(evidence_json)),
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
  status TEXT NOT NULL CHECK(status IN ('PROPOSED','ACTIVE','REJECTED','SUPERSEDED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK(row_version >= 1)
);

CREATE TABLE audit_events (
  id TEXT PRIMARY KEY,
  workspace_id TEXT REFERENCES workspaces(id) ON DELETE RESTRICT,
  stream_key TEXT NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no >= 1),
  actor_type TEXT NOT NULL CHECK(actor_type IN ('USER','SERVICE_ACCOUNT','SYSTEM')),
  actor_id TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  event_json TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(event_json)),
  event_hash TEXT NOT NULL,
  previous_event_hash TEXT,
  occurred_at TEXT NOT NULL,
  UNIQUE(stream_key,sequence_no),
  UNIQUE(stream_key,event_hash)
);
CREATE INDEX idx_audit_workspace_time ON audit_events(workspace_id,occurred_at);

CREATE TABLE capability_registry (
  id TEXT PRIMARY KEY,
  workspace_id TEXT REFERENCES workspaces(id) ON DELETE RESTRICT,
  provider TEXT NOT NULL,
  capability_type TEXT NOT NULL,
  requirement TEXT NOT NULL CHECK(requirement IN ('REQUIRED','OPTIONAL','OPERATION_REQUIRED')),
  state TEXT NOT NULL CHECK(state IN ('AVAILABLE','DEGRADED','UNAVAILABLE','INCOMPATIBLE')),
  version TEXT,
  secret_ref TEXT,
  diagnostic_code TEXT,
  last_checked_at TEXT NOT NULL
);
CREATE UNIQUE INDEX uq_capability_workspace
  ON capability_registry(workspace_id,provider,capability_type) WHERE workspace_id IS NOT NULL;
CREATE UNIQUE INDEX uq_capability_global
  ON capability_registry(provider,capability_type) WHERE workspace_id IS NULL;


-- =====================================================================
-- v2.2 database invariants and immutability
-- =====================================================================

CREATE VIEW timeline_workspace_view AS
SELECT t.id AS timeline_id, c.workspace_id AS workspace_id, c.project_id AS project_id,
       t.content_version_id AS content_version_id
FROM timelines t
JOIN content_versions cv ON cv.id=t.content_version_id
JOIN contents c ON c.id=cv.content_id;

-- Core workspace consistency.
CREATE TRIGGER trg_assets_project_workspace_ins
BEFORE INSERT ON assets
WHEN NEW.project_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id
)
BEGIN SELECT RAISE(ABORT,'asset project/workspace mismatch'); END;
CREATE TRIGGER trg_assets_project_workspace_upd
BEFORE UPDATE OF project_id,workspace_id ON assets
WHEN NEW.project_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id
)
BEGIN SELECT RAISE(ABORT,'asset project/workspace mismatch'); END;

CREATE TRIGGER trg_contents_project_workspace_ins
BEFORE INSERT ON contents
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'content project/workspace mismatch'); END;
CREATE TRIGGER trg_contents_project_workspace_upd
BEFORE UPDATE OF project_id,workspace_id ON contents
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'content project/workspace mismatch'); END;

CREATE TRIGGER trg_benchmarks_workspace_ins
BEFORE INSERT ON benchmarks
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
  OR (NEW.source_asset_id IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id
  ))
BEGIN SELECT RAISE(ABORT,'benchmark workspace mismatch'); END;
CREATE TRIGGER trg_benchmarks_workspace_upd
BEFORE UPDATE OF project_id,workspace_id,source_asset_id ON benchmarks
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
  OR (NEW.source_asset_id IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id
  ))
BEGIN SELECT RAISE(ABORT,'benchmark workspace mismatch'); END;

CREATE TRIGGER trg_benchmark_analysis_must_start_queued
BEFORE INSERT ON benchmark_analyses
WHEN NEW.status<>'QUEUED'
  OR NEW.started_at IS NOT NULL
  OR NEW.completed_at IS NOT NULL
  OR NEW.result_json IS NOT NULL
  OR NEW.result_hash IS NOT NULL
BEGIN SELECT RAISE(ABORT,'benchmark analysis must start as an empty QUEUED execution'); END;

CREATE TRIGGER trg_benchmark_analysis_transition_guard
BEFORE UPDATE OF status ON benchmark_analyses
WHEN NEW.status<>OLD.status
  AND NOT (
    (OLD.status='QUEUED' AND NEW.status IN ('RUNNING','CANCELLED'))
    OR (OLD.status='RUNNING' AND NEW.status IN ('COMPLETED','FAILED','CANCELLED'))
  )
BEGIN SELECT RAISE(ABORT,'invalid benchmark analysis status transition'); END;

CREATE TRIGGER trg_benchmark_analysis_identity_guard
BEFORE UPDATE ON benchmark_analyses
WHEN NEW.id<>OLD.id
  OR NEW.benchmark_id<>OLD.benchmark_id
  OR NEW.analysis_version<>OLD.analysis_version
  OR NEW.model_evidence_json<>OLD.model_evidence_json
  OR NEW.created_at<>OLD.created_at
  OR NEW.row_version<>OLD.row_version+1
BEGIN SELECT RAISE(ABORT,'benchmark analysis identity is immutable and row_version must advance once'); END;

CREATE TRIGGER trg_benchmark_analysis_terminal_immutable
BEFORE UPDATE ON benchmark_analyses
WHEN OLD.status IN ('COMPLETED','FAILED','CANCELLED')
BEGIN SELECT RAISE(ABORT,'terminal benchmark analysis evidence is immutable'); END;

CREATE TRIGGER trg_benchmark_analysis_terminal_no_delete
BEFORE DELETE ON benchmark_analyses
WHEN OLD.status IN ('COMPLETED','FAILED','CANCELLED')
BEGIN SELECT RAISE(ABORT,'terminal benchmark analysis history is immutable'); END;

CREATE TRIGGER trg_design_preset_project_workspace_ins
BEFORE INSERT ON design_presets
WHEN NEW.scope='PROJECT' AND NOT EXISTS(
  SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id
)
BEGIN SELECT RAISE(ABORT,'design preset project/workspace mismatch'); END;
CREATE TRIGGER trg_design_preset_project_workspace_upd
BEFORE UPDATE OF scope,project_id,workspace_id ON design_presets
WHEN NEW.scope='PROJECT' AND NOT EXISTS(
  SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id
)
BEGIN SELECT RAISE(ABORT,'design preset project/workspace mismatch'); END;

-- ContentVersion immutable payload/history.
CREATE TRIGGER trg_content_versions_no_delete
BEFORE DELETE ON content_versions
BEGIN SELECT RAISE(ABORT,'content version history is immutable'); END;

CREATE TRIGGER trg_content_versions_approved_payload_immutable
BEFORE UPDATE ON content_versions
WHEN OLD.status IN ('APPROVED','SUPERSEDED') AND (
  NEW.content_id<>OLD.content_id OR NEW.version_number<>OLD.version_number
  OR COALESCE(NEW.parent_version_id,'')<>COALESCE(OLD.parent_version_id,'')
  OR COALESCE(NEW.title_snapshot,'')<>COALESCE(OLD.title_snapshot,'')
  OR COALESCE(NEW.script_snapshot_json,'')<>COALESCE(OLD.script_snapshot_json,'')
  OR NEW.content_snapshot_json<>OLD.content_snapshot_json
  OR NEW.snapshot_hash<>OLD.snapshot_hash
  OR COALESCE(NEW.created_by,'')<>COALESCE(OLD.created_by,'')
  OR NEW.created_at<>OLD.created_at
  OR COALESCE(NEW.approved_at,'')<>COALESCE(OLD.approved_at,'')
  OR COALESCE(NEW.approved_by,'')<>COALESCE(OLD.approved_by,'')
)
BEGIN SELECT RAISE(ABORT,'approved content version payload is immutable'); END;

CREATE TRIGGER trg_content_versions_status_guard
BEFORE UPDATE OF status ON content_versions
WHEN OLD.status='SUPERSEDED' AND NEW.status<>'SUPERSEDED'
  OR OLD.status='APPROVED' AND NEW.status NOT IN ('APPROVED','SUPERSEDED')
BEGIN SELECT RAISE(ABORT,'approved content version status cannot move backward'); END;

-- Timeline structural semantics.
CREATE TRIGGER trg_transition_semantics_ins
BEFORE INSERT ON timeline_transitions
BEGIN
  SELECT CASE WHEN (SELECT sequence_no FROM timeline_clips WHERE id=NEW.from_clip_id) >=
                        (SELECT sequence_no FROM timeline_clips WHERE id=NEW.to_clip_id)
    THEN RAISE(ABORT,'transition direction invalid') END;
  SELECT CASE WHEN EXISTS(
    SELECT 1 FROM timeline_clips mid
    WHERE mid.track_id=NEW.track_id
      AND mid.sequence_no > (SELECT sequence_no FROM timeline_clips WHERE id=NEW.from_clip_id)
      AND mid.sequence_no < (SELECT sequence_no FROM timeline_clips WHERE id=NEW.to_clip_id)
  ) THEN RAISE(ABORT,'transition clips are not adjacent') END;
  SELECT CASE WHEN NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
                    OR NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.to_clip_id)
    THEN RAISE(ABORT,'transition duration exceeds clip duration') END;
  SELECT CASE WHEN NEW.transition_type='CUT' AND
    (SELECT timeline_start_ms FROM timeline_clips WHERE id=NEW.to_clip_id) <>
    (SELECT timeline_start_ms+duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
    THEN RAISE(ABORT,'CUT temporal equation invalid') END;
  SELECT CASE WHEN NEW.transition_type<>'CUT' AND
    (SELECT timeline_start_ms FROM timeline_clips WHERE id=NEW.to_clip_id) <>
    (SELECT timeline_start_ms+duration_ms-NEW.duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
    THEN RAISE(ABORT,'overlap transition temporal equation invalid') END;
END;
CREATE TRIGGER trg_transition_semantics_upd
BEFORE UPDATE ON timeline_transitions
BEGIN
  SELECT CASE WHEN (SELECT sequence_no FROM timeline_clips WHERE id=NEW.from_clip_id) >=
                        (SELECT sequence_no FROM timeline_clips WHERE id=NEW.to_clip_id)
    THEN RAISE(ABORT,'transition direction invalid') END;
  SELECT CASE WHEN EXISTS(
    SELECT 1 FROM timeline_clips mid
    WHERE mid.track_id=NEW.track_id
      AND mid.sequence_no > (SELECT sequence_no FROM timeline_clips WHERE id=NEW.from_clip_id)
      AND mid.sequence_no < (SELECT sequence_no FROM timeline_clips WHERE id=NEW.to_clip_id)
  ) THEN RAISE(ABORT,'transition clips are not adjacent') END;
  SELECT CASE WHEN NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
                    OR NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.to_clip_id)
    THEN RAISE(ABORT,'transition duration exceeds clip duration') END;
  SELECT CASE WHEN NEW.transition_type='CUT' AND
    (SELECT timeline_start_ms FROM timeline_clips WHERE id=NEW.to_clip_id) <>
    (SELECT timeline_start_ms+duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
    THEN RAISE(ABORT,'CUT temporal equation invalid') END;
  SELECT CASE WHEN NEW.transition_type<>'CUT' AND
    (SELECT timeline_start_ms FROM timeline_clips WHERE id=NEW.to_clip_id) <>
    (SELECT timeline_start_ms+duration_ms-NEW.duration_ms FROM timeline_clips WHERE id=NEW.from_clip_id)
    THEN RAISE(ABORT,'overlap transition temporal equation invalid') END;
END;

CREATE TRIGGER trg_clip_fade_duration_ins
BEFORE INSERT ON clip_fades
WHEN NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.clip_id)
BEGIN SELECT RAISE(ABORT,'fade duration exceeds clip duration'); END;
CREATE TRIGGER trg_clip_fade_duration_upd
BEFORE UPDATE ON clip_fades
WHEN NEW.duration_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.clip_id)
BEGIN SELECT RAISE(ABORT,'fade duration exceeds clip duration'); END;

CREATE TRIGGER trg_overlay_track_type_ins
BEFORE INSERT ON timeline_overlays
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id
    AND (
      (NEW.overlay_type='TEXT' AND tr.track_type='TEXT')
      OR (NEW.overlay_type<>'TEXT' AND tr.track_type IN ('GRAPHIC','VIDEO_OVERLAY'))
    )
)
BEGIN SELECT RAISE(ABORT,'overlay/track type mismatch'); END;
CREATE TRIGGER trg_overlay_track_type_upd
BEFORE UPDATE OF track_id,timeline_id,overlay_type ON timeline_overlays
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id
    AND (
      (NEW.overlay_type='TEXT' AND tr.track_type='TEXT')
      OR (NEW.overlay_type<>'TEXT' AND tr.track_type IN ('GRAPHIC','VIDEO_OVERLAY'))
    )
)
BEGIN SELECT RAISE(ABORT,'overlay/track type mismatch'); END;

CREATE TRIGGER trg_caption_track_type_ins
BEFORE INSERT ON captions
WHEN NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type='CAPTION')
BEGIN SELECT RAISE(ABORT,'caption requires CAPTION track'); END;
CREATE TRIGGER trg_caption_track_type_upd
BEFORE UPDATE OF track_id,timeline_id ON captions
WHEN NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type='CAPTION')
BEGIN SELECT RAISE(ABORT,'caption requires CAPTION track'); END;

CREATE TRIGGER trg_ducking_audio_tracks_ins
BEFORE INSERT ON audio_ducking_rules
WHEN NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.trigger_track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX'))
  OR NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.target_track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX'))
BEGIN SELECT RAISE(ABORT,'ducking requires audio tracks'); END;
CREATE TRIGGER trg_ducking_audio_tracks_upd
BEFORE UPDATE ON audio_ducking_rules
WHEN NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.trigger_track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX'))
  OR NOT EXISTS(SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.target_track_id AND tr.timeline_id=NEW.timeline_id AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX'))
BEGIN SELECT RAISE(ABORT,'ducking requires audio tracks'); END;

-- Transition/fade media-scope compatibility.
CREATE TRIGGER trg_transition_media_scope_ins
BEFORE INSERT ON timeline_transitions
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND NEW.media_scope IN ('VIDEO','BOTH'))
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND NEW.media_scope='AUDIO')
  )
)
BEGIN SELECT RAISE(ABORT,'transition media scope incompatible with track'); END;
CREATE TRIGGER trg_transition_media_scope_upd
BEFORE UPDATE OF track_id,timeline_id,media_scope ON timeline_transitions
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND NEW.media_scope IN ('VIDEO','BOTH'))
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND NEW.media_scope='AUDIO')
  )
)
BEGIN SELECT RAISE(ABORT,'transition media scope incompatible with track'); END;
CREATE TRIGGER trg_fade_media_scope_ins
BEFORE INSERT ON clip_fades
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_clips c JOIN timeline_tracks tr ON tr.id=c.track_id AND tr.timeline_id=c.timeline_id
  WHERE c.id=NEW.clip_id AND c.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND NEW.media_scope IN ('VIDEO','BOTH'))
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND NEW.media_scope='AUDIO')
  )
)
BEGIN SELECT RAISE(ABORT,'fade media scope incompatible with track'); END;
CREATE TRIGGER trg_fade_media_scope_upd
BEFORE UPDATE OF clip_id,timeline_id,media_scope ON clip_fades
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_clips c JOIN timeline_tracks tr ON tr.id=c.track_id AND tr.timeline_id=c.timeline_id
  WHERE c.id=NEW.clip_id AND c.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND NEW.media_scope IN ('VIDEO','BOTH'))
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND NEW.media_scope='AUDIO')
  )
)
BEGIN SELECT RAISE(ABORT,'fade media scope incompatible with track'); END;

-- Keyframe target/property/time/range.
CREATE TRIGGER trg_keyframe_semantics_ins
BEFORE INSERT ON timeline_keyframes
BEGIN
  SELECT CASE WHEN NEW.target_type='AUDIO_TRACK' AND (
    NEW.property_name<>'VOLUME' OR NOT EXISTS(
      SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id
        AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX')
    )) THEN RAISE(ABORT,'audio track keyframe must target audio VOLUME') END;
  SELECT CASE WHEN NEW.target_type='OVERLAY' AND NEW.property_name NOT IN (
    'POSITION_X','POSITION_Y','SCALE_X','SCALE_Y','ROTATION_DEG','OPACITY','BLUR_RADIUS','SATURATION'
  ) THEN RAISE(ABORT,'overlay keyframe property incompatible') END;
  SELECT CASE WHEN NEW.target_type='CLIP' AND NEW.time_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.clip_id)
    THEN RAISE(ABORT,'clip keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.target_type='OVERLAY' AND NEW.time_ms > (SELECT end_ms-start_ms FROM timeline_overlays WHERE id=NEW.overlay_id)
    THEN RAISE(ABORT,'overlay keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.target_type='AUDIO_TRACK' AND NEW.time_ms > COALESCE((SELECT duration_ms FROM timeline_duration_view WHERE timeline_id=NEW.timeline_id),0)
    THEN RAISE(ABORT,'track keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.property_name IN ('POSITION_X','POSITION_Y','OPACITY','CROP_X','CROP_Y','CROP_WIDTH','CROP_HEIGHT')
    AND (CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<0 OR CAST(json_extract(NEW.auto_value_json,'$') AS REAL)>1)
    THEN RAISE(ABORT,'normalized keyframe auto value out of range') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('POSITION_X','POSITION_Y','OPACITY','CROP_X','CROP_Y','CROP_WIDTH','CROP_HEIGHT')
    AND (CAST(json_extract(NEW.override_value_json,'$') AS REAL)<0 OR CAST(json_extract(NEW.override_value_json,'$') AS REAL)>1)
    THEN RAISE(ABORT,'normalized keyframe override out of range') END;
  SELECT CASE WHEN NEW.property_name IN ('SCALE_X','SCALE_Y') AND CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<=0
    THEN RAISE(ABORT,'scale keyframe must be positive') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('SCALE_X','SCALE_Y') AND CAST(json_extract(NEW.override_value_json,'$') AS REAL)<=0
    THEN RAISE(ABORT,'scale override must be positive') END;
  SELECT CASE WHEN NEW.property_name IN ('VOLUME','BLUR_RADIUS','SATURATION') AND CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<0
    THEN RAISE(ABORT,'keyframe value must be nonnegative') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('VOLUME','BLUR_RADIUS','SATURATION') AND CAST(json_extract(NEW.override_value_json,'$') AS REAL)<0
    THEN RAISE(ABORT,'keyframe override must be nonnegative') END;
END;
CREATE TRIGGER trg_keyframe_semantics_upd
BEFORE UPDATE ON timeline_keyframes
BEGIN
  SELECT CASE WHEN NEW.target_type='AUDIO_TRACK' AND (
    NEW.property_name<>'VOLUME' OR NOT EXISTS(
      SELECT 1 FROM timeline_tracks tr WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id
        AND tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX')
    )) THEN RAISE(ABORT,'audio track keyframe must target audio VOLUME') END;
  SELECT CASE WHEN NEW.target_type='OVERLAY' AND NEW.property_name NOT IN (
    'POSITION_X','POSITION_Y','SCALE_X','SCALE_Y','ROTATION_DEG','OPACITY','BLUR_RADIUS','SATURATION'
  ) THEN RAISE(ABORT,'overlay keyframe property incompatible') END;
  SELECT CASE WHEN NEW.target_type='CLIP' AND NEW.time_ms > (SELECT duration_ms FROM timeline_clips WHERE id=NEW.clip_id)
    THEN RAISE(ABORT,'clip keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.target_type='OVERLAY' AND NEW.time_ms > (SELECT end_ms-start_ms FROM timeline_overlays WHERE id=NEW.overlay_id)
    THEN RAISE(ABORT,'overlay keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.target_type='AUDIO_TRACK' AND NEW.time_ms > COALESCE((SELECT duration_ms FROM timeline_duration_view WHERE timeline_id=NEW.timeline_id),0)
    THEN RAISE(ABORT,'track keyframe time out of bounds') END;
  SELECT CASE WHEN NEW.property_name IN ('POSITION_X','POSITION_Y','OPACITY','CROP_X','CROP_Y','CROP_WIDTH','CROP_HEIGHT')
    AND (CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<0 OR CAST(json_extract(NEW.auto_value_json,'$') AS REAL)>1)
    THEN RAISE(ABORT,'normalized keyframe auto value out of range') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('POSITION_X','POSITION_Y','OPACITY','CROP_X','CROP_Y','CROP_WIDTH','CROP_HEIGHT')
    AND (CAST(json_extract(NEW.override_value_json,'$') AS REAL)<0 OR CAST(json_extract(NEW.override_value_json,'$') AS REAL)>1)
    THEN RAISE(ABORT,'normalized keyframe override out of range') END;
  SELECT CASE WHEN NEW.property_name IN ('SCALE_X','SCALE_Y') AND CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<=0
    THEN RAISE(ABORT,'scale keyframe must be positive') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('SCALE_X','SCALE_Y') AND CAST(json_extract(NEW.override_value_json,'$') AS REAL)<=0
    THEN RAISE(ABORT,'scale override must be positive') END;
  SELECT CASE WHEN NEW.property_name IN ('VOLUME','BLUR_RADIUS','SATURATION') AND CAST(json_extract(NEW.auto_value_json,'$') AS REAL)<0
    THEN RAISE(ABORT,'keyframe value must be nonnegative') END;
  SELECT CASE WHEN NEW.override_value_json IS NOT NULL AND NEW.property_name IN ('VOLUME','BLUR_RADIUS','SATURATION') AND CAST(json_extract(NEW.override_value_json,'$') AS REAL)<0
    THEN RAISE(ABORT,'keyframe override must be nonnegative') END;
END;

-- Workspace consistency for media graph and downstream side effects.
CREATE TRIGGER trg_clip_source_workspace_ins
BEFORE INSERT ON timeline_clips
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_workspace_view tw JOIN assets a ON a.id=NEW.source_asset_id
  WHERE tw.timeline_id=NEW.timeline_id AND a.workspace_id=tw.workspace_id
)
BEGIN SELECT RAISE(ABORT,'clip source asset workspace mismatch'); END;
CREATE TRIGGER trg_clip_source_workspace_upd
BEFORE UPDATE OF timeline_id,source_asset_id ON timeline_clips
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_workspace_view tw JOIN assets a ON a.id=NEW.source_asset_id
  WHERE tw.timeline_id=NEW.timeline_id AND a.workspace_id=tw.workspace_id
)
BEGIN SELECT RAISE(ABORT,'clip source asset workspace mismatch'); END;

CREATE TRIGGER trg_overlay_asset_workspace_ins
BEFORE INSERT ON timeline_overlays
WHEN NEW.asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timeline_workspace_view tw JOIN assets a ON a.id=NEW.asset_id
  WHERE tw.timeline_id=NEW.timeline_id AND a.workspace_id=tw.workspace_id
)
BEGIN SELECT RAISE(ABORT,'overlay asset workspace mismatch'); END;
CREATE TRIGGER trg_overlay_asset_workspace_upd
BEFORE UPDATE OF timeline_id,asset_id ON timeline_overlays
WHEN NEW.asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timeline_workspace_view tw JOIN assets a ON a.id=NEW.asset_id
  WHERE tw.timeline_id=NEW.timeline_id AND a.workspace_id=tw.workspace_id
)
BEGIN SELECT RAISE(ABORT,'overlay asset workspace mismatch'); END;

CREATE TRIGGER trg_media_analysis_workspace_ins
BEFORE INSERT ON media_analysis_runs
WHEN NOT EXISTS(SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'media analysis workspace mismatch'); END;
CREATE TRIGGER trg_media_analysis_workspace_upd
BEFORE UPDATE OF workspace_id,source_asset_id ON media_analysis_runs
WHEN NOT EXISTS(SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'media analysis workspace mismatch'); END;

CREATE TRIGGER trg_asset_proxy_workspace_ins
BEFORE INSERT ON asset_proxies
WHEN NEW.proxy_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets s JOIN assets p ON p.id=NEW.proxy_asset_id
  WHERE s.id=NEW.source_asset_id AND s.workspace_id=p.workspace_id
)
BEGIN SELECT RAISE(ABORT,'proxy asset workspace mismatch'); END;

CREATE TRIGGER trg_waveform_workspace_ins
BEFORE INSERT ON audio_waveforms
WHEN NEW.waveform_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets s JOIN assets w ON w.id=NEW.waveform_asset_id
  WHERE s.id=NEW.source_asset_id AND s.workspace_id=w.workspace_id
)
BEGIN SELECT RAISE(ABORT,'waveform asset workspace mismatch'); END;

CREATE TRIGGER trg_reframe_workspace_ins
BEFORE INSERT ON reframe_plans
WHEN NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.source_asset_id
  WHERE cv.id=NEW.content_version_id AND a.workspace_id=c.workspace_id
)
BEGIN SELECT RAISE(ABORT,'reframe source workspace mismatch'); END;

CREATE TRIGGER trg_short_candidate_workspace_ins
BEFORE INSERT ON short_candidates
WHEN NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.source_asset_id
  WHERE cv.id=NEW.source_content_version_id AND a.workspace_id=c.workspace_id
)
BEGIN SELECT RAISE(ABORT,'short candidate source workspace mismatch'); END;

CREATE TRIGGER trg_render_snapshot_integrity_ins
BEFORE INSERT ON render_snapshots
WHEN NOT EXISTS(
  SELECT 1 FROM timelines t
  JOIN content_versions cv ON cv.id=t.content_version_id
  JOIN contents c ON c.id=cv.content_id
  JOIN timeline_materializations tm ON tm.id=NEW.timeline_materialization_id AND tm.timeline_id=t.id
  WHERE t.id=NEW.timeline_id AND cv.id=NEW.content_version_id AND c.workspace_id=NEW.workspace_id
    AND tm.graph_revision=t.graph_revision
) OR (
  NEW.snapshot_type='FINAL' AND NOT EXISTS(
    SELECT 1 FROM timelines t
    JOIN content_versions cv ON cv.id=t.content_version_id
    JOIN timeline_approvals ta ON ta.timeline_id=t.id AND ta.materialization_id=NEW.timeline_materialization_id
    WHERE t.id=NEW.timeline_id AND cv.id=NEW.content_version_id
      AND cv.status='APPROVED' AND t.status='APPROVED'
  )
)
BEGIN SELECT RAISE(ABORT,'render snapshot workspace/content/timeline/materialization gate mismatch'); END;

CREATE TRIGGER trg_render_job_workspace_ins
BEFORE INSERT ON render_jobs
WHEN NOT EXISTS(
  SELECT 1 FROM render_snapshots rs
  WHERE rs.id=NEW.render_snapshot_id AND rs.workspace_id=NEW.workspace_id AND rs.snapshot_type=NEW.render_type
)
BEGIN SELECT RAISE(ABORT,'render job workspace/type mismatch'); END;

CREATE TRIGGER trg_render_job_completed_require_output_ins
BEFORE INSERT ON render_jobs
WHEN NEW.status='COMPLETED' AND (
  NEW.output_asset_id IS NULL OR NEW.output_checksum_sha256 IS NULL OR NEW.completed_at IS NULL OR NOT EXISTS(
    SELECT 1 FROM assets a
    JOIN render_snapshots rs ON rs.id=NEW.render_snapshot_id
    JOIN content_versions cv ON cv.id=rs.content_version_id
    JOIN contents c ON c.id=cv.content_id
    WHERE a.id=NEW.output_asset_id AND a.workspace_id=NEW.workspace_id AND a.project_id=c.project_id
      AND a.status='AVAILABLE' AND a.checksum_sha256=NEW.output_checksum_sha256
      AND ((NEW.render_type='FINAL' AND a.asset_type='FINAL_VIDEO')
        OR (NEW.render_type IN ('PREVIEW','DRAFT') AND a.asset_type='PREVIEW_VIDEO'))
  )
)
BEGIN SELECT RAISE(ABORT,'completed render job requires matching output asset evidence'); END;
CREATE TRIGGER trg_render_job_completed_require_output
BEFORE UPDATE OF status,output_asset_id,output_checksum_sha256 ON render_jobs
WHEN NEW.status='COMPLETED' AND (
  NEW.output_asset_id IS NULL OR NEW.output_checksum_sha256 IS NULL OR NEW.completed_at IS NULL OR NOT EXISTS(
    SELECT 1 FROM assets a
    JOIN render_snapshots rs ON rs.id=NEW.render_snapshot_id
    JOIN content_versions cv ON cv.id=rs.content_version_id
    JOIN contents c ON c.id=cv.content_id
    WHERE a.id=NEW.output_asset_id AND a.workspace_id=NEW.workspace_id AND a.project_id=c.project_id
      AND a.status='AVAILABLE' AND a.checksum_sha256=NEW.output_checksum_sha256
      AND ((NEW.render_type='FINAL' AND a.asset_type='FINAL_VIDEO')
        OR (NEW.render_type IN ('PREVIEW','DRAFT') AND a.asset_type='PREVIEW_VIDEO'))
  )
)
BEGIN SELECT RAISE(ABORT,'completed render job requires matching output asset evidence'); END;

CREATE TRIGGER trg_render_job_completed_immutable
BEFORE UPDATE ON render_jobs
WHEN OLD.status='COMPLETED'
BEGIN SELECT RAISE(ABORT,'completed render job is immutable'); END;
CREATE TRIGGER trg_render_job_no_delete
BEFORE DELETE ON render_jobs
BEGIN SELECT RAISE(ABORT,'render job history is immutable'); END;

CREATE TRIGGER trg_publication_workspace_ins
BEFORE INSERT ON publications
WHEN NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN platform_accounts pa ON pa.id=NEW.platform_account_id
  WHERE cv.id=NEW.content_version_id AND c.workspace_id=NEW.workspace_id AND pa.workspace_id=NEW.workspace_id
    AND (NEW.status IN ('NOT_READY','CANCELLED') OR cv.status='APPROVED')
) OR (NEW.final_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.final_asset_id AND a.workspace_id=NEW.workspace_id
)) OR (NEW.final_render_job_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM render_jobs rj JOIN render_snapshots rs ON rs.id=rj.render_snapshot_id
  WHERE rj.id=NEW.final_render_job_id AND rj.workspace_id=NEW.workspace_id
    AND rj.status='COMPLETED' AND rj.render_type='FINAL'
    AND rj.output_asset_id=NEW.final_asset_id AND rs.content_version_id=NEW.content_version_id
)) OR (NEW.status NOT IN ('NOT_READY','CANCELLED') AND NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.final_asset_id AND a.workspace_id=NEW.workspace_id
    AND a.status='AVAILABLE' AND (
      (NEW.publication_type IN ('LONG_FORM','SHORT','REEL') AND a.asset_type='FINAL_VIDEO' AND NEW.final_render_job_id IS NOT NULL)
      OR (NEW.publication_type='IMAGE' AND a.asset_type IN ('IMAGE','THUMBNAIL') AND NEW.final_render_job_id IS NULL)
    )
))
BEGIN SELECT RAISE(ABORT,'publication workspace/readiness/final-render lineage mismatch'); END;
CREATE TRIGGER trg_publication_workspace_upd
BEFORE UPDATE OF workspace_id,content_version_id,platform_account_id,final_asset_id,final_render_job_id,publication_type,status ON publications
WHEN NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN platform_accounts pa ON pa.id=NEW.platform_account_id
  WHERE cv.id=NEW.content_version_id AND c.workspace_id=NEW.workspace_id AND pa.workspace_id=NEW.workspace_id
    AND (NEW.status IN ('NOT_READY','CANCELLED') OR cv.status='APPROVED')
) OR (NEW.final_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.final_asset_id AND a.workspace_id=NEW.workspace_id
)) OR (NEW.final_render_job_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM render_jobs rj JOIN render_snapshots rs ON rs.id=rj.render_snapshot_id
  WHERE rj.id=NEW.final_render_job_id AND rj.workspace_id=NEW.workspace_id
    AND rj.status='COMPLETED' AND rj.render_type='FINAL'
    AND rj.output_asset_id=NEW.final_asset_id AND rs.content_version_id=NEW.content_version_id
)) OR (NEW.status NOT IN ('NOT_READY','CANCELLED') AND NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.final_asset_id AND a.workspace_id=NEW.workspace_id
    AND a.status='AVAILABLE' AND (
      (NEW.publication_type IN ('LONG_FORM','SHORT','REEL') AND a.asset_type='FINAL_VIDEO' AND NEW.final_render_job_id IS NOT NULL)
      OR (NEW.publication_type='IMAGE' AND a.asset_type IN ('IMAGE','THUMBNAIL') AND NEW.final_render_job_id IS NULL)
    )
))
BEGIN SELECT RAISE(ABORT,'publication workspace/readiness/final-render lineage mismatch'); END;

CREATE TRIGGER trg_publication_identity_lock_after_upload
BEFORE UPDATE ON publications
WHEN OLD.status IN ('UPLOADING','PROCESSING','PUBLISHED') AND (
  NEW.workspace_id<>OLD.workspace_id OR NEW.content_version_id<>OLD.content_version_id
  OR NEW.platform_account_id<>OLD.platform_account_id OR NEW.publication_type<>OLD.publication_type
  OR NEW.metadata_json<>OLD.metadata_json OR NEW.metadata_hash<>OLD.metadata_hash
  OR COALESCE(NEW.final_asset_id,'')<>COALESCE(OLD.final_asset_id,'')
  OR COALESCE(NEW.final_render_job_id,'')<>COALESCE(OLD.final_render_job_id,'')
)
BEGIN SELECT RAISE(ABORT,'publication intent is immutable after remote upload begins'); END;
CREATE TRIGGER trg_publication_published_evidence
BEFORE UPDATE OF status ON publications
WHEN NEW.status='PUBLISHED' AND (NEW.remote_media_id IS NULL OR NEW.published_at IS NULL)
BEGIN SELECT RAISE(ABORT,'published publication requires remote identity and timestamp'); END;
CREATE TRIGGER trg_publication_no_delete
BEFORE DELETE ON publications
BEGIN SELECT RAISE(ABORT,'publication history is immutable'); END;

CREATE TRIGGER trg_analytics_workspace_ins
BEFORE INSERT ON analytics_metrics
WHEN NOT EXISTS(SELECT 1 FROM publications p WHERE p.id=NEW.publication_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'analytics workspace mismatch'); END;

CREATE TRIGGER trg_experiment_workspace_ins
BEFORE INSERT ON experiments
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'experiment workspace mismatch'); END;
CREATE TRIGGER trg_project_learning_workspace_ins
BEFORE INSERT ON project_learning
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'project learning workspace mismatch'); END;

-- Media evidence output/source checksum and derivative type integrity.
CREATE TRIGGER trg_media_analysis_checksum_ins
BEFORE INSERT ON media_analysis_runs
WHEN NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id
    AND a.checksum_sha256 IS NOT NULL AND a.checksum_sha256=NEW.source_checksum_sha256
)
BEGIN SELECT RAISE(ABORT,'media analysis source checksum mismatch'); END;
CREATE TRIGGER trg_media_analysis_checksum_upd
BEFORE UPDATE OF workspace_id,source_asset_id,source_checksum_sha256 ON media_analysis_runs
WHEN NOT EXISTS(
  SELECT 1 FROM assets a WHERE a.id=NEW.source_asset_id AND a.workspace_id=NEW.workspace_id
    AND a.checksum_sha256 IS NOT NULL AND a.checksum_sha256=NEW.source_checksum_sha256
)
BEGIN SELECT RAISE(ABORT,'media analysis source checksum mismatch'); END;

CREATE TRIGGER trg_asset_proxy_evidence_ins
BEFORE INSERT ON asset_proxies
WHEN NOT EXISTS(
  SELECT 1 FROM assets s WHERE s.id=NEW.source_asset_id AND s.checksum_sha256 IS NOT NULL
    AND s.checksum_sha256=NEW.source_checksum_sha256
) OR (NEW.proxy_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets s JOIN assets p ON p.id=NEW.proxy_asset_id
  WHERE s.id=NEW.source_asset_id AND p.workspace_id=s.workspace_id
    AND (p.project_id=s.project_id OR (p.project_id IS NULL AND s.project_id IS NULL))
    AND p.asset_type='PREVIEW_VIDEO' AND p.status='AVAILABLE'
)) OR (NEW.status='READY' AND NEW.proxy_asset_id IS NULL)
BEGIN SELECT RAISE(ABORT,'proxy source checksum or output asset evidence mismatch'); END;
CREATE TRIGGER trg_asset_proxy_evidence_upd
BEFORE UPDATE OF source_asset_id,proxy_asset_id,source_checksum_sha256,status ON asset_proxies
WHEN NOT EXISTS(
  SELECT 1 FROM assets s WHERE s.id=NEW.source_asset_id AND s.checksum_sha256 IS NOT NULL
    AND s.checksum_sha256=NEW.source_checksum_sha256
) OR (NEW.proxy_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets s JOIN assets p ON p.id=NEW.proxy_asset_id
  WHERE s.id=NEW.source_asset_id AND p.workspace_id=s.workspace_id
    AND (p.project_id=s.project_id OR (p.project_id IS NULL AND s.project_id IS NULL))
    AND p.asset_type='PREVIEW_VIDEO' AND p.status='AVAILABLE'
)) OR (NEW.status='READY' AND NEW.proxy_asset_id IS NULL)
BEGIN SELECT RAISE(ABORT,'proxy source checksum or output asset evidence mismatch'); END;

CREATE TRIGGER trg_waveform_evidence_ins
BEFORE INSERT ON audio_waveforms
WHEN NOT EXISTS(
  SELECT 1 FROM assets s WHERE s.id=NEW.source_asset_id AND s.checksum_sha256 IS NOT NULL
    AND s.checksum_sha256=NEW.source_checksum_sha256
) OR (NEW.waveform_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets s JOIN assets w ON w.id=NEW.waveform_asset_id
  WHERE s.id=NEW.source_asset_id AND w.workspace_id=s.workspace_id
    AND (w.project_id=s.project_id OR (w.project_id IS NULL AND s.project_id IS NULL))
    AND w.asset_type='METADATA' AND w.status='AVAILABLE'
))
BEGIN SELECT RAISE(ABORT,'waveform source checksum or output asset evidence mismatch'); END;

-- OAuth human actor must belong to the workspace initiating the flow.
CREATE TRIGGER trg_oauth_user_membership_ins
BEFORE INSERT ON oauth_transactions
WHEN NOT EXISTS(
  SELECT 1 FROM workspace_memberships wm WHERE wm.workspace_id=NEW.workspace_id AND wm.user_id=NEW.user_id
)
BEGIN SELECT RAISE(ABORT,'oauth user is not a workspace member'); END;

CREATE TRIGGER trg_waveform_evidence_upd
BEFORE UPDATE OF source_asset_id,waveform_asset_id,source_checksum_sha256,status,peaks_json ON audio_waveforms
WHEN NOT EXISTS(
  SELECT 1 FROM assets src WHERE src.id=NEW.source_asset_id AND src.checksum_sha256 IS NOT NULL
    AND src.checksum_sha256=NEW.source_checksum_sha256
) OR (NEW.waveform_asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets src JOIN assets w ON w.id=NEW.waveform_asset_id
  WHERE src.id=NEW.source_asset_id AND w.workspace_id=src.workspace_id
    AND (w.project_id=src.project_id OR (w.project_id IS NULL AND src.project_id IS NULL))
    AND w.asset_type='METADATA' AND w.status='AVAILABLE'
)) OR (NEW.status='READY' AND NEW.waveform_asset_id IS NULL AND NEW.peaks_json IS NULL)
BEGIN SELECT RAISE(ABORT,'waveform source checksum or output asset evidence mismatch'); END;

CREATE TRIGGER trg_silence_decider_membership_ins
BEFORE INSERT ON silence_regions
WHEN NEW.decided_by IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets a JOIN workspace_memberships wm ON wm.workspace_id=a.workspace_id
  WHERE a.id=NEW.source_asset_id AND wm.user_id=NEW.decided_by AND wm.role IN ('ADMIN','EDITOR','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'silence decision actor is not a workspace member'); END;
CREATE TRIGGER trg_silence_decider_membership_upd
BEFORE UPDATE OF source_asset_id,decision,decided_by ON silence_regions
WHEN NEW.decided_by IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM assets a JOIN workspace_memberships wm ON wm.workspace_id=a.workspace_id
  WHERE a.id=NEW.source_asset_id AND wm.user_id=NEW.decided_by AND wm.role IN ('ADMIN','EDITOR','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'silence decision actor is not a workspace member'); END;

CREATE TRIGGER trg_reframe_approval_requires_keyframe
BEFORE UPDATE OF status ON reframe_plans
WHEN NEW.status='APPROVED' AND NOT EXISTS(
  SELECT 1 FROM reframe_keyframes rk WHERE rk.reframe_plan_id=NEW.id
)
BEGIN SELECT RAISE(ABORT,'reframe approval requires at least one keyframe'); END;

CREATE TRIGGER trg_oauth_consume_membership
BEFORE UPDATE OF consumed_at ON oauth_transactions
WHEN NEW.consumed_at IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM workspace_memberships wm WHERE wm.workspace_id=NEW.workspace_id AND wm.user_id=NEW.user_id
)
BEGIN SELECT RAISE(ABORT,'oauth callback user is no longer a workspace member'); END;

-- Timeline materialization/approval.
CREATE TRIGGER trg_materialization_current_revision_ins
BEFORE INSERT ON timeline_materializations
WHEN NOT EXISTS(
  SELECT 1 FROM timelines t
  JOIN timeline_duration_view dv ON dv.timeline_id=t.id
  JOIN timeline_validations tv ON tv.id=NEW.timeline_validation_id AND tv.timeline_id=t.id
  WHERE t.id=NEW.timeline_id AND t.graph_revision=NEW.graph_revision AND dv.duration_ms=NEW.duration_ms
    AND tv.graph_revision=t.graph_revision AND tv.status='VALID'
)
BEGIN SELECT RAISE(ABORT,'timeline materialization requires current VALID graph validation and duration'); END;

CREATE TRIGGER trg_timeline_approval_current_materialization
BEFORE INSERT ON timeline_approvals
WHEN NOT EXISTS(
  SELECT 1 FROM timelines t
  JOIN timeline_materializations tm ON tm.id=NEW.materialization_id AND tm.timeline_id=t.id
  WHERE t.id=NEW.timeline_id AND tm.graph_revision=t.graph_revision
    AND t.status IN ('DRAFT','REVIEW_REQUIRED')
)
BEGIN SELECT RAISE(ABORT,'timeline approval requires current materialization'); END;

CREATE TRIGGER trg_timeline_approval_apply
AFTER INSERT ON timeline_approvals
BEGIN
  UPDATE timelines SET status='APPROVED', updated_at=NEW.approved_at,
    row_version=row_version+1 WHERE id=NEW.timeline_id;
END;

CREATE TRIGGER trg_timeline_direct_approve_guard
BEFORE UPDATE OF status ON timelines
WHEN NEW.status='APPROVED' AND NOT EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.id)
BEGIN SELECT RAISE(ABORT,'timeline approval row required'); END;

CREATE TRIGGER trg_timeline_approved_status_guard
BEFORE UPDATE OF status ON timelines
WHEN OLD.status='SUPERSEDED' AND NEW.status<>'SUPERSEDED'
  OR OLD.status='APPROVED' AND NEW.status NOT IN ('APPROVED','SUPERSEDED')
BEGIN SELECT RAISE(ABORT,'approved timeline status cannot move backward'); END;

-- Timeline validation evidence is immutable.
CREATE TRIGGER trg_timeline_validation_current_ins
BEFORE INSERT ON timeline_validations
WHEN NOT EXISTS(
  SELECT 1 FROM timelines t WHERE t.id=NEW.timeline_id AND t.graph_revision=NEW.graph_revision
)
BEGIN SELECT RAISE(ABORT,'timeline validation graph revision is stale'); END;
CREATE TRIGGER trg_timeline_validation_no_update BEFORE UPDATE ON timeline_validations
BEGIN SELECT RAISE(ABORT,'timeline validation is immutable'); END;
CREATE TRIGGER trg_timeline_validation_no_delete BEFORE DELETE ON timeline_validations
BEGIN SELECT RAISE(ABORT,'timeline validation is immutable'); END;

-- Human approval/review actors must be Workspace members.
CREATE TRIGGER trg_content_version_actor_membership_ins
BEFORE INSERT ON content_versions
WHEN NEW.created_by IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM contents c JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE c.id=NEW.content_id AND wm.user_id=NEW.created_by
)
BEGIN SELECT RAISE(ABORT,'content version creator is not a workspace member'); END;
CREATE TRIGGER trg_content_version_approver_membership_upd
BEFORE UPDATE OF status,approved_by ON content_versions
WHEN NEW.status='APPROVED' AND NOT EXISTS(
  SELECT 1 FROM contents c JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE c.id=NEW.content_id AND wm.user_id=NEW.approved_by AND wm.role IN ('ADMIN','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'content version approver lacks workspace review membership'); END;
CREATE TRIGGER trg_review_actor_membership_ins
BEFORE INSERT ON review_sessions
WHEN NEW.reviewer_user_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE cv.id=NEW.content_version_id AND wm.user_id=NEW.reviewer_user_id AND wm.role IN ('ADMIN','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'reviewer lacks workspace review membership'); END;
CREATE TRIGGER trg_timeline_approver_membership_ins
BEFORE INSERT ON timeline_approvals
WHEN NOT EXISTS(
  SELECT 1 FROM timelines t JOIN content_versions cv ON cv.id=t.content_version_id
  JOIN contents c ON c.id=cv.content_id
  JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE t.id=NEW.timeline_id AND wm.user_id=NEW.approved_by AND wm.role IN ('ADMIN','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'timeline approver lacks workspace review membership'); END;
CREATE TRIGGER trg_timeline_validator_membership_ins
BEFORE INSERT ON timeline_validations
WHEN NEW.validated_by IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timelines t JOIN content_versions cv ON cv.id=t.content_version_id
  JOIN contents c ON c.id=cv.content_id
  JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE t.id=NEW.timeline_id AND wm.user_id=NEW.validated_by
)
BEGIN SELECT RAISE(ABORT,'timeline validator is not a workspace member'); END;

-- Reframe lifecycle and approved-plan immutability.
CREATE TRIGGER trg_reframe_must_start_draft
BEFORE INSERT ON reframe_plans
WHEN NEW.status<>'DRAFT'
BEGIN SELECT RAISE(ABORT,'reframe plan must start DRAFT'); END;
CREATE TRIGGER trg_reframe_approver_membership_upd
BEFORE UPDATE OF status,approved_by ON reframe_plans
WHEN NEW.status='APPROVED' AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE cv.id=NEW.content_version_id AND wm.user_id=NEW.approved_by AND wm.role IN ('ADMIN','REVIEWER')
)
BEGIN SELECT RAISE(ABORT,'reframe approver lacks workspace review membership'); END;
CREATE TRIGGER trg_reframe_approved_immutable
BEFORE UPDATE ON reframe_plans
WHEN OLD.status IN ('APPROVED','SUPERSEDED') AND (
  NEW.content_version_id<>OLD.content_version_id OR NEW.source_asset_id<>OLD.source_asset_id
  OR NEW.target_aspect_ratio<>OLD.target_aspect_ratio OR NEW.plan_version<>OLD.plan_version
  OR NEW.analysis_evidence_json<>OLD.analysis_evidence_json
  OR COALESCE(NEW.approved_at,'')<>COALESCE(OLD.approved_at,'')
  OR COALESCE(NEW.approved_by,'')<>COALESCE(OLD.approved_by,'')
)
BEGIN SELECT RAISE(ABORT,'approved reframe plan payload is immutable'); END;
CREATE TRIGGER trg_reframe_status_guard
BEFORE UPDATE OF status ON reframe_plans
WHEN OLD.status='SUPERSEDED' AND NEW.status<>'SUPERSEDED'
  OR OLD.status='APPROVED' AND NEW.status NOT IN ('APPROVED','SUPERSEDED')
BEGIN SELECT RAISE(ABORT,'approved reframe status cannot move backward'); END;
CREATE TRIGGER trg_reframe_no_delete BEFORE DELETE ON reframe_plans
BEGIN SELECT RAISE(ABORT,'reframe plan history is immutable'); END;
CREATE TRIGGER trg_reframe_keyframe_approved_no_insert BEFORE INSERT ON reframe_keyframes
WHEN EXISTS(SELECT 1 FROM reframe_plans rp WHERE rp.id=NEW.reframe_plan_id AND rp.status IN ('APPROVED','SUPERSEDED'))
BEGIN SELECT RAISE(ABORT,'approved reframe keyframes are immutable'); END;
CREATE TRIGGER trg_reframe_keyframe_approved_no_update BEFORE UPDATE ON reframe_keyframes
WHEN EXISTS(SELECT 1 FROM reframe_plans rp WHERE rp.id=OLD.reframe_plan_id AND rp.status IN ('APPROVED','SUPERSEDED'))
BEGIN SELECT RAISE(ABORT,'approved reframe keyframes are immutable'); END;
CREATE TRIGGER trg_reframe_keyframe_approved_no_delete BEFORE DELETE ON reframe_keyframes
WHEN EXISTS(SELECT 1 FROM reframe_plans rp WHERE rp.id=OLD.reframe_plan_id AND rp.status IN ('APPROVED','SUPERSEDED'))
BEGIN SELECT RAISE(ABORT,'approved reframe keyframes are immutable'); END;

-- Available Asset physical identity is write-once; replacement creates a new Asset.
CREATE TRIGGER trg_asset_available_identity_immutable
BEFORE UPDATE OF workspace_id,storage_provider,storage_key,original_filename,mime_type,size_bytes,checksum_sha256 ON assets
WHEN OLD.checksum_sha256 IS NOT NULL AND (
  NEW.workspace_id<>OLD.workspace_id OR NEW.storage_provider<>OLD.storage_provider
  OR NEW.storage_key<>OLD.storage_key OR NEW.original_filename<>OLD.original_filename
  OR NEW.mime_type<>OLD.mime_type OR COALESCE(NEW.size_bytes,-1)<>COALESCE(OLD.size_bytes,-1)
  OR COALESCE(NEW.checksum_sha256,'')<>COALESCE(OLD.checksum_sha256,'')
)
BEGIN SELECT RAISE(ABORT,'available asset physical identity is immutable'); END;
CREATE TRIGGER trg_asset_referenced_project_immutable
BEFORE UPDATE OF project_id ON assets
WHEN COALESCE(NEW.project_id,'')<>COALESCE(OLD.project_id,'') AND (
  EXISTS(SELECT 1 FROM render_jobs rj WHERE rj.output_asset_id=OLD.id AND rj.status='COMPLETED')
  OR EXISTS(SELECT 1 FROM publications p WHERE p.final_asset_id=OLD.id AND p.status IN ('UPLOADING','PROCESSING','PUBLISHED'))
  OR EXISTS(SELECT 1 FROM publication_assets pa JOIN publications p ON p.id=pa.publication_id
            WHERE pa.asset_id=OLD.id AND p.status IN ('UPLOADING','PROCESSING','PUBLISHED'))
)
BEGIN SELECT RAISE(ABORT,'referenced publication/render asset project is immutable'); END;

-- Publication thumbnail/cover linkage is typed, checksummed and locked after upload.
CREATE TRIGGER trg_publication_asset_scope_ins
BEFORE INSERT ON publication_assets
WHEN NOT EXISTS(
  SELECT 1 FROM publications p JOIN assets a ON a.id=NEW.asset_id
  WHERE p.id=NEW.publication_id AND a.workspace_id=p.workspace_id AND a.status='AVAILABLE'
    AND a.checksum_sha256=NEW.asset_checksum_sha256
    AND ((NEW.asset_role='THUMBNAIL' AND a.asset_type IN ('THUMBNAIL','IMAGE'))
      OR (NEW.asset_role='COVER' AND a.asset_type IN ('THUMBNAIL','IMAGE')))
)
BEGIN SELECT RAISE(ABORT,'publication attachment workspace/type/checksum mismatch'); END;
CREATE TRIGGER trg_publication_asset_scope_upd
BEFORE UPDATE ON publication_assets
WHEN NOT EXISTS(
  SELECT 1 FROM publications p JOIN assets a ON a.id=NEW.asset_id
  WHERE p.id=NEW.publication_id AND a.workspace_id=p.workspace_id AND a.status='AVAILABLE'
    AND a.checksum_sha256=NEW.asset_checksum_sha256
    AND a.asset_type IN ('THUMBNAIL','IMAGE')
)
BEGIN SELECT RAISE(ABORT,'publication attachment workspace/type/checksum mismatch'); END;
CREATE TRIGGER trg_publication_asset_lock_ins
BEFORE INSERT ON publication_assets
WHEN EXISTS(SELECT 1 FROM publications p WHERE p.id=NEW.publication_id AND p.status IN ('UPLOADING','PROCESSING','PUBLISHED'))
BEGIN SELECT RAISE(ABORT,'publication attachment cannot be added after upload begins'); END;
CREATE TRIGGER trg_publication_asset_lock_upd
BEFORE UPDATE ON publication_assets
WHEN EXISTS(SELECT 1 FROM publications p WHERE p.id=OLD.publication_id AND p.status IN ('UPLOADING','PROCESSING','PUBLISHED'))
BEGIN SELECT RAISE(ABORT,'publication attachment is immutable after upload begins'); END;
CREATE TRIGGER trg_publication_asset_lock_del
BEFORE DELETE ON publication_assets
WHEN EXISTS(SELECT 1 FROM publications p WHERE p.id=OLD.publication_id AND p.status IN ('UPLOADING','PROCESSING','PUBLISHED'))
BEGIN SELECT RAISE(ABORT,'publication attachment is immutable after upload begins'); END;

-- Review terminal decisions require a concrete authorized human reviewer.
CREATE TRIGGER trg_review_actor_membership_upd
BEFORE UPDATE OF status,reviewer_user_id ON review_sessions
WHEN NEW.status<>'OPEN' AND (
  NEW.reviewer_user_id IS NULL OR NOT EXISTS(
    SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
    JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
    WHERE cv.id=NEW.content_version_id AND wm.user_id=NEW.reviewer_user_id AND wm.role IN ('ADMIN','REVIEWER')
  )
)
BEGIN SELECT RAISE(ABORT,'terminal review requires authorized workspace reviewer'); END;

CREATE TRIGGER trg_timeline_materializer_membership_ins
BEFORE INSERT ON timeline_materializations
WHEN NEW.generated_by IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timelines t JOIN content_versions cv ON cv.id=t.content_version_id
  JOIN contents c ON c.id=cv.content_id
  JOIN workspace_memberships wm ON wm.workspace_id=c.workspace_id
  WHERE t.id=NEW.timeline_id AND wm.user_id=NEW.generated_by
)
BEGIN SELECT RAISE(ABORT,'timeline materializer is not a workspace member'); END;

CREATE TRIGGER trg_reframe_keyframe_parent_immutable
BEFORE UPDATE OF reframe_plan_id ON reframe_keyframes
WHEN NEW.reframe_plan_id<>OLD.reframe_plan_id
BEGIN SELECT RAISE(ABORT,'reframe keyframe parent is immutable'); END;

CREATE TRIGGER trg_publication_asset_identity_immutable
BEFORE UPDATE OF publication_id,asset_role ON publication_assets
WHEN NEW.publication_id<>OLD.publication_id OR NEW.asset_role<>OLD.asset_role
BEGIN SELECT RAISE(ABORT,'publication attachment parent/role identity is immutable'); END;

-- Immutable evidence tables.
CREATE TRIGGER trg_generation_evidence_no_update BEFORE UPDATE ON generation_evidence
BEGIN SELECT RAISE(ABORT,'generation evidence is immutable'); END;
CREATE TRIGGER trg_generation_evidence_no_delete BEFORE DELETE ON generation_evidence
BEGIN SELECT RAISE(ABORT,'generation evidence is immutable'); END;
CREATE TRIGGER trg_timeline_materialization_no_update BEFORE UPDATE ON timeline_materializations
BEGIN SELECT RAISE(ABORT,'timeline materialization is immutable'); END;
CREATE TRIGGER trg_timeline_materialization_no_delete BEFORE DELETE ON timeline_materializations
BEGIN SELECT RAISE(ABORT,'timeline materialization is immutable'); END;
CREATE TRIGGER trg_timeline_approval_no_update BEFORE UPDATE ON timeline_approvals
BEGIN SELECT RAISE(ABORT,'timeline approval is immutable'); END;
CREATE TRIGGER trg_timeline_approval_no_delete BEFORE DELETE ON timeline_approvals
BEGIN SELECT RAISE(ABORT,'timeline approval is immutable'); END;
CREATE TRIGGER trg_render_snapshot_no_update BEFORE UPDATE ON render_snapshots
BEGIN SELECT RAISE(ABORT,'render snapshot is immutable'); END;
CREATE TRIGGER trg_render_snapshot_no_delete BEFORE DELETE ON render_snapshots
BEGIN SELECT RAISE(ABORT,'render snapshot is immutable'); END;
CREATE TRIGGER trg_audit_event_no_update BEFORE UPDATE ON audit_events
BEGIN SELECT RAISE(ABORT,'audit event is append-only'); END;
CREATE TRIGGER trg_audit_event_no_delete BEFORE DELETE ON audit_events
BEGIN SELECT RAISE(ABORT,'audit event is append-only'); END;
CREATE TRIGGER trg_review_materialization_content_ins
BEFORE INSERT ON review_sessions
WHEN NEW.timeline_materialization_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timeline_materializations tm
  JOIN timelines t ON t.id=tm.timeline_id
  WHERE tm.id=NEW.timeline_materialization_id AND t.content_version_id=NEW.content_version_id
)
BEGIN SELECT RAISE(ABORT,'review materialization/content mismatch'); END;
CREATE TRIGGER trg_review_materialization_content_upd
BEFORE UPDATE OF timeline_materialization_id,content_version_id ON review_sessions
WHEN NEW.timeline_materialization_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM timeline_materializations tm
  JOIN timelines t ON t.id=tm.timeline_id
  WHERE tm.id=NEW.timeline_materialization_id AND t.content_version_id=NEW.content_version_id
)
BEGIN SELECT RAISE(ABORT,'review materialization/content mismatch'); END;

CREATE TRIGGER trg_review_target_integrity_ins
BEFORE INSERT ON review_sessions
WHEN NOT EXISTS(
  SELECT 1 FROM content_versions cv
    WHERE cv.id=NEW.content_version_id
      AND cv.snapshot_hash=NEW.content_hash
      AND cv.row_version=json_extract(NEW.review_target_json,'$.data.content_row_version')
  )
  OR (
    NEW.timeline_materialization_id IS NOT NULL
    AND NOT EXISTS(
      SELECT 1 FROM timeline_materializations tm
      JOIN timelines t ON t.id=tm.timeline_id
      WHERE tm.id=NEW.timeline_materialization_id
        AND tm.canonical_hash=NEW.timeline_materialization_hash
        AND tm.graph_revision=t.graph_revision
        AND t.content_version_id=NEW.content_version_id
        AND t.id=json_extract(NEW.review_target_json,'$.data.timeline.timeline_id')
        AND t.row_version=json_extract(NEW.review_target_json,'$.data.timeline.timeline_row_version')
        AND t.graph_revision=json_extract(NEW.review_target_json,'$.data.timeline.graph_revision')
    )
  )
  OR (
    json_type(NEW.review_target_json,'$.data.preview') IS NOT NULL
    AND NOT EXISTS(
      SELECT 1
      FROM render_jobs rj
      JOIN render_snapshots rs ON rs.id=rj.render_snapshot_id
      JOIN assets a ON a.id=rj.output_asset_id AND a.workspace_id=rj.workspace_id
      JOIN content_versions cv ON cv.id=rs.content_version_id
      JOIN contents c ON c.id=cv.content_id AND c.workspace_id=rj.workspace_id
      WHERE rj.id=json_extract(NEW.review_target_json,'$.data.preview.render_job_id')
        AND rj.row_version=json_extract(NEW.review_target_json,'$.data.preview.render_job_row_version')
        AND rs.id=json_extract(NEW.review_target_json,'$.data.preview.render_snapshot_id')
        AND rs.snapshot_hash=json_extract(NEW.review_target_json,'$.data.preview.render_snapshot_hash')
        AND a.id=json_extract(NEW.review_target_json,'$.data.preview.output_asset_id')
        AND a.checksum_sha256=json_extract(NEW.review_target_json,'$.data.preview.output_checksum_sha256')
        AND rj.output_checksum_sha256=a.checksum_sha256
        AND rj.status='COMPLETED' AND rj.render_type IN ('PREVIEW','DRAFT')
        AND rs.snapshot_type=rj.render_type
        AND rs.content_version_id=NEW.content_version_id
        AND rs.timeline_id=json_extract(NEW.review_target_json,'$.data.timeline.timeline_id')
        AND rs.timeline_materialization_id=NEW.timeline_materialization_id
        AND a.status='AVAILABLE' AND a.asset_type='PREVIEW_VIDEO'
    )
  )
BEGIN SELECT RAISE(ABORT,'review target must match exact content, materialization and preview evidence'); END;

CREATE TRIGGER trg_review_target_integrity_approval
BEFORE UPDATE OF status ON review_sessions
WHEN NEW.status='APPROVED' AND (
  NOT EXISTS(
    SELECT 1 FROM content_versions cv
    WHERE cv.id=NEW.content_version_id
      AND cv.snapshot_hash=NEW.content_hash
      AND cv.row_version=json_extract(NEW.review_target_json,'$.data.content_row_version')
  )
  OR (
    NEW.timeline_materialization_id IS NOT NULL
    AND NOT EXISTS(
      SELECT 1 FROM timeline_materializations tm
      JOIN timelines t ON t.id=tm.timeline_id
      WHERE tm.id=NEW.timeline_materialization_id
        AND tm.canonical_hash=NEW.timeline_materialization_hash
        AND tm.graph_revision=t.graph_revision
        AND t.content_version_id=NEW.content_version_id
        AND t.id=json_extract(NEW.review_target_json,'$.data.timeline.timeline_id')
        AND t.row_version=json_extract(NEW.review_target_json,'$.data.timeline.timeline_row_version')
        AND t.graph_revision=json_extract(NEW.review_target_json,'$.data.timeline.graph_revision')
    )
  )
  OR (
    json_type(NEW.review_target_json,'$.data.preview') IS NOT NULL
    AND NOT EXISTS(
      SELECT 1
      FROM render_jobs rj
      JOIN render_snapshots rs ON rs.id=rj.render_snapshot_id
      JOIN assets a ON a.id=rj.output_asset_id AND a.workspace_id=rj.workspace_id
      JOIN content_versions cv ON cv.id=rs.content_version_id
      JOIN contents c ON c.id=cv.content_id AND c.workspace_id=rj.workspace_id
      WHERE rj.id=json_extract(NEW.review_target_json,'$.data.preview.render_job_id')
        AND rj.row_version=json_extract(NEW.review_target_json,'$.data.preview.render_job_row_version')
        AND rs.id=json_extract(NEW.review_target_json,'$.data.preview.render_snapshot_id')
        AND rs.snapshot_hash=json_extract(NEW.review_target_json,'$.data.preview.render_snapshot_hash')
        AND a.id=json_extract(NEW.review_target_json,'$.data.preview.output_asset_id')
        AND a.checksum_sha256=json_extract(NEW.review_target_json,'$.data.preview.output_checksum_sha256')
        AND rj.output_checksum_sha256=a.checksum_sha256
        AND rj.status='COMPLETED' AND rj.render_type IN ('PREVIEW','DRAFT')
        AND rs.snapshot_type=rj.render_type
        AND rs.content_version_id=NEW.content_version_id
        AND rs.timeline_id=json_extract(NEW.review_target_json,'$.data.timeline.timeline_id')
        AND rs.timeline_materialization_id=NEW.timeline_materialization_id
        AND a.status='AVAILABLE' AND a.asset_type='PREVIEW_VIDEO'
    )
  )
)
BEGIN SELECT RAISE(ABORT,'review approval target evidence no longer matches'); END;
CREATE TRIGGER trg_video_review_approval_requires_current_materialization
BEFORE UPDATE OF status ON review_sessions
WHEN NEW.status='APPROVED' AND EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  WHERE cv.id=NEW.content_version_id AND c.content_type IN ('LONG_FORM','SHORT','REEL')
) AND NOT EXISTS(
  SELECT 1 FROM timeline_materializations tm JOIN timelines t ON t.id=tm.timeline_id
  WHERE tm.id=NEW.timeline_materialization_id AND t.content_version_id=NEW.content_version_id
    AND tm.graph_revision=t.graph_revision
)
BEGIN SELECT RAISE(ABORT,'video review approval requires current timeline materialization'); END;

CREATE TRIGGER trg_video_review_approval_requires_timeline
BEFORE UPDATE OF status ON review_sessions
WHEN NEW.status='APPROVED' AND EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  WHERE cv.id=NEW.content_version_id AND c.content_type IN ('LONG_FORM','SHORT','REEL')
) AND NEW.timeline_materialization_id IS NULL
BEGIN SELECT RAISE(ABORT,'video review approval requires timeline materialization'); END;

CREATE TRIGGER trg_review_terminal_no_update BEFORE UPDATE ON review_sessions
WHEN OLD.status<>'OPEN'
BEGIN SELECT RAISE(ABORT,'terminal review session is immutable'); END;
CREATE TRIGGER trg_review_no_delete BEFORE DELETE ON review_sessions
BEGIN SELECT RAISE(ABORT,'review session history is immutable'); END;


-- Review and ContentVersion approval lineage.
CREATE TRIGGER trg_review_session_must_start_open
BEFORE INSERT ON review_sessions
WHEN NEW.status<>'OPEN' OR NEW.decided_at IS NOT NULL
BEGIN SELECT RAISE(ABORT,'review session must start OPEN'); END;

CREATE TRIGGER trg_review_approval_content_hash
BEFORE UPDATE OF status ON review_sessions
WHEN NEW.status='APPROVED' AND NOT EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=NEW.content_version_id AND cv.snapshot_hash=NEW.content_hash
)
BEGIN SELECT RAISE(ABORT,'review approval content hash mismatch'); END;

CREATE TRIGGER trg_content_version_must_start_draft
BEFORE INSERT ON content_versions
WHEN NEW.status<>'DRAFT'
BEGIN SELECT RAISE(ABORT,'content version must start DRAFT'); END;

CREATE TRIGGER trg_content_version_approval_requires_review
BEFORE UPDATE OF status ON content_versions
WHEN NEW.status='APPROVED' AND (
  OLD.status<>'REVIEW_REQUIRED' OR NOT EXISTS(
    SELECT 1 FROM review_sessions rs
    WHERE rs.content_version_id=NEW.id AND rs.status='APPROVED' AND rs.content_hash=NEW.snapshot_hash
  ) OR (
    EXISTS(SELECT 1 FROM contents c WHERE c.id=NEW.content_id AND c.content_type IN ('LONG_FORM','SHORT','REEL'))
    AND NOT EXISTS(
      SELECT 1 FROM review_sessions rs
      JOIN timeline_materializations tm ON tm.id=rs.timeline_materialization_id
      JOIN timelines t ON t.id=tm.timeline_id AND t.content_version_id=NEW.id
      JOIN timeline_approvals ta ON ta.timeline_id=t.id AND ta.materialization_id=tm.id
      WHERE rs.content_version_id=NEW.id AND rs.status='APPROVED' AND rs.content_hash=NEW.snapshot_hash
        AND t.status='APPROVED' AND tm.graph_revision=t.graph_revision
    )
  )
)
BEGIN SELECT RAISE(ABORT,'content version approval requires approved matching review and timeline'); END;

-- Timeline identity/history.
CREATE TRIGGER trg_timeline_revision_immutable
BEFORE UPDATE OF revision_no ON timelines
WHEN NEW.revision_no<>OLD.revision_no
BEGIN SELECT RAISE(ABORT,'timeline revision number is immutable'); END;
CREATE TRIGGER trg_timeline_no_delete
BEFORE DELETE ON timelines
BEGIN SELECT RAISE(ABORT,'timeline history is immutable'); END;

-- Schedule definition/occurrence integrity.
CREATE TRIGGER trg_schedule_occurrence_current_version_ins
BEFORE INSERT ON schedule_occurrences
WHEN NOT EXISTS(
  SELECT 1 FROM schedules s WHERE s.id=NEW.schedule_id AND s.workspace_id=NEW.workspace_id
    AND s.schedule_version=NEW.schedule_version AND s.status='ACTIVE'
)
BEGIN SELECT RAISE(ABORT,'occurrence requires current active schedule version'); END;
CREATE TRIGGER trg_schedule_occurrence_identity_immutable
BEFORE UPDATE OF workspace_id,schedule_id,schedule_version,occurrence_key,scheduled_at_utc,intended_local_datetime,utc_offset_minutes,fold ON schedule_occurrences
WHEN NEW.workspace_id<>OLD.workspace_id OR NEW.schedule_id<>OLD.schedule_id OR NEW.schedule_version<>OLD.schedule_version
  OR NEW.occurrence_key<>OLD.occurrence_key OR NEW.scheduled_at_utc<>OLD.scheduled_at_utc
  OR NEW.intended_local_datetime<>OLD.intended_local_datetime OR NEW.utc_offset_minutes<>OLD.utc_offset_minutes OR NEW.fold<>OLD.fold
BEGIN SELECT RAISE(ABORT,'schedule occurrence identity is immutable'); END;
CREATE TRIGGER trg_schedule_occurrence_no_delete
BEFORE DELETE ON schedule_occurrences
BEGIN SELECT RAISE(ABORT,'schedule occurrence history is immutable'); END;
CREATE TRIGGER trg_schedule_workspace_immutable
BEFORE UPDATE OF workspace_id ON schedules
WHEN NEW.workspace_id<>OLD.workspace_id
BEGIN SELECT RAISE(ABORT,'schedule workspace is immutable'); END;

-- Audit stream continuity. Append service computes hash; DB enforces order and predecessor link.
CREATE TRIGGER trg_audit_event_chain_ins
BEFORE INSERT ON audit_events
WHEN NEW.sequence_no <> COALESCE((SELECT MAX(a.sequence_no)+1 FROM audit_events a WHERE a.stream_key=NEW.stream_key),1)
  OR (NEW.sequence_no=1 AND NEW.previous_event_hash IS NOT NULL)
  OR (NEW.sequence_no>1 AND NOT EXISTS(
    SELECT 1 FROM audit_events a WHERE a.stream_key=NEW.stream_key
      AND a.sequence_no=NEW.sequence_no-1 AND a.event_hash=NEW.previous_event_hash
  ))
  OR (NEW.workspace_id IS NOT NULL AND NEW.stream_key<>'workspace:'||NEW.workspace_id)
  OR (NEW.workspace_id IS NULL AND NEW.stream_key<>'global')
BEGIN SELECT RAISE(ABORT,'audit stream sequence/hash/workspace continuity invalid'); END;

-- OAuth transaction is one-time and immutable except first consume timestamp.
CREATE TRIGGER trg_oauth_transaction_update_guard
BEFORE UPDATE ON oauth_transactions
WHEN NEW.id<>OLD.id OR NEW.workspace_id<>OLD.workspace_id OR NEW.user_id<>OLD.user_id
  OR NEW.provider<>OLD.provider OR NEW.state_hash<>OLD.state_hash
  OR COALESCE(NEW.pkce_verifier_secret_ref,'')<>COALESCE(OLD.pkce_verifier_secret_ref,'')
  OR NEW.redirect_uri<>OLD.redirect_uri OR COALESCE(NEW.return_path,'')<>COALESCE(OLD.return_path,'')
  OR NEW.created_at<>OLD.created_at OR NEW.expires_at<>OLD.expires_at
  OR OLD.consumed_at IS NOT NULL OR NEW.consumed_at IS NULL
BEGIN SELECT RAISE(ABORT,'oauth transaction is immutable/one-time'); END;
CREATE TRIGGER trg_oauth_transaction_no_delete
BEFORE DELETE ON oauth_transactions
BEGIN SELECT RAISE(ABORT,'oauth transaction history is immutable'); END;

-- Cross-workspace optional/reference relations.
CREATE TRIGGER trg_hook_benchmark_workspace_ins
BEFORE INSERT ON hooks
WHEN NEW.benchmark_pattern_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN benchmark_patterns bp ON bp.id=NEW.benchmark_pattern_id
  JOIN benchmark_analyses ba ON ba.id=bp.benchmark_analysis_id
  JOIN benchmarks b ON b.id=ba.benchmark_id
  WHERE cv.id=NEW.content_version_id AND c.workspace_id=b.workspace_id
)
BEGIN SELECT RAISE(ABORT,'hook benchmark workspace mismatch'); END;
CREATE TRIGGER trg_hook_benchmark_workspace_upd
BEFORE UPDATE OF content_version_id,benchmark_pattern_id ON hooks
WHEN NEW.benchmark_pattern_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id
  JOIN benchmark_patterns bp ON bp.id=NEW.benchmark_pattern_id
  JOIN benchmark_analyses ba ON ba.id=bp.benchmark_analysis_id
  JOIN benchmarks b ON b.id=ba.benchmark_id
  WHERE cv.id=NEW.content_version_id AND c.workspace_id=b.workspace_id
)
BEGIN SELECT RAISE(ABORT,'hook benchmark workspace mismatch'); END;

CREATE TRIGGER trg_thumbnail_asset_workspace_ins
BEFORE INSERT ON thumbnails
WHEN NEW.asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.asset_id
  WHERE cv.id=NEW.content_version_id AND a.workspace_id=c.workspace_id AND a.asset_type IN ('THUMBNAIL','IMAGE')
)
BEGIN SELECT RAISE(ABORT,'thumbnail asset workspace/type mismatch'); END;
CREATE TRIGGER trg_thumbnail_asset_workspace_upd
BEFORE UPDATE OF content_version_id,asset_id ON thumbnails
WHEN NEW.asset_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.asset_id
  WHERE cv.id=NEW.content_version_id AND a.workspace_id=c.workspace_id AND a.asset_type IN ('THUMBNAIL','IMAGE')
)
BEGIN SELECT RAISE(ABORT,'thumbnail asset workspace/type mismatch'); END;

CREATE TRIGGER trg_experiment_variant_scope_ins
BEFORE INSERT ON experiment_variants
WHEN (NEW.content_version_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN content_versions cv ON cv.id=NEW.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
)) OR (NEW.hook_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN hooks h ON h.id=NEW.hook_id JOIN content_versions cv ON cv.id=h.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
)) OR (NEW.thumbnail_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN thumbnails th ON th.id=NEW.thumbnail_id JOIN content_versions cv ON cv.id=th.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
))
BEGIN SELECT RAISE(ABORT,'experiment variant project/workspace mismatch'); END;
CREATE TRIGGER trg_experiment_variant_scope_upd
BEFORE UPDATE ON experiment_variants
WHEN (NEW.content_version_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN content_versions cv ON cv.id=NEW.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
)) OR (NEW.hook_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN hooks h ON h.id=NEW.hook_id JOIN content_versions cv ON cv.id=h.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
)) OR (NEW.thumbnail_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM experiments e JOIN thumbnails th ON th.id=NEW.thumbnail_id JOIN content_versions cv ON cv.id=th.content_version_id JOIN contents c ON c.id=cv.content_id
  WHERE e.id=NEW.experiment_id AND c.project_id=e.project_id AND c.workspace_id=e.workspace_id
))
BEGIN SELECT RAISE(ABORT,'experiment variant project/workspace mismatch'); END;

-- Lifecycle identities not expressible as static table checks.
CREATE TRIGGER trg_timeline_must_start_draft
BEFORE INSERT ON timelines
WHEN NEW.status<>'DRAFT'
BEGIN SELECT RAISE(ABORT,'timeline must start DRAFT'); END;

CREATE TRIGGER trg_schedule_version_semantics
BEFORE UPDATE ON schedules
WHEN (
  NEW.schedule_type<>OLD.schedule_type OR NEW.job_type<>OLD.job_type
  OR NEW.target_type<>OLD.target_type OR NEW.target_id<>OLD.target_id
  OR NEW.timezone<>OLD.timezone OR NEW.dst_policy<>OLD.dst_policy
  OR NEW.past_due_policy<>OLD.past_due_policy
  OR COALESCE(NEW.one_time_local_datetime,'')<>COALESCE(OLD.one_time_local_datetime,'')
  OR COALESCE(NEW.recurrence_json,'')<>COALESCE(OLD.recurrence_json,'')
) AND NEW.schedule_version<=OLD.schedule_version
BEGIN SELECT RAISE(ABORT,'schedule semantic change requires version increment'); END;
CREATE TRIGGER trg_schedule_version_no_decrease
BEFORE UPDATE OF schedule_version ON schedules
WHEN NEW.schedule_version<OLD.schedule_version
BEGIN SELECT RAISE(ABORT,'schedule version cannot decrease'); END;
CREATE TRIGGER trg_schedule_no_delete
BEFORE DELETE ON schedules
BEGIN SELECT RAISE(ABORT,'schedule history is immutable'); END;

CREATE TRIGGER trg_worker_job_identity_immutable
BEFORE UPDATE OF workspace_id,schedule_occurrence_id,job_type,payload_json,execution_fingerprint,idempotency_key ON worker_jobs
WHEN NEW.workspace_id<>OLD.workspace_id
  OR COALESCE(NEW.schedule_occurrence_id,'')<>COALESCE(OLD.schedule_occurrence_id,'')
  OR NEW.job_type<>OLD.job_type OR NEW.payload_json<>OLD.payload_json
  OR NEW.execution_fingerprint<>OLD.execution_fingerprint
  OR COALESCE(NEW.idempotency_key,'')<>COALESCE(OLD.idempotency_key,'')
BEGIN SELECT RAISE(ABORT,'worker job execution identity is immutable'); END;
CREATE TRIGGER trg_worker_job_no_delete
BEFORE DELETE ON worker_jobs
BEGIN SELECT RAISE(ABORT,'worker job history is immutable'); END;

CREATE TRIGGER trg_oauth_transaction_expiry_guard
BEFORE UPDATE OF consumed_at ON oauth_transactions
WHEN NEW.consumed_at IS NOT NULL AND NEW.consumed_at>NEW.expires_at
BEGIN SELECT RAISE(ABORT,'expired oauth transaction cannot be consumed'); END;

-- Child aggregate identity is stable even while draft payload is editable.
CREATE TRIGGER trg_hook_parent_immutable BEFORE UPDATE OF content_version_id,variant_key ON hooks
WHEN NEW.content_version_id<>OLD.content_version_id OR NEW.variant_key<>OLD.variant_key
BEGIN SELECT RAISE(ABORT,'hook parent/variant identity is immutable'); END;
CREATE TRIGGER trg_thumbnail_parent_immutable BEFORE UPDATE OF content_version_id,variant_key ON thumbnails
WHEN NEW.content_version_id<>OLD.content_version_id OR NEW.variant_key<>OLD.variant_key
BEGIN SELECT RAISE(ABORT,'thumbnail parent/variant identity is immutable'); END;
CREATE TRIGGER trg_experiment_variant_parent_immutable BEFORE UPDATE OF experiment_id,variant_key ON experiment_variants
WHEN NEW.experiment_id<>OLD.experiment_id OR NEW.variant_key<>OLD.variant_key
BEGIN SELECT RAISE(ABORT,'experiment variant identity is immutable'); END;
CREATE TRIGGER trg_review_parent_immutable
BEFORE UPDATE OF content_version_id,timeline_materialization_id,review_target_json,review_target_hash,content_hash,timeline_materialization_hash,design_hash,caption_hash
ON review_sessions
WHEN NEW.content_version_id<>OLD.content_version_id
  OR COALESCE(NEW.timeline_materialization_id,'')<>COALESCE(OLD.timeline_materialization_id,'')
  OR NEW.review_target_json<>OLD.review_target_json
  OR NEW.review_target_hash<>OLD.review_target_hash
  OR NEW.content_hash<>OLD.content_hash
  OR COALESCE(NEW.timeline_materialization_hash,'')<>COALESCE(OLD.timeline_materialization_hash,'')
  OR COALESCE(NEW.design_hash,'')<>COALESCE(OLD.design_hash,'')
  OR COALESCE(NEW.caption_hash,'')<>COALESCE(OLD.caption_hash,'')
BEGIN SELECT RAISE(ABORT,'review subject identity is immutable'); END;
CREATE TRIGGER trg_render_job_identity_immutable BEFORE UPDATE OF workspace_id,render_snapshot_id,render_type,idempotency_key ON render_jobs
WHEN NEW.workspace_id<>OLD.workspace_id OR NEW.render_snapshot_id<>OLD.render_snapshot_id
  OR NEW.render_type<>OLD.render_type OR NEW.idempotency_key<>OLD.idempotency_key
BEGIN SELECT RAISE(ABORT,'render job identity is immutable'); END;
CREATE TRIGGER trg_publication_job_identity_immutable BEFORE UPDATE OF workspace_id,publication_id,profile_binding_id,idempotency_key,request_hash,execution_fingerprint ON publication_jobs
WHEN NEW.workspace_id<>OLD.workspace_id OR NEW.publication_id<>OLD.publication_id
  OR NEW.profile_binding_id<>OLD.profile_binding_id
  OR NEW.idempotency_key<>OLD.idempotency_key OR NEW.request_hash<>OLD.request_hash
  OR NEW.execution_fingerprint<>OLD.execution_fingerprint
BEGIN SELECT RAISE(ABORT,'publication job identity is immutable'); END;
CREATE TRIGGER trg_publication_job_no_delete BEFORE DELETE ON publication_jobs
BEGIN SELECT RAISE(ABORT,'publication job history is immutable'); END;

-- Approved timeline child mutation block + graph revision bump.

CREATE TRIGGER trg_timeline_tracks_approved_no_insert BEFORE INSERT ON timeline_tracks
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_tracks_approved_no_update BEFORE UPDATE ON timeline_tracks
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_tracks_approved_no_delete BEFORE DELETE ON timeline_tracks
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_tracks_graph_bump_insert AFTER INSERT ON timeline_tracks
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_tracks_graph_bump_update AFTER UPDATE ON timeline_tracks
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_tracks_graph_bump_delete AFTER DELETE ON timeline_tracks
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_timeline_clips_approved_no_insert BEFORE INSERT ON timeline_clips
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_clips_approved_no_update BEFORE UPDATE ON timeline_clips
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_clips_approved_no_delete BEFORE DELETE ON timeline_clips
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_clips_graph_bump_insert AFTER INSERT ON timeline_clips
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_clips_graph_bump_update AFTER UPDATE ON timeline_clips
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_clips_graph_bump_delete AFTER DELETE ON timeline_clips
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_timeline_transitions_approved_no_insert BEFORE INSERT ON timeline_transitions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_transitions_approved_no_update BEFORE UPDATE ON timeline_transitions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_transitions_approved_no_delete BEFORE DELETE ON timeline_transitions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_transitions_graph_bump_insert AFTER INSERT ON timeline_transitions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_transitions_graph_bump_update AFTER UPDATE ON timeline_transitions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_transitions_graph_bump_delete AFTER DELETE ON timeline_transitions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_clip_fades_approved_no_insert BEFORE INSERT ON clip_fades
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_fades_approved_no_update BEFORE UPDATE ON clip_fades
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_fades_approved_no_delete BEFORE DELETE ON clip_fades
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_fades_graph_bump_insert AFTER INSERT ON clip_fades
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_clip_fades_graph_bump_update AFTER UPDATE ON clip_fades
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_clip_fades_graph_bump_delete AFTER DELETE ON clip_fades
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_timeline_overlays_approved_no_insert BEFORE INSERT ON timeline_overlays
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_overlays_approved_no_update BEFORE UPDATE ON timeline_overlays
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_overlays_approved_no_delete BEFORE DELETE ON timeline_overlays
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_overlays_graph_bump_insert AFTER INSERT ON timeline_overlays
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_overlays_graph_bump_update AFTER UPDATE ON timeline_overlays
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_overlays_graph_bump_delete AFTER DELETE ON timeline_overlays
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_timeline_keyframes_approved_no_insert BEFORE INSERT ON timeline_keyframes
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_keyframes_approved_no_update BEFORE UPDATE ON timeline_keyframes
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_keyframes_approved_no_delete BEFORE DELETE ON timeline_keyframes
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_timeline_keyframes_graph_bump_insert AFTER INSERT ON timeline_keyframes
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_keyframes_graph_bump_update AFTER UPDATE ON timeline_keyframes
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_timeline_keyframes_graph_bump_delete AFTER DELETE ON timeline_keyframes
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_captions_approved_no_insert BEFORE INSERT ON captions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_captions_approved_no_update BEFORE UPDATE ON captions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_captions_approved_no_delete BEFORE DELETE ON captions
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_captions_graph_bump_insert AFTER INSERT ON captions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_captions_graph_bump_update AFTER UPDATE ON captions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_captions_graph_bump_delete AFTER DELETE ON captions
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_audio_ducking_rules_approved_no_insert BEFORE INSERT ON audio_ducking_rules
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=NEW.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_audio_ducking_rules_approved_no_update BEFORE UPDATE ON audio_ducking_rules
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_audio_ducking_rules_approved_no_delete BEFORE DELETE ON audio_ducking_rules
WHEN EXISTS(SELECT 1 FROM timeline_approvals ta WHERE ta.timeline_id=OLD.timeline_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_audio_ducking_rules_graph_bump_insert AFTER INSERT ON audio_ducking_rules
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_audio_ducking_rules_graph_bump_update AFTER UPDATE ON audio_ducking_rules
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=NEW.timeline_id; END;
CREATE TRIGGER trg_audio_ducking_rules_graph_bump_delete AFTER DELETE ON audio_ducking_rules
BEGIN UPDATE timelines SET graph_revision=graph_revision+1, row_version=row_version+1,
  updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=OLD.timeline_id; END;

CREATE TRIGGER trg_clip_effects_approved_no_insert BEFORE INSERT ON clip_effects
WHEN EXISTS(SELECT 1 FROM timeline_clips c JOIN timeline_approvals ta ON ta.timeline_id=c.timeline_id WHERE c.id=NEW.clip_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_effects_approved_no_update BEFORE UPDATE ON clip_effects
WHEN EXISTS(SELECT 1 FROM timeline_clips c JOIN timeline_approvals ta ON ta.timeline_id=c.timeline_id WHERE c.id=OLD.clip_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_effects_approved_no_delete BEFORE DELETE ON clip_effects
WHEN EXISTS(SELECT 1 FROM timeline_clips c JOIN timeline_approvals ta ON ta.timeline_id=c.timeline_id WHERE c.id=OLD.clip_id)
BEGIN SELECT RAISE(ABORT,'approved timeline graph is immutable'); END;
CREATE TRIGGER trg_clip_effects_graph_bump_insert AFTER INSERT ON clip_effects
BEGIN UPDATE timelines SET graph_revision=graph_revision+1,row_version=row_version+1,
 updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')
 WHERE id=(SELECT timeline_id FROM timeline_clips WHERE id=NEW.clip_id); END;
CREATE TRIGGER trg_clip_effects_graph_bump_update AFTER UPDATE ON clip_effects
BEGIN UPDATE timelines SET graph_revision=graph_revision+1,row_version=row_version+1,
 updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')
 WHERE id=(SELECT timeline_id FROM timeline_clips WHERE id=NEW.clip_id); END;
CREATE TRIGGER trg_clip_effects_graph_bump_delete AFTER DELETE ON clip_effects
BEGIN UPDATE timelines SET graph_revision=graph_revision+1,row_version=row_version+1,
 updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')
 WHERE id=(SELECT timeline_id FROM timeline_clips WHERE id=OLD.clip_id); END;

-- Materialization/approval/render/audit evidence may never be hard deleted via cascading paths.


-- Parent/root identity cannot be moved across aggregates after creation.
CREATE TRIGGER trg_projects_workspace_immutable BEFORE UPDATE OF workspace_id ON projects
WHEN NEW.workspace_id<>OLD.workspace_id BEGIN SELECT RAISE(ABORT,'project workspace is immutable'); END;
CREATE TRIGGER trg_assets_workspace_immutable BEFORE UPDATE OF workspace_id ON assets
WHEN NEW.workspace_id<>OLD.workspace_id BEGIN SELECT RAISE(ABORT,'asset workspace is immutable'); END;
CREATE TRIGGER trg_contents_workspace_immutable BEFORE UPDATE OF workspace_id ON contents
WHEN NEW.workspace_id<>OLD.workspace_id BEGIN SELECT RAISE(ABORT,'content workspace is immutable'); END;
CREATE TRIGGER trg_content_versions_parent_immutable BEFORE UPDATE OF content_id ON content_versions
WHEN NEW.content_id<>OLD.content_id BEGIN SELECT RAISE(ABORT,'content version parent is immutable'); END;
CREATE TRIGGER trg_timelines_parent_immutable BEFORE UPDATE OF content_version_id ON timelines
WHEN NEW.content_version_id<>OLD.content_version_id BEGIN SELECT RAISE(ABORT,'timeline parent is immutable'); END;
CREATE TRIGGER trg_platform_account_workspace_immutable BEFORE UPDATE OF workspace_id ON platform_accounts
WHEN NEW.workspace_id<>OLD.workspace_id BEGIN SELECT RAISE(ABORT,'platform account workspace is immutable'); END;
CREATE TRIGGER trg_timeline_track_parent_immutable BEFORE UPDATE OF timeline_id ON timeline_tracks
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'track timeline is immutable'); END;
CREATE TRIGGER trg_timeline_clip_parent_immutable BEFORE UPDATE OF timeline_id ON timeline_clips
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'clip timeline is immutable'); END;
CREATE TRIGGER trg_timeline_transition_parent_immutable BEFORE UPDATE OF timeline_id ON timeline_transitions
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'transition timeline is immutable'); END;
CREATE TRIGGER trg_clip_fade_parent_immutable BEFORE UPDATE OF timeline_id ON clip_fades
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'fade timeline is immutable'); END;
CREATE TRIGGER trg_overlay_parent_immutable BEFORE UPDATE OF timeline_id ON timeline_overlays
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'overlay timeline is immutable'); END;
CREATE TRIGGER trg_keyframe_parent_immutable BEFORE UPDATE OF timeline_id ON timeline_keyframes
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'keyframe timeline is immutable'); END;
CREATE TRIGGER trg_caption_parent_immutable BEFORE UPDATE OF timeline_id ON captions
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'caption timeline is immutable'); END;
CREATE TRIGGER trg_ducking_parent_immutable BEFORE UPDATE OF timeline_id ON audio_ducking_rules
WHEN NEW.timeline_id<>OLD.timeline_id BEGIN SELECT RAISE(ABORT,'ducking timeline is immutable'); END;
CREATE TRIGGER trg_clip_effect_parent_immutable BEFORE UPDATE OF clip_id ON clip_effects
WHEN NEW.clip_id<>OLD.clip_id BEGIN SELECT RAISE(ABORT,'clip effect parent is immutable'); END;

-- Track/source/clip-kind compatibility. Probe validation still confirms actual streams.
CREATE TRIGGER trg_clip_track_media_type_ins
BEFORE INSERT ON timeline_clips
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr JOIN assets a ON a.id=NEW.source_asset_id
  WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND a.asset_type='SOURCE_VIDEO' AND NEW.clip_kind IN ('NORMAL','FREEZE_FRAME'))
    OR (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND a.asset_type IN ('IMAGE','LOGO','THUMBNAIL') AND NEW.clip_kind='STILL_IMAGE')
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND a.asset_type IN ('SOURCE_VIDEO','SOURCE_AUDIO') AND NEW.clip_kind='NORMAL')
  )
)
BEGIN SELECT RAISE(ABORT,'clip track/source/clip-kind media mismatch'); END;
CREATE TRIGGER trg_clip_track_media_type_upd
BEFORE UPDATE OF track_id,source_asset_id,clip_kind ON timeline_clips
WHEN NOT EXISTS(
  SELECT 1 FROM timeline_tracks tr JOIN assets a ON a.id=NEW.source_asset_id
  WHERE tr.id=NEW.track_id AND tr.timeline_id=NEW.timeline_id AND (
    (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND a.asset_type='SOURCE_VIDEO' AND NEW.clip_kind IN ('NORMAL','FREEZE_FRAME'))
    OR (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY') AND a.asset_type IN ('IMAGE','LOGO','THUMBNAIL') AND NEW.clip_kind='STILL_IMAGE')
    OR (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX') AND a.asset_type IN ('SOURCE_VIDEO','SOURCE_AUDIO') AND NEW.clip_kind='NORMAL')
  )
)
BEGIN SELECT RAISE(ABORT,'clip track/source/clip-kind media mismatch'); END;

-- Workspace update variants for mutable draft records.
CREATE TRIGGER trg_asset_proxy_workspace_upd BEFORE UPDATE OF source_asset_id,proxy_asset_id ON asset_proxies
WHEN NEW.proxy_asset_id IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM assets s JOIN assets p ON p.id=NEW.proxy_asset_id WHERE s.id=NEW.source_asset_id AND s.workspace_id=p.workspace_id
) BEGIN SELECT RAISE(ABORT,'proxy asset workspace mismatch'); END;
CREATE TRIGGER trg_waveform_workspace_upd BEFORE UPDATE OF source_asset_id,waveform_asset_id ON audio_waveforms
WHEN NEW.waveform_asset_id IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM assets s JOIN assets w ON w.id=NEW.waveform_asset_id WHERE s.id=NEW.source_asset_id AND s.workspace_id=w.workspace_id
) BEGIN SELECT RAISE(ABORT,'waveform asset workspace mismatch'); END;
CREATE TRIGGER trg_reframe_workspace_upd BEFORE UPDATE OF content_version_id,source_asset_id ON reframe_plans
WHEN NOT EXISTS(
 SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.source_asset_id
 WHERE cv.id=NEW.content_version_id AND a.workspace_id=c.workspace_id
) BEGIN SELECT RAISE(ABORT,'reframe source workspace mismatch'); END;
CREATE TRIGGER trg_short_candidate_workspace_upd BEFORE UPDATE OF source_content_version_id,source_asset_id,converted_content_id ON short_candidates
WHEN NOT EXISTS(
 SELECT 1 FROM content_versions cv JOIN contents c ON c.id=cv.content_id JOIN assets a ON a.id=NEW.source_asset_id
 WHERE cv.id=NEW.source_content_version_id AND a.workspace_id=c.workspace_id
) OR (NEW.converted_content_id IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM content_versions cv JOIN contents src ON src.id=cv.content_id JOIN contents dst ON dst.id=NEW.converted_content_id
 WHERE cv.id=NEW.source_content_version_id AND src.workspace_id=dst.workspace_id
)) BEGIN SELECT RAISE(ABORT,'short candidate workspace mismatch'); END;
CREATE TRIGGER trg_analytics_workspace_upd BEFORE UPDATE OF workspace_id,publication_id ON analytics_metrics
WHEN NOT EXISTS(SELECT 1 FROM publications p WHERE p.id=NEW.publication_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'analytics workspace mismatch'); END;
CREATE TRIGGER trg_experiment_workspace_upd BEFORE UPDATE OF workspace_id,project_id ON experiments
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'experiment workspace mismatch'); END;
CREATE TRIGGER trg_project_learning_workspace_upd BEFORE UPDATE OF workspace_id,project_id ON project_learning
WHEN NOT EXISTS(SELECT 1 FROM projects p WHERE p.id=NEW.project_id AND p.workspace_id=NEW.workspace_id)
BEGIN SELECT RAISE(ABORT,'project learning workspace mismatch'); END;
-- =====================================================================
-- v2.2 final-pass authentication, probe, approval and evidence invariants
-- =====================================================================

-- App-managed session records store only a token hash and have one-way revocation.
CREATE TRIGGER trg_auth_session_identity_immutable
BEFORE UPDATE OF id,user_id,session_token_hash,session_family_id,rotated_from_session_id,created_at,expires_at ON auth_sessions
WHEN NEW.id<>OLD.id OR NEW.user_id<>OLD.user_id OR NEW.session_token_hash<>OLD.session_token_hash
  OR NEW.session_family_id<>OLD.session_family_id
  OR COALESCE(NEW.rotated_from_session_id,'')<>COALESCE(OLD.rotated_from_session_id,'')
  OR NEW.created_at<>OLD.created_at OR NEW.expires_at<>OLD.expires_at
BEGIN SELECT RAISE(ABORT,'session identity is immutable; rotate by creating a new session'); END;

CREATE TRIGGER trg_auth_session_revocation_one_way
BEFORE UPDATE OF revoked_at,revocation_reason ON auth_sessions
WHEN (OLD.revoked_at IS NOT NULL AND (
       NEW.revoked_at IS NULL OR NEW.revoked_at<>OLD.revoked_at
       OR COALESCE(NEW.revocation_reason,'')<>COALESCE(OLD.revocation_reason,'')
     ))
  OR (OLD.revoked_at IS NULL AND NEW.revoked_at IS NULL
      AND COALESCE(NEW.revocation_reason,'')<>COALESCE(OLD.revocation_reason,''))
BEGIN SELECT RAISE(ABORT,'session revocation is one-way and reason-bound'); END;

-- Probe evidence is immutable and must match the exact source bytes.
CREATE TRIGGER trg_media_probe_source_ins
BEFORE INSERT ON media_probes
WHEN NOT EXISTS(
  SELECT 1 FROM assets a
  WHERE a.id=NEW.source_asset_id AND a.status='AVAILABLE'
    AND a.asset_type IN ('SOURCE_VIDEO','SOURCE_AUDIO')
    AND a.checksum_sha256=NEW.source_checksum_sha256
)
BEGIN SELECT RAISE(ABORT,'media probe source/checksum/type mismatch'); END;

CREATE TRIGGER trg_media_probe_no_update
BEFORE UPDATE ON media_probes
BEGIN SELECT RAISE(ABORT,'media probe evidence is immutable'); END;

CREATE TRIGGER trg_media_probe_no_delete
BEFORE DELETE ON media_probes
BEGIN SELECT RAISE(ABORT,'media probe evidence is immutable'); END;

-- A clip graph may remain an invalid draft, but a materialization requires exact probe/stream binding.
CREATE TRIGGER trg_materialization_requires_probe_streams
BEFORE INSERT ON timeline_materializations
WHEN EXISTS(
  SELECT 1
  FROM timeline_clips c
  JOIN timeline_tracks tr ON tr.id=c.track_id AND tr.timeline_id=c.timeline_id
  WHERE c.timeline_id=NEW.timeline_id AND c.enabled=1 AND (
    (c.clip_kind IN ('NORMAL','FREEZE_FRAME') AND (
       c.source_probe_id IS NULL
       OR NOT EXISTS(
          SELECT 1 FROM media_probes mp
          WHERE mp.id=c.source_probe_id AND mp.source_asset_id=c.source_asset_id
            AND c.source_end_ms*1000 <= mp.duration_us
            AND (
              (tr.track_type IN ('VIDEO_PRIMARY','VIDEO_BROLL','VIDEO_OVERLAY')
               AND c.video_stream_index IS NOT NULL
               AND c.video_stream_index < mp.video_stream_count)
              OR
              (tr.track_type IN ('AUDIO_PRIMARY','AUDIO_MUSIC','AUDIO_SFX')
               AND c.audio_stream_index IS NOT NULL
               AND c.audio_stream_index < mp.audio_stream_count)
            )
       )
    ))
    OR
    (c.clip_kind='STILL_IMAGE' AND (
       c.source_probe_id IS NOT NULL OR c.video_stream_index IS NOT NULL OR c.audio_stream_index IS NOT NULL
    ))
  )
)
BEGIN SELECT RAISE(ABORT,'timeline materialization requires exact source probe and stream selection'); END;

-- Timeline approval follows an approved human review of the exact materialization.
CREATE TRIGGER trg_timeline_approval_requires_review
BEFORE INSERT ON timeline_approvals
WHEN NOT EXISTS(
  SELECT 1
  FROM timeline_materializations tm
  JOIN timelines t ON t.id=tm.timeline_id
  JOIN review_sessions rs ON rs.content_version_id=t.content_version_id
    AND rs.timeline_materialization_id=tm.id
  WHERE tm.id=NEW.materialization_id AND tm.timeline_id=NEW.timeline_id
    AND rs.status='APPROVED' AND rs.reviewer_user_id IS NOT NULL
)
BEGIN SELECT RAISE(ABORT,'timeline approval requires approved review of exact materialization'); END;

-- Approved or historically consumed authoring/evidence cannot be rewritten.
CREATE TRIGGER trg_thumbnail_approved_immutable
BEFORE UPDATE ON thumbnails
WHEN OLD.status='APPROVED' AND (
  NEW.content_version_id<>OLD.content_version_id OR NEW.variant_key<>OLD.variant_key
  OR COALESCE(NEW.asset_id,'')<>COALESCE(OLD.asset_id,'')
  OR NEW.design_json<>OLD.design_json OR NEW.design_hash<>OLD.design_hash
  OR NEW.status<>'APPROVED'
)
BEGIN SELECT RAISE(ABORT,'approved thumbnail is immutable; create a new variant'); END;

CREATE TRIGGER trg_thumbnail_approved_no_delete
BEFORE DELETE ON thumbnails
WHEN OLD.status='APPROVED'
   OR EXISTS(SELECT 1 FROM experiment_variants ev WHERE ev.thumbnail_id=OLD.id)
BEGIN SELECT RAISE(ABORT,'approved/referenced thumbnail history is immutable'); END;

CREATE TRIGGER trg_hooks_approved_parent_no_update
BEFORE UPDATE ON hooks
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'hook under approved content version is immutable'); END;
CREATE TRIGGER trg_hooks_approved_parent_no_delete
BEFORE DELETE ON hooks
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'hook under approved content version is immutable'); END;

CREATE TRIGGER trg_scenes_approved_parent_no_update
BEFORE UPDATE ON scenes
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'scene under approved content version is immutable'); END;
CREATE TRIGGER trg_scenes_approved_parent_no_delete
BEFORE DELETE ON scenes
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'scene under approved content version is immutable'); END;

CREATE TRIGGER trg_design_override_approved_parent_no_insert
BEFORE INSERT ON design_overrides
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=NEW.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'approved content version cannot receive new live design overrides'); END;
CREATE TRIGGER trg_design_override_approved_parent_no_update
BEFORE UPDATE ON design_overrides
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'design override under approved content version is immutable'); END;
CREATE TRIGGER trg_design_override_approved_parent_no_delete
BEFORE DELETE ON design_overrides
WHEN EXISTS(
  SELECT 1 FROM content_versions cv WHERE cv.id=OLD.content_version_id AND cv.status IN ('APPROVED','SUPERSEDED')
)
BEGIN SELECT RAISE(ABORT,'design override under approved content version is immutable'); END;

CREATE TRIGGER trg_media_analysis_terminal_immutable
BEFORE UPDATE ON media_analysis_runs
WHEN OLD.status IN ('COMPLETED','FAILED')
BEGIN SELECT RAISE(ABORT,'terminal media analysis evidence is immutable'); END;
CREATE TRIGGER trg_media_analysis_no_delete
BEFORE DELETE ON media_analysis_runs
BEGIN SELECT RAISE(ABORT,'media analysis history is immutable'); END;

CREATE TRIGGER trg_asset_proxy_ready_immutable
BEFORE UPDATE ON asset_proxies
WHEN OLD.status='READY'
BEGIN SELECT RAISE(ABORT,'ready proxy evidence is immutable'); END;
CREATE TRIGGER trg_asset_proxy_no_delete
BEFORE DELETE ON asset_proxies
WHEN OLD.status='READY'
BEGIN SELECT RAISE(ABORT,'ready proxy evidence is immutable'); END;

CREATE TRIGGER trg_waveform_ready_immutable
BEFORE UPDATE ON audio_waveforms
WHEN OLD.status='READY'
BEGIN SELECT RAISE(ABORT,'ready waveform evidence is immutable'); END;
CREATE TRIGGER trg_waveform_no_delete
BEFORE DELETE ON audio_waveforms
WHEN OLD.status='READY'
BEGIN SELECT RAISE(ABORT,'ready waveform evidence is immutable'); END;

CREATE TRIGGER trg_short_candidate_converted_immutable
BEFORE UPDATE ON short_candidates
WHEN OLD.status='CONVERTED'
BEGIN SELECT RAISE(ABORT,'converted short candidate is immutable'); END;
CREATE TRIGGER trg_short_candidate_converted_no_delete
BEFORE DELETE ON short_candidates
WHEN OLD.status='CONVERTED'
BEGIN SELECT RAISE(ABORT,'converted short candidate history is immutable'); END;

CREATE TRIGGER trg_experiment_variant_lock_update
BEFORE UPDATE ON experiment_variants
WHEN EXISTS(
  SELECT 1 FROM experiments e WHERE e.id=OLD.experiment_id
    AND e.status IN ('RUNNING','COLLECTING','COMPLETED','INCONCLUSIVE')
)
BEGIN SELECT RAISE(ABORT,'active/completed experiment variants are immutable'); END;
CREATE TRIGGER trg_experiment_variant_lock_delete
BEFORE DELETE ON experiment_variants
WHEN EXISTS(
  SELECT 1 FROM experiments e WHERE e.id=OLD.experiment_id
    AND e.status IN ('RUNNING','COLLECTING','COMPLETED','INCONCLUSIVE')
)
BEGIN SELECT RAISE(ABORT,'active/completed experiment variants are immutable'); END;

-- =====================================================================
-- v2.2.1 runtime execution evidence and fencing invariants
-- =====================================================================

CREATE TRIGGER trg_render_dispatch_no_update
BEFORE UPDATE ON render_job_dispatches
BEGIN SELECT RAISE(ABORT,'render dispatch identity is immutable'); END;
CREATE TRIGGER trg_render_dispatch_no_delete
BEFORE DELETE ON render_job_dispatches
BEGIN SELECT RAISE(ABORT,'render dispatch history is immutable'); END;

CREATE TRIGGER trg_publication_dispatch_no_update
BEFORE UPDATE ON publication_job_dispatches
BEGIN SELECT RAISE(ABORT,'publication dispatch identity is immutable'); END;
CREATE TRIGGER trg_publication_dispatch_no_delete
BEFORE DELETE ON publication_job_dispatches
BEGIN SELECT RAISE(ABORT,'publication dispatch history is immutable'); END;

CREATE TRIGGER trg_worker_attempt_no_update
BEFORE UPDATE ON worker_job_attempts
WHEN OLD.outcome<>'RUNNING'
  OR NEW.id<>OLD.id
  OR NEW.worker_job_id<>OLD.worker_job_id
  OR NEW.attempt_no<>OLD.attempt_no
  OR NEW.lease_generation<>OLD.lease_generation
  OR NEW.lease_owner<>OLD.lease_owner
  OR NEW.started_at<>OLD.started_at
  OR NEW.correlation_id<>OLD.correlation_id
  OR COALESCE(NEW.causation_id,'')<>COALESCE(OLD.causation_id,'')
  OR NEW.outcome='RUNNING'
  OR NEW.ended_at IS NULL
BEGIN SELECT RAISE(ABORT,'worker attempt identity/terminal evidence is immutable'); END;
CREATE TRIGGER trg_worker_attempt_no_delete
BEFORE DELETE ON worker_job_attempts
BEGIN SELECT RAISE(ABORT,'worker attempt evidence is immutable'); END;

CREATE TRIGGER trg_render_attempt_no_update
BEFORE UPDATE ON render_attempts
WHEN OLD.outcome<>'RUNNING'
  OR NEW.id<>OLD.id
  OR NEW.render_job_id<>OLD.render_job_id
  OR NEW.worker_attempt_id<>OLD.worker_attempt_id
  OR NEW.attempt_no<>OLD.attempt_no
  OR NEW.started_at<>OLD.started_at
  OR NEW.render_plan_hash<>OLD.render_plan_hash
  OR NEW.argument_plan_hash<>OLD.argument_plan_hash
  OR NEW.outcome='RUNNING'
  OR NEW.ended_at IS NULL
BEGIN SELECT RAISE(ABORT,'render attempt identity/terminal evidence is immutable'); END;
CREATE TRIGGER trg_render_attempt_no_delete
BEFORE DELETE ON render_attempts
BEGIN SELECT RAISE(ABORT,'render attempt evidence is immutable'); END;

CREATE TRIGGER trg_publication_attempt_no_update
BEFORE UPDATE ON publication_attempts
WHEN OLD.outcome<>'RUNNING'
  OR NEW.id<>OLD.id
  OR NEW.publication_job_id<>OLD.publication_job_id
  OR NEW.worker_attempt_id<>OLD.worker_attempt_id
  OR NEW.attempt_no<>OLD.attempt_no
  OR NEW.started_at<>OLD.started_at
  OR NEW.provider_request_hash<>OLD.provider_request_hash
  OR NEW.adapter_version<>OLD.adapter_version
  OR NEW.outcome='RUNNING'
  OR NEW.ended_at IS NULL
BEGIN SELECT RAISE(ABORT,'publication attempt identity/terminal evidence is immutable'); END;
CREATE TRIGGER trg_publication_attempt_no_delete
BEFORE DELETE ON publication_attempts
BEGIN SELECT RAISE(ABORT,'publication attempt evidence is immutable'); END;

CREATE TRIGGER trg_operation_event_no_update
BEFORE UPDATE ON operation_events
BEGIN SELECT RAISE(ABORT,'operation event is append-only'); END;
CREATE TRIGGER trg_operation_event_no_delete
BEFORE DELETE ON operation_events
BEGIN SELECT RAISE(ABORT,'operation event is append-only'); END;

CREATE TRIGGER trg_render_dispatch_job_type_ins
BEFORE INSERT ON render_job_dispatches
WHEN NOT EXISTS(
  SELECT 1 FROM worker_jobs w
  JOIN render_jobs r
    ON r.id=NEW.render_job_id AND r.workspace_id=NEW.workspace_id
  WHERE w.id=NEW.worker_job_id AND w.workspace_id=NEW.workspace_id
    AND w.job_type IN ('PREVIEW_RENDER','FINAL_RENDER')
    AND w.execution_fingerprint=r.execution_fingerprint
)
BEGIN SELECT RAISE(ABORT,'render dispatch requires matching WorkerJob type and execution fingerprint'); END;

CREATE TRIGGER trg_publication_dispatch_job_type_ins
BEFORE INSERT ON publication_job_dispatches
WHEN NOT EXISTS(
  SELECT 1 FROM worker_jobs w
  JOIN publication_jobs p
    ON p.id=NEW.publication_job_id AND p.workspace_id=NEW.workspace_id
  WHERE w.id=NEW.worker_job_id AND w.workspace_id=NEW.workspace_id
    AND w.job_type='PUBLISH'
    AND w.execution_fingerprint=p.execution_fingerprint
)
BEGIN SELECT RAISE(ABORT,'publication dispatch requires matching PUBLISH WorkerJob fingerprint'); END;

-- A job may change terminal state only while the service owns the current lease
-- generation. The exact compare-and-swap statement is frozen in
-- TRANSACTION_AND_CONCURRENCY.md; stale workers must update zero rows.

CREATE TRIGGER trg_worker_job_lease_generation_guard
BEFORE UPDATE ON worker_jobs
WHEN NEW.lease_generation < OLD.lease_generation
  OR (
    NEW.status='RUNNING'
    AND (
      OLD.status<>'RUNNING'
      OR COALESCE(NEW.lease_owner,'')<>COALESCE(OLD.lease_owner,'')
    )
    AND NEW.lease_generation<>OLD.lease_generation+1
  )
BEGIN SELECT RAISE(ABORT,'worker lease claim/reclaim must increment lease_generation exactly once'); END;

CREATE TRIGGER trg_worker_attempt_current_lease_ins
BEFORE INSERT ON worker_job_attempts
WHEN NOT EXISTS(
  SELECT 1 FROM worker_jobs w
  WHERE w.id=NEW.worker_job_id
    AND w.status='RUNNING'
    AND w.lease_generation=NEW.lease_generation
    AND w.lease_owner=NEW.lease_owner
)
BEGIN SELECT RAISE(ABORT,'worker attempt must own the current lease generation'); END;

CREATE TRIGGER trg_worker_attempt_current_lease_close
BEFORE UPDATE OF outcome,ended_at,error_code,retry_decision,evidence_json,evidence_hash
ON worker_job_attempts
WHEN OLD.outcome='RUNNING'
  AND NOT EXISTS(
    SELECT 1 FROM worker_jobs w
    WHERE w.id=OLD.worker_job_id
      AND w.status='RUNNING'
      AND w.lease_generation=OLD.lease_generation
      AND w.lease_owner=OLD.lease_owner
  )
  AND NOT (
    NEW.outcome='LEASE_LOST'
    AND EXISTS(
      SELECT 1 FROM worker_jobs w
      WHERE w.id=OLD.worker_job_id AND w.lease_generation>OLD.lease_generation
    )
  )
BEGIN SELECT RAISE(ABORT,'stale worker attempt is fenced'); END;

-- =====================================================================
-- v2.2.1 exact review, profile binding and staging lifecycle invariants
-- =====================================================================

CREATE TRIGGER trg_review_item_scope_ins
BEFORE INSERT ON review_items
WHEN NEW.status<>'OPEN'
  OR NOT EXISTS(
    SELECT 1
    FROM review_sessions r
    JOIN content_versions cv ON cv.id=r.content_version_id
    JOIN contents c ON c.id=cv.content_id
    JOIN workspace_memberships wm
      ON wm.workspace_id=c.workspace_id AND wm.user_id=NEW.created_by_user_id
    WHERE r.id=NEW.review_session_id
      AND r.status='OPEN'
      AND c.workspace_id=NEW.workspace_id
  )
  OR (
    NEW.source_review_item_id IS NOT NULL
    AND NOT EXISTS(
      SELECT 1 FROM review_items source
      WHERE source.id=NEW.source_review_item_id
        AND source.workspace_id=NEW.workspace_id
        AND source.review_session_id<>NEW.review_session_id
    )
  )
BEGIN SELECT RAISE(ABORT,'review item requires an open same-workspace review and member author'); END;

CREATE TRIGGER trg_review_item_update_guard
BEFORE UPDATE ON review_items
WHEN OLD.status<>'OPEN'
  OR NEW.id<>OLD.id
  OR NEW.workspace_id<>OLD.workspace_id
  OR NEW.review_session_id<>OLD.review_session_id
  OR COALESCE(NEW.source_review_item_id,'')<>COALESCE(OLD.source_review_item_id,'')
  OR NEW.created_by_user_id<>OLD.created_by_user_id
  OR NEW.created_at<>OLD.created_at
  OR NEW.row_version<>OLD.row_version+1
  OR NOT EXISTS(
    SELECT 1
    FROM review_sessions r
    JOIN content_versions cv ON cv.id=r.content_version_id
    JOIN contents c ON c.id=cv.content_id
    WHERE r.id=NEW.review_session_id
      AND r.status='OPEN'
      AND c.workspace_id=NEW.workspace_id
  )
  OR (
    NEW.status IN ('RESOLVED','WONT_FIX')
    AND NOT EXISTS(
      SELECT 1 FROM workspace_memberships wm
      WHERE wm.workspace_id=NEW.workspace_id AND wm.user_id=NEW.resolved_by_user_id
    )
  )
BEGIN SELECT RAISE(ABORT,'review item update violates identity, session, version or resolver scope'); END;

CREATE TRIGGER trg_review_item_no_delete
BEFORE DELETE ON review_items
BEGIN SELECT RAISE(ABORT,'review item evidence is immutable'); END;

CREATE TRIGGER trg_review_approval_no_open_blockers
BEFORE UPDATE OF status ON review_sessions
WHEN NEW.status='APPROVED'
  AND EXISTS(
    SELECT 1 FROM review_items i
    WHERE i.review_session_id=OLD.id AND i.status='OPEN' AND i.severity='BLOCKING'
  )
BEGIN SELECT RAISE(ABORT,'review approval requires all blocking review items resolved'); END;

CREATE TRIGGER trg_platform_media_profile_actor_ins
BEFORE INSERT ON platform_media_profiles
WHEN NEW.status<>'ACTIVE'
  OR NOT EXISTS(
    SELECT 1 FROM workspace_memberships wm
    WHERE wm.workspace_id=NEW.workspace_id AND wm.user_id=NEW.created_by
  )
BEGIN SELECT RAISE(ABORT,'platform media profile must start active and be created by a workspace member'); END;

CREATE TRIGGER trg_platform_media_profile_update_guard
BEFORE UPDATE ON platform_media_profiles
WHEN OLD.status<>'ACTIVE'
  OR NEW.status<>'DEPRECATED'
  OR NEW.id<>OLD.id
  OR NEW.workspace_id<>OLD.workspace_id
  OR NEW.platform<>OLD.platform
  OR NEW.publication_type<>OLD.publication_type
  OR NEW.profile_key<>OLD.profile_key
  OR NEW.profile_version<>OLD.profile_version
  OR NEW.profile_json<>OLD.profile_json
  OR NEW.profile_hash<>OLD.profile_hash
  OR NEW.created_by<>OLD.created_by
  OR NEW.created_at<>OLD.created_at
  OR NEW.row_version<>OLD.row_version+1
BEGIN SELECT RAISE(ABORT,'platform media profile payload is immutable; only deprecation is allowed'); END;

CREATE TRIGGER trg_platform_media_profile_no_delete
BEFORE DELETE ON platform_media_profiles
BEGIN SELECT RAISE(ABORT,'platform media profile history is immutable'); END;

CREATE TRIGGER trg_publication_profile_binding_integrity_ins
BEFORE INSERT ON publication_profile_bindings
WHEN NOT EXISTS(
  SELECT 1
  FROM publications p
  JOIN platform_accounts a
    ON a.id=p.platform_account_id AND a.workspace_id=p.workspace_id
  JOIN platform_media_profiles m
    ON m.id=NEW.platform_media_profile_id AND m.workspace_id=NEW.workspace_id
  LEFT JOIN assets final_asset
    ON final_asset.id=p.final_asset_id AND final_asset.workspace_id=p.workspace_id
  JOIN workspace_memberships wm
    ON wm.workspace_id=p.workspace_id AND wm.user_id=NEW.bound_by
  WHERE p.id=NEW.publication_id
    AND p.workspace_id=NEW.workspace_id
    AND m.status='ACTIVE'
    AND m.platform=a.platform
    AND m.publication_type=p.publication_type
    AND p.row_version=NEW.publication_row_version
    AND m.row_version=NEW.profile_row_version
    AND m.profile_version=NEW.profile_version
    AND m.profile_hash=NEW.profile_hash
    AND p.metadata_hash=NEW.metadata_hash
    AND (
      (p.final_asset_id IS NULL AND NEW.final_asset_checksum_sha256 IS NULL)
      OR
      (p.final_asset_id IS NOT NULL
        AND final_asset.checksum_sha256=NEW.final_asset_checksum_sha256)
    )
)
BEGIN SELECT RAISE(ABORT,'publication profile binding must match workspace, platform, profile and exact payload hashes'); END;

CREATE TRIGGER trg_publication_profile_binding_no_update
BEFORE UPDATE ON publication_profile_bindings
BEGIN SELECT RAISE(ABORT,'publication profile binding is immutable'); END;
CREATE TRIGGER trg_publication_profile_binding_no_delete
BEFORE DELETE ON publication_profile_bindings
BEGIN SELECT RAISE(ABORT,'publication profile binding history is immutable'); END;

CREATE TRIGGER trg_publication_staging_scope_ins
BEFORE INSERT ON publication_staging_objects
WHEN NOT EXISTS(
    SELECT 1 FROM publications p
    WHERE p.id=NEW.publication_id AND p.workspace_id=NEW.workspace_id
  )
  OR (
    NEW.publication_job_id IS NOT NULL
    AND NOT EXISTS(
      SELECT 1 FROM publication_jobs j
      WHERE j.id=NEW.publication_job_id
        AND j.workspace_id=NEW.workspace_id
        AND j.publication_id=NEW.publication_id
    )
  )
  OR (
    NEW.publication_attempt_id IS NOT NULL
    AND (
      NEW.publication_job_id IS NULL
      OR NOT EXISTS(
        SELECT 1 FROM publication_attempts a
        WHERE a.id=NEW.publication_attempt_id
          AND a.publication_job_id=NEW.publication_job_id
      )
    )
  )
BEGIN SELECT RAISE(ABORT,'publication staging object must match publication, job and attempt scope'); END;

CREATE TRIGGER trg_publication_staging_identity_guard
BEFORE UPDATE ON publication_staging_objects
WHEN OLD.status='CLEANED'
  OR NEW.id<>OLD.id
  OR NEW.workspace_id<>OLD.workspace_id
  OR NEW.publication_id<>OLD.publication_id
  OR COALESCE(NEW.publication_job_id,'')<>COALESCE(OLD.publication_job_id,'')
  OR COALESCE(NEW.publication_attempt_id,'')<>COALESCE(OLD.publication_attempt_id,'')
  OR NEW.object_role<>OLD.object_role
  OR NEW.storage_provider<>OLD.storage_provider
  OR NEW.bucket_or_container<>OLD.bucket_or_container
  OR NEW.object_key<>OLD.object_key
  OR NEW.created_at<>OLD.created_at
  OR NEW.row_version<>OLD.row_version+1
BEGIN SELECT RAISE(ABORT,'staging object identity and terminal cleanup evidence are immutable'); END;

CREATE TRIGGER trg_publication_staging_transition_guard
BEFORE UPDATE OF status ON publication_staging_objects
WHEN NEW.status<>OLD.status
  AND NOT (
    (OLD.status='ALLOCATED' AND NEW.status IN ('UPLOADING','EXPIRED','CLEANUP_PENDING'))
    OR (OLD.status='UPLOADING' AND NEW.status IN ('READY','EXPIRED','CLEANUP_PENDING','CLEANUP_FAILED'))
    OR (OLD.status='READY' AND NEW.status IN ('CONSUMED','EXPIRED','CLEANUP_PENDING'))
    OR (OLD.status='CONSUMED' AND NEW.status IN ('EXPIRED','CLEANUP_PENDING'))
    OR (OLD.status='EXPIRED' AND NEW.status IN ('CLEANUP_PENDING','CLEANUP_FAILED','CLEANED'))
    OR (OLD.status='CLEANUP_PENDING' AND NEW.status IN ('CLEANUP_FAILED','CLEANED'))
    OR (OLD.status='CLEANUP_FAILED' AND NEW.status IN ('CLEANUP_PENDING','CLEANED'))
  )
BEGIN SELECT RAISE(ABORT,'invalid publication staging lifecycle transition'); END;

CREATE TRIGGER trg_publication_staging_no_delete
BEFORE DELETE ON publication_staging_objects
BEGIN SELECT RAISE(ABORT,'publication staging lifecycle evidence is immutable'); END;
