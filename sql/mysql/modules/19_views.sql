-- ============================================================================
-- 台鐵職工福利平台 — 業務與報表視圖
-- 模組：19_views.sql
-- 說明：唯讀業務視圖，授權後查詢投影
-- 依賴：DDL 模組 01-16
-- ============================================================================

USE tra_welfare_test;

-- VW-01: 職工案件進度時間線
CREATE OR REPLACE VIEW vw_ben_application_progress AS
SELECT
    ba.id AS application_id,
    ba.application_no,
    ba.applicant_employee_id,
    ee.name AS applicant_name,
    ee.employee_no,
    bt.type_name AS benefit_type_name,
    bp.program_name AS benefit_program_name,
    ba.requested_amount,
    ba.approved_amount,
    ba.current_status,
    ba.current_stage,
    ba.submitted_at,
    ba.approved_at,
    ba.closed_at,
    ba.created_at,
    bsh.action_type AS last_action,
    bsh.created_at AS last_action_at,
    bsh.remark AS last_remark
FROM ben_application ba
INNER JOIN emp_employee ee ON ba.applicant_employee_id = ee.id
INNER JOIN ben_type bt ON ba.benefit_type_id = bt.id
INNER JOIN ben_program bp ON ba.benefit_program_id = bp.id
LEFT JOIN ben_application_status_history bsh ON bsh.application_id = ba.id
    AND bsh.created_at = (SELECT MAX(created_at) FROM ben_application_status_history WHERE application_id = ba.id);

-- VW-02: 審核工作台
CREATE OR REPLACE VIEW vw_ben_review_workbench AS
SELECT
    wt.id AS task_id,
    wt.task_code,
    wt.task_status,
    wt.due_at,
    wi.id AS instance_id,
    wi.instance_no,
    ba.id AS application_id,
    ba.application_no,
    ee.name AS applicant_name,
    ee.employee_no,
    ou.unit_name AS applicant_org,
    bt.type_name AS benefit_type_name,
    ba.requested_amount,
    ba.current_status,
    ba.submitted_at,
    aor.overall_confidence AS ocr_confidence,
    aar.severity AS anomaly_severity
FROM wf_task wt
INNER JOIN wf_instance wi ON wt.instance_id = wi.id
INNER JOIN ben_application_workflow baw ON baw.wf_instance_id = wi.id
INNER JOIN ben_application ba ON baw.application_id = ba.id
INNER JOIN emp_employee ee ON ba.applicant_employee_id = ee.id
INNER JOIN ben_type bt ON ba.benefit_type_id = bt.id
LEFT JOIN org_unit ou ON ba.org_unit_id = ou.id
LEFT JOIN (
    SELECT application_id, MAX(overall_confidence) AS overall_confidence
    FROM ai_ocr_result aor2
    INNER JOIN ai_ocr_attempt aoa2 ON aor2.ocr_attempt_id = aoa2.id
    INNER JOIN ai_ocr_job aoj2 ON aoa2.ocr_job_id = aoj2.id
    WHERE aoj2.job_status = 'completed'
    GROUP BY aoj2.application_id
) aor ON aor.application_id = ba.id
LEFT JOIN (
    SELECT application_id, MAX(severity) AS severity
    FROM ai_anomaly_result
    WHERE result_status = 'open'
    GROUP BY application_id
) aar ON aar.application_id = ba.id
WHERE wt.task_status IN ('ready', 'claimed');

-- VW-03: 批次摘要
CREATE OR REPLACE VIEW vw_pay_batch_summary AS
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    pb.batch_type,
    pb.batch_status,
    pb.total_count,
    pb.total_amount,
    pb.currency_code,
    pb.created_at,
    pb.approved_at,
    ou.unit_name AS org_unit_name,
    wsu.unit_name AS welfare_shop_name,
    COALESCE(frc.claim_count, 0) AS claim_count,
    COALESCE(frc.claim_total, 0) AS claim_total,
    COALESCE(far.roster_count, 0) AS roster_count,
    COALESCE(far.roster_total, 0) AS roster_total,
    COALESCE(fv.voucher_count, 0) AS voucher_count,
    COALESCE(fv.voucher_total, 0) AS voucher_total
FROM pay_batch pb
LEFT JOIN org_unit ou ON pb.org_unit_id = ou.id
LEFT JOIN org_unit wsu ON pb.welfare_shop_id = wsu.id
LEFT JOIN (SELECT batch_id, COUNT(*) AS claim_count, COALESCE(SUM(total_amount), 0) AS claim_total
    FROM fin_reimbursement_claim GROUP BY batch_id) frc ON frc.batch_id = pb.id
LEFT JOIN (SELECT source_batch_id, COUNT(*) AS roster_count, COALESCE(SUM(total_amount), 0) AS roster_total
    FROM fin_approval_roster GROUP BY source_batch_id) far ON far.source_batch_id = pb.id
