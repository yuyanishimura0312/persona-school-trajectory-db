-- PST-DB Schema v1.0
-- Persona-School-Trajectory Integrated DB
-- 5層構造：L1 子どもの人格 / L2 適合学校 / L3 活躍経路 / L4 偉人パターン / L5 時代適合

PRAGMA foreign_keys = ON;

-- =============================================
-- L1: 人格次元・アーキタイプマスタ
-- =============================================

CREATE TABLE IF NOT EXISTS personality_dimensions (
    id              TEXT PRIMARY KEY,
    name_ja         TEXT NOT NULL,
    name_en         TEXT,
    big_five_axis   TEXT,                    -- O/C/E/A/N
    sub_dimension   TEXT,                    -- facet
    measurement_tool TEXT,                   -- BFI-J/BFI-2-J/TIPI-J
    age_floor       INTEGER DEFAULT 8,
    description     TEXT
);

CREATE TABLE IF NOT EXISTS persona_archetypes (
    id              TEXT PRIMARY KEY,        -- arch_explorer等（jpms互換）
    name_ja         TEXT NOT NULL,
    name_en         TEXT,
    big_five_thresholds TEXT,                -- JSON: {"O": ">75", "C": ">60"}
    holland_codes   TEXT,                    -- JSON: ["I", "A"]
    description     TEXT,
    population_pct  REAL,                    -- 推定人口比率
    typical_traits  TEXT
);

-- =============================================
-- L2: 学校（jpms連携）
-- =============================================

CREATE TABLE IF NOT EXISTS schools_pst (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    jpms_school_id  TEXT,                    -- jpms_v2.schools_v2 への参照
    school_name     TEXT NOT NULL,
    prefecture      TEXT,
    school_type     TEXT,                    -- middle/high/integrated
    lca_cluster     INTEGER,                 -- jpms LCA k=8
    culture_profile TEXT,                    -- JSON: 5次元スコア
    philosophy_summary TEXT,
    notes           TEXT
);

-- =============================================
-- Phase B: 学校×時代適合（タスク1）
-- =============================================

