#!/bin/bash
# PST-DB Codex並列ランチャー Phase B-E
set -e
PROJ="$HOME/projects/research/persona-school-trajectory-db"
PST_DB="$PROJ/data/pst.db"
JPMS_DB="$HOME/projects/research/jpms-db/v2/jpms_v2.db"
ETD_DB="$HOME/projects/research/era-talents-db/data/era_talents.db"
LOG_DIR="$PROJ/build/logs"
RESEARCH_DIR="$PROJ/research"
CODEX="/opt/homebrew/bin/codex"
mkdir -p "$LOG_DIR"

declare -a TASKS=(
  # === Phase B: 学校×時代適合 (8 tasks) ===
  "B|meiji|jpms 551校をmeiji時代の能力像と適合度評価。era_required_traitsとL1当時言説、L2事後評価を参照"
  "B|taisho|jpms 551校をtaisho時代の能力像と適合度評価"
  "B|showa_pre|jpms 551校をshowa_pre時代と適合度評価"
  "B|showa_post|jpms 551校をshowa_post時代と適合度評価"
  "B|heisei|jpms 551校をheisei時代と適合度評価"
  "B|reiwa|jpms 551校をreiwa時代と適合度評価"
  "B|future_2030|jpms 551校×2030予測（WEF/OECD/経産省）の適合"
  "B|future_2050|jpms 551校×2050予測（IPCC SSPs/長寿社会）の適合"
  # === Phase C: 学校×人格 (5 tasks) ===
  "C|arch_explorer_creator|arch_explorer/arch_creator型と551校のフィット分析"
  "C|arch_leader_warrior|arch_leader/arch_warrior型と551校のフィット分析"
  "C|arch_caregiver_mediator|arch_caregiver/arch_mediator型と551校のフィット分析"
  "C|arch_craftsman_steady|arch_craftsman/arch_steady型と551校のフィット分析"
  "C|arch_introvert_social|arch_introvert_thinker/arch_social_creator型と551校のフィット分析"
  # === Phase D: 予測モデル (5 tasks) ===
  "D|model_design|R5レポートに基づき予測パスモデル(NumPy/SQLite)を実装し、prediction_paths生成"
  "D|matching_algorithm|10archetype×8 LCA cluster=80セルマッチング行列を生成"
  "D|simulation_paths|各archetypeの活躍経路シミュレーション（学校→大学→職業→活躍）"
  "D|confidence_intervals|予測の信頼区間とシナリオ分岐を計算"
  "D|interpretation_layer|モデル説明可能性（rationale）を各予測に付与"
  # === Phase E: 偉人×時代翻訳 (8 tasks) ===
  "E|eminent_meiji|era-talents meiji 1,412人をBig Five推定+archetype分類"
  "E|eminent_taisho|era-talents taisho 1,196人をBig Five推定+archetype分類"
  "E|eminent_showa_pre|era-talents showa_pre 1,105人をBig Five推定+archetype分類"
  "E|eminent_showa_post|era-talents showa_post 1,911人をBig Five推定+archetype分類"
  "E|eminent_heisei|era-talents heisei 2,952人をBig Five推定+archetype分類"
  "E|eminent_reiwa|era-talents reiwa 4,382人をBig Five推定+archetype分類"
  "E|era_translation|時代翻訳係数（明治→現代/未来）を計算"
  "E|scenario_persona_fit|10archetype×3未来×複数シナリオの適合スコア生成"
)