LEFT JOIN (SELECT vsl.source_id, COUNT(DISTINCT fv.id) AS voucher_count, COALESCE(SUM(fv.total_debit), 0) AS voucher_total
    FROM fin_voucher_source_link vsl
    INNER JOIN fin_voucher fv ON vsl.voucher_id = fv.id
    WHERE vsl.source_type = 'batch'
    GROUP BY vsl.source_id) fv ON fv.source_id = pb.id;

-- VW-04: 財務文件一致性查核
CREATE OR REPLACE VIEW vw_fin_document_consistency AS
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    pb.batch_status,
    pb.total_amount AS batch_total,
    COALESCE(frc.claim_total, 0) AS reimbursement_total,
    COALESCE(far.roster_total, 0) AS roster_total,
    COALESCE(fv.voucher_total, 0) AS voucher_total,
    CASE
        WHEN pb.total_amount = COALESCE(frc.claim_total, 0)
         AND pb.total_amount = COALESCE(far.roster_total, 0)
         AND pb.total_amount = COALESCE(fv.voucher_total, 0)
        THEN 'consistent'
        WHEN pb.total_amount = 0 THEN 'empty'
        ELSE 'inconsistent'
    END AS consistency_status
FROM pay_batch pb
LEFT JOIN (SELECT batch_id, COALESCE(SUM(total_amount), 0) AS claim_total
    FROM fin_reimbursement_claim GROUP BY batch_id) frc ON frc.batch_id = pb.id
LEFT JOIN (SELECT source_batch_id, COALESCE(SUM(total_amount), 0) AS roster_total
    FROM fin_approval_roster GROUP BY source_batch_id) far ON far.source_batch_id = pb.id
LEFT JOIN (SELECT vsl.source_id, COALESCE(SUM(fv.total_debit), 0) AS voucher_total
    FROM fin_voucher_source_link vsl
    INNER JOIN fin_voucher fv ON vsl.voucher_id = fv.id
    WHERE vsl.source_type = 'batch'
    GROUP BY vsl.source_id) fv ON fv.source_id = pb.id
WHERE pb.total_amount > 0;

-- VW-05: 已發佈商店與優惠公開欄位
CREATE OR REPLACE VIEW vw_mch_public_offer AS
SELECT
    mm.id AS merchant_id,
    mm.merchant_name,
    mm.phone AS contact_phone,
    mm.description,
    mc.category_name,
    mb.id AS branch_id,
    mb.branch_name,
    mb.address,
    mb.latitude,
    mb.longitude,
    mb.phone AS branch_phone,
    mb.business_hours,
    mo.id AS offer_id,
    mo.offer_title,
    mo.offer_type,
    mo.effective_date AS offer_effective_date,
    mo.expiration_date AS offer_expiration_date,
    mo.is_featured,
    mom.file_id AS media_file_id
FROM mch_merchant mm
INNER JOIN mch_category mc ON mm.category_id = mc.id
INNER JOIN mch_branch mb ON mb.merchant_id = mm.id AND mb.branch_status = 'active'
INNER JOIN mch_offer mo ON mo.merchant_id = mm.id
    AND mo.publish_status = 'published'
    AND mo.effective_date <= CURDATE()
    AND (mo.expiration_date IS NULL OR mo.expiration_date >= CURDATE())
LEFT JOIN mch_offer_media mom ON mom.offer_id = mo.id AND mom.media_type = 'logo'
WHERE mm.is_published = 1 AND mm.merchant_status = 'active';

-- VW-06: 公告發送與已讀彙總
CREATE OR REPLACE VIEW vw_ann_delivery_summary AS
SELECT
    aa.id AS announcement_id,
    aa.announcement_no,
    aa.title,
    aa.announcement_status,
    aa.published_at,
    ac.category_name,
    CONCAT(aa.published_by) AS published_by_name,
    ars.total_recipients,
    ars.delivered_count,
    ars.read_count,
    ROUND(CASE WHEN ars.total_recipients > 0
        THEN ars.read_count / ars.total_recipients * 100 ELSE 0 END, 1) AS read_rate_pct
FROM ann_announcement aa
LEFT JOIN ann_category ac ON aa.category_id = ac.id
LEFT JOIN ann_reach_summary ars ON ars.announcement_id = aa.id
    AND ars.summary_date = CURDATE();

-- VW-07: 授權後審計查詢投影
CREATE OR REPLACE VIEW vw_sec_audit_search AS
SELECT
    sae.id AS event_id,
    sae.event_time,
    sae.module_code,
    sae.action_code,
    sae.actor_name,
    sae.source_ip,
    sae.request_trace,
    sae.object_type,
    sae.object_identifier,
    sae.result_status,
    sae.detail
FROM sec_audit_event sae;