CREATE TABLE IF NOT EXISTS school_era_fit (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    school_id       INTEGER NOT NULL REFERENCES schools_pst(id),
    era_id          TEXT NOT NULL,           -- meiji/taisho/.../future_2030/2050/2100
    fit_score       REAL CHECK(fit_score BETWEEN 0 AND 1),
    matched_capabilities TEXT,               -- JSON array of capability_id
    rationale_ja    TEXT,
    is_uncertain    INTEGER DEFAULT 0,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- =============================================
-- Phase C: 学校×人格モデル（タスク2）
-- =============================================

CREATE TABLE IF NOT EXISTS school_archetype_fit (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    school_id       INTEGER NOT NULL REFERENCES schools_pst(id),
    archetype_id    TEXT NOT NULL REFERENCES persona_archetypes(id),
    fit_score       REAL CHECK(fit_score BETWEEN 0 AND 1),
    fit_type        TEXT,                    -- direct_fit/stretch_fit/poor_fit
    psychological_rationale TEXT,
    risks           TEXT,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- =============================================
-- Phase D: 予測モデル（タスク3）
-- =============================================

CREATE TABLE IF NOT EXISTS prediction_paths (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    archetype_id    TEXT NOT NULL,
    school_id       INTEGER REFERENCES schools_pst(id),
    likely_career_domains TEXT,              -- JSON array
    estimated_outcomes TEXT,                 -- JSON: {"creativity": 8, ...}
    confidence_interval TEXT,                -- JSON: {"lower": 0.55, "upper": 0.85}
    scenario_breakdown TEXT,                 -- JSON: {"SSP1": 0.7, "SSP3": 0.4, "AGI": 0.6}
    rationale_ja    TEXT,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- =============================================
-- L4: 偉人プロファイル（era-talents連携、Big Five推定）
-- =============================================

CREATE TABLE IF NOT EXISTS eminent_persona_profiles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    achiever_id     INTEGER,                 -- era-talents.achievers.id
    name_ja         TEXT NOT NULL,
    primary_era_id  TEXT,
    domain          TEXT,
    big_five        TEXT,                    -- JSON: {"O": 85, "C": 65, "E": 55, "A": 45, "N": 30}
    holland_codes   TEXT,                    -- JSON: ["I", "A"]
    archetype_id    TEXT REFERENCES persona_archetypes(id),
    cluster_id      INTEGER,                 -- GMM cluster
    archetype_confidence REAL,
    estimation_method TEXT,                  -- capability_mapping/text_analysis/historical_record
    notes           TEXT,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- =============================================
-- Phase E: 時代翻訳・偉人パターン
-- =============================================

CREATE TABLE IF NOT EXISTS persona_era_translation (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    archetype_id    TEXT NOT NULL,
    source_era      TEXT,                    -- 過去（meiji等）
    target_era      TEXT,                    -- 現代/未来（reiwa, future_2030等）
    translation_factor REAL,                 -- 補正係数
    representative_eminent_ids TEXT,         -- JSON array of eminent_persona_profiles.id
    modern_equivalent_summary TEXT,
    cautions        TEXT,                    -- 時代差異への配慮事項
    created_at      TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS scenario_persona_fit (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    archetype_id    TEXT NOT NULL,
    future_era_id   TEXT,                    -- future_2030/2050/2100
    scenario        TEXT,                    -- baseline/SSP1/SSP3/AGI/post_humanity等
    fit_score       REAL CHECK(fit_score BETWEEN 0 AND 1),
    rationale_ja    TEXT,
    representative_capabilities TEXT,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- =============================================
-- インデックス
-- =============================================

CREATE INDEX IF NOT EXISTS idx_school_era_fit_school ON school_era_fit(school_id);
CREATE INDEX IF NOT EXISTS idx_school_era_fit_era ON school_era_fit(era_id);
CREATE INDEX IF NOT EXISTS idx_school_archetype_school ON school_archetype_fit(school_id);
CREATE INDEX IF NOT EXISTS idx_eminent_archetype ON eminent_persona_profiles(archetype_id);
CREATE INDEX IF NOT EXISTS idx_eminent_era ON eminent_persona_profiles(primary_era_id);
CREATE INDEX IF NOT EXISTS idx_prediction_archetype ON prediction_paths(archetype_id);

-- =============================================
-- 初期データ：persona_archetypes（jpms 10類型を準拠）
-- =============================================

INSERT OR IGNORE INTO persona_archetypes (id, name_ja, name_en, big_five_thresholds, holland_codes, description, population_pct) VALUES
('arch_explorer',         '探究者',     'Explorer',          '{"O": ">75", "C": ">60"}',                'I,A',   '知的好奇心が強く、新領域への探求を好む。研究者・学者の若年期典型。', 0.12),
('arch_creator',          '創造者',     'Creator',           '{"O": ">80", "N": ">55"}',                'A,I',   '内的世界が豊かで創作・表現に向かう。芸術家・作家の若年期典型。', 0.08),
('arch_leader',           'リーダー型', 'Leader',            '{"E": ">70", "C": ">65", "A": "<60"}',    'E,S',   '対人影響力と達成志向。経営者・政治家の若年期典型。', 0.10),
('arch_caregiver',        '養育者',     'Caregiver',         '{"A": ">75", "E": ">55"}',                'S,A',   '他者ケア志向。教師・医療専門家・NPO人の若年期典型。', 0.15),
('arch_warrior',          '挑戦者',     'Warrior',           '{"E": ">70", "C": ">70", "N": "<40"}',    'E,R',   '困難に立ち向かう型。アスリート・起業家の若年期典型。', 0.07),
('arch_mediator',         '調停者',     'Mediator',          '{"A": ">75", "O": ">65"}',                'S,E',   '対立調整・価値統合志向。外交官・調停者・コミュニティリーダーの若年期典型。', 0.06),
('arch_craftsman',        '職人型',     'Craftsman',         '{"C": ">80", "O": "40-65"}',              'R,C',   '専門技能の磨き上げ志向。技術者・職人・専門家の若年期典型。', 0.12),
('arch_introvert_thinker','内省思索者', 'Introvert Thinker', '{"E": "<40", "O": ">70", "N": ">55"}',    'I,A',   '内向的な思索・観察志向。哲学者・研究者の若年期典型。', 0.09),
('arch_social_creator',   '社交創造者', 'Social Creator',    '{"E": ">70", "O": ">75"}',                'A,E',   '社交性と創造性の両立。クリエイター・プロデューサーの若年期典型。', 0.06),
('arch_steady',           '堅実型',     'Steady',            '{"C": ">70", "A": ">65", "N": "<45"}',    'C,S',   '安定志向の堅実型。専門職・公務員の若年期典型。', 0.15);

-- =============================================
-- 初期データ：personality_dimensions（Big Five 5軸）
-- =============================================

INSERT OR IGNORE INTO personality_dimensions (id, name_ja, name_en, big_five_axis, measurement_tool, description) VALUES
('big5_O', '開放性',   'Openness',          'O', 'BFI-2-J', '新規体験への開放、想像力、知的好奇心'),
('big5_C', '誠実性',   'Conscientiousness', 'C', 'BFI-2-J', '計画性、責任感、勤勉性'),
('big5_E', '外向性',   'Extraversion',      'E', 'BFI-2-J', '社交性、活発さ、肯定的感情'),
('big5_A', '協調性',   'Agreeableness',     'A', 'BFI-2-J', '思いやり、信頼、協力'),
('big5_N', '神経症傾向','Neuroticism',      'N', 'BFI-2-J', '不安、抑うつ、情緒不安定'),
('gmnst',  '成長マインドセット','Growth Mindset','-','MSCI-J','能力は努力で伸びるという信念（Dweck）'),
('grit',   'グリット', 'Grit',              '-', 'GRIT-S', '長期目標への情熱と粘り強さ（Duckworth）'),
('srq',    '自己制御', 'Self-Regulation',   '-', 'SRQ',    '自己決定理論ベースの内発的動機');