prompt_template() {
  local phase="$1"
  local theme="$2"
  local desc="$3"

  cat <<EOF
あなたはPST-DB（Persona-School-Trajectory Integrated DB）構築チームのCodexエージェントです。

【プロジェクト】
JPMS-DB（私立学校DB551校）× era-talents-db（活躍人材12,958人×9時代×19能力次元）× フォーサイトを横断統合し、入学前の子どもの人格 → 適合学校 → 活躍経路 → 偉人パターンの予測モデルを構築する補助DB。

【担当】
phase: Phase ${phase}
theme: ${theme}
説明: ${desc}

【データソース】
- PST DB: ${PST_DB}
- JPMS DB: ${JPMS_DB}
- ETD DB: ${ETD_DB}
- 先行研究: ${RESEARCH_DIR}/R1〜R5_*.md

【投入対象テーブル】
- Phase B: pst.db.school_era_fit
- Phase C: pst.db.school_archetype_fit
- Phase D: pst.db.prediction_paths
- Phase E (eminent_*): pst.db.eminent_persona_profiles
- Phase E (era_translation): pst.db.persona_era_translation
- Phase E (scenario_persona_fit): pst.db.scenario_persona_fit

【先行研究参照（必読）】
- R1 personality_models: Big Five・Holland・自己決定理論
- R2 person_env_fit: P-E Fit理論、Stretch Fit概念
- R3 eminent_personality: 19能力次元→Big Five推定式
- R4 foresight_persona: 10archetype×3未来×シナリオの適合
- R5 predictive_model: マハラノビス距離、ベイジアンネット、GMM

【厳守ルール】
1. 「序列付け」絶対禁止。すべて「相性・適合」フレーム
2. 決定論回避：「この子はこの学校」ではなく「この傾向に合う環境」
3. 時代差異の自覚：偉人パターン直接適用しない、翻訳が必要
4. 不確実性明示：confidence_intervals 併記
5. 50件ずつバッチINSERTで進める

【Phase B 指示】
school_era_fit に 551校×該当時代 のレコードを投入：
- school_id（jpms_school_id 経由）
- era_id（${theme}）
- fit_score（0.0-1.0、jpms culture_score×era_required_traits×era-talents L1/L2/L4から算出）
- matched_capabilities
- rationale_ja

【Phase C 指示】
school_archetype_fit に 該当archetype×551校：
- archetype_id（${theme}）
- school_id、fit_score、fit_type（direct/stretch/poor）
- psychological_rationale（R1, R2の理論引用）
- risks

【Phase D 指示】
prediction_paths に各archetype × 適合学校 → 活躍経路：
- likely_career_domains
- estimated_outcomes（jpms outcome_dim_v2の各次元）
- confidence_interval、scenario_breakdown（SSP1/SSP3/AGI）

【Phase E 指示】
eminent_*: era-talents achievers から該当時代の人物を取得し、
- big_five をachiever_capabilities から推定（R3式）
- holland_codes をdomainから推定
- archetype_id をBig Fiveから判定
- estimation_method='capability_mapping'

era_translation: 各archetype × source_era × target_era の翻訳係数
scenario_persona_fit: 10 archetype × 3 future_era × 各シナリオ

【完了報告】
最終件数を sqlite3 で確認し報告。
EOF
}

case "${1:-help}" in
  status)
    echo "=== PST-DB 進捗 ==="
    for t in school_era_fit school_archetype_fit prediction_paths eminent_persona_profiles persona_era_translation scenario_persona_fit; do
      n=$(sqlite3 "$PST_DB" "SELECT COUNT(*) FROM $t" 2>/dev/null || echo "0")
      printf "  %-30s %s\n" "$t" "$n"
    done
    ;;

  dry-run)
    echo "=== ${#TASKS[@]} タスクプレビュー ==="
    for i in "${!TASKS[@]}"; do
      IFS='|' read -r ph th ds <<< "${TASKS[$i]}"
      printf "%2d. [%s] %-30s\n" "$((i+1))" "$ph" "$th"
    done
    ;;

  launch)
    cat_idx="${2:-1}"
    if [ "$cat_idx" -lt 1 ] || [ "$cat_idx" -gt ${#TASKS[@]} ]; then
      echo "Error"; exit 1
    fi
    task="${TASKS[$((cat_idx - 1))]}"
    IFS='|' read -r ph th ds <<< "$task"
    log="$LOG_DIR/p${ph}_${th}_$(date +%H%M%S).log"
    echo "[起動 #$cat_idx] Phase $ph / $th"
    prompt_template "$ph" "$th" "$ds" | "$CODEX" exec --sandbox workspace-write --skip-git-repo-check > "$log" 2>&1 &
    echo "PID: $!"
    echo "$!" >> "$LOG_DIR/active_pids.txt"
    ;;

  launch_b) for i in 1 2 3 4 5 6 7 8; do $0 launch $i; sleep 2; done ;;
  launch_c) for i in 9 10 11 12 13; do $0 launch $i; sleep 2; done ;;
  launch_d) for i in 14 15 16 17 18; do $0 launch $i; sleep 2; done ;;
  launch_e) for i in 19 20 21 22 23 24 25 26; do $0 launch $i; sleep 2; done ;;

  launch_all)
    $0 launch_b; sleep 30
    $0 launch_c; sleep 30
    $0 launch_d; sleep 30
    $0 launch_e
    ;;

  *)
    cat <<HELP
PST-DB Codex並列ランチャー
Usage: $0 {status|dry-run|launch <N>|launch_b|launch_c|launch_d|launch_e|launch_all}
HELP
    for i in "${!TASKS[@]}"; do
      IFS='|' read -r ph th ds <<< "${TASKS[$i]}"
      printf "  %2d. [%s] %s\n" "$((i+1))" "$ph" "$th"
    done
    ;;
esac
